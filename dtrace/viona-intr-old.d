/*
 * Track viona notifications in both directions, counting frequency by
 * direction, ring, and notification method. Also track totals in each
 * direction per method. A spurious guest-to-host interrupt is when
 * the host receives a notification when there are no waiters to
 * receive it. Per the VRITIO spec, all devices and drivers must
 * accept spurious interrupts, but a large number of them could
 * indicate some dubious logic causing unnecessary work.
 *
 * This is the "old" script, which tracks interrupts in a pre
 * illumos-18243 world.
 *
 * illumos-18243: want F_EVENT_IDX support for viona
 */

/* ioctl notification */
viona_ioc_ring_kick:entry
{
	this->ring = &args[0]->l_vrings[args[1]];
	/* TX rings are odd numbered */
	this->dir = args[1] % 2 == 0 ? "RX" : "TX";
	/* dir, ring, method */
	@gth[this->dir, this->ring, "IOCTL"] = count();
	@gth_total[this->dir, "IOCTL"] = count();

	/*
	 * If the worker is not waiting on the CV, then this interrupt
	 * was not needed.
	 */
	this->cv = (condvar_impl_t *)(&this->ring->vr_cv);
	if (this->cv->cv_waiters == 0) {
		@gth_spurious[this->dir, this->ring, "IOCTL"] = count();
		@gth_spurious_total[this->dir, "IOCTL"] = count();
	}
}

/* I/O port notification */
viona_notify_iop:entry
{
	this->link = (viona_link_t *)args[0];
	this->idx = *args[4];
}

viona_notify_iop:return /arg1 == 0 && this->link/
{
	this->ring = &this->link->l_vrings[this->idx];
	this->dir = this->idx % 2 == 0 ? "RX" : "TX";
	@gth[this->dir, this->ring, "I/O PORT"] = count();
	@gth_total[this->dir, "I/O PORT"] = count();

	this->cv = (condvar_impl_t *)(&this->ring->vr_cv);
	if (this->cv->cv_waiters == 0) {
		@gth_spurious[this->dir, this->ring, "I/O PORT"] = count();
		@gth_spurious_total[this->dir, "I/O PORT"] = count();
	}
}

/* MMIO notification */
viona_notify_mmio:entry /args[1]/
{
	this->link = (viona_link_t *)args[0];
	this->idx = *args[4];
	this->ring = &this->link->l_vrings[this->idx];
	this->dir = this->idx % 2 == 0 ? "RX" : "TX";

	@gth[this->dir, this->ring, "MMIO"] = count();
	@gth_total[this->dir, "MMIO"] = count();

	this->cv = (condvar_impl_t *)(&this->ring->vr_cv);
	if (this->cv->cv_waiters == 0) {
		@gth_spurious[this->dir, this->ring, "MMIO"] = count();
		@gth_spurious_total[this->dir, "MMIO"] = count();
	}
}

viona_intr_ring:entry
{
	self->ring = args[0];
}

vmm_drv_msi:entry /self->ring/
{
	this->dir = self->ring->vr_index % 2 == 0 ? "RX" : "TX";
	this->method = "MSI";
	@htg[this->dir, self->ring, this->method] = count();
	@htg_total[this->dir, this->method] = count();
}

viona_intr_ring:return
{
	self->ring = 0;
}

END
{
	printf("=== GUEST -> HOST INTR =====================\n");
	printa("%s 0x%p %-16s %@u\n", @gth);
	printf(".............................................\n");
	printa("%s                    %-16s %@u\n", @gth_total);

	printf("\n");
	printf("--- SPURIOUS INTR --------------------------\n");
	printa("%s 0x%p %-16s %@u\n", @gth_spurious);
	printf(".............................................\n");
	printa("%s                    %-16s %@u\n", @gth_spurious_total);

	printf("\n");
	printf("=== HOST -> GUEST INTR =====================\n");
	printa("%s 0x%p %-16s %@u\n", @htg);
	printf(".............................................\n");
	printa("%s                    %-16s %@u\n", @htg_total);
}
