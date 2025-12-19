/*
 * Track read/write stats of iperf3 processes. This is useful for characterizing
 * how effeciently the network stack is operating. Any given throughput target
 * (e.g. 40Gbps) is going to have upper bounds on how long a given read/write
 * operation can take given a particular buffer size. For example, for a single
 * iperf TCP stream to reach 40Gbps using the default 128K buffer, you need to
 * achieve at least ~38.1K ops/s. That means that each op must have an average
 * duration of 26μs or less.
 *
 * 40 Gbps = 40_000_000_000 bits/s
 * 40 Gbps = 5_000_000_000 bytes = 48_82_812 Ki
 * 48_82_812Ki / 128Ki = 38_146 ops/s
 * 1_000_000_000ns / 38_146ops = 26_215us
 *
 * Ops/s rounded up, Avg Duration rounded down.
 *
 * Target	Op Len		Ops/s	Avg Duration
 * -------------------------------------------------
 * 10Gbps	128Ki		9.6K	104us
 * 20Gbps	128Ki		19.1K	52us
 * 30Gbps	128Ki		28.7K	34us
 * 40Gbps	128Ki		38.2K	26us
 * 50Gbps	128Ki		47.7K	20.9us
 * 60Gbps	128Ki		57.3K	17.4us
 * 70Gbps	128Ki		66.8K	14.9us
 * 80Gbps	128Ki		76.3K	13.1us
 * 90Gbps	128Ki		85.9K	11.6us
 * 100Gbps	128Ki		95.4K	10.4us
 *
 *
 * As the thoughput target goes up the the ops/s and required duration become
 * untennable for a single stream. Either you need to add parallelism or
 * increase batching/buffer size. By increasing the op size to 256Ki the ops/s
 * halve and the average duration doubles; increase to 512Ki and ops/s are
 * reduced to 1/4th and the duration quadruples.
 *
 * Target	Op Len		Ops/s	Avg Duration
 * -------------------------------------------------
 * 50Gbps	256Ki		23.9K	41.9us
 * 60Gbps	256Ki		28.7K	34.9us
 * 70Gbps	256Ki		33.4K	29.9us
 * 80Gbps	256Ki		38.2K	26.2us
 * 90Gbps	256Ki		42.3K	23.3us
 * 100Gbps	256Ki		47.7K	20.9us
 *
 * These numbers are much more approachable. However, while iperf may interact
 * with the system with this op size that's not the case for the underlying
 * network. In the best case we have TSO (64K) and jumbo frames (9K). That means
 * that sockfs/TCP can send down 64K at a time all the way to the driver on the
 * client side, but the server receives in 9K segments (assuming no hardware or
 * software LRO). So the real question is: how many 9K ops can you run a second?
 *
 * I used 8K because that's currently performing better on cxgbe for me.
 *
 * Target	Op Len		Ops/s	Avg Duration
 * -------------------------------------------------
 * 30Gbps	8K		468.8K	2.13us
 * 40Gbps	8K		625.0K	1.60us
 * 50Gbps	8K		781.3K	1.28us
 * 60Gbps	8K		937.5K	1.06us
 * 70Gbps	8K		1.09M	914ns
 * 80Gbps	8K		1.25M	800ns
 * 90Gbps	8K		1.41M	711ns
 * 100Gbps	8K		1.53M	640ns
 *
 * The other thing that needs to be kept in mind are the sizes of the various
 * queues between the client and server.
 *
 * - TCP send/recv queues
 * - TCP window
 * - SRS/softring queues
 * - cxgbe Tx/Rx queues
 * - internal T6 queues
 * - ???
 *
 * Each of these will dictate the total amount of outstanding data that can be
 * in flight before backpressure is applied, threads wait/sleep, or packets are
 * dropped. Anytime any part of the system is changed this script is vital for
 * understanding what effect it's having from iperf's perspective. A key aspect
 * of all of this is that the sender is going to have an easier time sending
 * data than the server will have reading it; so it often helps to focus on the
 * receive path. But, conversely, a slow server will slow down the sender.
 *
 */
syscall::read:entry /execname == "iperf3"/
{
	self->ts = timestamp;
}

syscall::read:return /self->ts/
{
	this->delta = timestamp - self->ts;
	this->ps = stringof(curpsinfo->pr_psargs);

	@rl[this->ps, "read lat"] = lquantize(this->delta, 0, 48000, 4000);
	@rs[this->ps, "read len act"] = quantize(arg1);

	@ra[this->ps, "read lat avg"] = avg(this->delta);
	@ra[this->ps, "read len act avg"] = avg(arg1);

	self->ts = 0;
}

syscall::write:entry /execname == "iperf3"/
{
	self->ts = timestamp;
}

syscall::write:return /self->ts/
{
	this->delta = timestamp - self->ts;
	this->ps = stringof(curpsinfo->pr_psargs);

	@wl[this->ps, "write lat"] = lquantize(this->delta, 0, 48000, 4000);
	@ws[this->ps, "write len act"] = quantize(arg1);

	@wa[this->ps, "write lat avg"] = avg(this->delta);
	@wa[this->ps, "write len act avg"] = avg(arg1);

	self->ts = 0;
}

END
{
	printf("=== READ STATS\n");
	printa(@rl);
	printa(@rs);
	printa(@ra);

	printf("\n=== WRITE STATS\n");
	printa(@wl);
	printa(@ws);
	printa(@wa);
}
