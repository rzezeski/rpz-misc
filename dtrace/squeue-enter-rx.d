/*
 * Track calls to squeue_enter() in the receive path; grouped by (CPU/squeue,
 * destination IP, state, process_flag, sq_count).
 *
 * There is no reason to bother tracking the 'cnt' argument as it is always one
 * (nothing currently enters the squeue with more than one mblk at a time).
 *
 */
ip_input:entry
{
	self->t = 1;
}

ip_input:return
{
	self->t = 0;
}

#define V4_PART_OF_V6(v6) ((v6)._S6_un._S6_u32[3])

squeue_enter:entry /self->t/
{
	this->sqp = args[0];
	/*
	 * The ip module stashes a pointer to the conn_t in b_prev (see
	 * SET_SQUEUE).
	 */
	this->connp = (conn_t *)args[1]->b_prev;
	this->ipdst = &V4_PART_OF_V6(this->connp->connua_v6addr.connua_laddr);
	this->sq_count = this->sqp->sq_count > 1 ? 2 : this->sqp->sq_count;

	@[cpu, arg0, inet_ntoa(this->ipdst), this->sqp->sq_state, arg5,
	    this->sq_count] = count();
}

END
{
	printf("%-4s %-16s %-18s %-10s %-6s %-6s %-8s\n",
	    "CPU", "SQUEUE", "DST IP", "SQ_STATE", "PFLAG", "SQ_CNT", "NUM");
	printa("%-4d 0x%p %-16s 0x%-8x 0x%-4x %-6u %@-8u\n", @);

	printf("\nDecoder Ring:\n");
	printf("\t0x320	SQS_ILL_BOUND|SQS_POLL_CAPAB|SQS_BOUND\n");
	printf("\t0x820	SQS_DEFAULT|SQS_BOUND\n");
	printf("\t0x825	SQS_DEFAULT|SQS_BOUND|SQS_ENTER|SQS_PROC\n");
	printf("\t0x829	SQS_DEFAULT|SQS_BOUND|SQS_FAST|SQS_PROC\n");
}
