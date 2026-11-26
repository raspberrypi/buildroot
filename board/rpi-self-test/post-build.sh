#!/bin/sh
#
# The self-test image must not provide any way to log in or to obtain a shell
# on the UART, HDMI/keyboard or network. Remove the login programs and mask
# every systemd unit that could start a getty or an emergency shell.

set -u
set -e

SYSTEMD_DIR="${TARGET_DIR}/etc/systemd/system"
mkdir -p "${SYSTEMD_DIR}"

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

# Only the Wi-Fi / Bluetooth firmware for BCM2711 and BCM2712 boards (CYW43455
# and CYW43456) is needed.
FIRMWARE_DIR="${TARGET_DIR}/usr/lib/firmware"
rm -rf "${FIRMWARE_DIR}/synaptics"
rm -f "${FIRMWARE_DIR}"/*/*4343[0-9A]* \
	"${FIRMWARE_DIR}"/*/*3-model-*

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

# curl is given the CA bundle, so the individual certificates and the links
# to them are not needed.
find "${TARGET_DIR}/etc/ssl/certs" -mindepth 1 ! -name ca-certificates.crt -delete
rm -rf "${TARGET_DIR}/usr/share/ca-certificates"

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
