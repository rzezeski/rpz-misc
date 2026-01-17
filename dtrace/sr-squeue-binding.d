/*
 * Track mac softring and squeue CPU binding as well as IP ring/squeue
 * creation.
 */
ip_squeue_add_ring:entry
{
	this->mrf = (mac_rx_fifo_t *)arg1;
	this->sr = (mac_soft_ring_t *)this->mrf->mrf_rx_arg;

	printf("%-24s %-32s s_ring_cpuid: %-4d mrf_cpu_id: %-4d\n", probefunc,
	    stringof(this->sr->s_ring_name), this->sr->s_ring_cpuid,
	    this->mrf->mrf_cpu_id);
	stack();
}

ip_squeue_bind_ring:entry
{
	this->sr = (mac_soft_ring_t *)args[1]->rr_rx_handle;
	this->cpuid = arg2;

	printf("%-24s %-32s s_ring_cpuid: %-4d cpuid: %-4d\n", probefunc,
	    this->sr->s_ring_name, this->sr->s_ring_cpuid, this->cpuid);
	stack();
}

mac_soft_ring_bind:entry
{
	this->sr = args[0];
	this->cpuid = arg1;

	printf("%-24s %-32s s_ring_cpuid: %-4d cpuid: %-4d\n", probefunc,
	    this->sr->s_ring_name, this->sr->s_ring_cpuid, this->cpuid);
	stack();
}

mac_soft_ring_unbind:entry {
	this->sr = args[0];

	printf("%-24s %-32s s_ring_cpuid: %-4d\n", probefunc,
	    this->sr->s_ring_name, this->sr->s_ring_cpuid);
	stack();
}

squeue_bind:entry
{
	this->sq = args[0];
	this->cpuid = args[1];
	this->sr = (mac_soft_ring_t *)(this->sq->sq_rx_ring->rr_rx_handle);

	printf("%-24s %-32s 0x%p s_ring_cpuid: %-4d cpuid: %-4d\n", probefunc,
	    this->sr->s_ring_name, this->sq, this->sr->s_ring_cpuid, this->cpuid);
	stack();
}

squeue_unbind:entry
{
	this->sq = args[0];
	/* this->sr = (mac_soft_ring_t *)(this->sq->sq_rx_ring->rr_rx_handle); */

	/* printf("%-24s %-32s 0x%p s_ring_cpuid: %-4d\n", probefunc, */
	/*     this->sr->s_ring_name, this->sq, this->sr->s_ring_cpuid); */
	printf("%-24s 0x%p [0x%p] 0x%x\n", probefunc, this->sq,
	    this->sq->sq_rx_ring, this->sq->sq_state);
	stack();
}
