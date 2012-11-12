pistrap
=======

ABOUT:
pistrap.sh - Bootstraps your own minimal RaspberryPi SD-card image, supporting various dists,arches and suites. The tool will also download, configure, and install the latest RPi firmware, kernel module etc... 

Images will fit in 1gb and take about 15m (on my crummy ADSL connection)

CREDITS:
Based on work by Klaus M Pfeiffer <klaus.m.pfeiffer@kmp.or.at> at http://blog.kmp.or.at/2012/05/build-your-own-raspberry-pi-image/.
However, I added a lot more customisability, fixed lots of bugs, and added a UI.
We take the "QEMU/debootstrap approach". See: http://wiki.debian.org/EmDebian/CrossDebootstrap.

The program is wizard driven (curses-ey) and you specify the following:
* A block device (SD Card), to work with. DONT be an idiot, and specify your hard drive here :p
* The location to use as a buildroot. This should be an (empty) directory where you want the new system to be populated. This directory will reflect the root filesystem of the new system. Note that the host system is not affected in any way, and all modifications are restricted to the directory you have chosen.
* The Debian suite (Release e.g. stable, testing, sid), that you want to bootstrap.
* The target architecture (i.e. armel, armhf), that you want to bootstrap. - NOTE: there is no sanity checking here. i.e. stock Debian armhf wont boot on the Pi.
* A mirror from which the necessary .deb packages will be downloaded. Choose any mirror, as long as it has the architecture you are trying to bootstrap. See http://www.debian.org/mirror/list for the list of available Debian mirrors. NOTE: I have only currently tested debian (wheezy/armel) from http://http.debian.net/debian. Raspbian (wheezy/armhf) from  should work too. (I could not get emdebian (squeeze/armel) from http://ftp.uk.debian.org/emdebian/grip to work).
* The target hostname

TIPS:
* You need to have superuser rights to use this tool because debootstrap will create device nodes (using mknod) as well as chroot into the newly *created system.
* On the host, you need to get some build dependencies first. These should get automatically installed.
* The root password on the created image will be "raspberry".
* The network is configured to use DHCP.
* We install NTP as the date and time will be wrong, due to no RTC being on the board.
* We also install  vim, screen, and SSH so you can get started quickly with it.

TODO:
* Support making and dd-ing re-usable image files. Also, cache packages for rebuilds.
* Progress bars.
* Configure users and passwords.
* Configure boot paramaters.
* Make more robust.

