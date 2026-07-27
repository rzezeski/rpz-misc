#!/bin/ksh
#
# Print information about the TX queues for the cxgbe devices. This
# hacky script has since been replaced by a proper mdb module.

core_file=${1-}

mdb="mdb -k"
if [[ -n "$core_file" ]]; then
	mdb="mdb $core_file"
fi

cxgbe0=$($mdb <<<'::walk mac_impl_cache |::printf "0x%p %s\n" mac_impl_t . mi_name' \
		 | awk '/cxgbe0/ { print $1 }')

#set -x
$mdb <<EOF
$cxgbe0::print mac_impl_t mi_driver |::print struct port_info adapter |::print struct adapter sge.txq_count |>ntxq
<ntxq="Num TX Queues: "Unn

$cxgbe0::print mac_impl_t mi_driver |::print struct port_info adapter |::print -t struct adapter sge.txq |::array struct sge_txq \$[<ntxq] |::printf "0x%p %4u %4u/%-4u %4u %4u %6u %6u %4u/%-4u %4u %4u\n" struct sge_txq . eq.tse_pending eq.tse_avail eq.tse_qsize eq.tse_pidx eq.tse_cidx eq.tse_spg->pidx eq.tse_spg->cidx tx_dhdl_avail tx_dhdl_total tx_dhdl_pidx tx_dhdl_cidx

EOF
#set +x
