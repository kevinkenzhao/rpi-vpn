# rpi-vpn


This project explores the prospect of converting a Raspberry Pi 4 Model B device into both an OpenVPN server (to which we could connect from personal devices) and client (from which we could connect to a third-party provider like ProtonVPN). When a personal device is successfully connected to our OpenVPN server, it should be able to access Samba services provided by the Pi and all DNS traffic should be routed through the Pi-Hole service living in a Docker container, which will be managed by Portainer. All external traffic should tunnel through the virtual adapter associated with ProtonVPN (see **Remediating DNS Leak**.)

To achieve the flow described above, we will create three bash scripts and make minor adjustments to the openvpn/server.conf file on the Pi.

## Prerequisites

- Raspberry Pi 4
- OpenMediaVault with SMB/CIFS enabled, OMV-Extras (Docker and Portainer) installed
- Pihole (Docker image)
- Subscription to 3rd Party VPN service and access to .ovpn configuration files

## Static IP Addresses

Raspberry Pi: 192.168.0.4/24
OpenVPN server virtual network: 10.8.0.0/24
Pi-hole: 192.168.0.100

## Installation

The easiest way to install OpenVPN onto your Pi 4 device is to run the following command at the terminal:
```
curl -L https://install.pivpn.io | bash
```
During installation, you will be prompted to configure items like a static IP address, OpenVPN server port number, upstream DNS resolver (can be Cloudflare's 1.1.1.1 for now, but will be changed to the IP address of Pi-Hole once it is configured), and whether personal devices will be connecting via your home router's public IP address or a DNS name. This [video](https://www.youtube.com/watch?v=15VjDVCISj0) covers how to set up OpenVPN on a Pi in reasonable depth.

#### Inability to resolve URLs

Shortly prompting you to enable/disable unattended upgrades, the auto-install script will restart the openvpn service, causing a disruption in name resolution (ie. no longer able to access resources by their FQDN):
```
$SUDO systemctl enable openvpn.service &> /dev/null
$SUDO systemctl restart openvpn.service
```
If this occurs, navigate to the ```/etc/resolv.conf```file, which will (likely) have no name servers specified. Add the following lines using sudo:
```
nameserver 1.1.1.1
nameserver 1.1.1.2
```
Otherwise, the installer will exit with an error pertaining to the inability to locate "http://raspbian.raspberrypi.org/raspbian/pool/main/d/distro-info/python3-distro-info_0.21_all.deb". You should be able to to resume configuration of unattended upgrades thereafter.

----

The easiest way to install OpenMediaVault onto your Pi 4 device is to run the following command at the terminal:
```
wget -O - https://github.com/OpenMediaVault-Plugin-Developers/installScript/raw/master/install | sudo bash
```
This [article](https://dbtechreviews.com/2019/12/how-to-install-openmediavault-on-raspberry-pi-4/) covers how to install and set up OpenMediaVault in reasonable depth.

After Docker and Portainer are installed and running, download the Pihole Docker script into your $HOME directory:

```
curl -L https://raw.githubusercontent.com/pi-hole/docker-pi-hole/master/docker_run.sh > docker-pihole.sh
```
Add/change the following:

- Add ```-e WEBPASSWORD="password" \``` where **password** is your desired admin console password.
- ```-p 80:80 \```: change **80** before the colon to any other unused port as openmediavault is listening on port 80. Or, we could configure OMV to listen on a different port and leave this configuration as is.
- ```-e ServerIP="127.0.0.1" \``` change **127.0.0.1** to **192.168.0.100**, which will be used in our macvlan interface
- Optionally, you may replace **${PIHOLE_BASE}** in ```-v "${PIHOLE_BASE}/etc-pihole/:/etc/pihole/" \``` and ```-v "${PIHOLE_BASE}/etc-dnsmasq.d/:/etc/dnsmasq.d/" \``` with a folder of your choice. By default it will create the folder in the same directory from which the docker-pihole.sh script is executed.

Finally, enable the execution bit on the script for the user: ```sudo chmod u+x docker-pihole.sh``` and run! If performed successfully, the container should appear shortly in Portainer.

## High Level Description of Scripts Used

**firewall-openvpn-rules.sh** applies iptables NAT and Forwarding rules between the tunnels from our OpenVPN client(s) to the OpenVPN server and from the Pi to ProtonVPN.

**pihole_while_vpn.sh** creates a macvlan bridge on eth0, adds 192.168.0.100/32 to the bridge, and creates a route to 192.168.0.0/24.

**up.sh** is executed upon connection to ProtonVPN. Similarly, **down.sh** is executed upon connnection teardown. To achieve this, we must include the following in our .ovpn config file which we had downloaded from the ProtonVPN portal:
```
--script-security 2
--up /etc/openvpn/up.sh
--down /etc/openvpn/down.sh
```

To automate the login process, we log our ProtonVPN credentials into a text file and pass it into the .ovpn configuration using the ```auth-user-pass /etc/openvpn/login.txt``` directive.
##### Warning: credentials are neither encrypted nor encoded

## Remediating DNS Leak

By default, a client which does not have a static DNS configuration set relies on the default gateway for name resolution. On a workstation, for example, the traffic will be sent outside of the tunnel to the router. Similarly, if a mobile device is connected to our Pi OpenVPN server, DNS traffic will be router to the carrier. 

Fortunately, we can correct this issue by appending the ```dhcp-option DNS {piholeip}``` directive to the client .ovpn file **or** ```push "dhcp-option DNS {ip}"``` directive on the server configuration at /etc/openvpn/server.conf.
