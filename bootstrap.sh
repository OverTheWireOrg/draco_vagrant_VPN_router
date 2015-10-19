#!/usr/bin/env bash

VPN_STATIC_IP=

if [ "$VPN_STATIC_IP" = "" ];
then
    echo "ERROR: VPN_STATIC_IP must have a value (Check $0)"
    exit 1
fi

# install openvpn client
apt-get update
apt-get -y install openvpn

# add persistent iptables config
cat > /etc/network/if-pre-up.d/iptablesload << EOL
#!/bin/sh
iptables-restore < /etc/iptables.rules
exit 0
EOL
chmod +x /etc/network/if-pre-up.d/iptablesload

cat > /etc/network/if-post-down.d/iptablessave << EOL
#!/bin/sh
iptables-save -c > /etc/iptables.rules
exit 0
EOL
chmod +x /etc/network/if-post-down.d/iptablessave

# add iptables rules
LAN_SUBNET=$(ip route | sed -n '2p' | awk '{print $1}')

cat > /etc/iptables.rules << EOL
########################################################################
# filter table

# Drop anything we aren't explicitly allowing. All outbound traffic is okay
*filter
:INPUT   DROP
:FORWARD DROP
:OUTPUT  ACCEPT

# chain for all input on eth0
:FW-eth0-INPUT -
# chain for all input on eth1
:FW-eth1-INPUT -
# chain for all output on eth1
:FW-eth1-OUTPUT -
# chain for all input on tun0
:FW-tun0-INPUT -
# chain for forwarding to/from tun0 and eth1
:FW-tun0-eth1-FORWARD -
:FW-eth1-tun0-FORWARD -

########################################################################
# INPUT rules

# Accept all on loopback interface
-A INPUT -i lo -j ACCEPT

# Accept ICMP packets needed for ping, traceroute, etc.
-A INPUT -p icmp --icmp-type echo-reply -j ACCEPT
-A INPUT -p icmp --icmp-type destination-unreachable -j ACCEPT
-A INPUT -p icmp --icmp-type time-exceeded -j ACCEPT

# Add custom INPUT filters
-A INPUT -i eth0 -j FW-eth0-INPUT
-A INPUT -i eth1 -j FW-eth1-INPUT
-A INPUT -i tun0 -j FW-tun0-INPUT

########################################################################
# FORWARD rules

# Add custom FORWARD filters
-A FORWARD -i tun0 -o eth1 -j FW-tun0-eth1-FORWARD
-A FORWARD -i eth1 -o tun0 -j FW-eth1-tun0-FORWARD

########################################################################
# OUTPUT rules

# Add custom OUTPUT filters
-A OUTPUT -o eth1 -j FW-eth1-OUTPUT

########################################################################
# FW-eth0-INPUT rules

# Accept connections from LAN
-A FW-eth0-INPUT -s ${LAN_SUBNET} -j ACCEPT

# Log anything on eth0 claiming it's from a local or non-routable network
# https://oav.net/mirrors/cidr.html
-A FW-eth0-INPUT -s 0.0.0.0/8          -j LOG --log-prefix "eth0-INPUT DROP LOCAL: "
-A FW-eth0-INPUT -s 10.0.0.0/8         -j LOG --log-prefix "eth0-INPUT DROP A: "
-A FW-eth0-INPUT -d 127.0.0.0/8        -j LOG --log-prefix "eth0-INPUT DROP LOOPBACK: "
-A FW-eth0-INPUT -s 169.254.0.0/16     -j LOG --log-prefix "eth0-INPUT DROP LINK-LOCAL: "
-A FW-eth0-INPUT -s 172.16.0.0/12      -j LOG --log-prefix "eth0-INPUT DROP B: "
-A FW-eth0-INPUT -s 192.168.0.0/16     -j LOG --log-prefix "eth0-INPUT DROP C: "
-A FW-eth0-INPUT -s 224.0.0.0/4        -j LOG --log-prefix "eth0-INPUT DROP MULTICAST D: "
-A FW-eth0-INPUT -s 240.0.0.0/5        -j LOG --log-prefix "eth0-INPUT DROP E: "
-A FW-eth0-INPUT -s 240.0.0.0/4        -j LOG --log-prefix "eth0-INPUT DROP FUTURE: "
-A FW-eth0-INPUT -s 248.0.0.0/5        -j LOG --log-prefix "eth0-INPUT DROP RESERVED: "
-A FW-eth0-INPUT -s 255.255.255.255/32 -j LOG --log-prefix "eth0-INPUT DROP BROADCAST: "

# Accept any established connections
-A FW-eth0-INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Log and drop everything else
-A FW-eth0-INPUT -j LOG --log-prefix "eth0-INPUT DROP: "

########################################################################
# FW-eth1-INPUT rules

# Log and drop everything
-A FW-eth1-INPUT -j LOG --log-prefix "eth1-INPUT DROP: "

########################################################################
# FW-tun0-INPUT rules

# Accept any established connections
-A FW-tun0-INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Log and drop anything else
-A FW-tun0-INPUT -j LOG --log-prefix "tun0-INPUT DROP: "

########################################################################
# FW-tun0-eth1-FORWARD rules

# Log and accept everything forwarded to the VPN static IP, drop the rest
-A FW-tun0-eth1-FORWARD -j LOG --log-prefix "tun0-eth1-FORWARD: "
-A FW-tun0-eth1-FORWARD -d ${VPN_STATIC_IP} -j ACCEPT

########################################################################
# FW-eth1-tun0-FORWARD rules

# Log and accept everything forwarded from the VPN static IP, drop the rest
-A FW-eth1-tun0-FORWARD -j LOG --log-prefix "eth1-tun0-FORWARD: "
-A FW-eth1-tun0-FORWARD -s ${VPN_STATIC_IP} -j ACCEPT

########################################################################
# FW-eth1-OUTPUT rules

# Log and drop everything
-A FW-eth1-OUTPUT -j LOG --log-prefix "eth1-OUTPUT DROP: "
-A FW-eth1-OUTPUT -j DROP

COMMIT
EOL

# load iptables rules
iptables-restore < /etc/iptables.rules

# enable IP forwarding
sed -i '/net.ipv4.ip_forward/s/#//' /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

