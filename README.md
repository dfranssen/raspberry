# Raspberry dockerized
Scripts to initialize a Raspberry Pi (with docker)

### initSD.sh
```
Helper script to flash an SD card with Raspian Jessie Lite...

Usage: initSD.sh [-o]

Parameters:

  -o: indicates that OTG should be enabled. Optional

      NOTE: attache the OTG usb cable to the usb port, not the power port!

      WARNING: The Raspberry Pi Zero (and model A and A+) support USB On The Go,
      given the processor is connected directly to the USB port, unlike on the
      B, B+ or 2B, which goes via a USB hub.
 ```
 
### dockerizePI.sh
```
As docker-machine create does not seem to work with arm devices...

Usage: dockerizePI.sh -a {install|regenerateCerts} -n <hostname>

Parameters:

  -a: action to be performed (install or regenerateCerts). Required.

        install:          initialize a fresh Raspberry PI with the latest
                          docker installation, change the hostname, secure the
                          daemon for tcp and configure docker-machine locally.

        regenerateCerts : regenerate the server certificates signed by the ca
                          docker-machine certificate.
                          This could be handy when switching ip addresses when
                          connecting to different wireless routers.

  -n: hostname to be used. E.g. 'pi3'. Required.
```
