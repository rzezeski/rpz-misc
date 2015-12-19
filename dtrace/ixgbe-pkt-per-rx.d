/*
 * Build histogram of packets received per ixgbe Rx interrupt. The
 * rx_ring->stat_ipackets is a cumulative count. Calculate the before
 * (pktsA) and after (pktsB) difference and you know how many packets
 * were pulled off the ring for that particular call of
 * ixbge_ring_rx().
 */
fbt::ixgbe_ring_rx:entry
{
	self->statp=&args[0]->stat_ipackets;
	self->pktsA=*self->statp;
}

fbt::ixgbe_ring_rx:return
/self->statp && self->pktsA > 0/
{
	this->pktsB=*self->statp;
	@["packets per Rx interrupt"] = quantize(this->pktsB - self->pktsA);
	self->pktsA=0;
	self->statp=0;
}
