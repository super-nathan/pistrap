pistrap
=======

ABOUT:
pistrap.sh - Bootstraps your own minimal RaspberryPi SD-card image, supporting various dists,arches and suites. The tool will also download, configure, and install the latest RPi firmware, kernel module etc...  It is not called "piss-trap"!!! ಠ_ಠ

Images will fit in 1gb and take about 15m (on my crummy ADSL connection)

CREDITS:
Based on work by Klaus M Pfeiffer <klaus.m.pfeiffer@kmp.or.at> at http://blog.kmp.or.at/2012/05/build-your-own-raspberry-pi-image/.
However, I added a lot more customisability, fixed lots of bugs, and added a UI.
We take the "QEMU/debootstrap approach". See: http://wiki.debian.org/EmDebian/CrossDebootstrap.

USAGE:
The program is wizard driven (curses-ey) and you specify the following:
* A block device (SD Card), to work with. DONT be an idiot, and specify your hard drive here :p . Choose cancel to make an image instead, which you can DD yourself later.
* The location to use as a buildroot. This should be an (empty) directory where you want the new system to be populated. This directory will reflect the root filesystem of the new system. Note that the host system is not affected in any way, and all modifications are restricted to the directory you have chosen.
* The Debian suite (Release e.g. stable, testing, sid), that you want to bootstrap.
* The target architecture (i.e. armel, armhf), that you want to bootstrap. - NOTE: there is no sanity checking here. i.e. stock Debian armhf wont boot on the Pi.
* A mirror from which the necessary .deb packages will be downloaded. Choose any mirror, as long as it has the architecture you are trying to bootstrap. See http://www.debian.org/mirror/list for the list of available Debian mirrors. NOTE: I have only currently tested debian (wheezy/armel) from http://http.debian.net/debian. Raspbian (wheezy/armhf) from http://archive.raspbian.org/raspbian should work too. (I could not get emdebian (squeeze/armel) from http://ftp.uk.debian.org/emdebian/grip to work).
* The target hostname

TIPS:
* The root password on the created image will be "raspberry".
* The network is configured to use DHCP.
* We install NTP as the date and time will be wrong, due to no RTC being on the board. We also need this and the SSL certificates, so we can checkout the firmware from github.
* We also install  vim, screen, and SSH so you can get started quickly with it.
* We support making and dd-ing re-usable image files.
* You are advised to run the debian-packaged version of this software, rather than trunk. The package will pull in the host build dependencies and they will be automatically installed.
* You need to have superuser rights to use this tool because debootstrap will create device nodes (using mknod) as well as chroot into the newly *created system.
* It *should* work on non-debian systems that have debootstrap. We should not assume the user is running a Debian derived system. ... I have been told you can install debootstrap on Fedora, Arch Linux etc... so we should not make calls to apt-get, which will not work on systems that don't use apt for package management (ie, most things that isn't Debian derived). Our apt-get's are done inside the debian chroots now, which is fine.

TODO:
* Support extremely small installs using minibase variant and /or emdebian?
* Due to a known problem with Raspbian, we dont check GPG keys when using debootstrap. We probably should fix this.
* A page of "qemu: Unsupported syscall" is a known problem, though it seems to work OK. We probably should fix this.
* Custom package selection
* Cache packages and workdirs, for fast rebuilds.
* Configure users and passwords.
* Configure boot paramaters.
* Make more robust.
