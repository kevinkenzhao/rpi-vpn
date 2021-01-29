#!/bin/sh
#Set timeout to wait host network is up and running
sleep 30

#Host macvlan bridge recreate

ip link add macvlan-br0 link eth0 type macvlan mode bridge
ip addr add 192.168.0.100/32 dev macvlan-br0
ip link set macvlan-br0 up
ip route add 192.168.0.0/24 dev macvlan-br0