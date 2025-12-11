#pragma D option quiet
#pragma D option switchrate=500hz

typedef enum {
	STATE_EVENT_IQ_IDLE = 0,
	STATE_EVENT_IQ_PROC_ENTRIES,
	STATE_EVENT_IQ_PROC_INTR_FWDS,

	STATE_RX_IQ_IDLE,

	/* STATE_RX_IQ_INTR_PROC, */
	STATE_RX_IQ_INTR_ACT,

	/* STATE_RX_IQ_POLL_PROC, */
	STATE_RX_IQ_POLL_ACTIVE,

	STATE_RX_IQ_POLL_ON,
	STATE_RX_IQ_POLL_OFF,

	STATE_TX_IDLE,

	/* STATE_TX_SEND_IDLE, */
	STATE_TX_SEND_PROC,

	/* STATE_TX_RECY_IDLE, */
	STATE_TX_RECY_CHECK,
	STATE_TX_RECY_PROC,
	STATE_TX_RECY_FREE,

	STATE_IPERF_USER,
	STATE_IPERF_SEND,
	STATE_IPERF_READ,

	STATE_TCP_SND_QUEUE_FULL,
	STATE_TCP_SND_QUEUE_CLEAR,

	STATE_RX_SR_IDLE,
	STATE_RX_SR_DRAIN,
	STATE_RX_SR_PROC,
	STATE_RX_SR_POLL,

	STATE_TX_SR_IDLE,
	STATE_TX_SR_DRAIN,
	STATE_TX_SR_PROC,

	STATE_RX_SRS_IDLE,
	STATE_RX_SRS_PROC,
	STATE_RX_SRS_DRAIN,
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
	STATE_METADATA(STATE_EVENT_IQ_IDLE, "idle", "#3449EB");
	STATE_METADATA(STATE_EVENT_IQ_PROC_ENTRIES, "proc_entries", "#EB4034");
	STATE_METADATA(STATE_EVENT_IQ_PROC_INTR_FWDS, "proc_fwd",
	    "#34EB77");

	/* RPZ I should maybe make idle and rx-idle one state */
	STATE_METADATA(STATE_RX_IQ_IDLE, "rx-idle", "#3449EB");

	/* STATE_METADATA(STATE_RX_IQ_INTR_PROC, "intr", "#34EB77"); */
	STATE_METADATA(STATE_RX_IQ_INTR_ACT, "intr-act", "#34EB77");

	/* STATE_METADATA(STATE_RX_IQ_POLL_PROC, "poll", "#19F7F4"); */
	STATE_METADATA(STATE_RX_IQ_POLL_ACTIVE, "poll-act", "#19F7F4");

	/* rx-iq-poll entities */
	STATE_METADATA(STATE_RX_IQ_POLL_ON, "poll-on", "#FA14F2");
	STATE_METADATA(STATE_RX_IQ_POLL_OFF, "poll-off", "#750B72");

	STATE_METADATA(STATE_TX_IDLE, "tx-idle", "#3449EB");

	/* STATE_METADATA(STATE_TX_SEND_IDLE, "tx-send-idle", "#3449EB"); */
	STATE_METADATA(STATE_TX_SEND_PROC, "tx-send-proc", "#E0800B");

	/* STATE_METADATA(STATE_TX_RECY_IDLE, "tx-recy-idle", "#3449EB"); */
	STATE_METADATA(STATE_TX_RECY_CHECK, "tx-recy-check", "#8EBD99");
	STATE_METADATA(STATE_TX_RECY_PROC, "tx-recy-proc", "#10B537");
	STATE_METADATA(STATE_TX_RECY_FREE, "tx-recy-free", "#024D14");

	STATE_METADATA(STATE_IPERF_USER, "iperf-user", "#3449EB");
	STATE_METADATA(STATE_IPERF_SEND, "iperf-send", "#9E19E6");
	STATE_METADATA(STATE_IPERF_READ, "iperf-read", "#F005E8");

	STATE_METADATA(STATE_TCP_SND_QUEUE_FULL, "tcp-snd-full", "#EB4034");
	STATE_METADATA(STATE_TCP_SND_QUEUE_CLEAR, "tcp-snd-clear", "#3449EB");

	STATE_METADATA(STATE_RX_SR_IDLE, "rx-sr-idle", "#3449EB");
	STATE_METADATA(STATE_RX_SR_DRAIN, "rx-sr-drain", "#19F7F4");
	STATE_METADATA(STATE_RX_SR_PROC, "rx-sr-proc", "#9E19E6");
	STATE_METADATA(STATE_RX_SR_POLL, "rx-sr-poll", "#024D14");

	STATE_METADATA(STATE_TX_SR_IDLE, "tx-sr-idle", "#3449EB");
	STATE_METADATA(STATE_TX_SR_DRAIN, "tx-sr-drain", "#19F7F4");
	STATE_METADATA(STATE_TX_SR_PROC, "tx-sr-proc", "#9E19E6");

	STATE_METADATA(STATE_RX_SRS_IDLE, "rx-srs-idle", "#3449EB");
	STATE_METADATA(STATE_RX_SRS_DRAIN, "rx-srs-drain", "#19F7F4");
	STATE_METADATA(STATE_RX_SRS_PROC, "rx-srs-proc", "#9E19E6");

	STATE_METADATA(STATE_MAX, "--", "#000000");

	printf("\t}\n}\n");
	start = timestamp;
}

/*
 * ----------------------------------------------------------------------
 * Event IQ transitions
 * ----------------------------------------------------------------------
 */
#define	transition_event_iq(_time, _entity, _state) \
	printf("{ \"time\": \"%d\", \"entity\": \"event-iq-0x%p\", \"state\": %u }\n", \
	    _time - start, _entity, _state);


t4_process_event_iq:entry
{
	self->event_iq = args[0];
	transition_event_iq(timestamp, self->event_iq,
	    STATE_EVENT_IQ_PROC_ENTRIES);
}

t4_process_event_iq:return /self->event_iq/
{
	transition_event_iq(timestamp, self->event_iq, STATE_EVENT_IQ_IDLE);
	self->event_iq = 0;
}

t4_process_rx_iq:entry /self->event_iq/
{
	transition_event_iq(timestamp, self->event_iq,
	    STATE_EVENT_IQ_PROC_INTR_FWDS);
}

/*
 * Make sure to only catch the t4_iq_gts_update() called from inside
 * t4_process_event_iq() by checking the event_iq pointer against arg0.
 */
t4_iq_gts_update:entry /self->event_iq && arg0 == (uint64_t)self->event_iq/
{
	/*
	 * This is technically just doing the GTS update and unlock but didn't
	 * want to make another state for it.
	 */
	transition_event_iq(timestamp, self->event_iq,
	    STATE_EVENT_IQ_PROC_ENTRIES);
}

#undef transition_event_iq

/*
 * ----------------------------------------------------------------------
 * Rx IQ interrupt active/idle transitions (rx-iq-intr) (prefix: rii_)
 * ----------------------------------------------------------------------
 */
#define	transition_rx_iq_intr(_time, _name, _addr, _state)		\
	printf("{ \"time\": \"%d\", \"entity\": \"rx-iq-intr-%s-0x%p\", \"state\": %u }\n", \
	    _time - start, _name, _addr, _state);

/* desc_budget > 0, this is interrupt context  */
t4_process_rx_iq:entry /arg1 > 0/
{
	/*
	 * This is okay as t4_sge_iq_t is always the first member of struct
	 * sge_rxq.
	 */
	self->rii_rx_iq = args[0];
	this->mi = (mac_impl_t *)((struct sge_rxq *)self->rii_rx_iq)->port->mh;
	self->rii_name = stringof(this->mi->mi_name);

	transition_rx_iq_intr(timestamp, self->rii_name, self->rii_rx_iq,
	    STATE_RX_IQ_INTR_ACT);
}

t4_process_rx_iq:return /self->rii_rx_iq/
{
	transition_rx_iq_intr(timestamp, self->rii_name, self->rii_rx_iq,
	    STATE_RX_IQ_IDLE);

	self->rii_name = 0;
	self->rii_rx_iq = 0;
}

#undef transition_rx_iq_intr

/*
 * ----------------------------------------------------------------------
 * Rx IQ polling active/idle transitions (rx-iq-poll) (prefix: rip_)
 * ----------------------------------------------------------------------
 */
#define	transition_rx_iq_poll(_time, _name, _addr, _state)		\
	printf("{ \"time\": \"%d\", \"entity\": \"rx-iq-poll-%s-0x%p\", \"state\": %u }\n", \
	    _time - start, _name, _addr, _state);

/* tpr != NULL, this is polling context */
t4_process_rx_iq:entry /arg2 != NULL/
{
	self->rip_rx_iq = args[0];
	this->mi = (mac_impl_t *)((struct sge_rxq *)self->rip_rx_iq)->port->mh;
	self->rip_name = stringof(this->mi->mi_name);

	transition_rx_iq_poll(timestamp, self->rip_name, self->rip_rx_iq,
	    STATE_RX_IQ_POLL_ACTIVE);
}

t4_process_rx_iq:return /self->rip_rx_iq/
{
	transition_rx_iq_poll(timestamp, self->rip_name, self->rip_rx_iq,
	    STATE_RX_IQ_IDLE);

	self->rip_name = 0;
	self->rip_rx_iq = 0;
}

#undef transition_rx_iq_poll

/*
 * ----------------------------------------------------------------------
 * Rx IQ poll enabled (on/off) transitions (rx-iq-poll-enable)
 *
 * This entities are the same as the rx-iq entities, except they show the
 * polling status of the rx queue. I did it this way because polling mode
 * enable/disable can overlap with the processing states of the rx queue.
 * ----------------------------------------------------------------------
 */
#define	transition_rx_iq_poll_en(_time, _name, _addr, _state)	\
	printf("{ \"time\": \"%d\", \"entity\": \"rx-iq-poll-enable-%s-0x%p\", \"state\": %u }\n", \
	    _time - start, _name, _addr, _state);

t4_ring_intr_enable:entry
{
	this->rxq = (struct sge_rxq *)arg0;
	this->mi = (mac_impl_t *)(this->rxq)->port->mh;
	this->name = stringof(this->mi->mi_name);

	transition_rx_iq_poll_en(timestamp, this->name, this->rxq,
	    STATE_RX_IQ_POLL_OFF);
}

t4_ring_intr_disable:entry
{
	this->rxq = (struct sge_rxq *)arg0;
	this->mi = (mac_impl_t *)(this->rxq)->port->mh;
	this->name = stringof(this->mi->mi_name);

	transition_rx_iq_poll_en(timestamp, this->name, this->rxq,
	    STATE_RX_IQ_POLL_ON);
}

#undef transition_rx_iq_poll_en

/*
 * ----------------------------------------------------------------------
 * Tx EQ idle/send (tx-send) (prefix: ts_)
 *
 * TODO What about t4_tx_reclaim_credits()? That shouldn't count as sending.
 * ----------------------------------------------------------------------
 */
#define	transition_tx_send(_time, _name, _addr, _state)		\
	printf("{ \"time\": \"%d\", \"entity\": \"tx-send-%s-0x%p\", \"state\": %u }\n", \
	    _time - start, _name, _addr, _state);

t4_eth_tx:entry
{
	self->ts_txq = (struct sge_txq*)arg0;
	this->mi = (mac_impl_t *)(self->ts_txq)->port->mh;
	self->ts_name = stringof(this->mi->mi_name);

	transition_tx_send(timestamp, self->ts_name, self->ts_txq,
	    STATE_TX_SEND_PROC);
}

t4_eth_tx:return /self->ts_txq/
{
	transition_tx_send(timestamp, self->ts_name, self->ts_txq,
	    STATE_TX_IDLE);

	self->ts_txq = 0;
	self->ts_name = 0;
}

#undef transition_tx_send

/*
 * ----------------------------------------------------------------------
 * Tx EQ idle/recycle (tx-recy)	(prefix: recy_)
 * ----------------------------------------------------------------------
 */
#define	transition_tx_recy(_time, _name, _entity, _state)		\
	printf("{ \"time\": \"%d\", \"entity\": \"tx-recy-%s-0x%p\", \"state\": %u }\n", \
	    _time - start, _name, _entity, _state);

/* TODO I'll also want to look at any contention on the IQ that is delivering
 * the SGE events */
t4_sge_egr_update:entry
{
	self->recy_ts_entry = timestamp;
	self->recy_track = 1;
}

t4-elide-reclaim /self->recy_track/
{
	self->recy_txq = (struct sge_txq*)arg0;
	this->mi = (mac_impl_t *)(self->recy_txq)->port->mh;
	self->recy_name = stringof(this->mi->mi_name);

	transition_tx_recy(self->recy_ts_entry, self->recy_name,
	    self->recy_txq, STATE_TX_RECY_CHECK);

	self->recy_ts_entry = 0;
}

t4_tx_reclaim_credits:entry /self->recy_track/
{
	self->recy_txq = args[0];
	this->mi = (mac_impl_t *)(self->recy_txq)->port->mh;
	self->recy_name = stringof(this->mi->mi_name);

	transition_tx_recy(self->recy_ts_entry, self->recy_name,
	    self->recy_txq, STATE_TX_RECY_CHECK);

	transition_tx_recy(timestamp, self->recy_name, self->recy_txq,
	    STATE_TX_RECY_PROC);

	self->recy_ts_entry = 0;
}

t4_tx_reclaim_credits:return /self->recy_track/
{
	transition_tx_recy(timestamp, self->recy_name, self->recy_txq,
	    STATE_TX_RECY_FREE);
}

t4_sge_egr_update:return /self->recy_track/
{
	transition_tx_recy(timestamp, self->recy_name, self->recy_txq,
	    STATE_TX_IDLE);

	self->recy_track = 0;
	self->recy_txq = 0;
	self->recy_name = 0;
}

#undef transition_tx_recy

/*
 * ----------------------------------------------------------------------
 * iperf entity (send/read/user)
 *
 * Note that this assumes two processes on same machine: server & client.
 * ----------------------------------------------------------------------
 */
#define	transition_iperf(_time, _pid, _tid, _state)		\
	printf("{ \"time\": \"%d\", \"entity\": \"iperf-%d-%d\", \"state\": %u }\n", \
	    _time - start, _pid, _tid, _state);

#define	transition_iperf_w(_time, _pid, _tid, _state, _tag)		\
	printf("{ \"time\": \"%d\", \"entity\": \"iperf-%d-%d\", \"state\": %u, \"tag\": \"wl-%u\" }\n", \
	    _time - start, _pid, _tid, _state, _tag);

syscall::write:entry /execname == "iperf3"/
{
	this->len = arg2;

	if (!istagged_w[this->len]) {
		istagged_w[this->len] = 1;
		printf("{ \"state\": %u, \"tag\": \"wl-%u\", \"len\": \"%u\" }\n",
		    STATE_IPERF_SEND, this->len, this->len);
	}

	transition_iperf_w(timestamp, pid, tid, STATE_IPERF_SEND, this->len);
}

syscall::write:return /execname == "iperf3"/
{
	transition_iperf(timestamp, pid, tid, STATE_IPERF_USER);
}

#define	transition_iperf_r(_time, _pid, _tid, _state, _tag)		\
	printf("{ \"time\": \"%d\", \"entity\": \"iperf-%d-%d\", \"state\": %u, \"tag\": \"rl-%u\" }\n", \
	    _time - start, _pid, _tid, _state, _tag);

syscall::read:entry /execname == "iperf3"/
{
	this->len = arg2;

	if (!istagged_r[this->len]) {
		istagged_r[this->len] = 1;
		printf("{ \"state\": %u, \"tag\": \"rl-%u\", \"len\": \"%u\" }\n",
		    STATE_IPERF_READ, this->len, this->len);
	}

	transition_iperf_r(timestamp, pid, tid, STATE_IPERF_READ, this->len);
}

syscall::read:return /execname == "iperf3"/
{
	transition_iperf(timestamp, pid, tid, STATE_IPERF_USER);
}

#undef transition_iperf

/*
 * ----------------------------------------------------------------------
 * tcp queue entity (clear/full)
 *
 * This is hard-coded to client sending from 10.0.3.102.
 * ----------------------------------------------------------------------
 */
#define	transition_tcp_snd_queue(_time, _laddr, _lport, _state)			\
	printf("{ \"time\": \"%d\", \"entity\": \"tcp-snd-queue-%s:%u\", \"state\": %u }\n", \
	    _time - start, _laddr, _lport, _state);

tcp_setqfull:entry
{
	this->tcp = args[0];
	this->laddr = this->tcp->tcp_ipha->ipha_src;
	/* this->laddr = inet_ntoa(&this->tcp->tcp_ipha->ipha_src); */
	this->lport = this->tcp->tcp_connp->u_port.connu_ports.connu_lport;
	/* this->tcps = xlate<tcpsinfo_t>(this->tcp); */

	/* if (this->laddr == "10.0.3.102") { */
	if (this->laddr == 0x6603000a) {
		transition_tcp_snd_queue(timestamp, "10.0.3.102",
		    this->lport, STATE_TCP_SND_QUEUE_FULL);
	}
}

tcp_clrqfull:entry
{
	this->tcp = args[0];
	this->laddr = this->tcp->tcp_ipha->ipha_src;
	/* this->laddr = inet_ntoa(&this->tcp->tcp_ipha->ipha_src); */
	this->lport = this->tcp->tcp_connp->u_port.connu_ports.connu_lport;
	/* this->tcps = xlate<tcpsinfo_t>(this->tcp); */

	/* if (this->laddr == "10.0.3.102") { */
	if (this->laddr == 0x6603000a) {
		transition_tcp_snd_queue(timestamp, "10.0.3.102",
		    this->lport, STATE_TCP_SND_QUEUE_CLEAR);
	}
}

#undef transition_tcp_snd_queue

/*
 * ----------------------------------------------------------------------
 * Rx softring entities:
 *
 *  - drain entity
 *  - poll entity
 *  - proc entity
 * ----------------------------------------------------------------------
 */

/*
 * ----------------------------------------------------------------------
 * Rx softring drain entity (rx-sr-drain) (prefix: rsd)
 * ----------------------------------------------------------------------
 */
#define	transition_rx_sr_drain(_time, _name, _addr, _state)		\
	printf("{ \"time\": \"%d\", \"entity\": \"rx-sr-drain-%s-0x%p\", \"state\": %u }\n", \
	    _time - start, _name, _addr, _state);

mac_rx_soft_ring_drain:entry
{
	this->srs = args[0]->s_ring_set;
	this->mci_name = stringof(this->srs->srs_mcip->mci_name);

	if (strstr(this->mci_name, "cx") != NULL) {
		self->rsd_sr = args[0];
		self->rsd_name = this->mci_name;

		transition_rx_sr_drain(timestamp, self->rsd_name,
		    self->rsd_sr, STATE_RX_SR_DRAIN);
	}
}

mac_rx_soft_ring_drain:return /self->rsd_sr/
{
	transition_rx_sr_drain(timestamp, self->rsd_name, self->rsd_sr,
	    STATE_RX_SR_IDLE);

	self->rsd_sr = 0;
	self->rsd_name = 0;
}

#undef transition_rx_sr_drain

/*
 * ----------------------------------------------------------------------
 * Rx softring process entity (rx-sr-proc) (prefix: rsp)
 * ----------------------------------------------------------------------
 */
#define	transition_rx_sr_proc(_time, _name, _addr, _state)		\
	printf("{ \"time\": \"%d\", \"entity\": \"rx-sr-proc-%s-0x%p\", \"state\": %u }\n", \
	    _time - start, _name, _addr, _state);

mac_rx_soft_ring_process:entry
{
	this->mci_name = stringof(args[0]->mci_name);

	if (strstr(this->mci_name, "cx") != NULL) {
		self->rsp_sr = args[1];
		self->rsp_name = this->mci_name;

		transition_rx_sr_proc(timestamp, self->rsp_name, self->rsp_sr,
		    STATE_RX_SR_PROC);
	}
}

mac_rx_soft_ring_process:return /self->rsp_sr/
{
	transition_rx_sr_proc(timestamp, self->rsp_name, self->rsp_sr,
	    STATE_RX_SR_IDLE);

	self->rsp_sr = 0;
	self->rsp_name = 0;
}

#undef transition_rx_sr_proc

/*
 * ----------------------------------------------------------------------
 * Rx softring poll entity (rx-sr-poll) (prefix: rspoll_)
 * ----------------------------------------------------------------------
 */

#define	transition_rx_sr_poll(_time, _name, _addr, _state)		\
	printf("{ \"time\": \"%d\", \"entity\": \"rx-sr-poll-%s-0x%p\", \"state\": %u }\n", \
	    _time - start, _name, _addr, _state);

mac_soft_ring_poll:entry
{
	this->srs = args[0]->s_ring_set;
	this->mci_name = stringof(this->srs->srs_mcip->mci_name);

	if (strstr(this->mci_name, "cx") != NULL) {
		self->rspoll_sr = args[0];
		self->rspoll_name = this->mci_name;

		transition_rx_sr_poll(timestamp, self->rspoll_name,
		    self->rspoll_sr, STATE_RX_SR_POLL);
	}
}

mac_soft_ring_poll:entry /self->rspoll_sr/
{
	transition_rx_sr_poll(timestamp, self->rspoll_name, self->rspoll_sr,
	    STATE_RX_SR_IDLE);

	self->rspoll_sr = 0;
	self->rspoll_name = 0;
}

#undef transition_rx_sr_poll

/*
 * ----------------------------------------------------------------------
 * Tx softring entities:
 *
 *  - drain entity
 *  - proc entity?
 * ----------------------------------------------------------------------
 */
#define	transition_tx_sr_drain(_time, _name, _addr, _state)		\
	printf("{ \"time\": \"%d\", \"entity\": \"tx-sr-drain-%s-0x%p\", \"state\": %u }\n", \
	    _time - start, _name, _addr, _state);

mac_tx_soft_ring_drain:entry
{
	this->srs = args[0]->s_ring_set;
	this->mci_name = stringof(this->srs->srs_mcip->mci_name);
	if (strstr(this->mci_name, "cx") != NULL) {
		self->tx_sr_drain = args[0];
		self->tx_sr_drain_name = this->mci_name;
		transition_tx_sr_drain(timestamp, self->tx_sr_drain_name,
		    self->tx_sr_drain, STATE_TX_SR_DRAIN);
	}
}

mac_tx_soft_ring_drain:return /self->tx_sr_drain/
{
	transition_tx_sr_drain(timestamp, self->tx_sr_drain_name,
	    self->tx_sr_drain, STATE_TX_SR_IDLE);
	self->tx_sr_drain = 0;
	self->tx_sr_drain_name = 0;
}

#undef transition_tx_sr_drain

#define	transition_tx_sr_proc(_time, _name, _addr, _state)		\
	printf("{ \"time\": \"%d\", \"entity\": \"tx-sr-proc-%s-0x%p\", \"state\": %u }\n", \
	    _time - start, _name, _addr, _state);

mac_tx_soft_ring_process:entry
{
	this->srs = args[0]->s_ring_set;
	this->mci_name = stringof(this->srs->srs_mcip->mci_name);
	if (strstr(this->mci_name, "cx") != NULL) {
		self->tx_sr_proc = args[0];
		self->tx_sr_proc_name = this->mci_name;
		transition_tx_sr_proc(timestamp, self->tx_sr_proc_name,
		    self->tx_sr_proc, STATE_TX_SR_PROC);
	}
}

mac_tx_soft_ring_process:return /self->tx_sr_proc/
{
	transition_tx_sr_proc(timestamp, self->tx_sr_proc_name,
	    self->tx_sr_proc, STATE_TX_SR_IDLE);
	self->tx_sr_proc = 0;
	self->tx_sr_proc_name = 0;
}

#undef transition_tx_sr_proc

/*
 * ----------------------------------------------------------------------
 * Rx SRS entities
 *
 *  - proc entity
 *  - drain entity
 *
 *  Only tracks cxgbe SRSes.
 * ----------------------------------------------------------------------
 */
#define	transition_rx_srs_proc(_time, _name, _addr, _state)		\
	printf("{ \"time\": \"%d\", \"entity\": \"rx-srs-proc-%s-0x%p\", \"state\": %u }\n", \
	    _time - start, _name, _addr, _state);

mac_rx_srs_process:entry
{
	this->srs = (mac_soft_ring_set_t *)arg1;
	this->mci_name = stringof(this->srs->srs_mcip->mci_name);
	if (strstr(this->mci_name, "cx") != NULL) {
		self->rx_srs_proc = this->srs;
		self->rx_srs_proc_name = this->mci_name;
		transition_rx_srs_proc(timestamp, self->rx_srs_proc_name,
		    self->rx_srs_proc, STATE_RX_SRS_PROC);
	}
}

mac_rx_srs_process:return /self->rx_srs_proc/
{
	transition_rx_srs_proc(timestamp, self->rx_srs_proc_name,
	    self->rx_srs_proc, STATE_RX_SRS_IDLE);
	self->rx_srs_proc = 0;
	self->rx_srs_proc_name = 0;
}

#undef transition_rx_srs_proc


#define	transition_rx_srs_drain(_time, _name, _addr, _state)		\
	printf("{ \"time\": \"%d\", \"entity\": \"rx-srs-drain-%s-0x%p\", \"state\": %u }\n", \
	    _time - start, _name, _addr, _state);

mac_rx_srs_drain:entry
{
	this->srs = args[0];
	this->mci_name = stringof(this->srs->srs_mcip->mci_name);
	if (strstr(this->mci_name, "cx") != NULL) {
		self->rx_srs_drain = this->srs;
		self->rx_srs_drain_name = this->mci_name;
		transition_rx_srs_drain(timestamp, self->rx_srs_drain_name,
		    self->rx_srs_drain,  STATE_RX_SRS_DRAIN);
	}
}

mac_rx_srs_drain:return /self->rx_srs_drain/
{
	transition_rx_srs_drain(timestamp, self->rx_srs_drain_name,
	    self->rx_srs_drain, STATE_RX_SRS_IDLE);
	self->rx_srs_drain = 0;
	self->rx_srs_drain_name = 0;
}

#undef transition_rx_srs_drain

tick-1sec
/(timestamp - start) > (2 * 1000000000)/
{
	exit(0);
}
