DISTRO_NAME="Ubuntu (20.04)"

TARBALL_URL['aarch64']="https://github.com/termux/proot-distro/releases/download/v1.10.0/ubuntu-aarch64.tar.xz"
TARBALL_SHA256['aarch64']="b262f18521cb9ca7a46a83093f2d992f50ecd5d7d87d919541833f6095f8ae0f"
TARBALL_URL['arm']="https://github.com/termux/proot-distro/releases/download/v1.10.0/ubuntu-arm.tar.xz"
TARBALL_SHA256['arm']="e8bcaea0076925f448d93494e424decdf391b96bb0904497ecc6dc29d70bc58b"
TARBALL_URL['x86_64']="https://github.com/termux/proot-distro/releases/download/v1.10.0/ubuntu-x86_64.tar.xz"
TARBALL_SHA256['x86_64']="39a1d14bfd9250e2fb7a09436237f465b96b7698de2e37cd247837080458ee56"

distro_setup() {
	# Enable additional repository components.
	if [ "$DISTRO_ARCH" = "amd64" ]; then
		echo "deb http://archive.ubuntu.com/ubuntu focal main universe multiverse" > ./etc/apt/sources.list
	else
		echo "deb http://ports.ubuntu.com/ubuntu-ports focal main universe multiverse" > ./etc/apt/sources.list
	fi

	# Don't update gvfs-daemons and udisks2
	run_proot_cmd apt-mark hold gvfs-daemons udisks2
}
