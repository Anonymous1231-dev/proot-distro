DISTRO_NAME="Void Linux"

TARBALL_URL['aarch64']="https://github.com/termux/proot-distro/releases/download/v1.10.0/void-aarch64.tar.xz"
TARBALL_SHA256['aarch64']="136b08879f5b45ce98e5a473d971c8152dfb1d9ca64f168c97c3053d3cf358a6"
TARBALL_URL['arm']="https://github.com/termux/proot-distro/releases/download/v1.10.0/void-arm.tar.xz"
TARBALL_SHA256['arm']="ad5cb959c1cbeb2c07a121adff7a2a970082f0cb8b5b7f95b174fd4b6b10e701"
TARBALL_URL['i686']="https://github.com/termux/proot-distro/releases/download/v1.10.0/void-i686.tar.xz"
TARBALL_SHA256['i686']="9be351c1154f6b34d437c93c345f36e32a5fe363cefd5729c4b3869c2127a917"
TARBALL_URL['x86_64']="https://github.com/termux/proot-distro/releases/download/v1.10.0/void-x86_64.tar.xz"
TARBALL_SHA256['x86_64']="2d56c65f20fef100c10d4da4a4853b50dd33bf59078ca02dc52df8b4483b5080"

distro_setup() {
	# Set default shell to bash.
	run_proot_cmd usermod --shell /bin/bash root
}
