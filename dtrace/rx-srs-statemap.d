/*
 * Track the states of all cxgbe Rx SRSEs.
 *
 *  - SRS processing
 *  - SRS draining
 *  - SRS poll-mode on/off
 *
 * Each entity above is tracked for each Rx SRS that sees traffic.
 * The entity names start with the SRS address so that each SRS's
 * entities are stacked on top of each other.
 */
#pragma D option quiet
#pragma D option bufsize=64m
#pragma D option dynvarsize=64m
#pragma D option switchrate=500hz

typedef enum {
	STATE_IDLE = 0,

	STATE_RX_SRS_PROC,
	STATE_RX_SRS_DRAIN,

	STATE_RX_SRS_POLL_ON,
	STATE_RX_SRS_POLL_OFF,

	STATE_MAX,
} state_t;

#define STATE_METADATA(_state, _str, _color)				\
	printf("\t\t\"%s\": {\"value\": %d, \"color\": \"%s\" }%s\n",	\
	    _str, _state, _color, _state < STATE_MAX ? "," : "")

BEGIN {
	desc = $$1;
	wall = walltimestamp;

	printf("{\n\t\"start\": [ %d, %d ],\n",
	    wall / 1000000000, wall % 1000000000);
	printf("\t\"title\": \"cxgbe queues\",\n");
	printf("\t\"desc\": \"%s\",\n", desc);
	printf("\t\"host\": \"%s\",\n", `utsname.nodename);
	printf("\t\"states\": {\n");

	/* TODO actually pick colors */
	STATE_METADATA(STATE_IDLE, "idle", "#BDBBBB");

	STATE_METADATA(STATE_RX_SRS_DRAIN, "rx-srs-drain", "#19F7F4");
	STATE_METADATA(STATE_RX_SRS_PROC, "rx-srs-proc", "#9E19E6");

	STATE_METADATA(STATE_RX_SRS_POLL_ON, "poll-on", "#FA14F2");
	STATE_METADATA(STATE_RX_SRS_POLL_OFF, "poll-off", "#750B72");


	STATE_METADATA(STATE_MAX, "--", "#000000");

	printf("\t}\n}\n");
	start = timestamp;
}

/*
 * ----------------------------------------------------------------------
 *
 * Track processing of the SRS. This is how the interrupt delivers
 * pacetks to the SRS. Depending on the state of the SRS and the
 * number of packets being delivered, it's either going to do
 * "PROC_FAST" (where everything happens in the interrupt) or
 * enqueue onto the SRS if the poll mode is on (or if latency mode
 * is disabled).
 *
 * ----------------------------------------------------------------------
 */
#define	transition_rx_srs_proc(_time, _name, _addr, _state)		\
	printf("{ \"time\": \"%d\", \"entity\": \"%s-0x%p-rx-srs-proc\", \"state\": %u }\n", \
	    _time - start, _name, _addr, _state);

mac_rx_srs_process:entry
{
	this->ts = timestamp;
	this->srs = (mac_soft_ring_set_t *)arg1;
	this->mci_name = stringof(this->srs->srs_mcip->mci_name);
	if (strstr(this->mci_name, "cx") != NULL) {
		self->rx_srs_proc = this->srs;
		self->rx_srs_proc_name = this->mci_name;
		transition_rx_srs_proc(this->ts, self->rx_srs_proc_name,
		    self->rx_srs_proc, STATE_RX_SRS_PROC);
	}
}

mac_rx_srs_process:return /self->rx_srs_proc/
{
	transition_rx_srs_proc(timestamp, self->rx_srs_proc_name,
	    self->rx_srs_proc, STATE_IDLE);
	self->rx_srs_proc = 0;
	self->rx_srs_proc_name = 0;
}

#undef transition_rx_srs_proc


#define	transition_rx_srs_drain(_time, _name, _addr, _state)		\
	printf("{ \"time\": \"%d\", \"entity\": \"%s-0x%p-rx-srs-drain\", \"state\": %u }\n", \
	    _time - start, _name, _addr, _state);

/*
 * ----------------------------------------------------------------------
 *
 * Track draining of the SRS. This is how packets are delivered
 * from SRS to individual softrings. The drain happens in one of
 * three contexts: PROC_FAST, WORKER, POLLING.
 *
 * ----------------------------------------------------------------------
 */
mac_rx_srs_drain:entry
{
	this->ts = timestamp;
	this->srs = args[0];
	this->mci_name = stringof(this->srs->srs_mcip->mci_name);
	if (strstr(this->mci_name, "cx") != NULL) {
		self->rx_srs_drain = this->srs;
		self->rx_srs_drain_name = this->mci_name;
		transition_rx_srs_drain(this->ts, self->rx_srs_drain_name,
		    self->rx_srs_drain,  STATE_RX_SRS_DRAIN);
	}
}

mac_rx_srs_drain:return /self->rx_srs_drain/
{
	transition_rx_srs_drain(timestamp, self->rx_srs_drain_name,
	    self->rx_srs_drain, STATE_IDLE);
	self->rx_srs_drain = 0;
	self->rx_srs_drain_name = 0;
}

#undef transition_rx_srs_drain


/*
 * ----------------------------------------------------------------------
 *
 * Track poll mode of the SRS. When an SRS enters poll mode it
 * means that the poll thread is responsible for pulling packets
 * from the HW ring and enqueuing them onto the SRS. It is also
 * responsible for draining them if latency mode is on (no active
 * worker).
 *
 * ----------------------------------------------------------------------
 */
#define	transition_rx_srs_poll(_time, _name, _addr, _state)		\
	printf("{ \"time\": \"%d\", \"entity\": \"%s-0x%prx-srs-poll\", \"state\": %u }\n", \
	    _time - start, _name, _addr, _state);

mac_hwring_disable_intr:entry
{
	this->ts = timestamp;
	this->ring = (mac_ring_t *)args[0];
	this->srs = this->ring->mr_srs;
	this->mci_name = stringof(this->srs->srs_mcip->mci_name);
	if (strstr(this->mci_name, "cx") != NULL) {
		transition_rx_srs_poll(this->ts, this->mci_name, this->srs,
		    STATE_RX_SRS_POLL_ON);
	}
}

mac_hwring_enable_intr:entry
{
	this->ts = timestamp;
	this->ring = (mac_ring_t *)args[0];
	this->srs = this->ring->mr_srs;
	this->mci_name = stringof(this->srs->srs_mcip->mci_name);
	if (strstr(this->mci_name, "cx") != NULL) {
		transition_rx_srs_poll(this->ts, this->mci_name, this->srs,
		    STATE_RX_SRS_POLL_OFF);
	}
}

#undef transition_rx_srs_poll

tick-1sec
/(timestamp - start) > (2 * 1000000000)/
{
	exit(0);
}
