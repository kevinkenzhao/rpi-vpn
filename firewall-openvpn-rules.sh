#firewall-openvpn-rules.sh !/bin/sh
#tun0 is openvpn server tunnel
#tun1 is PIA client tunnel
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j SNAT --to-source 192.168.0.4 #my openvpn server
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o tun1 -j MASQUERADE
#
iptables -A FORWARD -i tun0 -o tun1 -j ACCEPT
iptables -A FORWARD -i tun1 -o tun0 -j ACCEPT
iptables -A FORWARD -i eth0 -o tun1 -j ACCEPT
iptables -A FORWARD -i tun1 -o eth0 -j ACCEPT
#
# this line lets me access the LAN when both tunnels are up
iptables -I FORWARD -i tun0 -j ACCEPT

#TEST RULE: hopefully this creates a route to SMB server when both tunnels are up
#iptables -A FORWARD -i tun0 -s 10.8.0.0/24 -d 192.168.0.4/32 -j ACCEPT
#iptables -A FORWARD -i tun0 -s 192.168.0.4/32 -d 10.8.0.0/24 -j ACCEPT

#SECOND TEST RULE: The following should be equivalent to the above
#iptables -A FORWARD -i eth0 -o tun0 -j ACCEPT
#iptables -A FORWARD -i tun0 -o eth0 -j ACCEPT