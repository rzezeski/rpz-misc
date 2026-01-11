/*
 * Track flow control on socket receive queue.
 *
 * There is no actual queue of allocated memory, rather the queue consists of a
 * chain of mblks which were sent up from the device driver (unless the data
 * came via mac-loopback). Packets are placed onto the queue by so_queue_msg()
 * which calls so_queue_msg_impl(), and they are read from the queue by
 * so_dequeue_msg() which calls so_check_flow_control().
 *
 * The queue size is stored in so_rcvbuf. Flow control is enabled by
 * so_queue_msg_impl() when there is no space left.
 *
 *    so_rcvbuf - so_rcv_queued <= 0
 *
 * The so_flowctrld flag is set to true to indicate flow control. This can only
 * be cleared by so_check_flow_control(), which clears it when the amount of
 * queued data is below the low watermark.
 *
 *    so_rcv_queued < so_rcvlowat
 *
 * This can only happen as part of reading data off of the socket (by the user
 * application). Until the application reads enough data to get below the low
 * watermark any incoming data will cause the tcp_rwnd to shrink until it
 * reaches zero; at which point the sender should stop sending data.
 *
 * so_rcvbuf (tcp_rwnd)
 * --------------------
 *
 * This value determines how large the receive buffer (queue of linked mblks) is
 * allowed to grow for the given socket. It's the same as the TCP receive
 * window: tcp_rwnd. The tcp_rwnd value comes from conn_rcvbuf, which comes from
 * tcps_recv_hiwat. This value can be get/set via ipadm's 'tcp.recv_buf'.
 *
 * so_rcvlowat
 * -----------
 *
 * The receive buffer low watermark. This value is currently hard-coded to 1024
 * (SOCKET_RECVLOWATER). There is no way to change it.
 *
 *
 * NOTE: so_queue_msg_impl() is very hot, running this script under high
 * throughput will mostly likely reduce performance. We need to add a dedicated
 * SDT flag for flow control state changes.
 *
 */
#define V4_PART_OF_V6(v6) ((v6)._S6_un._S6_u32[3])

so_queue_msg_impl:entry
{
	this->connp = (conn_t *)(args[0]->so_proto_handle);
	this->laddr = V4_PART_OF_V6(this->connp->connua_v6addr.connua_laddr);
	this->fctrlp = &args[0]->so_flowctrld;
	this->before = *this->fctrlp;
}

so_queue_msg_impl:return /this->fctrlp && !this->before && *this->fctrlp/
{
	printf("flow ctrl on\t0x%x\t%u\n", this->laddr, timestamp);
}

so_check_flow_control:entry
{
	this->connp = (conn_t *)args[0]->so_proto_handle;
	this->laddr = V4_PART_OF_V6(this->connp->connua_v6addr.connua_laddr);
	this->fctrlp = &args[0]->so_flowctrld;
	this->before = *this->fctrlp;
}

so_check_flow_control:return /this->fctrlp && this->before && !*this->fctrlp/
{

	printf("flow ctrl off\t0x%x\t%u\n", this->laddr, timestamp);
}
