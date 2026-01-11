/*
 * Track ip squeue creation as it happens and print various information about
 * it.
 */
ip_squeue_add_ring:entry
{
	self->t = 1;
	self->mrfp = (mac_rx_fifo_t *)arg1;
}

ip_squeue_add_ring:return
{
	self->t = 0;
	self->mrfp = 0;
}

ip_squeue_bind_ring:entry /self->t/
{
	this->rr = args[1];	/* ill_rx_ring_t */
	this->cpuid = arg2;
	this->softring = (mac_soft_ring_t *)self->mrfp->mrf_rx_arg;

	printf("sq=0x%p cpu=%d ill_rr=0x%p ill=0x%p [%s] sr=0x%p srs=0x%p\n",
	    this->rr->rr_sqp, this->cpuid, this->rr, this->rr->rr_ill,
	    stringof(this->rr->rr_ill->ill_name), this->softring,
	    this->softring->s_ring_set);
	printf("\n");
	stack();
}
