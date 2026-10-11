#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
image=${1:-web-app-test:local}
version=${2:-local}
[[ "$version" =~ ^[a-zA-Z0-9._-]+$ ]] || { echo 'Invalid version' >&2; exit 1; }
docker build --build-arg "VERSION=$version" --tag "$image" .
container=$(docker run --detach --read-only --tmpfs /tmp:rw,noexec,nosuid,size=16m \
  --cap-drop ALL --security-opt no-new-privileges --user 101:101 \
  --publish 127.0.0.1::8080 "$image")
trap 'docker rm --force "$container" >/dev/null' EXIT
port=$(docker port "$container" 8080/tcp)
url="http://$port"
for attempt in {1..30}; do
  if curl --fail --silent --max-time 2 "$url/healthz" >/dev/null; then break; fi
  sleep 1
done
[[ "$(curl --fail --silent --max-time 5 "$url/healthz")" == ok ]]
curl --fail --silent --max-time 5 "$url/" | cmp --silent app/index.html -
[[ "$(curl --fail --silent --max-time 5 "$url/version.txt")" == "$version" ]]
[[ "$(curl --silent --output /dev/null --write-out '%{http_code}' --max-time 5 "$url/missing")" == 404 ]]
echo "Container smoke check passed: $image ($version)"
