#!/bin/bash

echo "--- ndd IP ---"
ndd /dev/ip \? | \
	awk '{ print $1 }' | \
	while read name
	do
		val=$(pfexec ndd -get /dev/ip $name);
		printf "%-32s %-16s\n" $name $val;
	done

echo
echo "--- ndd TCP ---"
ndd /dev/tcp \? | \
	awk '{ print $1 }' | \
	while read name
	do
		val=$(pfexec ndd -get /dev/tcp $name);
		printf "%-32s %-16s\n" $name $val;
	done
