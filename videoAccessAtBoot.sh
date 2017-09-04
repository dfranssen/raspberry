#!/bin/bash
# Use at own risk ;-)
# Author: dirk.franssen@gmail.com

usage() {
cat << EOF
Enables 'dev/video0' access once booted by changing the '/etc/rc.local'.
This script should be executed only once per hostname.

Usage: videoAccessAtBoot.sh -n <hostname>

Parameters:

  -n: hostname to be used. E.g. 'pi3'. Required.
EOF
exit 0
}
hostname=""
enableVideo() {
  echo "About to change /etc/rc.local"
  ssh -i ~/.ssh/id_rsa_iot pi@$hostname.local "sudo sed -i '/exit 0/i \
  modprobe bcm2835-v4l2\
  ' /etc/rc.local"

  echo "done"
}

while getopts "hn:" optname; do
  case "$optname" in
    "h")
      usage
      ;;
    "n")
      hostname="$OPTARG"
      enableVideo
      ;;
    *)
      # should not occur
      echo "Unknown error while processing options inside initSD.sh"
      ;;
  esac
done
