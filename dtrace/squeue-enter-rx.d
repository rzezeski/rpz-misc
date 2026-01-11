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
	self->t = 4;
}

ip_input:return
{
	self->t = 0;
}

ip_input_v6:entry
{
	self->t = 6;
}

ip_input_v6:return
{
	self->t = 0;
}

#define V4_PART_OF_V6(v6) ((v6)._S6_un._S6_u32[3])

squeue_enter:entry /self->t == 4/
{
	this->sqp = args[0];
	/*
	 * The ip module stashes a pointer to the conn_t in b_prev (see
	 * SET_SQUEUE).
	 */
	this->connp = (conn_t *)args[1]->b_prev;
	this->ipdst = &V4_PART_OF_V6(this->connp->connua_v6addr.connua_laddr);
	this->sq_count = this->sqp->sq_count > 1 ? 2 : this->sqp->sq_count;

	@ip4[cpu, arg0, inet_ntoa(this->ipdst), this->sqp->sq_state, arg5,
	    this->sq_count] = count();
}

squeue_enter:entry /self->t == 6/
{
	this->sqp = args[0];
	/*
	 * The ip module stashes a pointer to the conn_t in b_prev (see
	 * SET_SQUEUE).
	 */
	this->connp = (conn_t *)args[1]->b_prev;
	this->ip6dst = &this->connp->connua_v6addr.connua_laddr;
	this->sq_count = this->sqp->sq_count > 1 ? 2 : this->sqp->sq_count;

	@ip6[cpu, arg0, inet_ntoa6(this->ip6dst), this->sqp->sq_state, arg5,
	    this->sq_count] = count();
}

END
{
	printf("--- IPV4 -----------------------------------------------\n");
	printf("%-4s %-18s %-16s %-10s %-6s %-6s %-8s\n",
	    "CPU", "SQUEUE", "DST IP", "SQ_STATE", "PFLAG", "SQ_CNT", "NUM");
	printa("%-4d 0x%p %-16s 0x%-8x 0x%-4x %-6u %@-8u\n", @ip4);
	printf("\n");

	printf("--- IPV6 -----------------------------------------------\n");
	printf("%-4s %-18s %-28s %-10s %-6s %-6s %-8s\n",
	    "CPU", "SQUEUE", "DST IP", "SQ_STATE", "PFLAG", "SQ_CNT", "NUM");
	printa("%-4d 0x%p %-28s 0x%-8x 0x%-4x %-6u %@-8u\n", @ip6);
	printf("\n");

	printf("--- Decoder Ring ---------------------------------------\n");
	printf("0x320	SQS_ILL_BOUND|SQS_POLL_CAPAB|SQS_BOUND\n");
	printf("0x820	SQS_DEFAULT|SQS_BOUND\n");
	printf("0x825	SQS_DEFAULT|SQS_BOUND|SQS_ENTER|SQS_PROC\n");
	printf("0x829	SQS_DEFAULT|SQS_BOUND|SQS_FAST|SQS_PROC\n");
}
