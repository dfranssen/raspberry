#!/bin/bash
# Use at own risk ;-)
# Author: dirk.franssen@gmail.com

usage() {
cat << EOF
Configure wifi on boot partition of SD card for Raspberry PI.

Usage: configureWifi -s <SSID> -p <password>

Parameters:

  -s: SSID of your wifi
  -p: password of your wifi
EOF
exit 0
}

configureWIFI() {
    echo "Starting WIFI setup..."
    touch $root/ssh

echo 'network={
  ssid="'$WIFI_SSID'"
  psk="'$WIFI_PASSWORD'"
  key_mgmt=WPA-PSK
}' > $root/interfaces

echo 'auto wlan0
allow-hotplug wlan0
iface wlan0 inet dhcp
wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
iface default inet dhcp' > $root/wpa_supplicant.conf

    echo "Done..."
    echo "Unmount and insert SD in pi."
}

root=/Volumes/boot
argumentCnt=0
WIFI_SSID=""
WIFI_PASSWORD=""

while getopts "hs:p:" optname; do
  case "$optname" in
    "h")
      usage
      ;;
    "s")
      WIFI_SSID="$OPTARG"
      ((argumentCnt++))
      ;;
    "p")
      WIFI_PASSWORD="$OPTARG"
      ((argumentCnt++))
      ;;
    *)
      # should not occur
      echo "Unknown error while processing options inside configureWifi.sh"
      ;;
  esac
done

if [ $argumentCnt -ne 2 ]; then usage; fi

configureWIFI