/*
 * This script assumes ethernet traffic.
 */

#define	MBLKL(mp)	((mp)->b_wptr - (mp)->b_rptr)
#define OK_32PTR(ptr)	(((ptr) & 0x3) == 0)

/* uts/common/sys/stream.h */
#define M_DATA 0x00

/* uts/common/sys/ethernet.h */
#define	ETHERTYPE_IP	(0x0800)
#define	ETHERTYPE_IPV6	(0x86dd)

/* uts/common/netinet/in.h */
#define	IPPROTO_ICMP	1
#define	IPPROTO_TCP	6
#define	IPPROTO_UDP	17
#define	IPPROTO_ICMPV6	58

/* uts/common/sys/mac_provider.h  */
typedef enum mac_classify_type {
	MAC_NO_CLASSIFIER = 0,
	MAC_SW_CLASSIFIER,
	MAC_HW_CLASSIFIER,
	MAC_PASSTHRU_CLASSIFIER
} mac_classify_type_t;

typedef enum mac_ether_offload_flags {
        MEOI_L2INFO_SET         = 1 << 0,
        MEOI_L3INFO_SET         = 1 << 1,
        MEOI_L4INFO_SET         = 1 << 2,
        MEOI_VLAN_TAGGED        = 1 << 3,
        MEOI_L3_FRAG_MORE       = 1 << 4,
        MEOI_L3_FRAG_OFFSET     = 1 << 5
} mac_ether_offload_flags_t;

/* uts/common/sys/mac_soft_ring.h */
#define	SRST_LINK		0x00000001
#define	SRST_FLOW		0x00000002
#define	SRST_NO_SOFT_RINGS	0x00000004

#define	SRST_FANOUT_PROTO	0x00000010
#define	SRST_FANOUT_SRC_IP	0x00000020

#define	SRST_DEFAULT_GRP	0x00000080

#define	SRST_TX			0x00000100
#define	SRST_BW_CONTROL		0x00000200

#define	SRST_DLS_BYPASS		0x00001000
#define	SRST_CLIENT_POLL_ENABLED 0x00002000

/* uts/common/sys/mac_client_impl.h */
#define	MCIS_RX_BYPASS_DISABLE		0x1000


string filter;

BEGIN {
	filter=$$1;
}

mac_rx_srs_proto_fanout:entry {
	this->mac_srs = args[0];
	this->mcip = this->mac_srs->srs_mcip;
	this->client = stringof(this->mcip->mci_name);

	/*
	 * Used to track if we have determined a fanout result for the current
	 * mblk.
	 */
	self->determine_result = 0;
}

mac_rx_srs_proto_fanout:entry /strstr(this->client, filter) != 0/ {
	self->t = 1;
	this->mcip = this->mac_srs->srs_mcip;
	this->srs_ring = this->mac_srs->srs_ring;

	this->hw_classified = this->srs_ring != NULL &&
	    this->srs_ring->mr_classify_type == MAC_HW_CLASSIFIER;

	this->dls_bypass = (this->mac_srs->srs_type & SRST_DLS_BYPASS) &&
	    ((this->mcip->mci_state_flags & MCIS_RX_BYPASS_DISABLE) == 0);

	this->client = stringof(this->mcip->mci_name);
	this->classify = this->hw_classified ? "HW" : "SW";

	this->srs_type = this->mac_srs->srs_type;
	this->type_str = "";

	/*
	 * I don't think LINK and FLOW can coexist, but let's not rule it out
	 * for now.
	 */
	if (this->srs_type & SRST_LINK) {
		this->type_str = strjoin(this->type_str, "LINK|");
	}

	if (this->srs_type & SRST_FLOW) {
		this->type_str = strjoin(this->type_str, "FLOW|");
	}

	if (this->srs_type & SRST_NO_SOFT_RINGS) {
		this->type_str = strjoin(this->type_str, "NO_SOFT_RINGS|");
	}

	if (this->srs_type & SRST_FANOUT_PROTO) {
		this->type_str = strjoin(this->type_str, "FANOUT_PROTO|");
	}

	if (this->srs_type & SRST_FANOUT_SRC_IP) {
		this->type_str = strjoin(this->type_str, "FANOUT_SRC_IP|");
	}

	if (this->srs_type & SRST_DEFAULT_GRP) {
		this->type_str = strjoin(this->type_str, "DEFAULT_GRP|");
	}

	/* This type of SRS should never be processed in rx context. */
	if (this->srs_type & SRST_TX) {
		this->type_str = strjoin(this->type_str, "TX(BUG!)|");
	}

	if (this->srs_type & SRST_BW_CONTROL) {
		this->type_str = strjoin(this->type_str, "BW|");
	}

	if (this->srs_type & SRST_DLS_BYPASS) {
		this->type_str = strjoin(this->type_str, "DLS_BYPASS|");
	}

	if (this->srs_type & SRST_CLIENT_POLL_ENABLED) {
		this->type_str = strjoin(this->type_str, "CLIENT_POLL|");
	}

	/* print the SRS data here */
	printf("%s 0x%p %s %s\n", this->client, this->mac_srs, this->classify,
	    this->type_str);
	printf("\t%-7s %-4s %-9s %-24s %-12s\n", "MSGLEN", "MEOI", "PROTOCOLS",
	    "FASTPATH DISABLE?", "SOFTRING");
}

mac_rx_srs_proto_fanout:return {
	self->t = 0;

	/*
	 * We are returning from mac_rx_srs_proto_fanout() without determining a
	 * result, which means the last packet was queued on OTH ring as it was
	 * determined not to be fastpath capable.
	 */
	if (self->determine_result) {
		self->determine_result = 0;
		printf("OTH (no-fastpath)\n");
	}
}

/*
 * We are calling mac_ether_offload_info() again without determining a result,
 * which means the last packet was queued on OTH ring as it was determined not
 * to be fastpath capable.
 */
mac_ether_offload_info:entry /self->determine_result/ {
	self->determine_result = 0;
	printf("OTH (no-fastpath)\n");
}

mac_ether_offload_info:entry /self->t/ {
	this->mp = args[0];
	this->meoi = args[1];
}

mac_ether_offload_info:return /self->t/ {
	self->determine_result = 1;

	/* print per-mblk info here and if it meets fastpath criteria */
	this->info_str = "NO_MEOI";

	if (this->meoi->meoi_flags & MEOI_L2INFO_SET) {
		this->info_str="L2";
	}

	if (this->meoi->meoi_flags & MEOI_L3INFO_SET) {
		this->info_str = "L3";
	}

	if (this->meoi->meoi_flags & MEOI_L4INFO_SET) {
		this->info_str = "L4";
	}

	if (this->meoi->meoi_flags & MEOI_VLAN_TAGGED) {
		this->info_str = strjoin(this->info_str, "|VLAN");
	}

	if (this->meoi->meoi_flags & MEOI_L3_FRAG_MORE) {
		this->info_str = strjoin(this->info_str, "|L3_FRAG_MORE");
	}

	if (this->meoi->meoi_flags & MEOI_L3_FRAG_OFFSET) {
		this->info_str = strjoin(this->info_str, "|L3_FRAG_OFFSET");
	}

	this->l3proto = this->meoi->meoi_l3proto;
	this->l3str = lltostr(this->l3proto, 16);

	if (this->l3proto == ETHERTYPE_IP) {
		this->l3str = "IP4";
	} else if (this->l3proto == ETHERTYPE_IPV6) {
		this->l3str = "IP6";
	}

	this->l4proto = this->meoi->meoi_l4proto;
	this->l4str = lltostr(this->l4proto, 10);

	if (this->l4proto == IPPROTO_TCP) {
		this->l4str = "TCP/";
	} else if (this->l4proto == IPPROTO_UDP) {
		this->l4str = "UDP/";
	} else if (this->l4proto == IPPROTO_ICMP) {
		this->l4str = "ICMP4/";
	} else if (this->l4proto == IPPROTO_ICMPV6) {
		this->l4str = "ICMP6/";
	}

	this->protos = strjoin(this->l4str, this->l3str);

	this->fps = "";

	this->db_type = this->mp->b_datap->db_type;
	if (this->db_type != M_DATA) {
		this->fps = "!MDATA ";
	}

	this->db_ref = this->mp->b_datap->db_ref;
	if (this->db_ref > 1) {
		this->fps = strjoin(this->fps,
		    strjoin("DB_REF=", lltostr(this->db_ref)));
		this->fps = strjoin(this->fps, " ");
	}

	this->total_hdr = this->meoi->meoi_l2hlen + this->meoi->meoi_l3hlen +
	    this->meoi->meoi_l4hlen;

	this->hdr_spill = this->total_hdr > MBLKL(this->mp);

	if (this->hdr_spill) {
		this->fps = strjoin(this->fps, "HDR_SPILL[");
		this->fps = strjoin(this->fps, lltostr(this->total_hdr));
		this->fps = strjoin(this->fps, ">");
		this->fps = strjoin(this->fps, lltostr(MBLKL(this->mp)));
		this->fps = strjoin(this->fps, "] ");
	}

	this->ip_align = OK_32PTR((uintptr_t)this->mp->b_rptr +
	    this->meoi->meoi_l2hlen);

	if (!this->ip_align) {
		this->fps = strjoin(this->fps, "!IP_32b_ALIGN ");
	}

	printf("\t%-7u %-4s %-9s ", msgsize(this->mp), this->info_str,
	    this->protos);

	if (this->mcip->mci_state_flags & MCIS_RX_BYPASS_DISABLE) {
		this->fps = strjoin(this->fps, "CLIENT-BYPASS-OFF");
	}

	if (this->fps == "") {
		this->fps = "--";
	}

	printf("%-24s ", this->fps);
}

mac-drop /self->determine_result/ {
	self->determine_result = 0;
	printf("DROP\n");
}

no-dls-bypass /self->determine_result/ {
	self->determine_result = 0;
	printf("OTH (no DLS bypass)\n");
}

srs-proto-fanout-proto /self->determine_result/ {
	self->determine_result = 0;
	printf("PROTO\n");
}
