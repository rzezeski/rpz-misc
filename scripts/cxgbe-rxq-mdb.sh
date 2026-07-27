#!/bin/ksh
#
# Print RX queue state for cxgbe devices. This hacky script has since
# been replaced by a proper mdb module.

core_file=${1-}

mdb_run()
{
	if [[ -n "$core_file" ]]; then
		command mdb "$*" "$core_file"
	else
		command mdb -k "$*"
	fi
}


# tmp_file="mdb-tmp.txt"
cxgbe0=$(mdb_run -e '::walk mac_impl_cache ' \
		 '|::printf "0x%p %s\n" mac_impl_t . mi_name"' \
		 | awk '/cxgbe0/ { printf("%s", $1) }')

# > $tmp_file
# printf "== tmp_file\n"
# cat $tmp_file

# cxgbe0=$(awk '/cxgbe0/ { printf("%s", $1) }' $tmp_file)
echo
echo "cxgbe0: $cxgbe0"

rxq_count=$(mdb_run -e "$cxgbe0::print mac_impl_t mi_driver |::print struct port_info adapter |::printf \"%u\" struct t4nex\`adapter sge.rxq_count")
echo
echo "rxq_count: $rxq_count"

rxqs_file=rxq-addrs.txt
mdb_run -e "$cxgbe0::print mac_impl_t mi_driver |::print struct port_info adapter |::print -t struct t4nex\`adapter sge.rxq |::array struct sge_rxq 0t${rxq_count}" > $rxqs_file
echo "== rxqs"
cat $rxqs_file

rxqs_iq_gen_file="rxqs-iq-gen.txt"
mdb_run -e "::cat $rxqs_file | ::printf \"%x\n\" struct sge_rxq iq.tsi_gen" \
	> $rxqs_iq_gen_file
echo
echo "== rxqs-iq-gen"
cat $rxqs_iq_gen_file

# maybe combine this with above?
rxqs_iq_cidx_file=rxqs-iq-cidx.txt
mdb_run -e "::cat $rxqs_file | ::printf \"%u\n\" struct sge_rxq iq.tsi_cidx" \
	> $rxqs_iq_cidx_file
echo
echo "== rxqs-iq-cidx"
cat $rxqs_iq_cidx_file

rxqs_iq_desc_file=rxqs-iq-desc.txt
mdb_run -e "::cat $rxqs_file | ::printf \"0x%p\\n\" struct sge_rxq iq.tsi_desc" \
	> $rxqs_iq_desc_file
echo
echo "== rxqs-iq-desc"
cat $rxqs_iq_desc_file

rxq0=$(head -1 $rxqs_file)
tsi_cap=$(mdb_run -e "$rxq0::printf \"%u\\n\" struct sge_rxq iq.tsi_cap")
echo
echo "tsi_cap: $tsi_cap"

# now that I have gen + cidx, go through all tsi_desc and determine
# which entries are "outstanding". an entry before cidx is outstanding
# if it has the opposite gen value as tsi_gen because that means the
# device has rolled over the end of the queue and flipped its gen
# value. an entry on or after cidx is outstanding if it has the same
# gen value as tsi_gen

echo
echo "== RX queue state"

num=1
while IFS= read -r line
do
	rxq_addr=$(sed -n -e "${num}p" $rxqs_file)
	iq_gen=$(sed -n -e "${num}p" $rxqs_iq_gen_file)
	iq_cidx=$(sed -n -e "${num}p" $rxqs_iq_cidx_file)

	#echo "== descs rxq: $line iq_gen: $iq_gen iq_cidx: $iq_cidxx
	#set -x

	# RPZ Yes, just pass iq_gen as string, do not prefix iq_gen
	# values with 0x in the preceeding mdb as it will break the
	# comparison below. This is all a big hack.
	printf "rxq: $rxq_addr iq.tsi_desc: $line iq.tsi_gen: 0x%-6s iq.tsi_cidx: %-6u" $iq_gen $iq_cidx
	mdb_run -e "$line,0t$tsi_cap/n56+B7+n" | \
		sed -e '1d' -e '/^[[:space:]]*$/d' \
		-e 's/^[[:space:]]*\([[:alnum:]]\)/\1/' | \
		awk -v iq_gen="$iq_gen" -v iq_cidx="$iq_cidx" '
	{ idx = NR - 1; }
	idx < iq_cidx && $1 != iq_gen { outstanding += 1; }
	idx >= iq_cidx && $1 == iq_gen { outstanding += 1; }
	END { printf("outstanding: %-6u\n", outstanding); }
	'
	#set +x
	num=$((num + 1))
done < $rxqs_iq_desc_file

#
# Now we need to check the "event" queues, where the hardware
# interrupts are actually delivered.
#
intr_per_port=$(mdb_run -e "$cxgbe0::print mac_impl_t mi_driver |::print struct port_info adapter |::printf \"%x\" struct t4nex\`adapter intr_queue_cfg.intr_per_port")
echo
echo "intr_per_port: $intr_per_port"

set -x
intr_iqs_file=cxbge0-intr-iqs.txt
mdb_run -e "$cxgbe0::print mac_impl_t mi_driver " \
	"|::print struct port_info intr_iqs " \
	"|::array t4_sge_iq_t 0x${intr_per_port} " \
	"|::printf \"0x%p 0x%p %u %x %u \\n\" " \
	"t4_sge_iq_t . tsi_desc tsi_cap tsi_gen tsi_cidx" \
	> $intr_iqs_file
set +x

echo "=== intr_iqs_file"
cat $intr_iqs_file

num=1
while IFS=' ' read -r addr descs cap gen cidx
do
	# echo "$addr\t$gen\t$cidx"
	msg="event_iq: $addr tsi_desc: $descs tsi_cap: %-6u "
        msg+="tsi_gen: 0x%-6s tsi_cidx: %-6u"
	printf "$msg" $cap $gen $cidx

	#
	# We need GNU AWK for the bitwise and() function.
	#
	mdb_run -e "$descs,0t${cap}/n56+B7+n" | \
		sed -e '1d' -e '/^[[:space:]]*$/d' \
		-e 's/^[[:space:]]*\([[:alnum:]]\)/0x\1/' | \
		gawk -v iq_gen="0x$gen" -v iq_cidx="$cidx" '
	BEGIN { gen_mask=strtonum("0x80"); iq_gen=strtonum(iq_gen); }
	{ idx = NR - 1; cur_gen=strtonum($1); }
	#{ printf("%s\n", $0); }
	#{ printf("idx: %u 1: %s iq_gen: 0x%x 1: 0x%x and(1, 0x80): %x ", idx, $1, iq_gen, cur_gen, and(cur_gen, gen_mask)); }
	idx < iq_cidx && (and(cur_gen, gen_mask) != and(iq_gen, gen_mask)) { outstanding += 1; }
	idx >= iq_cidx && (and(cur_gen, gen_mask) == and(iq_gen, gen_mask)) { outstanding += 1; }
	#{ printf("\n"); }
	END { printf("outstanding: %-6u\n", outstanding); }
	'
	#set +x
	num=$((num + 1))
done < $intr_iqs_file


