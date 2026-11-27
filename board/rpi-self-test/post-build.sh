#!/bin/sh
#
# The self-test image must not provide any way to log in or to obtain a shell
# on the UART, HDMI/keyboard or network. Remove the login programs and mask
# every systemd unit that could start a getty or an emergency shell.

set -u
set -e

SYSTEMD_DIR="${TARGET_DIR}/etc/systemd/system"
mkdir -p "${SYSTEMD_DIR}"

# The build identity which is shown in the header of the report: the short
# commit id of this buildroot tree, marked -dirty if a tracked file has been
# modified, and the build date (SOURCE_DATE_EPOCH for a reproducible build).
BOARD_DIR="$(dirname "$0")"
BUILD_COMMIT="$(git -C "${BOARD_DIR}" rev-parse --short=10 HEAD 2>/dev/null || true)"
if [ -z "${BUILD_COMMIT}" ]; then
	BUILD_COMMIT="unknown"
elif [ -n "$(git -C "${BOARD_DIR}" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
	BUILD_COMMIT="${BUILD_COMMIT}-dirty"
fi
BUILD_DATE="$(date -u ${SOURCE_DATE_EPOCH:+-d "@${SOURCE_DATE_EPOCH}"} +%Y-%m-%d)"
echo "${BUILD_COMMIT} ${BUILD_DATE}" > "${TARGET_DIR}/etc/rpi-self-test-version"

for unit in \
	autovt@.service \
	console-getty.service \
	container-getty@.service \
	ctrl-alt-del.target \
	debug-shell.service \
	emergency.service \
	emergency.target \
	getty@.service \
	rescue.service \
	rescue.target \
	serial-getty@.service \
	systemd-firstboot.service \
	systemd-network-generator.service; do
	ln -sf /dev/null "${SYSTEMD_DIR}/${unit}"
done
rm -rf "${SYSTEMD_DIR}/getty.target.wants"
# Remove generators which could start a getty / shell or mount a partition.
for gen in debug getty gpt-auto run ssh; do
	rm -f "${TARGET_DIR}/usr/lib/systemd/system-generators/systemd-${gen}-generator"
done

# Do not probe attached disks for btrfs, which the kernel does not support.
rm -f "${TARGET_DIR}/usr/lib/udev/rules.d/64-btrfs.rules"

# Only the Wi-Fi / Bluetooth firmware for BCM2837, BCM2711 and BCM2712 boards
# (CYW43430A1, CYW43455 and CYW43456) is needed. Remove the firmware for the
# Zero family and Pico W.
FIRMWARE_DIR="${TARGET_DIR}/usr/lib/firmware"
rm -rf "${FIRMWARE_DIR}/synaptics"
rm -f "${FIRMWARE_DIR}"/*/*4343[69A]* \
	"${FIRMWARE_DIR}"/*/*43430[bB]0* \
	"${FIRMWARE_DIR}"/*/*model-zero* \
	"${FIRMWARE_DIR}"/*/*0-compute-module*

# Names are resolved from /etc files and DNS. The systemd name service
# plugins are large and are not needed.
rm -f "${TARGET_DIR}"/usr/lib/libnss_systemd.so* \
	"${TARGET_DIR}"/usr/lib/libnss_resolve.so* \
	"${TARGET_DIR}"/usr/lib/libnss_myhostname.so*
sed -i -E -e 's/^(passwd|group|shadow):.*/\1:\t\tfiles/' \
	-e 's/^hosts:.*/hosts:\t\tfiles dns/' "${TARGET_DIR}/etc/nsswitch.conf"

rm -rf "${TARGET_DIR}/usr/share/bash-completion"

# Tools which could start a program, mount a disk or change the boot setup.
# Nothing in the self-test uses them.
for prog in bootctl hwclock mount.ddi systemd-creds systemd-dissect \
	systemd-mount systemd-pty-forward systemd-run systemd-socket-activate \
	systemd-stdio-bridge systemd-umount systemd-vpick wcurl; do
	rm -f "${TARGET_DIR}/usr/bin/${prog}"
done
for unit in systemd-creds.socket systemd-factory-reset.socket; do
	rm -f "${TARGET_DIR}/usr/lib/systemd/system/sockets.target.wants/${unit}"
done

# Make sure that nothing is left which could provide a login or a shell
# with elevated privileges.
for dir in bin sbin usr/bin usr/sbin; do
	for prog in agetty getty login su sulogin nologin passwd; do
		rm -f "${TARGET_DIR}/${dir}/${prog}"
	done
done

# Lock all accounts (buildroot already disables the root password when
# BR2_TARGET_ENABLE_ROOT_LOGIN is not set).
sed -i -E 's/^([^:]+):[^:]*:/\1:!*:/' "${TARGET_DIR}/etc/shadow"

# Enable only the services the self-test needs rather than relying on the
# first boot presets.
mkdir -p "${SYSTEMD_DIR}/multi-user.target.wants"
for unit in rpi-self-test.service systemd-networkd.service systemd-resolved.service; do
	ln -sf "/usr/lib/systemd/system/${unit}" \
		"${SYSTEMD_DIR}/multi-user.target.wants/${unit}"
done
