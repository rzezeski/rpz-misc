/*
 * Track packet chain count arriving at Rx SRS for processing
 * (interrupt).
 *
 * XXX Push my new dtrace subroutine to count the length of linked
 * lists to avoid silly scripts like this.
 */
mac_rx_srs_process:entry /args[2] != NULL/ {
	/* XXX need to push this feature */
	/* msgnext_cnt(this->mp); */
	/* list_len(this->mp, b_next, 1024) */
	this->count = 1;
	this->sz = msgsize(args[2]);
	this->mp = args[2]->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

/* 10 */
mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

/* 20 */
mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

/* 30 */
mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

/* 40 */
mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

/* 50 */
mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

/* 60 */
mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

/* 70 */
mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

/* 80 */
mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

/* 90 */
mac_rx_srs_process:entry /this->mp != NULL/ {
	this->count++;
	this->sz += msgsize(this->mp);
	this->mp = this->mp->b_next;
}

mac_rx_srs_process:entry {
	@["RX SRS PROCESS CHAIN COUNT"] = quantize(this->count);
	@["RX SRS PROCESS CHAIN SIZE"] = quantize(this->sz);
}
