#!/usr/bin/env bash
##
## Script for making rootfs creation easier.
##

set -e -u

if [ "$(uname -o)" == "Android" ]; then
	echo "[!] This script cannot be executed on Android OS."
	exit 1
fi

if [ -z "$(command -v sudo)" ]; then
	echo "[!] 'sudo' is not installed."
	exit 1
fi

# Where to put generated plug-ins.
PLUGIN_DIR=$(dirname "$(realpath "$0")")/distro-plugins

# Where to put generated rootfs tarballs.
ROOTFS_DIR=$(dirname "$(realpath "$0")")/rootfs

# Working directory where chroots will be created.
WORKDIR=/tmp/proot-distro-bootstrap

# This is used to generate proot-distro plug-ins.
TAB=$'\t'
CURRENT_VERSION=$(git tag | sort -Vr | head -n1)
if [ -z "$CURRENT_VERSION" ]; then
	echo "[!] Cannot detect the latest proot-distro version tag."
	exit 1
fi

# Usually all newly created tarballs are uploaded into GitHub release of
# current proot-distro version.
GIT_RELEASE_URL="https://github.com/termux/proot-distro/releases/download/${CURRENT_VERSION}"

# Normalize architecture names.
# Prefer aarch64,arm,i686,x86_64 architecture names just like used by
# termux-packages.
translate_arch() {
	case "$1" in
		aarch64|arm64) echo "aarch64";;
		armel|armhf|armv7|armv7a|armv8l) echo "arm";;
		i386|i686|x86) echo "i686";;
		amd64|x86_64) echo "x86_64";;
		*)
			echo "translate_arch(): unknown arch '$1'" >&2
			exit 1
			;;
	esac
}

##############################################################################

# Reset workspace. This also deletes any previously made rootfs tarballs.
sudo rm -rf "${ROOTFS_DIR:?}" "${WORKDIR:?}"
mkdir -p "$ROOTFS_DIR" "$WORKDIR"
cd "$WORKDIR"

# Alpine Linux.
printf "\n[*] Building Alpine Linux...\n"
version="3.14.1"
for arch in aarch64 armv7 x86 x86_64; do
	curl --fail --location \
		--output "${WORKDIR}/alpine-minirootfs-${version}-${arch}.tar.gz" \
		"https://dl-cdn.alpinelinux.org/alpine/v${version:0:4}/releases/${arch}/alpine-minirootfs-${version}-${arch}.tar.gz"
	curl --fail --location \
		--output "${WORKDIR}/alpine-minirootfs-${version}-${arch}.tar.gz.sha256" \
		"https://dl-cdn.alpinelinux.org/alpine/v${version:0:4}/releases/${arch}/alpine-minirootfs-${version}-${arch}.tar.gz.sha256"
	sha256sum -c "${WORKDIR}/alpine-minirootfs-${version}-${arch}.tar.gz.sha256"

	sudo mkdir -m 755 "${WORKDIR}/alpine-$(translate_arch "$arch")"
	sudo tar -zx \
		-f "${WORKDIR}/alpine-minirootfs-${version}-${arch}.tar.gz" \
		-C "${WORKDIR}/alpine-$(translate_arch "$arch")"

	cat <<- EOF | sudo unshare -mpf bash -
	rm -f "${WORKDIR}/alpine-$(translate_arch "$arch")/etc/resolv.conf"
	echo "nameserver 1.1.1.1" > "${WORKDIR}/alpine-$(translate_arch "$arch")/etc/resolv.conf"
	mount --bind /dev "${WORKDIR}/alpine-$(translate_arch "$arch")/dev"
	mount --bind /proc "${WORKDIR}/alpine-$(translate_arch "$arch")/proc"
	mount --bind /sys "${WORKDIR}/alpine-$(translate_arch "$arch")/sys"
	chroot "${WORKDIR}/alpine-$(translate_arch "$arch")" apk upgrade
	EOF

	sudo rm -f "${WORKDIR:?}/alpine-$(translate_arch "$arch")"/var/cache/apk/* || true

	sudo tar -J -c \
		-f "${ROOTFS_DIR}/alpine-$(translate_arch "$arch").tar.xz" \
		-C "$WORKDIR" \
		"alpine-$(translate_arch "$arch")"
	sudo chown $(id -un):$(id -gn) "${ROOTFS_DIR}/alpine-$(translate_arch "$arch").tar.xz"
done

cat <<- EOF > "${PLUGIN_DIR}/alpine.sh"
DISTRO_NAME="Alpine Linux ($version)"

TARBALL_URL['aarch64']="${GIT_RELEASE_URL}/alpine-aarch64.tar.xz"
TARBALL_SHA256['aarch64']="$(sha256sum "${ROOTFS_DIR}/alpine-aarch64.tar.xz" | awk '{ print $1}')"
TARBALL_URL['arm']="${GIT_RELEASE_URL}/alpine-arm.tar.xz"
TARBALL_SHA256['arm']="$(sha256sum "${ROOTFS_DIR}/alpine-arm.tar.xz" | awk '{ print $1}')"
TARBALL_URL['i686']="${GIT_RELEASE_URL}/alpine-i686.tar.xz"
TARBALL_SHA256['i686']="$(sha256sum "${ROOTFS_DIR}/alpine-i686.tar.xz" | awk '{ print $1}')"
TARBALL_URL['x86_64']="${GIT_RELEASE_URL}/alpine-x86_64.tar.xz"
TARBALL_SHA256['x86_64']="$(sha256sum "${ROOTFS_DIR}/alpine-x86_64.tar.xz" | awk '{ print $1}')"
EOF
unset version

# Debian (stable).
printf "\n[*] Building Debian...\n"
for arch in arm64 armhf i386 amd64; do
	sudo debootstrap \
		--arch=${arch} \
		--no-check-gpg \
		--variant=minbase \
		--include=gvfs-daemons,libsystemd0,systemd,udisks2,wget \
		stable \
		"${WORKDIR:?}/debian-$(translate_arch "$arch")"

	sudo rm -f "${WORKDIR:?}/debian-$(translate_arch "$arch")"/var/cache/apt/archives/* || true
	sudo rm -f "${WORKDIR:?}/debian-$(translate_arch "$arch")"/var/lib/apt/lists/* || true

	sudo tar -j -c \
		-f "${ROOTFS_DIR}/debian-$(translate_arch "$arch").tar.xz" \
		-C "$WORKDIR" \
		"debian-$(translate_arch "$arch")"
	sudo chown $(id -un):$(id -gn) "${ROOTFS_DIR}/debian-$(translate_arch "$arch").tar.xz"
done
unset arch

cat <<- EOF > "${PLUGIN_DIR}/debian.sh"
DISTRO_NAME="Debian (stable)"

TARBALL_URL['aarch64']="${GIT_RELEASE_URL}/debian-aarch64.tar.xz"
TARBALL_SHA256['aarch64']="$(sha256sum "${ROOTFS_DIR}/debian-aarch64.tar.xz" | awk '{ print $1}')"
TARBALL_URL['arm']="${GIT_RELEASE_URL}/debian-arm.tar.xz"
TARBALL_SHA256['arm']="$(sha256sum "${ROOTFS_DIR}/debian-arm.tar.xz" | awk '{ print $1}')"
TARBALL_URL['i686']="${GIT_RELEASE_URL}/debian-i686.tar.xz"
TARBALL_SHA256['i686']="$(sha256sum "${ROOTFS_DIR}/debian-i686.tar.xz" | awk '{ print $1}')"
TARBALL_URL['x86_64']="${GIT_RELEASE_URL}/debian-x86_64.tar.xz"
TARBALL_SHA256['x86_64']="$(sha256sum "${ROOTFS_DIR}/debian-x86_64.tar.xz" | awk '{ print $1}')"

distro_setup() {
${TAB}# Include security & updates.
${TAB}cat <<- EOF > ./etc/apt/sources.list
${TAB}deb https://deb.debian.org/debian stable main contrib
${TAB}deb https://deb.debian.org/debian-security/ stable/updates main contrib
${TAB}deb https://deb.debian.org/debian stable-updates main contrib
${TAB}EOF

${TAB}# Don't update gvfs-daemons and udisks2
${TAB}run_proot_cmd apt-mark hold gvfs-daemons udisks2
}
EOF

# Ubuntu (21.04).
printf "\n[*] Building Ubuntu...\n"
for arch in arm64 armhf amd64; do
	sudo debootstrap \
		--arch=${arch} \
		--no-check-gpg \
		--variant=minbase \
		--include=dbus-user-session,systemd,gvfs-daemons,libsystemd0,systemd-sysv,udisks2,wget \
		hirsute \
		"${WORKDIR:?}/ubuntu-$(translate_arch "$arch")"

	sudo rm -f "${WORKDIR:?}/ubuntu-$(translate_arch "$arch")"/var/cache/apt/archives/* || true
	sudo rm -f "${WORKDIR:?}/ubuntu-$(translate_arch "$arch")"/var/lib/apt/lists/* || true

	sudo tar -j -c \
		-f "${ROOTFS_DIR}/ubuntu-$(translate_arch "$arch").tar.xz" \
		-C "$WORKDIR" \
		"ubuntu-$(translate_arch "$arch")"
	sudo chown $(id -un):$(id -gn) "${ROOTFS_DIR}/ubuntu-$(translate_arch "$arch").tar.xz"
done
unset arch

cat <<- EOF > "${PLUGIN_DIR}/ubuntu.sh"
DISTRO_NAME="Ubuntu (21.04)"

TARBALL_URL['aarch64']="${GIT_RELEASE_URL}/ubuntu-aarch64.tar.xz"
TARBALL_SHA256['aarch64']="$(sha256sum "${ROOTFS_DIR}/ubuntu-aarch64.tar.xz" | awk '{ print $1}')"
TARBALL_URL['arm']="${GIT_RELEASE_URL}/ubuntu-arm.tar.xz"
TARBALL_SHA256['arm']="$(sha256sum "${ROOTFS_DIR}/ubuntu-arm.tar.xz" | awk '{ print $1}')"
TARBALL_URL['x86_64']="${GIT_RELEASE_URL}/ubuntu-x86_64.tar.xz"
TARBALL_SHA256['x86_64']="$(sha256sum "${ROOTFS_DIR}/ubuntu-x86_64.tar.xz" | awk '{ print $1}')"

distro_setup() {
${TAB}# Enable additional repository components.
${TAB}if [ "\$DISTRO_ARCH" = "amd64" ]; then
${TAB}${TAB}echo "deb http://archive.ubuntu.com/ubuntu focal main universe multiverse" > ./etc/apt/sources.list
${TAB}else
${TAB}${TAB}echo "deb http://ports.ubuntu.com/ubuntu-ports focal main universe multiverse" > ./etc/apt/sources.list
${TAB}fi

${TAB}# Don't update gvfs-daemons and udisks2
${TAB}run_proot_cmd apt-mark hold gvfs-daemons udisks2
}
EOF
