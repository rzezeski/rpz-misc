/*
 * Track various aspects of SRS fanout hashing and viona vring hashing.
 */
viona_rx_common:entry {
	@stacks[stack()] = count();
}

mac_rx_soft_ring_drain:entry {
	@sr[args[0], args[0]->s_ring_name] = sum(args[0]->s_ring_count);
	@hist["drain count"] = quantize(args[0]->s_ring_count);
}

mac_rx_soft_ring_process:entry /args[1]->s_ring_first == NULL && args[1]->s_ring_set->srs_rx.sr_poll_pkt_cnt <= 1/ {
	@counts["SR single pkt"] = count();
	@sr[args[1], args[1]->s_ring_name] = sum(1);
}

/*
 *
 * Use the viona-pkt-rx probe to inspect what 4-tuples are crossing each vring.
 * We should never see a unique 4-tuple on more than one vring.
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
	printa(@stacks);
	printf("\n");
	printa(@hist);
	printf("\n");
	printa("0x%p %s %@u\n", @sr);
	printf("\n");
	printa("%-16s %-6u %-16s %-6u %-4u %@u\n", @vrings);
}
