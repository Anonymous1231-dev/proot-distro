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
		armel|armhf|armhfp|armv7|armv7l|armv7a|armv8l) echo "arm";;
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
	sudo tar -zxp \
		-f "${WORKDIR}/alpine-minirootfs-${version}-${arch}.tar.gz" \
		-C "${WORKDIR}/alpine-$(translate_arch "$arch")"

	cat <<- EOF | sudo unshare -mpf bash -e -
	rm -f "${WORKDIR}/alpine-$(translate_arch "$arch")/etc/resolv.conf"
	echo "nameserver 1.1.1.1" > "${WORKDIR}/alpine-$(translate_arch "$arch")/etc/resolv.conf"
	mount --bind /dev "${WORKDIR}/alpine-$(translate_arch "$arch")/dev"
	mount --bind /proc "${WORKDIR}/alpine-$(translate_arch "$arch")/proc"
	mount --bind /sys "${WORKDIR}/alpine-$(translate_arch "$arch")/sys"
	chroot "${WORKDIR}/alpine-$(translate_arch "$arch")" apk upgrade
	EOF

	sudo rm -f "${WORKDIR:?}/alpine-$(translate_arch "$arch")"/var/cache/apk/* || true

	sudo tar -J -c \
		-f "${ROOTFS_DIR}/alpine-$(translate_arch "$arch")-pd-${CURRENT_VERSION}.tar.xz" \
		-C "$WORKDIR" \
		"alpine-$(translate_arch "$arch")"
	sudo chown $(id -un):$(id -gn) "${ROOTFS_DIR}/alpine-$(translate_arch "$arch")-pd-${CURRENT_VERSION}.tar.xz"
done

cat <<- EOF > "${PLUGIN_DIR}/alpine.sh"
DISTRO_NAME="Alpine Linux ($version)"

TARBALL_URL['aarch64']="${GIT_RELEASE_URL}/alpine-aarch64-pd-${CURRENT_VERSION}.tar.xz"
TARBALL_SHA256['aarch64']="$(sha256sum "${ROOTFS_DIR}/alpine-aarch64-pd-${CURRENT_VERSION}.tar.xz" | awk '{ print $1}')"
TARBALL_URL['arm']="${GIT_RELEASE_URL}/alpine-arm-pd-${CURRENT_VERSION}.tar.xz"
TARBALL_SHA256['arm']="$(sha256sum "${ROOTFS_DIR}/alpine-arm-pd-${CURRENT_VERSION}.tar.xz" | awk '{ print $1}')"
TARBALL_URL['i686']="${GIT_RELEASE_URL}/alpine-i686-pd-${CURRENT_VERSION}.tar.xz"
TARBALL_SHA256['i686']="$(sha256sum "${ROOTFS_DIR}/alpine-i686-pd-${CURRENT_VERSION}.tar.xz" | awk '{ print $1}')"
TARBALL_URL['x86_64']="${GIT_RELEASE_URL}/alpine-x86_64-pd-${CURRENT_VERSION}.tar.xz"
TARBALL_SHA256['x86_64']="$(sha256sum "${ROOTFS_DIR}/alpine-x86_64-pd-${CURRENT_VERSION}.tar.xz" | awk '{ print $1}')"
EOF
unset version

# Arch Linux (original, ARM, 32)
printf "\n[*] Building Arch Linux...\n"

for arch in aarch64 armv7; do
	curl --fail --location \
		--output "${WORKDIR}/archlinux-${arch}.tar.gz" \
		"http://os.archlinuxarm.org/os/ArchLinuxARM-${arch}-latest.tar.gz"

	sudo mkdir -m 755 "${WORKDIR}/archlinux-$(translate_arch "$arch")"
	sudo tar -zxpf "${WORKDIR}/archlinux-${arch}.tar.gz" \
		-C "${WORKDIR}/archlinux-$(translate_arch "$arch")"

	cat <<- EOF | sudo unshare -mpf bash -e -
	rm -f "${WORKDIR}/archlinux-$(translate_arch "$arch")/etc/resolv.conf"
	echo "nameserver 1.1.1.1" > "${WORKDIR}/archlinux-$(translate_arch "$arch")/etc/resolv.conf"
	mount --bind "${WORKDIR}/archlinux-$(translate_arch "$arch")/" "${WORKDIR}/archlinux-$(translate_arch "$arch")/"
	mount --bind /dev "${WORKDIR}/archlinux-$(translate_arch "$arch")/dev"
	mount --bind /proc "${WORKDIR}/archlinux-$(translate_arch "$arch")/proc"
	mount --bind /sys "${WORKDIR}/archlinux-$(translate_arch "$arch")/sys"
	chroot "${WORKDIR}/archlinux-$(translate_arch "$arch")" pacman-key --init
	chroot "${WORKDIR}/archlinux-$(translate_arch "$arch")" pacman-key --populate archlinuxarm
	if [ "$arch" = "aarch64" ]; then
	chroot "${WORKDIR}/archlinux-$(translate_arch "$arch")" pacman -Rnsc --noconfirm linux-aarch64
	else
	chroot "${WORKDIR}/archlinux-$(translate_arch "$arch")" pacman -Rnsc --noconfirm linux-armv7
	fi
	chroot "${WORKDIR}/archlinux-$(translate_arch "$arch")" pacman -Syu --noconfirm
	EOF

	sudo rm -f "${WORKDIR:?}/archlinux-$(translate_arch "$arch")"/var/cache/pacman/pkg/* || true

	sudo tar -J -c \
		-f "${ROOTFS_DIR}/archlinux-$(translate_arch "$arch")-pd-${CURRENT_VERSION}.tar.xz" \
		-C "$WORKDIR" \
		"archlinux-$(translate_arch "$arch")"
	sudo chown $(id -un):$(id -gn) "${ROOTFS_DIR}/archlinux-$(translate_arch "$arch")-pd-${CURRENT_VERSION}.tar.xz"
done
unset arch

version="2021.08.01"
curl --fail --location \
	--output "${WORKDIR}/archlinux-x86_64.tar.gz" \
	"https://mirror.rackspace.com/archlinux/iso/${version}/archlinux-bootstrap-${version}-x86_64.tar.gz"
unset version

sudo mkdir -m 755 "${WORKDIR}/archlinux-bootstrap"
sudo tar -zxp --strip-components=1 \
	-f "${WORKDIR}/archlinux-x86_64.tar.gz" \
	-C "${WORKDIR}/archlinux-bootstrap"

cat <<- EOF | sudo unshare -mpf bash -e -
rm -f "${WORKDIR}/archlinux-bootstrap/etc/resolv.conf"
echo "nameserver 1.1.1.1" > "${WORKDIR}/archlinux-bootstrap/etc/resolv.conf"
mount --bind "${WORKDIR}/archlinux-bootstrap/" "${WORKDIR}/archlinux-bootstrap/"
mount --bind /dev "${WORKDIR}/archlinux-bootstrap/dev"
mount --bind /proc "${WORKDIR}/archlinux-bootstrap/proc"
mount --bind /sys "${WORKDIR}/archlinux-bootstrap/sys"
mkdir "${WORKDIR}/archlinux-bootstrap/archlinux-i686"
mkdir "${WORKDIR}/archlinux-bootstrap/archlinux-x86_64"
chroot "${WORKDIR}/archlinux-bootstrap" pacman-key --init
chroot "${WORKDIR}/archlinux-bootstrap" pacman-key --populate archlinux
echo 'Server = http://mirror.rackspace.com/archlinux/\$repo/os/\$arch' > \
	"${WORKDIR}/archlinux-bootstrap/etc/pacman.d/mirrorlist"
chroot "${WORKDIR}/archlinux-bootstrap" pacstrap /archlinux-x86_64 base
sed -i 's|Architecture = auto|Architecture = i686|' \
	"${WORKDIR}/archlinux-bootstrap/etc/pacman.conf"
sed -i 's|Required DatabaseOptional|Never|' \
	"${WORKDIR}/archlinux-bootstrap/etc/pacman.conf"
echo 'Server = https://de.mirror.archlinux32.org/\$arch/\$repo' > \
	"${WORKDIR}/archlinux-bootstrap/etc/pacman.d/mirrorlist"
chroot "${WORKDIR}/archlinux-bootstrap" pacman -Scc --noconfirm
chroot "${WORKDIR}/archlinux-bootstrap" pacstrap /archlinux-i686 base
EOF

for arch in i686 x86_64; do
	sudo rm -f "${WORKDIR:?}/archlinux-bootstrap/archlinux-${arch}"/var/cache/pacman/pkg/* || true
	sudo tar -Jcf "${ROOTFS_DIR}/archlinux-${arch}-pd-${CURRENT_VERSION}.tar.xz" \
		-C "${WORKDIR}/archlinux-bootstrap" \
		"archlinux-${arch}"
	sudo chown $(id -un):$(id -gn) "${ROOTFS_DIR}/archlinux-${arch}-pd-${CURRENT_VERSION}.tar.xz"
done
unset arch

cat <<- EOF > "${PLUGIN_DIR}/archlinux.sh"
DISTRO_NAME="Arch Linux"

TARBALL_URL['aarch64']="${GIT_RELEASE_URL}/archlinux-aarch64-pd-${CURRENT_VERSION}.tar.xz"
TARBALL_SHA256['aarch64']="$(sha256sum "${ROOTFS_DIR}/archlinux-aarch64-pd-${CURRENT_VERSION}.tar.xz" | awk '{ print $1}')"
TARBALL_URL['arm']="${GIT_RELEASE_URL}/archlinux-arm-pd-${CURRENT_VERSION}.tar.xz"
TARBALL_SHA256['arm']="$(sha256sum "${ROOTFS_DIR}/archlinux-arm-pd-${CURRENT_VERSION}.tar.xz" | awk '{ print $1}')"
TARBALL_URL['i686']="${GIT_RELEASE_URL}/archlinux-i686-pd-${CURRENT_VERSION}.tar.xz"
TARBALL_SHA256['i686']="$(sha256sum "${ROOTFS_DIR}/archlinux-i686-pd-${CURRENT_VERSION}.tar.xz" | awk '{ print $1}')"
TARBALL_URL['x86_64']="${GIT_RELEASE_URL}/archlinux-x86_64-pd-${CURRENT_VERSION}.tar.xz"
TARBALL_SHA256['x86_64']="$(sha256sum "${ROOTFS_DIR}/archlinux-x86_64-pd-${CURRENT_VERSION}.tar.xz" | awk '{ print $1}')"
EOF

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
		-f "${ROOTFS_DIR}/debian-$(translate_arch "$arch")-pd-${CURRENT_VERSION}.tar.xz" \
		-C "$WORKDIR" \
		"debian-$(translate_arch "$arch")"
	sudo chown $(id -un):$(id -gn) "${ROOTFS_DIR}/debian-$(translate_arch "$arch")-pd-${CURRENT_VERSION}.tar.xz"
done
unset arch

cat <<- EOF > "${PLUGIN_DIR}/debian.sh"
DISTRO_NAME="Debian (stable)"

TARBALL_URL['aarch64']="${GIT_RELEASE_URL}/debian-aarch64-pd-${CURRENT_VERSION}.tar.xz"
TARBALL_SHA256['aarch64']="$(sha256sum "${ROOTFS_DIR}/debian-aarch64-pd-${CURRENT_VERSION}.tar.xz" | awk '{ print $1}')"
TARBALL_URL['arm']="${GIT_RELEASE_URL}/debian-arm-pd-${CURRENT_VERSION}.tar.xz"
TARBALL_SHA256['arm']="$(sha256sum "${ROOTFS_DIR}/debian-arm-pd-${CURRENT_VERSION}.tar.xz" | awk '{ print $1}')"
TARBALL_URL['i686']="${GIT_RELEASE_URL}/debian-i686-pd-${CURRENT_VERSION}.tar.xz"
TARBALL_SHA256['i686']="$(sha256sum "${ROOTFS_DIR}/debian-i686-pd-${CURRENT_VERSION}.tar.xz" | awk '{ print $1}')"
TARBALL_URL['x86_64']="${GIT_RELEASE_URL}/debian-x86_64-pd-${CURRENT_VERSION}.tar.xz"
TARBALL_SHA256['x86_64']="$(sha256sum "${ROOTFS_DIR}/debian-x86_64-pd-${CURRENT_VERSION}.tar.xz" | awk '{ print $1}')"

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

# Fedora 34.
printf "\n[*] Building Fedora...\n"
version="34-1.2"
for arch in aarch64 armhfp x86_64; do
	curl --fail --location \
		--output "${WORKDIR}/fedora-${version}-${arch}.tar.xz" \
		"https://mirror.de.leaseweb.net/fedora/linux/releases/${version:0:2}/Container/${arch}/images/Fedora-Container-Base-${version}.${arch}.tar.xz"

	mkdir "${WORKDIR}/fedora-$(translate_arch "$arch")"
	sudo tar -Jx --strip-components=1 \
		-f "${WORKDIR}/fedora-${version}-${arch}.tar.xz" \
		-C "${WORKDIR}/fedora-$(translate_arch "$arch")"
	sudo mkdir -m 755 "${WORKDIR}/fedora-$(translate_arch "$arch")/fedora-$(translate_arch "$arch")"
	sudo tar -xpf "${WORKDIR}/fedora-$(translate_arch "$arch")"/layer.tar \
		-C "${WORKDIR}/fedora-$(translate_arch "$arch")/fedora-$(translate_arch "$arch")"

	sudo tar -Jcf "${ROOTFS_DIR}/fedora-$(translate_arch "$arch")-pd-${CURRENT_VERSION}.tar.xz" \
		-C "${WORKDIR}/fedora-$(translate_arch "$arch")" \
		"fedora-$(translate_arch "$arch")"
	sudo chown $(id -un):$(id -gn) "${ROOTFS_DIR}/fedora-$(translate_arch "$arch")-pd-${CURRENT_VERSION}.tar.xz"
done
unset arch

cat <<- EOF > "${PLUGIN_DIR}/fedora.sh"
DISTRO_NAME="Fedora (${version:0:2})"

TARBALL_URL['aarch64']="${GIT_RELEASE_URL}/fedora-aarch64-pd-${CURRENT_VERSION}.tar.xz"
TARBALL_SHA256['aarch64']="$(sha256sum "${ROOTFS_DIR}/fedora-aarch64-pd-${CURRENT_VERSION}.tar.xz" | awk '{ print $1}')"
TARBALL_URL['arm']="${GIT_RELEASE_URL}/fedora-arm-pd-${CURRENT_VERSION}.tar.xz"
TARBALL_SHA256['arm']="$(sha256sum "${ROOTFS_DIR}/fedora-arm-pd-${CURRENT_VERSION}.tar.xz" | awk '{ print $1}')"
TARBALL_URL['x86_64']="${GIT_RELEASE_URL}/fedora-x86_64-pd-${CURRENT_VERSION}.tar.xz"
TARBALL_SHA256['x86_64']="$(sha256sum "${ROOTFS_DIR}/fedora-x86_64-pd-${CURRENT_VERSION}.tar.xz" | awk '{ print $1}')"
EOF

# Ubuntu (20.04).
printf "\n[*] Building Ubuntu...\n"
for arch in arm64 armhf amd64; do
	sudo debootstrap \
		--arch=${arch} \
		--no-check-gpg \
		--variant=minbase \
		--include=dbus-user-session,systemd,gvfs-daemons,libsystemd0,systemd-sysv,udisks2,wget \
		focal \
		"${WORKDIR:?}/ubuntu-$(translate_arch "$arch")"

	sudo rm -f "${WORKDIR:?}/ubuntu-$(translate_arch "$arch")"/var/cache/apt/archives/* || true
	sudo rm -f "${WORKDIR:?}/ubuntu-$(translate_arch "$arch")"/var/lib/apt/lists/* || true

	sudo tar -j -c \
		-f "${ROOTFS_DIR}/ubuntu-$(translate_arch "$arch")-pd-${CURRENT_VERSION}.tar.xz" \
		-C "$WORKDIR" \
		"ubuntu-$(translate_arch "$arch")"
	sudo chown $(id -un):$(id -gn) "${ROOTFS_DIR}/ubuntu-$(translate_arch "$arch")-pd-${CURRENT_VERSION}.tar.xz"
done
unset arch

cat <<- EOF > "${PLUGIN_DIR}/ubuntu.sh"
DISTRO_NAME="Ubuntu (20.04)"

TARBALL_URL['aarch64']="${GIT_RELEASE_URL}/ubuntu-aarch64-pd-${CURRENT_VERSION}.tar.xz"
TARBALL_SHA256['aarch64']="$(sha256sum "${ROOTFS_DIR}/ubuntu-aarch64-pd-${CURRENT_VERSION}.tar.xz" | awk '{ print $1}')"
TARBALL_URL['arm']="${GIT_RELEASE_URL}/ubuntu-arm-pd-${CURRENT_VERSION}.tar.xz"
TARBALL_SHA256['arm']="$(sha256sum "${ROOTFS_DIR}/ubuntu-arm-pd-${CURRENT_VERSION}.tar.xz" | awk '{ print $1}')"
TARBALL_URL['x86_64']="${GIT_RELEASE_URL}/ubuntu-x86_64-pd-${CURRENT_VERSION}.tar.xz"
TARBALL_SHA256['x86_64']="$(sha256sum "${ROOTFS_DIR}/ubuntu-x86_64-pd-${CURRENT_VERSION}.tar.xz" | awk '{ print $1}')"

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

# Void Linux.
printf "\n[*] Building Void Linux...\n"
version="20210316"
for arch in aarch64 armv7l i686 x86_64; do
	curl --fail --location \
		--output "${WORKDIR}/void-${arch}.tar.xz" \
		"https://alpha.de.repo.voidlinux.org/live/${version}/void-${arch}-ROOTFS-${version}.tar.xz"

	sudo mkdir -m 755 "${WORKDIR}/void-$(translate_arch "$arch")"
	sudo tar -Jxp \
		-f "${WORKDIR}/void-${arch}.tar.xz" \
		-C "${WORKDIR}/void-$(translate_arch "$arch")"

	cat <<- EOF | sudo unshare -mpf bash -e -
	rm -f "${WORKDIR}/void-$(translate_arch "$arch")/etc/resolv.conf"
	echo "nameserver 1.1.1.1" > "${WORKDIR}/void-$(translate_arch "$arch")/etc/resolv.conf"
	mount --bind /dev "${WORKDIR}/void-$(translate_arch "$arch")/dev"
	mount --bind /proc "${WORKDIR}/void-$(translate_arch "$arch")/proc"
	mount --bind /sys "${WORKDIR}/void-$(translate_arch "$arch")/sys"
	chroot "${WORKDIR}/void-$(translate_arch "$arch")" env SSL_NO_VERIFY_PEER=1 xbps-install -Suy xbps
	chroot "${WORKDIR}/void-$(translate_arch "$arch")" env SSL_NO_VERIFY_PEER=1 xbps-install -uy
	chroot "${WORKDIR}/void-$(translate_arch "$arch")" env SSL_NO_VERIFY_PEER=1 xbps-install -y base-minimal
	chroot "${WORKDIR}/void-$(translate_arch "$arch")" env SSL_NO_VERIFY_PEER=1 xbps-remove -y base-voidstrap
	chroot "${WORKDIR}/void-$(translate_arch "$arch")" env SSL_NO_VERIFY_PEER=1 xbps-reconfigure -fa
	EOF

	sudo rm -f "${WORKDIR}/void-$(translate_arch "$arch")"/var/cache/xbps/* || true

	sudo tar -J -c \
		-f "${ROOTFS_DIR}/void-$(translate_arch "$arch")-pd-${CURRENT_VERSION}.tar.xz" \
		-C "$WORKDIR" \
		"void-$(translate_arch "$arch")"
        sudo chown $(id -un):$(id -gn) "${ROOTFS_DIR}/void-$(translate_arch "$arch")-pd-${CURRENT_VERSION}.tar.xz"
done
unset version

cat <<- EOF > "${PLUGIN_DIR}/void.sh"
DISTRO_NAME="Void Linux"

TARBALL_URL['aarch64']="${GIT_RELEASE_URL}/void-aarch64-pd-${CURRENT_VERSION}.tar.xz"
TARBALL_SHA256['aarch64']="$(sha256sum "${ROOTFS_DIR}/void-aarch64-pd-${CURRENT_VERSION}.tar.xz" | awk '{ print $1}')"
TARBALL_URL['arm']="${GIT_RELEASE_URL}/void-arm-pd-${CURRENT_VERSION}.tar.xz"
TARBALL_SHA256['arm']="$(sha256sum "${ROOTFS_DIR}/void-arm-pd-${CURRENT_VERSION}.tar.xz" | awk '{ print $1}')"
TARBALL_URL['i686']="${GIT_RELEASE_URL}/void-i686-pd-${CURRENT_VERSION}.tar.xz"
TARBALL_SHA256['i686']="$(sha256sum "${ROOTFS_DIR}/void-i686-pd-${CURRENT_VERSION}.tar.xz" | awk '{ print $1}')"
TARBALL_URL['x86_64']="${GIT_RELEASE_URL}/void-x86_64-pd-${CURRENT_VERSION}.tar.xz"
TARBALL_SHA256['x86_64']="$(sha256sum "${ROOTFS_DIR}/void-x86_64-pd-${CURRENT_VERSION}.tar.xz" | awk '{ print $1}')"

distro_setup() {
${TAB}# Set default shell to bash.
${TAB}run_proot_cmd usermod --shell /bin/bash root
}
EOF
