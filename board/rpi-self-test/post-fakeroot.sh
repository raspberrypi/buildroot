#!/bin/sh
#
# Runs on the copy of the target directory which is packed into the initramfs.
# The certificates cannot be removed by post-build.sh because buildroot
# generates the CA bundle from them every time the image is built, so the
# bundle would be empty after an incremental build.

set -u
set -e

CERTS_DIR="${TARGET_DIR}/etc/ssl/certs"

if ! grep -q 'BEGIN CERTIFICATE' "${CERTS_DIR}/ca-certificates.crt"; then
	echo "$0: ${CERTS_DIR}/ca-certificates.crt has no certificates" >&2
	exit 1
fi

# curl is given the CA bundle, so the individual certificates and the links
# to them are not needed.
find "${CERTS_DIR}" -mindepth 1 ! -name ca-certificates.crt -delete
rm -rf "${TARGET_DIR}/usr/share/ca-certificates"
