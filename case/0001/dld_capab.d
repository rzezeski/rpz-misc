/* uts/common/sys/ethernet.h */
#define	ETHERTYPE_IP	(0x0800)
#define	ETHERTYPE_IPV6	(0x86dd)

BEGIN {
	dld_types[1] = "DLD_CAPAB_DIRECT";
	dld_types[2] = "DLD_CAPAB_POLL";
	dld_types[3] = "DLD_CAPAB_PERIM";
	dld_types[4] = "DLD_CAPAB_LSO";
#ifdef SMARTOS
	dld_types[5] = "DLD_CAPAB_IPCHECK";
#endif

	dld_flags[1] = "DLD_ENABLE";
	dld_flags[2] = "DLD_DISABLE";
	dld_flags[3] = "DLD_QUERY";

	saps[0x800] = "IPv4";
	saps[0x86DD] = "IPv6";
}

dld_capab:entry {
	this->dsp=args[0];
	this->mcip = (mac_client_impl_t *)args[0]->ds_mch;
	this->type=args[1];
	this->flags=args[3];
}

dld_capab:return /this->dsp/ {
	this->sap = lltostr(this->dsp->ds_sap, 16);

	if (this->dsp->ds_sap == ETHERTYPE_IP) {
		this->sap = "IPv4";
	} else if (this->dsp->ds_sap == ETHERTYPE_IPV6) {
		this->sap = "IPv6";
	}

	printf("%s %s SAP=%s type=%s flag=%s => %d\n", probefunc,
	    stringof(this->mcip->mci_name), this->sap,
	    dld_types[this->type], dld_flags[this->flags], args[1]);
}

#ifdef SMARTOS
dld_capab_ipcheck:return,
#endif
dld_capab_direct:return,
dld_capab_poll:return,
dld_capab_perim:return,
dld_capab_lso:return
{
	printf("%s => %d\n", probefunc, args[1]);
}
