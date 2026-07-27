/*
 * Script to help debug if LSO is enabled/disabled from the
 * perspective of TCP/IP.
 */
tcp_update_lso
{
	printf("LSO before: %d after: %d sz: %u\n", arg0, arg1, arg2);
}

tcp_update_lso:entry {
	printf("IXA hdr sz: %u IXA flags: 0x%x\n", args[1]->ixa_ip_hdr_length,
	    args[1]->ixa_flags);
}

conn_connect:entry {
	self->ixa = args[0]->conn_ixa;
	printf("flags: 0x%x\n", arg2);
	printf("ixa_flags: ");
	print(self->ixa->ixa_flags);
	printf("ixa_ipst->ips_ip_lso_outbound: ");
	print(self->ixa->ixa_ipst->ips_propinfo_tbl[54].u.mpi_bval);
}

ip_attr_connect:return /self->ixa/
{
	printf("ixa_ire: 0x%p\n", self->ixa->ixa_ire);
	printf("ixa_ire->ire_type: ");
	print(self->ixa->ixa_ire->ire_type);
	printf("ixa_ire->ire_flags: ");
	print(self->ixa->ixa_ire->ire_flags);
	printf("ixa_nce: 0x%p\n", self->ixa->ixa_nce);
	printf("ixa_nce->nce_ill: 0x%p\n", self->ixa->ixa_nce->nce_ill);
	this->lso_capab = self->ixa->ixa_nce->nce_ill->ill_lso_capab;
	printf("ixa_nce->nce_ill->ill_lso_capab: 0x%p\n", this->lso_capab);
	if (this->lso_capab) {
		printf("ixa_nce->nce_ill->ill_lso_capab->ill_lso_flags: 0x%x\n",
		    this->lso_capab->ill_lso_flags);
	}
}

conn_connect:return
{
	printf("%s:%s %d\n", probefunc, probename, arg1);
	self->ixa = 0;
}
