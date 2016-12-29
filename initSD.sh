#!/bin/bash
# Use at own risk ;-)
# Author: dirk.franssen@gmail.com

usage() {
cat << EOF
Helper script to flash an SD card with Raspian Jessie Lite...

Usage: initSD.sh [-o]

Parameters:

  -o: indicates that OTG should be enabled. Optional

      NOTE: attache the OTG usb cable to the usb port, not the power port!

      WARNING: The Raspberry Pi Zero (and model A and A+) support USB On The Go,
      given the processor is connected directly to the USB port, unlike on the
      B, B+ or 2B, which goes via a USB hub.
EOF
exit 0
}

otg=false

while getopts "ho" optname; do
  case "$optname" in
    "h")
      usage
      ;;
    "o")
      otg=true
      ;;
    *)
      # should not occur
      echo "Unknown error while processing options inside initSD.sh"
      ;;
  esac
done

echo "About to flash the SD card with Raspbian Jessie Lite (2016-11-25)"
sudo dd bs=1m if=2016-11-25-raspbian-jessie-lite.img of=/dev/rdisk2
echo "Waiting for the SD card to mount"
#give some time to mount the drive
sleep 5
echo "Changing boot files..."
touch /Volumes/boot/ssh
sed -i '.bak' 's/^gpu_mem/#gpu_mem/' /Volumes/boot/config.txt
echo "gpu_mem=16" >> /Volumes/boot/config.txt

if [ $otg == true ]
then
  echo "Enabling OTG"
  echo "dtoverlay=dwc2" >> /Volumes/boot/config.txt
  sed -i '.bak' 's/rootwait/rootwait modules-load=dwc2,g_ether/' /Volumes/boot/cmdline.txt
fi

echo "done"
