#!/usr/bin/env bash
set -euo pipefail

csv_file="${1:-}"
groupname="students"

if [[ -z "${csv_file}" || ! -r "${csv_file}" ]]; then
  echo "Usage: $0 <path-to-newusers.csv>" >&2
  exit 2
fi

# Ensure group exists (idempotent)
if ! getent group "${groupname}" >/dev/null; then
  groupadd "${groupname}"
fi

# Pick a user creation command for this distro
if command -v useradd >/dev/null 2>&1; then
  CREATOR="useradd"
  # useradd flags: create home, primary group, comment (full name)
  create_user() { useradd -m -g "${groupname}" -c "$2" "$1"; }
elif command -v adduser >/dev/null 2>&1; then
  CREATOR="adduser"
  # adduser flags (Debian/Ubuntu)
  create_user() { adduser --disabled-password --ingroup "${groupname}" --gecos "$2" "$1"; }
else
  echo "No user creation command found (useradd/adduser)." >&2
  exit 3
fi

# Normalize input: strip BOM, remove CR, then read CSV
line_no=0
sed '1s/^\xEF\xBB\xBF//' "${csv_file}" | tr -d '\r' | \
while IFS=, read -r username full_name _rest; do
  ((line_no++))

  # Skip blanks and header
  [[ -z "${username// }" ]] && continue
  [[ "${username,,}" == "username" ]] && continue

  # Normalize fields
  username="$(echo "$username" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
  full_name="$(echo "${full_name:-}" | sed 's/^ *//;s/ *$//')"

  # Validate username (POSIX-ish)
  if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    echo "Skipping line ${line_no}: invalid username '$username'" >&2
    continue
  fi

  if id -u "$username" >/dev/null 2>&1; then
    echo "User '$username' already exists; ensuring group membership…"
    usermod -aG "${groupname}" "$username" || true
    continue
  fi

  create_user "$username" "${full_name}"
  echo "Created user: $username (${full_name})"
done
