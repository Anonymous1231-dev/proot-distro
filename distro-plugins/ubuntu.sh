DISTRO_NAME="Ubuntu (21.04)"

TARBALL_URL['aarch64']="https://github.com/termux/proot-distro/releases/download/v1.10.0/ubuntu-aarch64.tar.xz"
TARBALL_SHA256['aarch64']="8ccff297706d25206c9fcd5222f648756b5260a2864db0cfcc04b2dfec9b223f"
TARBALL_URL['arm']="https://github.com/termux/proot-distro/releases/download/v1.10.0/ubuntu-arm.tar.xz"
TARBALL_SHA256['arm']="0b788cd4862941d19d645a1a288fbc5ee9caf033f56fb414096ce814bd6c14ee"
TARBALL_URL['x86_64']="https://github.com/termux/proot-distro/releases/download/v1.10.0/ubuntu-x86_64.tar.xz"
TARBALL_SHA256['x86_64']="2008aa7791e7e9399b3bfd20c4da8c90bcb7f02c4fd71d6fb046913b84c0f508"

distro_setup() {
	# Enable additional repository components.
	if [ "$DISTRO_ARCH" = "amd64" ]; then
		echo "deb http://archive.ubuntu.com/ubuntu focal main universe multiverse" >> ./etc/apt/sources.list
	else
		echo "deb http://ports.ubuntu.com/ubuntu-ports focal main universe multiverse" >> ./etc/apt/sources.list
	fi

	# Don't update gvfs-daemons and udisks2
	run_proot_cmd apt-mark hold gvfs-daemons udisks2
}
