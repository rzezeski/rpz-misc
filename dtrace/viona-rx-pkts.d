/*
 * Track size of packets landing at viona rx along with the number of
 * virtio buffers used and their virtio header values.
 */
#pragma D option dynvarsize=64m

viona_recv_merged:entry
{
	@calls[probefunc] = count();
	@l_features[args[0]->vr_link->l_features] = count();
	@["bytes"] = quantize(msgsize(args[1]));
	self->t = 1;
}

/*
 * This function may be called multiple times if more than one buffer is
 * needed to receive the packet; thus it is vital for the correctness of
 * this script to only set self->hdr on the first call. Otherwise,
 * self->hdr will point to packet data.
 */
vq_popchain:entry /self->t/
{
	this->iov = args[1];
}

vq_popchain:return /arg1 > 0 && self->t && !self->hdr/
{
	self->hdr = (struct virtio_net_mrgrxhdr *)(this->iov[0].iov_base);
}

vq_pushchain_many:entry /self->t && self->hdr/
{
	@vrh_bufs[self->hdr->vrh_bufs] = count();
	@vrh_gso_type[self->hdr->vrh_gso_type] = count();
	@vrh_flags[self->hdr->vrh_flags] = count();
	@vrh_gso_size[self->hdr->vrh_gso_size] = count();
	/* @c["vrh_csum_start", this->hdr->vrh_csum_start] = count(); */
	@vrh_hdr_len[self->hdr->vrh_hdr_len] = count();
}

viona_recv_merged:return /self->t/
{
	self->t = 0;
	self->hdr = 0;
}

viona_recv_plain:entry
{
	@calls[probefunc] = count();
}

END {
	printf("*** vrh_flags\n");
	printf("%-16s %s\n", "VALUE", "COUNT");
	printa("0x%-14x %@u\n", @vrh_flags);

	printf("\n");
	printf("*** vrh_bufs\n");
	printf("%-16s %s\n", "VALUE", "COUNT");
	printa("%-16u %@u\n", @vrh_bufs);

	printf("\n");
	printf("*** vrh_gso_type\n");
	printf("%-16s %s\n", "VALUE", "COUNT");
	printa("0x%-14x %@u\n", @vrh_gso_type);

	printf("\n");
	printf("*** vrh_hdr_len\n");
	printf("%-16s %s\n", "VALUE", "COUNT");
	printa("%-16u %@u\n", @vrh_hdr_len);

	printf("\n");
	printf("*** vrh_gso_size\n");
	printf("%-16s %s\n", "VALUE", "COUNT");
	printa("%-16u %@u\n", @vrh_gso_size);

	printf("\n");
	printf("*** l_features\n");
	printf("%-16s %s\n", "VALUE", "COUNT");
	printa("0x%-14x %@u\n", @l_features);

	printf("\n");
	printf("*** calls\n");
	printa(@calls);

	printf("\n");
	printf("*** mblk len\n");
	printa(@);
}
