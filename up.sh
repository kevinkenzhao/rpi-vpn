#!/bin/sh
ip rule add from 192.168.0.4 table 10
ip route add default via 192.168.0.1 table 10 #my router