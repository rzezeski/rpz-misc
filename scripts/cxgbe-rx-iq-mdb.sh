#!/bin/ksh
#
# Print RX queue entry information for a specific index in a specific
# queue. This hacky script has since been replaced by a proper mdb module.

rxq_addr=${1}
idx=${2}
core_file=${3-}

mdb_run()
{
	if [[ -n "$core_file" ]]; then
		command mdb "$*" "$core_file"
	else
		command mdb -k "$*"
	fi
}

iq_addr=$(mdb_run -e "$rxq_addr::print -a struct sge_rxq iq" \
		  "! awk 'NR == 1 { print \$1 }'")
tsi_desc=$(mdb_run -e "$iq_addr::printf \"0x%p\n\" t4_sge_iq_t tsi_desc")
desc=$(mdb_run -e "$tsi_desc + (0t64 * 0t$idx)=J")
mdb_run -e "::echo \"=== IQ\";" \
	"$iq_addr::print -ta t4_sge_iq_t;" \
	"::echo \"=== rss_header\";" \
	"$desc::print -ta struct rss_header;" \
	"::echo \"=== rsp_ctrl\";" \
	"$desc + 0t48::print -ta struct rsp_ctrl;" \
	"::echo \"=== cpl_rx_pkt\";" \
	"$desc + 0t8::print -ta struct cpl_rx_pkt;"
