#!/usr/bin/ksh
#
# A collection of functions to aid in the creation of network tests.


# Catch unset variables.
set -u

#
# Stolen from Mike Gerdts. Thanks Mike!
#
# https://mgerdts.github.io/2011/01/03/ksh93-stack-traces.html
#
function backtrace {
        typeset -a stack
	#
        # Use "set -u" and an undefined variable access in a subshell
        # to figure out how we got here.  Each token of the result is
        # stored as an element in an indexed array named "stack".
	#
        set -A stack $(exec 2>&1; set -u; unset __unset__; echo $__unset__)

	#
        # Trim the last entries in stack array until we find the one that
        # matches the name of this function.
	#
        typeset i=0
        for (( i = ${#stack[@]} - 1; i >= 0; i-- )); do
                [[ "${stack[i]}" == "${.sh.fun}:" ]] && break
        done

	#
        # Print the name of the function that called this one, stripping off
        # the [lineno] and appending any arguments provided to this function.
	#
        print -u2 "${stack[i-1]/\[[0-9]*\]} $*"

        # Print the backtrace.
        for (( i--; i >= 0; i-- )); do
                print -u2 "\t${stack[i]%:}"
        done
}

function fail
{
	typeset msg="$*"
	echo "FAIL [$TNAME]: $msg" >&2
	backtrace
	exit 1
}

function pass
{
	echo "PASS [$TNAME]"
}

function skip
{
	typeset msg="$*"
	echo "SKIP [$TNAME]: $msg"
}

function link_up
{
	typeset name=$1

	if dladm show-link -po state $name | grep up > /dev/null; then
		return 0
	else
		return 1
	fi
}

function vnic_over
{
	typeset link=$1

	if dladm show-vnic -po over | grep $link > /dev/null; then
		return 0
	else
		return 1
	fi
}

function nic_avail
{
	typeset nic=$1

	link_up $nic
	if [[ $? -ne 0 ]]; then
		return 1
	else
		dladm show-link | grep aggr | grep $nic > /dev/null
		if [[ $? -eq 0 ]]; then
			return 1
		fi
		return 0
	fi
}

function get_macaddr
{
	typeset vnic=$1

	dladm show-vnic -po macaddress $vnic
	if [[ $? -ne 0 ]]; then
		fail "could not get MAC address of VNIC $vnic"
	fi
}

function get_num_groups
{
	typeset nic=$1

	dladm show-phys -po ringtype -H $nic | grep RX | wc -l
}

#
# Get the number of available L2 unicast filters.
#
function get_igb_num_l2_filt
{
	typeset nic=$1

	typeset cmdstr="::walk mac_impl_cache |\
	    ::printf \"0x%p %s 0x%p\n\" mac_impl_t . mi_name mi_driver"
	typeset scratch=$(mdb -k -e "$cmdstr" | awk "/$nic/ { print \$3 }")
	typeset cmdstr="${scratch}::print igb_t unicst_avail |=D"
	integer num_l2_filt=$(pfexec mdb -k -e "$cmdstr")
	echo $num_l2_filt
}

function get_ixgbe_num_l2_filt
{
	typeset nic=$1

	typeset cmdstr="::walk mac_impl_cache |\
	    ::printf \"0x%p %s 0x%p\n\" mac_impl_t . mi_name mi_driver"
	typeset scratch=$(mdb -k -e "$cmdstr" | awk "/$nic/ { print \$3 }")
	typeset cmdstr="${scratch}::print ixgbe_t unicst_avail |=D"
	integer num_l2_filt=$(pfexec mdb -k -e "$cmdstr")
	echo $num_l2_filt
}

function get_i40e_num_l2_filt
{
	typeset nic=$1

	typeset cmdstr="::walk mac_impl_cache |\
	    ::printf \"0x%p %s 0x%p\n\" mac_impl_t . mi_name mi_driver"
	typeset scratch=$(mdb -k -e "$cmdstr" | awk "/$nic/ { print \$3 }")
	typeset cmdstr="${scratch}::print i40e_t"
	typeset cmdstr="$cmdstr i40e_resources.ifr_nmacfilt |=D"
	integer num_l2_filt_total=$(pfexec mdb -k -e "$cmdstr")
	typeset cmdstr="${scratch}::print i40e_t"
	typeset cmdstr="$cmdstr i40e_resources.ifr_nmacfilt_used |=D"
	integer num_l2_filt_used=$(pfexec mdb -k -e "$cmdstr")
	echo $(($num_l2_filt_total - $num_l2_filt_used))
}

function get_num_l2_filt
{
	typeset nic=$1

	case $nic in
	igb*)
		get_igb_num_l2_filt $nic
		;;
	ixgbe*)
		get_ixgbe_num_l2_filt $nic
		;;
	i40e*)
		get_i40e_num_l2_filt $nic
		;;
	*)
		fail "cannot query unknown nic type: $nic"
		;;
	esac
}

function get_mtu
{
	typeset link=$1
	typeset mtu=$(dladm show-linkprop -co value -p mtu $link)
	echo $mtu
}

function get_nic_type
{
	typeset nic=$1

	case $nic in
	ixgbe*)
		echo "ixgbe"
		;;
	i40e*)
		echo "i40e"
		;;
	igb*)
		echo "igb"
		;;
	esac
}

function is_nic_type
{
	typeset nic=$1
	typeset type=$2

	if [ "$(get_nic_type $nic)" == "$type" ]; then
		return 0
	else
		return 1
	fi
}

function get_nic_inst
{
	typeset nic=$1

	case $nic in
	ixgbe*)
		echo $nic | sed -E 's/ixgbe//g'
		;;
	i40e*)
		echo $nic | sed -E 's/i40e//g'
		;;
	igb*)
		echo $nic | sed -E 's/igb//g'
		;;
	esac
}

#
# Return the classification method (HW or SW) for the type of traffic:
# untagged or VLAN.
#
function get_classify_method
{
	typeset nic=$1
	typeset traffic_type=$2
	typeset nic_type=$(get_nic_type $nic)

	#
	# We assume aggrs are made up of identical ports.
	#
	if is_aggr $nic; then
		typeset nic=$(get_aggr_port $nic)
		typeset nic_type=$(get_nic_type $nic)
	fi

	case $nic in
	ixgbe*)
		echo hw
		;;
	i40e*)
		case $traffic_type in
		untagged)
			echo hw
			;;
		vlan)
			echo sw
			;;
		esac
		;;
	igb*)
		echo sw
		;;
	*)
		fail "cannot determine classification method for $nic"
		;;
	esac
}

function has_group_support
{
	typeset nic=$1
	typeset nic_type=$(get_nic_type $nic)
	typeset -A group_map
	group_map["ixgbe"]=true
	group_map["i40e"]=true
	group_map["igb"]=false
	typeset res=${group_map[$nic_type]}

	if [ -z  $res ]; then
		fail "cannot determined group support for $nic"
	fi

	if [ $res == true ]; then
		return 0
	else
		return 1
	fi
}

function create_aggr
{
	typeset name=$1
	typeset port1=$2
	typeset port2=$3

	if ! dladm create-aggr -t -P L2,L3,L4 -L active -T short \
	     -l $port1 -l $port2 $name; then
		fail "failed to create aggr $name: [$port1, $port2]"
	fi
}

function delete_aggr
{
	typeset name=$1

	if ! dladm delete-aggr $name; then
		fail "failed to delete aggr $aggr"
	fi
}

function get_aggr_port
{
	typeset name=$1
	typeset num=${2:-1}
	typeset nr=$(($num + 1))

	dladm show-aggr -xpo port $name | awk -v nr=$nr 'NR == nr { print $0 }'
}

function is_aggr
{
	typeset name=$1

	if dladm show-aggr -po link $name > /dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

function create_vlan
{
	typeset link=$1
	typeset vid=$2
	typeset name="${link}_${vid}"

	dladm create-vlan -t -l $link -v $vid $name

	if [[ $? -ne 0 ]]; then
		fail "failed to create VLAN $name ($vid) over $link"
	fi

	echo "$name"
}

function delete_vlan
{
	typeset name=$1

	dladm delete-vlan -t $name
}

function create_vnic
{
	typeset addr_str=""
	typeset prop_str=""
	typeset vid_str=""

	while getopts ":hm:sv:" opt
	do
		case $opt in
		h)
			prop_str="-p rxrings=hw"
			;;
		m)
			addr_str="-m $OPTARG"
			;;
		s)
			prop_str="-p rxrings=sw"
			;;
		v)
			vid_str="-v $OPTARG"
			;;
		':')
			fail "missing argument to $OPTARG"
			;;
		'?')
			fail "unknown option $OPTARG"
			;;
		esac
	done
	shift $((OPTIND -1))

	typeset link=$1
	typeset vnic=$2

	dladm create-vnic -t -l $link $addr_str $vid_str $prop_str $vnic

	if [[ $? -ne 0 ]]; then
		fail "failed to create VNIC $vnic over $link"
	fi
}

function delete_vnic
{
	typeset vnic=$1

	dladm delete-vnic -t $vnic

	if [[ $? -ne 0 ]]; then
		fail "failed to delete VNIC $vnic"
	fi
}

function primary_up
{
	typeset nic=$1

	if ! ifconfig $nic up; then
		fail "failed to bring up interface $nic"
	fi
}

function primary_down
{
	typeset nic=$1

	if ! ifconfig $nic down; then
		fail "failed to bring down interface $nic"
	fi
}

function create_interface
{
	typeset interface=$1

	ipadm create-if -t $interface

	if [[ $? -ne 0 ]]; then
		fail "failed to create interface $interface"
	fi
}

function delete_interface
{
	typeset interface=$1

	ipadm delete-if $interface

	if [[ $? -ne 0 ]]; then
		fail "failed to delete interface $interface"
	fi
}

function create_addr
{
	typeset iface=$1
	typeset ip=$2

	ipadm create-addr -t -T static -a $ip/24 $iface/v4

	if [[ $? -ne 0 ]]; then
		fail "failed to plumb IP onto $iface"
	fi
}

function delete_addr
{
	typeset iface=$1

	ipadm delete-addr $iface/v4

	if [[ $? -ne 0 ]]; then
		fail "failed to delete addr $iface/v4"
	fi
}

function create_addr6
{
	typeset iface=$1
	typeset ip=$2
	typeset ll_name=${iface}/v6
	typeset uni_name=${iface}/v6add

	if ! ipadm create-addr -t -T addrconf $ll_name; then
		fail "failed to create link-local addr $ll_name"
	fi

	if ! ipadm create-addr -t -T static -a $ip/64 $uni_name; then
		fail "failed to create unicast addr $uni_name"
	fi
}

function delete_addr6
{
	typeset iface=$1
	typeset ll_name=${iface}/v6
	typeset uni_name=${iface}/v6add

	if ! ipadm delete-addr $ll_name; then
		fail "failed to delete link-local addr $ll_name"
	fi

	if ! ipadm delete-addr $uni_name; then
		fail "failed to delete unicast addr $uni_name"
	fi
}

function read_bytes
{
	typeset link=$1
	typeset classify=$2	# hwlane, swlane, hwlane|swlane

	typeset bytes=$(kstat -p $link:::rbytes | \
				egrep "$classify" | \
				grep -v fanout | \
				awk '{ sum += $2 } END { print sum }')

	if [[ -z "$bytes" ]]; then
		fail "failed to read $classify rbytes"
	fi

	echo $bytes
}

function send_traffic
{
	typeset src_file=/tmp/mt_src
	typeset dst_file=/tmp/mt_dst
	typeset digest_file=/tmp/mt_src_digest
	typeset port=7777
	typeset proto=TCP4
	typeset classify="hwlane|swlane"

	while getopts ":6c:" opt
	do
		case $opt in
		6)
			typeset proto=TCP6
			;;
		c)
			typeset classify=$OPTARG
			;;
		'?')
			fail "unknown option $OPTARG"
			;;
		esac
	done
	shift $((OPTIND -1))

	if (($# != 3)); then
		fail "must specify exactly 3 arguments"
	fi

	typeset send_ip=$1
	typeset recv_ip=$2
	typeset recv_vnic=$3

	if [ $classify == hw ]; then
		typeset classify=hwlane
	fi

	if [ $classify == sw ]; then
		typeset classify=swlane
	fi

	ping -i $send_ip $recv_ip > /dev/null
	if [[ $? -ne 0 ]]; then
		fail "failed to ping $recv_ip from $send_ip"
	fi

	#
	# Create a 50M data file.
	#
	dd if=/dev/urandom of=$src_file bs=1024 count=50000 > /dev/null 2>&1
	digest -a sha1 $src_file > $digest_file

	rm -f $dst_file
	socat -u ${proto}-LISTEN:$port,bind=[$recv_ip],reuseaddr \
	      create:$dst_file &
	listener_pid=$!

	typeset bytes_before=$(read_bytes $recv_vnic $classify)

	#
	# Send some traffic to VNIC.
	#
	socat -T 10 -b 4096 STDIN \
	      ${proto}:[$recv_ip]:$port,bind=[$send_ip],connect-timeout=5 \
	      < $src_file
	if (($? != 0)); then
		kill -s TERM $listener_pid
		fail "failed to run socat client"
	fi

	#
	# Verify hwlane counters with kstat.
	#
	typeset bytes_after=$(read_bytes $recv_vnic $classify)
	typeset bytes_delta=$(($bytes_after - $bytes_before))
	typeset bytes_expected=$((1024 * 50000))
	if [[ $bytes_after -lt $bytes_before \
		      || $bytes_delta -lt $bytes_expected ]]
	then
		fail <<EOF
expected at least $bytes_expected bytes on $recv_vnic, saw $bytes_delta
EOF
	fi
}

function verify_nic_type
{
	typeset nic=$1
	typeset type=$2

	if ! echo $nic | grep "$type" > /dev/null; then
		fail "$nic is not of type $type"
	fi
}

function verify_primary_client
{
	typeset nic=$1

	if ! dladm show-phys -po clients -H $nic | grep $nic > /dev/null; then
		fail "no primary client found on $nic"
	fi
}

function verify_num_groups
{
	typeset nic=$1
	typeset expected=$2

	integer num=$(get_num_groups $nic)
	if (($expected != $num)); then
		fail "$nic has unexpected number of groups: $expected != $num"
	fi
}

function verify_num_groups_gte
{
	typeset nic=$1
	typeset expected=$2

	integer num=$(get_num_groups $nic)
	if (($num < $expected)); then
		fail "$nic does not have enough groups: $num < $expected"
	fi
}

function verify_no_primary
{
	typeset nic=$1

	if dladm show-phys -po clients -H | grep $nic; then
		fail "${nic}'s primary interface is already up"
	fi
}

function verify_nic
{
	typeset nic=$1

	if ! nic_avail $nic; then
		fail "link $nic does not exist or is part of aggr"
	fi

	if vnic_over $nic; then
		fail "found existing VNICs over $nic"
	fi
}

function verify_aggr
{
	typeset aggr=$1

	if ! dladm show-link -po state $aggr | grep up > /dev/null; then
		fail "aggr $aggr does not exist or is down"
	fi

	if vnic_over $aggr; then
		failed "found existing VNICs over $aggr"
	fi
}

function verify_if
{
	typeset interface=$1

	if ! ipadm show-if $interface > /dev/null 2>&1; then
		fail "interface $interface does not exist"
	fi
}

function verify_no_ip
{
	typeset ip=$1

	if ipadm show-addr -po addr | grep $ip > /dev/null; then
		fail "ip $ip already exists"
	fi
}

#
# Verify that $vnic is has a reserved (read hardware) group on $link.
# We can't use this with aggr's because a) they aren't exposed via
# `dladm show-phys` and b) the aggr's pseudo groups don't show up
# under the port's `show-phys -H` (it might be nice to rectify this
# situation).
#
function verify_hw_group
{
	typeset link=$1
	typeset client=$2

	if ! dladm show-phys -po ringtype,clients -H $link | grep RX | \
			grep $client > /dev/null
	then
		fail "no group info found for $client on $link"
	fi

	if dladm show-phys -po ringtype,clients -H $link | \
			grep $client | grep RX | grep default > /dev/null
	then
		fail "client $client is not on reserved (HW) group on $link"
	fi
}

#
# The opposite of verify_hw().
#
function verify_sw_group
{
	typeset link=$1
	typeset client=$2

	if ! dladm show-phys -po ringtype,clients -H $link | grep RX | \
			grep $client > /dev/null
	then
		fail "no group info found for $client on $link"
	fi

	if ! dladm show-phys -po ringtype,clients -H $link | \
			grep $client | grep RX | grep default > /dev/null
	then
		fail "client $client is not on default (SW) group on $link"
	fi
}

function verify_hw_lanes
{
	typeset link=$1

	if ! kstat -p $link:::rbytes | grep hwlane > /dev/null; then
		fail "VNIC $recv_vn1 doesn't have SRS hardware lanes"
	fi
}

function verify_sw_lanes
{
	typeset link=$1

	if kstat -p $link:::rbytes | grep hwlane > /dev/null; then
		fail "VNIC $recv_vn1 shouldn't have SRS hardware lanes"
	fi
}

function is_promisc
{
	typeset nic=$1
	typeset nic_type=$(get_nic_type $nic)
	typeset nic_inst=$(get_nic_inst $nic)
	integer promisc=$(kstat -p $nic_type:$nic_inst::promisc | \
					 awk '{ print $2 }')

	if (($promisc == 1)); then
		return 0
	else
		return 1
	fi

}

function verify_ip4_hostmodel
{
	typeset val=$(ipadm show-prop -co current -p hostmodel ipv4)
	if [[ "src-priority" != "$val" ]]; then
		fail "expected ipv4 hostmodel=src-priority, found \"$val\""
	fi
}

function verify_ip6_hostmodel
{
	typeset val=$(ipadm show-prop -co current -p hostmodel ipv6)
	if [[ "src-priority" != "$val" ]]; then
		fail "expected ipv6 hostmodel=src-priority, found \"$val\""
	fi
}

function wait_for_link_up
{
	typeset link=$1
	typeset secs=$2

	while ! dladm show-link -po state $link | grep up > /dev/null; do
		typeset secs=$(($secs - 1))
		if (($secs == 0)); then
			fail "link $link failed to come up"
		fi
		sleep 1
	done
}

#
# Would like to use -P, but there are two issues with it:
#
# 1. It still puts the NIC into promisc even though the man page
#    claims it doesn't. This is a bug in the code.
#
# 2. For some damn reason it doesn't show traffic being sent from the
#    interface.
#
SNOOP='snoop -r'
