/*
 * Monitor squeue traffic, showing unique combinations of local address, caller,
 * squeue function, cpu, and squeue. Also track total calls summarized by local
 * adddress.
 *
 * Currently assumes IPv4.
 */
#define V4_PART_OF_V6(v6) ((v6)._S6_un._S6_u32[3])

squeue-proc-start
{
	this->connp = (conn_t *)arg2;
	this->laddr = inet_ntoa(&V4_PART_OF_V6(
		    this->connp->connua_v6addr.connua_laddr));


	@[this->laddr, caller, probefunc, cpu, arg0] = count();
	@stacks[this->laddr, arg0, probefunc, stack()] = count();
	@unique[this->laddr, arg0] = count();
}

END
{
	printf("=== STACKS\n");
	printa(@stacks);

	printf("=== BREAKOUT\n");
	printf("%-16s %-32s %-16s %-4s %-18s %-8s\n",
	    "LADDR", "CALLER", "FUNC", "CPU", "SQUEUE", "COUNT");
	printa("%-16s %-32a %-16s %-4d 0x%p %@-8u\n", @);

	printf("\n");
	printf("=== SUMMARY\n");
	printf("%-16s %-18s %-8s\n", "LADDR", "SQUEUE", "COUNT");
	printa("%-16s 0x%p %@-8u\n", @unique);
}
