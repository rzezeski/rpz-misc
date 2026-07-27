#!/bin/ksh
#
# Print the next (current) mblk to be read from the device, if one is
# ready. This hacky script has since been replaced by a proper mdb
# module.
#

rxq_addr=${1}
core_file=${2-}

mdb="mdb -k"
if [[ -n "$core_file" ]]; then
	mdb="mdb $core_file"
fi

mdb_run()
{
	if [[ -n "$core_file" ]]; then
		command mdb "$*" "$core_file"
	else
		command mdb -k "$*"
	fi
}

$mdb <<EOF
::offsetof struct sge_rxq iq |>iq_off
$rxq_addr + <iq_off >iq_addr

::offsetof struct sge_rxq fl |>fl_off
$rxq_addr + <fl_off >fl_addr

$rxq_addr::print struct sge_rxq iq.tsi_adapter |>adapter_addr

<iq_addr::printf "0x%p\n" t4_sge_iq_t tsi_cdesc |>desc
<desc + 0t48::print struct rsp_ctrl u.type_gen |>type_gen
// See G_RSPD_TYPE
(<type_gen >> 4) & 0x3 >rsp_type
// See F_RSPD_GEN
(<type_gen & 0x7) >rsp_gen
// See F_RSPD_QOVFL
(<type_gen >> 6) & 0x1 >rsp_overflow

<desc + 0t48 >rsp_ctrl_addr

// The device stores its values in big-endian, we must convernt
<rsp_ctrl_addr::print struct rsp_ctrl pldbuflen_qid |>x

((<x & 0x000000FF) << 0t24) | ((<x & 0x0000FF00) << 0t8) | ((<x & 0x00FF0000) >> 0t8) | ((<x & 0xFF000000) >> 0t24) >dlen_nb
// See F_RSPD_NEWBUF
(<dlen_nb >> 0x31) & 0x1 >nb
// See G_RSPD_LEN
(<dlen_nb & 0x7fffffff) >data_len

0t8>FL_BUF_PTR_PER_HC
// This assumes NEWBUF is 0
<fl_addr::print struct sge_fl eq.tse_cidx |>tse_cidx
<fl_addr::print struct sge_fl cidx_sdesc |>cidx_sdesc
(<tse_cidx * <FL_BUF_PTR_PER_HC) + <cidx_sdesc >fl_sdesc_idx
<fl_sdesc_idx="fl_sdesc_idx: "D

<fl_addr::print struct sge_fl sdesc |>fl_sdesc_base_addr
<fl_sdesc_base_addr="fl_sdesc_base_addr: 0x"J

<fl_sdesc_base_addr + (<fl_sdesc_idx * 0t8) >fl_sdesc_addr
<fl_sdesc_addr="fl_sdes_addr: 0x"J

<fl_sdesc_addr/J |>rxb_addr
// It looks like you can't index into an array with a variable
//<fl_addr::print struct sge_fl sdesc[<fl_sdesc_idx]->rxb |>rxb_addr

<fl_addr::print struct sge_fl offset |>fl_offset
<fl_offset="fl_offset: 0x"J

<iq_addr::printf "tsi_gen: 0x%x\n" t4_sge_iq_t tsi_gen
<adapter_addr::printf "fl_align: %u\n" struct adapter sge.fl_align
<adapter_addr::print -t struct adapter sge
<rsp_gen="RSPD_GEN: 0x"J
<rsp_type="RSPD_TYPE: "J
<rsp_overflow="RSPD_OVERFLOW: "D
<nb="F_RSPD_NEWBUF: "D
<data_len="G_RSPD_LEN: "U

<desc::print -ta struct rss_header
// This assumes rss->opcode == CPL_RX_PKT (0x3B)
<desc + 0t8::print -ta struct cpl_rx_pkt
<rsp_ctrl_addr::print -ta struct rsp_ctrl

<rxb_addr::print -t struct rxbuf

<rxb_addr::print struct rxbuf va |>va
// The 0t2 is for the marging we tell the device to add
<va + <fl_offset + 0t2::print struct ether_header
<va + <fl_offset + 0t2 + 0t14::ip6hdr
<va + <fl_offset + 0t2 + 0t14 + 0t40::udphdr
EOF
