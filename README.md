# PRoot Distro

A Bash script wrapper for utility [proot] for easy management of chroot-based
Linux distribution installations. It does not require root or any special ROM,
kernel, etc. Everything you need to get started is the latest version of
[Termux] application. See [Installing](#installation) for details.

PRoot Distro is not a virtual machine, neither a traditional chroot. It shares
the same kernel as your Android system, so do not even try to update it through
package manager - this will not work.

This script should never be run as root user. If you do so, file permissions
and SELinux labels could get messed up. There also possibility of damaging
system if being executed as root. For safety, PRoot Distro checks the user id
before run and refuses to work if detected user id `0` (root).

***

## Supported distributions

PRoot Distro provides support only one version of distribution types, i.e. one
of stable, LTS or rolling-release. Support of versioned distributions ended
with branch 2.x. If you need a custom version, you will need to add it on your
own. See [Adding distribution](#adding-distribution).

Here are the supported distributions:

* Alpine Linux (3.14.x)
* Arch Linux / Arch Linux 32 / Arch Linux ARM
* Debian (stable)
* ~~Fedora 33~~
* ~~Gentoo~~
* Ubuntu (21.04)
* Void Linux

If desired distribution is not in the list, you can request it.

## Installing

With package manager:
```
pkg install proot-distro
```

With git:
```
pkg install git
git clone https://github.com/termux/proot-distro
cd proot-distro
./install.sh
```

Dependencies: bash, bzip2, coreutils, curl, findutils, gzip, ncurses-utils, proot, sed, tar, xz-utils

## How to use

TODO: fill this

## Adding distribution

TODO: fill this

[Termux]: <https://termux.com>
[proot]: <https://github.com/termux/proot>
