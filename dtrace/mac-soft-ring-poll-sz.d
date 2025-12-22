/*
 * Track the total size (in bytes) of the mblk chain returned from calls to
 * mac_soft_ring_poll(). This is called by the squeue poll thread when polling
 * is enabled.
 *
 * This script was written to prove the existence of a bug in mac, see
 * illumos-17813.
 *
 * https://www.illumos.org/issues/17813
 */
mac_soft_ring_poll:entry
{
	this->bytes_to_pickup = arg1;
}

mac_soft_ring_poll:return
{
	this->mp = args[1];

	/* 1 */
	this->size = this->mp != NULL ? msgsize(this->mp) : 0;
	this->cnt = 1;

	/* 2 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 3 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 4 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 5 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 6 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 7 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 8 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 9 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 10 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 11 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 12 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 16 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 17 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 18 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 19 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 20 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 21 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 22 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 23 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 24 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 25 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 26 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 27 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 28 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 29 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 30 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 31 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	/* 32 */
	this->mp = this->mp != NULL ? this->mp->b_next : NULL;
	this->size += this->mp != NULL ? msgsize(this->mp) : 0;

	@["mblk chain total bytes"] = quantize(this->size);

	if (this->size > this->bytes_to_pickup) {
		@lq["total bytes > bytes_to_pickup"] = lquantize(this->size,
		    150000, 250000, 10000);
		@c["total bytes > bytes_to_pickup"] = count();
	} else {
		@c["total bytes <= bytes_to_pickup"] = count();
	}
}
