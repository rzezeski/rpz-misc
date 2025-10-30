/*
 * illumos#17340 Want IPv6 Fast Path
 *
 * A script to help me determine what's happening ont he rx-side of a
 * mac-loopback IPv6 flow; i.e. why are packets vanishing?
 */

#define ETH_FMT "%x:%x:%x:%x:%x:%x"

srs-proto-fanout-ethertype {
	this->mp = (mblk_t *)arg1;
	this->mac_srs = (mac_soft_ring_set_t *)arg2;
	this->mcip = this->mac_srs->srs_mcip;
	this->name = stringof(this->mcip->mci_name);

	if (strstr(this->name, "rge0") == 0 &&
	    strstr(this->name, "ixgbe0") == 0) {
		printf("mac_rx_srs_proto_fanout %s msgsize(mp)=%u\n",
		    this->name, msgsize(this->mp));
	}
}

mac_rx_soft_ring_process:entry {
	this->mcip = args[0];
	this->mci_name = stringof(this->mcip->mci_name);
}

mac_rx_soft_ring_process:entry /strstr(this->mci_name, "rge0") == 0 &&
    strstr(this->mci_name, "ixgbe0") == 0/ {
	self->t = 1;

	printf("%s mcip=0x%p softring=0x%p %s cnt=%u sz=%u msgsize(mp)=%u ",
	    probefunc, args[0], args[1], stringof(this->mcip->mci_name),
	    args[4], args[5], msgsize(args[2]));
	printf("sr_poll_pkt_cnt=%u s_ring_type=0x%x s_ring_state=0x%x "
	    args[1]->s_ring_set->srs_rx.sr_poll_pkt_cnt, args[1]->s_ring_type,
	    args[1]->s_ring_state, args[1]->s_ring_first);
	printf("s_ring_first=0x%p proc=%a\n", args[1]->s_ring_first,
	    args[1]->s_ring_rx_func);
}

mac_rx_soft_ring_process:return /self->t/ {
	self->t = 0;
}

mac_rx_deliver:entry /self->t/ {
	this->mcip = (mac_client_impl_t *)arg0;
	printf("mci_nvids=%u mci_state_flags=0x%x mci_rx_fn=%a msglen(mp)=%u\n",
	    this->mcip->mci_nvids, this->mcip->mci_state_flags,
	    this->mcip->mci_rx_fn, msgsize(args[2]));
}

mac_strip_vlan_tag_chain:entry /self->t/ {
	this->mp_len = msgsize(args[0]);
}

mac_strip_vlan_tag_chain:return /self->t/ {
	printf("%s msgsize(mp) before=%u after=%u\n", probefunc, this->mp_len,
	    msgsize(args[1]));
}

i_dls_link_rx:entry /self->t/ {
	self->t2 = 1;
	this->mp = args[2];
	printf("%s msgsize(mp)=%u\n", probefunc, msgsize(this->mp));
	stack();
}

i_dls_link_rx:return /self->t/ {
	self->t2 = 0;
}

mac_vlan_header_info:entry /self->t2/ {
	this->mhip = args[2];
}

mac_vlan_header_info:return /self->t2/ {
	this->src = this->mhip->mhi_saddr;
	this->dst = this->mhip->mhi_daddr;

	printf("L2 SAP=0x%x LEN=%u SRC=", this->mhip->mhi_bindsap,
	    this->mhip->mhi_pktsize);
	printf(ETH_FMT, this->src[0], this->src[1], this->src[2], this->src[3],
	    this->src[4], this->src[5]);
	printf(" DST=");
	printf(ETH_FMT, this->dst[0], this->dst[1], this->dst[2], this->dst[3],
	    this->dst[4], this->dst[5]);
	printf("\n");
}

mac_vlan_header_info:return,dls_accept:return /self->t2/ {
	printf("%s => %d\n", probefunc, arg1);
}

mod_hash_find_cb_rval:entry /self->t2/ {
	this->key = (uint64_t)args[1];
	this->rval = args[4];
}

mod_hash_find_cb_rval:return /self->t2/ {
	printf("%s key=0x%x => %d [rval=%d]\n", probefunc, this->key,
	    (int)arg1, *this->rval);
}
