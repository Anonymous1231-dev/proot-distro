DISTRO_NAME="Debian (stable)"

TARBALL_URL["aarch64"]="https://github.com/termux/proot-distro/releases/download/v1.10.0/debian-aarch64.tar.xz"
TARBALL_SHA256["aarch64"]="34113b15340cdc1d1d836b994b831988ecb45000afb87d1fcdaa107a075e767b"
TARBALL_URL["arm"]="https://github.com/termux/proot-distro/releases/download/v1.10.0/debian-arm.tar.xz"
TARBALL_SHA256["arm"]="13ad6e1419fcdfe6e488d314e4f842c627fab96da605ecca229ae710e23ae737"
TARBALL_URL["i686"]="https://github.com/termux/proot-distro/releases/download/v1.10.0/debian-i686.tar.xz"
TARBALL_SHA256["i686"]="2fa4de1a2f37f714263fb46227a4c40c18c3ee909921062a08f819f0cc020aea"
TARBALL_URL["x86_64"]="https://github.com/termux/proot-distro/releases/download/v1.10.0/debian-x86_64.tar.xz"
TARBALL_SHA256["x86_64"]="9f5e4ccb247f4360e1ad61450d16541e4067a2f6c131377ac5ea7a47c21431f3"

distro_setup() {
	# Include security & updates.
	cat <<- EOF > ./etc/apt/sources.list
	deb https://deb.debian.org/debian stable main contrib
	deb https://deb.debian.org/debian-security/ stable/updates main contrib
	deb https://deb.debian.org/debian stable-updates main contrib
	EOF

	# Don't update gvfs-daemons and udisks2
	run_proot_cmd apt-mark hold gvfs-daemons udisks2
}
