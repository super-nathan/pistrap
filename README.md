pistrap
=======

ABOUT:
pistrap.sh - Bootstraps your own minimal RaspberryPi SD-card image, supporting various dists,arches and suites. The tool will also download, configure, and install the latest RPi firmware, kernel module etc...  It is not called "piss-trap"!!! ಠ_ಠ

We take the "QEMU/debootstrap approach". See: http://wiki.debian.org/EmDebian/CrossDebootstrap.
Images will fit in ~350mb and take about 15m (on my crummy ADSL connection)

CREDITS:
*Based on work by Klaus M Pfeiffer <klaus.m.pfeiffer@kmp.or.at> at http://blog.kmp.or.at/2012/05/build-your-own-raspberry-pi-image/.
* I added a lot more customisability, fixed lots of bugs, and added a UI.
*Thanks to Nathan Weber <supernathansunshine@gmaill.com>, and the PiBang Linux project, I have upstreamed some of the fixes in thier fork.

INSTALL:

Remember that "trunk" may be unstable. This software is currently under development.  You are advised to build and install debian packages using dpkg. The package will pull in the host build dependencies and they will be automatically installed along with pistrap, enabling it to be run like a normal program.

To make a package, f the pistrap folder run: 

    dpkg-buildpackage 

Install with:

    sudo dpkg -i ../[packagename].deb
    
You need to have superuser rights to use this tool because debootstrap will create device nodes (using mknod) as well as chroot into the newly *created system. Therefore, run it with:

    sudo pistrap

It *should* work on non-debian systems that have debootstrap. We should not assume the user is running a Debian derived system. ... I have been told you can install debootstrap on Fedora, Arch Linux etc... so we should not make calls to apt-get, which will not work on systems that don't use apt for package management (ie, most things that isn't Debian derived). Our apt-get's are done inside the debian chroots now, which is fine.

USAGE:
The program is wizard driven (curses-ey).  Just follow the directions and it's easy.  This program makes an image, which you can DD yourself later to your SD-Card. The image can be found in your  buildroot. This should be an existing (empty) directory where you want the new system to be populated. This directory will reflect the root filesystem of the new system. Note that the host system is not affected in any way, and all modifications are restricted to the directory you have chosen..

You may also specify things such as the following:
* The Debian suite (Release e.g. stable, testing, sid), that you want to bootstrap.
* The target architecture (i.e. armel, armhf), that you want to bootstrap. - NOTE: there is no sanity checking here. i.e. stock Debian armhf wont boot on the Pi.
* A mirror from which the necessary .deb packages will be downloaded. Choose any mirror, as long as it has the architecture you are trying to bootstrap. See http://www.debian.org/mirror/list for the list of available Debian mirrors. NOTE: I have only currently tested debian (wheezy/armel) from http://http.debian.net/debian. Raspbian (wheezy/armhf) from http://archive.raspbian.org/raspbian should work too. (I could not get emdebian (squeeze/armel) from http://ftp.uk.debian.org/emdebian/grip to work).
* Hostnames and passwords
* Custom package selection - Read from packages.list.

Everything is logged to /var/log/pistrap.log. You may want to do this in another tab to see what is going on:

    tail -f /var/log/pistrap.log

After it is build, to test your image on x86, follow http://xecdesign.com/qemu-emulating-raspberry-pi-the-easy-way/. To DD an image again: sudo dd bs=1m if=[your image file].img of=/dev/[sdcard].

TIPS:
* The network is configured to use DHCP.
* We install NTP as the date and time will be wrong, due to no RTC being on the board. We also need this and the SSL certificates, so we can checkout the firmware from github.

NEW:
* Now supports custom package selection
* Now supports configureable hostname and root password.
* Configured USB serial console for headless use - If you plug a USB-Serial dongle into your pi, and connect it to it over a null modem cable with Minicom, you can log in headlessly.

TODO:
* Support extremely small installs using minibase variant and /or emdebian?
* Due to a known problem with Raspbian, we dont check GPG keys when using debootstrap. We probably should fix this.
* A page of "qemu: Unsupported syscall" is a known problem, though it seems to work OK. We probably should fix this.
* Cache packages and workdirs, for fast rebuilds.
