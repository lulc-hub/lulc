#!/bin/bash -xe
# Script to set up user accounts and groups on admin machine
# Assumes no accounts/groups have been set up beyond the default when creating the box
# Expects a CSV file with one username per line as the first argument

# Check if a file was provided
if [ -z "$1" ]; then
  echo "Error: Please provide a CSV file with usernames"
  echo "Usage: $0 users.csv"
  exit 1
fi

# Check if the file exists and is readable
if [ ! -r "$1" ]; then
  echo "Error: File '$1' does not exist or is not readable"
  exit 1
fi

groupname='students'
csv_file="$1"

# Ensure the 'students' group exists
if ! getent group "$groupname" > /dev/null; then
  groupadd "$groupname"
fi

# Read usernames from CSV file and create users
while IFS= read -r username; do
  # Skip empty lines
  [ -z "$username" ] && continue

  # Create user
  adduser --gecos '' --disabled-password --ingroup "$groupname" "$username"
  echo "Created user: $username"

  # Set password to match username
  echo "${username}:${username}" | chpasswd

  # Force user to set password on next login
  chage -d 0 "$username"
done < "$csv_file"

# Create archive of user-related files
rm -f /etc/lab.d/users.tar.gz
cd /etc/
tar --same-owner -zpcf lab.d/users.tar.gz passwd shadow group gshadow
cd "$OLDPWD"

# Rsync home folders to each machine (LAB3)
for i in {01..40}; do
  MACHINE='LAB3-'$i
  rsync -aq /etc/lab.d/users.tar.gz "${MACHINE}:/etc/lab.d/users.tar.gz"
  ssh "$MACHINE" "tar --same-owner -xpf /etc/lab.d/users.tar.gz -C /etc/"
  rsync --mkpath -avzr /home/"${groupname}" "${MACHINE}:/home/"
  echo "$i"
done

# Rsync home folders to each machine (LAB1)
for i in {01..20}; do
  MACHINE='LAB1-'$i
  rsync -aq /etc/lab.d/users.tar.gz "${MACHINE}:/etc/lab.d/users.tar.gz"
  ssh "$MACHINE" "tar --same-owner -xpf /etc/lab.d/users.tar.gz -C /etc/"
  rsync --mkpath -avzr /home/"${groupname}" "${MACHINE}:/home/"
  echo "$i"
done

# Rsync to LAB1-ADMIN
MACHINE='LAB1-ADMIN'
rsync -aq /etc/lab.d/users.tar.gz "${MACHINE}:/etc/lab.d/users.tar.gz"
ssh "$MACHINE" "tar --same-owner -xpf /etc/lab.d/users.tar.gz -C /etc/"
rsync --mkpath -avzr /home/"${groupname}" "${MACHINE}:/home/"
echo "$i"
