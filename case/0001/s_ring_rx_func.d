/*
 * Trace all assignments to s_ring_rx_func.
 */
#define ST_RING_TCP             0x0004
#define	ST_RING_UDP		0x0008
#define	ST_RING_OTH		0x0010
#define	ST_RING_TCP6		0x0080
#define	ST_RING_UDP6		0x0100

BEGIN {
	ring_types[ST_RING_TCP] = "TCP";
	ring_types[ST_RING_UDP] = "UDP";
	ring_types[ST_RING_OTH] = "OTH";
	ring_types[ST_RING_TCP6] = "TCP6";
	ring_types[ST_RING_UDP6] = "UDP6";
}

mac_soft_ring_create:entry {
	this->type = args[2];
	this->mcip = args[4];
	this->srs = args[5];
	this->rx_func = arg7;
}

mac_soft_ring_create:return {
	this->softring = args[1];
	this->client = stringof(this->mcip->mci_name);
	this->rname = stringof(this->softring->s_ring_name);

	printf("%s client=%s ring=%s type=%s srs=0x%p rx_func=%a\n",
	    probefunc, this->client, this->rname, ring_types[this->type],
	    this->srs, this->rx_func);
	stack();
}

mac_soft_ring_dls_bypass:entry {
	this->softring = (mac_soft_ring_t *)arg0;
	this->type = this->softring->s_ring_type;
	this->srs = this->softring->s_ring_set;
	this->client = stringof(this->srs->srs_mcip->mci_name);
	this->rname = stringof(this->softring->s_ring_name);
	this->rx_func = arg1;

	printf("%s client=%s ring=%s type=%s srs=0x%p rx_func=%a\n", probefunc,
	    this->client, this->rname, ring_types[this->type], this->srs,
	    this->rx_func);
	stack();
}

mac_srs_client_poll_disable:entry {
	this->mcip = args[0];
	this->srs = args[1];
	this->client = stringof(this->mcip->mci_name);
	/* RPZ there could be more than one softring */
	this->softring = this->srs->srs_soft_ring_head;

	printf("%s client=%s ring=%s type=%s srs=0x%p\n", probefunc,
	    this->client, stringof(this->softring->s_ring_name),
	    ring_types[this->softring->s_ring_type], this->srs);
	stack();
}
