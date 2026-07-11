#!/usr/bin/env bash
set -euo pipefail

# Verify that a Talos ISO contains UFS drivers built-in.
#
# Usage:
#   ./scripts/verify-build.sh <iso_path>
#
# Arguments:
#   iso_path - Path to the metal-amd64.iso file

ISO_PATH="${1:?Usage: $0 <iso_path>}"

if [ ! -f "${ISO_PATH}" ]; then
  echo "ERROR: ISO file not found: ${ISO_PATH}" >&2
  exit 1
fi

# Docker requires an absolute path for bind mounts; a relative path is
# interpreted as a named volume and rejected with "invalid characters".
ISO_PATH="$(cd "$(dirname "${ISO_PATH}")" && pwd)/$(basename "${ISO_PATH}")"

echo "Verifying UFS drivers in ${ISO_PATH}..."

RESULT=$(docker run --rm --platform linux/amd64 \
  -v "${ISO_PATH}:/iso:ro" alpine:latest sh -c "
apk add --no-cache xorriso cpio zstd squashfs-tools 2>/dev/null >/dev/null
mkdir -p /tmp/work /tmp/sqsh
# Extract the initramfs from the ISO in userspace with xorriso/osirrox.
# A loop mount would need a host iso9660 kernel module + CAP_SYS_ADMIN,
# which is unreliable on CI runners; xorriso reads the ISO9660 image
# directly with no mount, no loop device, and no privileged container.
osirrox -indev /iso -extract /boot/initramfs.xz /tmp/initramfs.xz 2>/dev/null
cd /tmp/work
zstd -dc /tmp/initramfs.xz | cpio -idm 2>/dev/null
unsquashfs -d /tmp/sqsh rootfs.sqsh 'usr/lib/modules/*/modules.builtin' 2>/dev/null
grep -i ufs /tmp/sqsh/usr/lib/modules/*/modules.builtin || true
")

if echo "${RESULT}" | grep -q "ufshcd-core"; then
  echo "PASS: ufshcd-core found in modules.builtin"
else
  echo "FAIL: ufshcd-core NOT found in modules.builtin" >&2
  exit 1
fi

if echo "${RESULT}" | grep -q "ufshcd-pci"; then
  echo "PASS: ufshcd-pci found in modules.builtin"
else
  echo "FAIL: ufshcd-pci NOT found in modules.builtin" >&2
  exit 1
fi

echo "All UFS driver checks passed."
