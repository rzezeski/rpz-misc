/*
 * Track various aspects of SRS fanout hashing and viona vring hashing. Tracks
 * only IPv4 traffic.
 */
viona_rx_common:entry
{
	@stacks[stack()] = count();

	this->mp = (mblk_t *)arg1;
	this->b_rptr = this->mp->b_rptr;
	this->etype = htons(*(uint16_t *)(this->b_rptr + 12));
}

/*
 * Track what we see as the "top" mblk when receiving a chain.
 */
viona_rx_common:entry /this->mp->b_next != 0 && this->etype == 0x800/
{
	this->vring = args[0];
	this->b_rptr += 14;	/* skip ether */
	this->b_rptr += 12;	/* start of src ip */
	this->src = inet_ntoa((ipaddr_t *)this->b_rptr);
	this->b_rptr += 4;	/* start of dst ip */
	this->dst = inet_ntoa((ipaddr_t *)this->b_rptr);
	this->b_rptr += 4;	/* start of src port */
	this->sp = htons(*((uint16_t *)this->b_rptr));
	this->b_rptr +=2;	/* start of dst port */
	this->dp = htons(*((uint16_t *)this->b_rptr));

	@top[this->src, this->sp, this->dst, this->dp, this->vring->vr_index,
	    this->vring] = count();

}

mac_rx_soft_ring_drain:entry {
	this->mcip = args[0]->s_ring_set->srs_mcip;
	this->client = stringof(this->mcip->mci_name);
	this->mac = stringof(this->mcip->mci_mip->mi_name);

	@sr[this->mac, this->client, args[0], stringof(args[0]->s_ring_name)] =
	    sum(args[0]->s_ring_count);
	@hist["drain count"] = quantize(args[0]->s_ring_count);
}

mac_rx_soft_ring_process:entry /args[1]->s_ring_first == NULL && args[1]->s_ring_set->srs_rx.sr_poll_pkt_cnt <= 1/ {
	this->mcip = args[1]->s_ring_set->srs_mcip;
	this->client = stringof(this->mcip->mci_name);
	this->mac = stringof(this->mcip->mci_mip->mi_name);

	@counts["SR single pkt"] = count();
	@sr[this->mac, this->client, args[1], stringof(args[1]->s_ring_name)] =
	sum(1);
}

/*
 * Use the viona-pkt-rx probe to inspect what 4-tuples are crossing each vring.
 * We should never see a unique 4-tuple on more than one vring.
 *
 * This probe fires on each individual mblk in the chain, so we don't need to
 * follow b_next.
 */
viona-pkt-rx
{
	this->vring = (viona_vring_t *)arg0;
	this->mp = (mblk_t *)arg1;
	this->len = arg2;
	this->b_rptr = this->mp->b_rptr;
	this->etype = htons(*(uint16_t *)(this->b_rptr + 12));
}

viona-pkt-rx /this->etype == 0x800/
{
	this->b_rptr += 14;	/* skip ether */
	this->b_rptr += 12;	/* start of src ip */
	this->src = inet_ntoa((ipaddr_t *)this->b_rptr);
	this->b_rptr += 4;	/* start of dst ip */
	this->dst = inet_ntoa((ipaddr_t *)this->b_rptr);
	this->b_rptr += 4;	/* start of src port */
	this->sp = htons(*((uint16_t *)this->b_rptr));
	this->b_rptr +=2;	/* start of dst port */
	this->dp = htons(*((uint16_t *)this->b_rptr));

	@vrings[this->src, this->sp, this->dst, this->dp, this->vring->vr_index] =
	    sum(this->len);
}

END {
	printf("=== callstacks for viona_rx_common()\n");
	printa(@stacks);
	printf("\n");

	printf("=== length of softring queue upon drain\n");
	printa(@hist);
	printf("\n");

	printf("=== mac softring distribution\n");
	printf("%-12s %-12s %-18s %-40s %-12s\n", "MAC", "CLIENT", "SOFTRING",
	    "NAME", "PACKETS");
	printa("%-12s %-12s 0x%p %-40s %@u\n", @sr);
	printf("\n");

	printf("=== vring distribution\n");
	printf("%-16s %-6s %-16s %-6s %-4s %-12s\n", "SRC", "SPORT",
	    "DST", "DPORT", "IDX", "BYTES");
	printa("%-16s %-6u %-16s %-6u %-4u %@u\n", @vrings);
	printf("\n");

	printf("=== Top mblk in chain\n");
	printf("%-16s %-6s %-16s %-6s %-4s %-18s %-12s\n", "SRC", "SPORT",
	    "DST", "DPORT", "IDX", "VRING", "COUNT");
	printa("%-16s %-6u %-16s %-6u %-4u 0x%p %@u\n", @top);
}
