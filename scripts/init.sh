#!/usr/bin/env bash
# Replace the YOUR_GITHUB_USER placeholder everywhere with your GitHub username.
# Usage: ./scripts/init.sh <github-user>
set -euo pipefail
user="${1:?usage: $0 <github-user>}"
user="$(echo "$user" | tr 'A-Z' 'a-z')"   # GHCR image names must be lowercase
grep -rl --exclude-dir=.git YOUR_GITHUB_USER . | while read -r f; do
  sed -i.bak "s/YOUR_GITHUB_USER/${user}/g" "$f" && rm -f "$f.bak"
  echo "updated $f"
done
