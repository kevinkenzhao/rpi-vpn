# rpi-vpn


This project explores the prospect of converting a Raspberry Pi 4 Model B device into both an OpenVPN server (to which we could connect from personal devices) and client (from which we could connect to a third-party provider like ProtonVPN). When a personal device is successfully connected to our OpenVPN server, it should be able to access Samba services provided by the Pi and all DNS traffic should be routed through the Pi-Hole service living in a Docker container, which will be managed by Portainer. All external traffic should tunnel through the virtual adapter associated with ProtonVPN (see **Remediating DNS Leak**.)

To achieve the flow described above, we will create three bash scripts and make minor adjustments to the openvpn/server.conf file on the Pi.

## Prerequisites

- Raspberry Pi 4
- OpenMediaVault with SMB/CIFS enabled, OMV-Extras (Docker and Portainer) installed
- Pihole (Docker image)
- .ovpn configuration files from ProtonVPN (or the third-party VPN provider of choice)

## Static IP Addresses

OpenMediaVault: 192.168.0.4:8001
OpenVPN server virtual network: 10.8.0.0/24
Pi-hole: 192.168.0.4:80

## Installation

### OpenMediaVault

The easiest way to install OpenMediaVault is by running the following command at the terminal:
```
wget -O - https://github.com/OpenMediaVault-Plugin-Developers/installScript/raw/master/install | sudo bash
```
This [article](https://dbtechreviews.com/2019/12/how-to-install-openmediavault-on-raspberry-pi-4/) covers how to install and set up OpenMediaVault in reasonable depth.

Install Docker and Portainer via OMV-Extras at the left-hand menu and ensure they are both running. Then, run ```sudo docker swarm init --advertise-addr {ipofmaininterface}``` and reboot.

Curl the Pihole Docker script into your $HOME directory:

```
curl -L https://raw.githubusercontent.com/pi-hole/docker-pi-hole/master/docker_run.sh > docker-pihole.sh
```
Add/change the following:

- Add ```-e WEBPASSWORD="password" \``` where **password** is your desired admin console password.
- ```-p 80:80 \```: change **80** before the colon to any other unused port as openmediavault is listening on port 80. Or, we could configure OMV to listen on a different port and leave this configuration as is.
- Replace **${PIHOLE_BASE}** in ```-v "${PIHOLE_BASE}/etc-pihole/:/etc/pihole/" \``` and ```-v "${PIHOLE_BASE}/etc-dnsmasq.d/:/etc/dnsmasq.d/" \``` with a folder of your choice. If unchanged, the script will create the folders in the same directory as that of docker-pihole.sh.
- *Optional: ```-e ServerIP="127.0.0.1" \``` change **127.0.0.1** to **192.168.0.100**, which will be used on a macvlan interface. Macvlan allows the Pihole to appear as a physical device on the host network with valid IP/MAC addresses. However, difficulties with name resolution arose when clients were connected to OpenVPN (see **Macvlan Foray**)*

Finally, enable the execution bit on the script for the user: ```sudo chmod u+x docker-pihole.sh``` and run! If performed successfully, the container should appear shortly in Portainer.

### OpenVPN

The easiest way to install OpenVPN is by running the following command at the terminal:
```
curl -L https://install.pivpn.io | bash
```
During installation, you will be prompted to configure items like a static IP address, OpenVPN server port number, upstream DNS resolver (select local Pihole option), and whether personal devices will be connecting via your home router's public IP address or a DNS name. This [video](https://www.youtube.com/watch?v=15VjDVCISj0) covers how to set up OpenVPN on a Pi in reasonable depth.

#### Inability to resolve URLs

Before prompting you to enable/disable unattended upgrades, the auto-install script restarts the OpenVPN service,
```
$SUDO systemctl enable openvpn.service &> /dev/null
$SUDO systemctl restart openvpn.service
```
which may affect name resolution for the host.

If this occurs, navigate to the ```/etc/resolv.conf```file and add the following line:
```
nameserver 1.1.1.1
```
Otherwise, the installer will exit with an error pertaining to the inability to locate "http://raspbian.raspberrypi.org/raspbian/pool/main/d/distro-info/python3-distro-info_0.21_all.deb". You should be able to to resume configuration of unattended upgrades thereafter.

----

## High Level Description of Scripts Used

**firewall-openvpn-rules.sh** applies iptables NAT and Forwarding rules between the tunnels from our OpenVPN client(s) to the OpenVPN server and from the Pi to ProtonVPN.

**pihole_while_vpn.sh** creates a macvlan bridge on eth0, adds 192.168.0.100/32 to the bridge, and creates a route to 192.168.0.0/24.

**up.sh** is executed upon connection to ProtonVPN. Similarly, **down.sh** is executed upon connnection teardown. To achieve this, we must include the following in our .ovpn config file which we had downloaded from the ProtonVPN portal:
```
--script-security 2
--up /etc/openvpn/up.sh
--down /etc/openvpn/down.sh
```

To automate the login process, we log our ProtonVPN credentials into a text file and pass it into the .ovpn configuration using the ```auth-user-pass /etc/openvpn/login.txt``` directive. **Warning: credentials are not encrypted/obfuscated**

## Remediating DNS Leak

By default, a client which does not have a static DNS configuration set relies on the default gateway for name resolution. On a workstation, for example, the traffic will be sent outside of the tunnel to the router. Similarly, if a mobile device is connected to our Pi OpenVPN server, DNS traffic will be router to the carrier. 

Fortunately, we can correct this issue by appending the ```dhcp-option DNS {piholeip}``` directive to the client .ovpn file **or** ```push "dhcp-option DNS {piholeip}"``` directive on the server configuration at /etc/openvpn/server.conf. Moreover, we could ensure that the ```block-outside-dns``` directive is enabled.

## Macvlan Foray

We set up a [macvlan network in Portainer](https://web.archive.org/web/20201112013419/https://www.portainer.io/2018/09/using-macvlan-portainer-io/), tethered the Pihole container to it, and removed the Docker bridge network. As a result, Pihole would now be reachable at 192.168.0.100:80 (but not 192.168.0.4:80). However, the Docker host could no longer reach Pihole ([some](http://docs.docker.oeynet.com/engine/userguide/networking/get-started-macvlan/) [rationalizations](https://stackoverflow.com/questions/63203538/docker-macvlan-no-route-to-host-container) on the topic exist). Because traffic is tunneled to/through the Pi, all network activity requiring name resolution was rendered moot (ie. *ping 8.8.8.8* or *nslookup google.com 8.8.8.8* were functional). We tried exposing a macvlan interface via the **pihole_while_vpn.sh** script and configuring 192.168.0.100 as a static name server in /etc/dhcpcd.conf, to no avail.
