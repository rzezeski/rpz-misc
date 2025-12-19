/*
 * Track the number of available descriptors for viona tx/rx queues.
 *
 * For tx this represents the number of descriptors available for the host to
 * send to the driver.
 *
 * For rx this represents the number of descriptors the guest has free/ready for
 * filling by the host.
 *
 * Also track the the total number of "good" receives (successful) and drops on
 * the rx queue. A drop happens when mac has more packets to deliver than the
 * viona rx queue has available.
 */
viona_ring_disable_notify:entry
{
	this->link = args[0]->vr_link;
	self->tx =
	    stringof(((mac_client_impl_t *)this->link->l_mch)->mci_name);
}

viona_ring_num_avail:return /self->tx != 0/
{
	@t["tx", self->tx] = lquantize(arg1, 1, 48, 8);
}

viona_ring_enable_notify:entry /self->tx != 0/
{
	self->tx = 0;
}

viona_rx_common:entry
{
	this->link = args[0]->vr_link;
	self->rx =
	    stringof(((mac_client_impl_t *)this->link->l_mch)->mci_name);
}

viona_ring_num_avail:return /self->rx != 0/
{
	@["rx", self->rx] = lquantize(arg1, 1, 1024, 64);
}

viona_rx_common:return /self->rx != 0/
{
	self->rx = 0;
}

viona-rx
{
	this->link = (viona_link_t *)arg0;
	this->name =
	    stringof(((mac_client_impl_t *)this->link->l_mch)->mci_name);

	@totals[this->name, "rx good"] = sum(arg1);
	@totals[this->name, "rx drop"] = sum(arg2);
}

END
{
	printf("=== Tx available\n");
	printa(@t);
	printf("=== Rx available\n");
	printa(@);
	printf("=== Rx totals\n");
	printa("%s\t%s\t%@u\n", @totals);
}
