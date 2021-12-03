/*
 * Track consumers of a mac_impl_t. Detect any hold (mi_ref) leaks.
 */

mac_hold:entry {
	this->macname = stringof(args[0]);
	this->mip_ptr = args[1];
}

/*
 * Only count successful holds.
 */
mac_hold:return /arg1 == 0/ {
	@holders[execname] = sum(1);

	printf("HOLD pid=%d execname=%s macname=%s mi_ref=%u\n", pid, execname,
	    this->macname, (*this->mip_ptr)->mi_ref);
	ustack();
	stack();
}

/*
 * A mac_rele() ALWAYS decrements, so just check for entry.
 */
mac_rele:entry {
	@holders[execname] = sum(-1);

	printf("RELE pid=%d execname=%s macname=%s mi_ref=%u\n", pid, execname,
	    args[0]->mi_name, args[0]->mi_ref);
	ustack();
	stack();
}

END {
	printf("Remaining holders. ");
	printf("Any non-zero number is a _potential_ leak.\n");
	printa(@holders);
}
