#!/usr/bin/env bash
set -euo pipefail
url=${1:?public application URL required}
version=${2:?expected source commit required}
[[ "$url" =~ ^https?:// ]] || { echo 'URL must start with http:// or https://' >&2; exit 1; }
[[ "$version" =~ ^[0-9a-f]{40}$ ]] || { echo 'Invalid source commit' >&2; exit 1; }
for attempt in {1..90}; do
  actual=$(curl --fail --silent --max-time 5 -H 'Cache-Control: no-cache' \
    "${url%/}/version.txt?expected=$version&attempt=$attempt" || true)
  if [[ "$actual" == "$version" ]]; then
    echo "Deployment verified at $url: $version"
    exit 0
  fi
  sleep 5
done
echo "Timed out waiting for $version at $url; inspect Argo sync and pod health." >&2
exit 1
