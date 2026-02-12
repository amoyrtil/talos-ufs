#!/usr/bin/env bash
set -euo pipefail

# Apply UFS patches to siderolabs/pkgs and siderolabs/talos repositories.
#
# Usage:
#   ./scripts/apply-patches.sh <pkgs_dir> <talos_dir>
#
# Arguments:
#   pkgs_dir  - Path to the cloned siderolabs/pkgs repository
#   talos_dir - Path to the cloned siderolabs/talos repository

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHES_DIR="$(cd "${SCRIPT_DIR}/../patches" && pwd)"

PKGS_DIR="${1:?Usage: $0 <pkgs_dir> <talos_dir>}"
TALOS_DIR="${2:?Usage: $0 <pkgs_dir> <talos_dir>}"

apply_patch() {
  local repo_dir="$1"
  local patch_file="$2"
  local repo_name="$3"

  echo "Applying ${patch_file##*/} to ${repo_name}..."

  if ! git -C "${repo_dir}" apply --3way "${patch_file}"; then
    echo "ERROR: Failed to apply ${patch_file##*/} to ${repo_name}" >&2
    echo "The upstream code may have changed. Please update the patch." >&2
    return 1
  fi

  echo "Successfully applied ${patch_file##*/} to ${repo_name}"
}

# Apply kernel config patch to pkgs
apply_patch "${PKGS_DIR}" "${PATCHES_DIR}/kernel-config.patch" "pkgs"

# Apply EFI partition size patch to talos
apply_patch "${TALOS_DIR}" "${PATCHES_DIR}/efi-partition-size.patch" "talos"

echo "All patches applied successfully."
