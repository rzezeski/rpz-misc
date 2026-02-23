/*
 * Assumptions:
 *
 *   - post illumos-17526 bits
 *   - headers are in the first mblk
 *   - headers are aligned
 *   - IPv4
 *   - struct adapter.sge.pktshift = 0x2
 *
 * XXX Currently has too great a probe effect, probably due to use of
 * inet_ntoa() and using entry/return probes on t4_fl_get_payload(). I should
 * store IPs in raw format and post-process, and add an SDT probe for per-mblk
 * Rx.
 */

typedef enum mac_ether_offload_flags {
	MEOI_L2INFO_SET		= 1 << 0,
	MEOI_L3INFO_SET		= 1 << 1,
	MEOI_L4INFO_SET		= 1 << 2,
	MEOI_VLAN_TAGGED	= 1 << 3,
	MEOI_L3_FRAG_MORE	= 1 << 4,
	MEOI_L3_FRAG_OFFSET	= 1 << 5
} mac_ether_offload_flags_t;

#define ETHERTYPE_IP (0x0800)

get_frame_txinfo:entry
{
	this->txq = args[0];
	this->mp = *args[1];
	this->txinfop = args[2];
}

get_frame_txinfo:return
{
	this->meoi = &this->txinfop->meoi;
}

get_frame_txinfo:return /(this->meoi->meoi_flags & MEOI_L4INFO_SET) &&
this->meoi->meoi_l4proto == IPPROTO_TCP/
{
	/* Assuming aligned here, maybe shouldn't. */
	this->iphdr = (ipha_t *)(this->mp->b_rptr + this->meoi->meoi_l2hlen);
	/* tcph_t would be for unaligned */
	this->tcph = (tcpha_t *)(this->mp->b_rptr + this->meoi->meoi_l2hlen +
	    this->meoi->meoi_l3hlen);
	@tx[this->txq, "TCP", inet_ntoa(&this->iphdr->ipha_src),
	    ntohs(this->tcph->tha_lport),
	    inet_ntoa(&this->iphdr->ipha_dst),
	    ntohs(this->tcph->tha_fport)] = count();
}

get_frame_txinfo:return /!(this->meoi->meoi_flags & MEOI_L4INFO_SET)/
{
	@tx[this->txq, "OTH", "--", 0, "--", 0] = count();
}

t4_fl_get_payload:entry
{
	this->fl = args[0];
}

t4_fl_get_payload:return /args[1] != NULL/
{
	/* Add 0x2 for adapter.sge.pktshift */
	this->et =
	ntohs(((struct ether_header *)(args[1]->b_rptr + 0x2))->ether_type);
}

t4_fl_get_payload:return /this->et == ETHERTYPE_IP/
{
	this->iphdr = (ipha_t *)(args[1]->b_rptr + 0x2 +
	    sizeof (struct ether_header));
}

t4_fl_get_payload:return /this->iphdr->ipha_protocol == IPPROTO_TCP/
{
	/* Assuming no options. */
	this->tcph = (tcpha_t *)(args[1]->b_rptr + sizeof (struct ether_header) +
	    0x2 + sizeof (ipha_t));
	/*
	 * The FL is embedded in the rxq. Since we only care about mapping flows
	 * to unique queues it's enough to just use the FL address.
	 */
	@rx[this->fl, "TCP", inet_ntoa(&this->iphdr->ipha_src),
	    ntohs(this->tcph->tha_lport),
	    inet_ntoa(&this->iphdr->ipha_dst),
	    ntohs(this->tcph->tha_fport)] = count();
}

t4_fl_get_payload:return /args[1] != NULL && (this->et == 0 ||
    this->iphdr == 0 || this->iphdr->ipha_protocol != IPPROTO_TCP)/
{
	@rx[this->fl, "OTH", "--", 0, "--", 0] = count();
}

END
{
	printf("%-18s %-5s %-16s %-6s %-16s %-6s %-16s\n", "TX QUEUE", "PROTO",
	    "SRC ADDR", "SPORT", "DST ADDR", "DPORT", "NUM PKTS");
	printa("%-18p %-5s %-16s %-6u %-16s %-6u %-16@u\n", @tx);

	printf("%-18s %-5s %-16s %-6s %-16s %-6s %-16s\n", "RX QUEUE", "PROTO",
	    "SRC ADDR", "SPORT", "DST ADDR", "DPORT", "NUM PKTS");
	printa("%-18p %-5s %-16s %-6u %-16s %-6u %-16@u\n", @rx);
}
