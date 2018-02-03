#!/bin/bash

. $(dirname $0)/../global_definitions

# hostapd
RANDOM_POSTFIX=$(date +%s%N | sha256sum | head -c 4)
RANDOM_PSK=$(date +%s%N | sha512sum | head -c 8)

SSID=${SSID-"U.M.R_"${RANDOM_POSTFIX}}
PSK=${PSK-$RANDOM_PSK}
IFACE=${IFACE-wlan0}
# udhcpd
IPADDR=${IPADDR-"172.16.233.1"}
NETMASK=255.255.255.0

IPADDR_PUB=$(echo $IPADDR | cut -d '.' -f 1,2,3)

echo "This script will install and config hostapd and udhcpd."
echo "A hotspot will be brought up on $IFACE"
echo "SSID will be $SSID"
echo "PSK will be $PSK"

echo "Installing packages..."

chroot $ROOT_PATH apt-get install -y hostapd udhcpd

echo "Generating config for udhcpd..."

(
cat << EOF

# Generated by $0
# For more details see https://github.com/UMRnInside/RPi-arm64
interface   $IFACE

start   ${IPADDR_PUB}.20
end     ${IPADDR_PUB}.250

opt dns 8.8.8.8

EOF
) > $ROOT_PATH/etc/udhcpd.conf

echo "Generating config for hostapd..."

(
cat << EOF

# Generated by $0
# For more details see https://github.com/UMRnInside/RPi-arm64

interface=$IFACE
driver=nl80211

ssid=$SSID
channel=1
wpa=2
wpa_passphrase=$PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP

hw_mode=g

# See http://elinux.org/RPI-Wireless-Hotspot
ieee80211n=1
wmm_enabled=1
ht_capab=[HT40][SHORT-GI-20][DSSS_CCK-40]

EOF
) > $ROOT_PATH/etc/hostapd/hostapd.conf

echo "Generating /etc/network/interfaces.d/$IFACE"

(
cat << EOF
allow-hotplug $IFACE
iface $IFACE inet static
    address $IPADDR
    netmask $NETMASK
    post-up hostapd -B /etc/hostapd/hostapd.conf & /etc/init.d/udhcpd restart
    pre-down pkill hostapd

EOF
) > $ROOT_PATH/etc/network/interfaces.d/$IFACE

echo "Modifing /etc/default/udhcpd"

sed -i "s/^DHCPD_ENABLED/\#DHCPD_ENABLED/" $ROOT_PATH/etc/default/udhcpd
