/*
 * This script tracks all packets that hit cxgbe Tx and stores:
 *
 * 1. the ethertype
 * 2. the VLAN (if tagged)
 * 3. hardware flags (if any)
 *
 * For each unique combination of the above it tracks total count of
 * packets and the distribution of the packet sizes.
 *
 * Finally, there is a catch-all counter for "other" ethertypes.
 *
 * This script could be made more generic to work with other drivers,
 * probably by hooking into mac_provider_tx() and using `mi_name` to
 * track the link you are intersted in. But I was using this for some
 * specific feature testing so I kept it simple.
 *
 * To run this script use `dtrace -Cqs /path/to/cxgbe-tx-cksum.d`.
 */
#include <sys/types.h>
#include <sys/ethernet.h>

#define	VLAN_ID_MASK	0x0fffu
#define	VLAN_ID(evh)	(ntohs((evh)->ether_tci) & VLAN_ID_MASK)

t4_eth_tx:entry
{
	this->eh = (struct ether_header *)args[1]->b_rptr;
	this->vlan = "--";

	if (ntohs(this->eh->ether_type) == ETHERTYPE_VLAN) {
		this->evh = (struct ether_vlan_header *)args[1]->b_rptr;
		this->vlan = lltostr(VLAN_ID(this->evh));

		if (ntohs(this->evh->ether_type) == ETHERTYPE_IP) {
			this->etype = "IPv4";
		} else if (ntohs(this->evh->ether_type) == ETHERTYPE_IPV6) {
			this->etype = "IPv6";
		} else {
			this->etype = "OTH";
			@oth[ntohs(this->evh->ether_type)] = count();
		}
	} else {
		if (ntohs(this->eh->ether_type) == ETHERTYPE_IP) {
			this->etype = "IPv4";
		} else if (ntohs(this->eh->ether_type) == ETHERTYPE_IPV6) {
			this->etype = "IPv6";
		} else {
			this->etype = "OTH";
			@oth[ntohs(this->eh->ether_type)] = count();
		}
	}

	this->flags = args[1]->b_datap->db_struioun.cksum.flags;
	this->s = "";

	if (this->flags == 0x00) {
		this->s = "--";
	} else if (this->flags == 0x01) {
		this->s = "HDR";
	} else if (this->flags == 0x03) {
		this->s = "HDR + PARTIAL ULP";
	} else if (this->flags == 0x04) {
		this->s = "FULL ULP";
	} else if (this->flags == 0x05) {
		this->s = "HDR + FULL ULP";
	} else if (this->flags == 0x15) {
		this->s = "LSO + HDR + FULL ULP";
	} else {
		printf("unexpected hw checksum flags: 0x%x\n", this->flags);
		this->s = "unexpected";
	}

	@counts[this->etype, this->vlan, this->s] = count();
	@sizes[this->etype, this->vlan, this->s] = quantize(msgsize(args[1]));
}

END
{
	printf("=== COUNTS ===\n");
	printf("%-8s %-8s %-24s %-16s\n", "TYPE", "VLAN", "HW FLAGS",
	    "PKT COUNT");
	printa("%-8s %-8s %-24s %@u\n", @counts);

	printf("\n=== OTHER TRAFFIC TYPES ===\n");
	printa("0x%x %@u\n", @oth);

	printf("\n=== SIZES ===\n");
	printa(@sizes);
}
