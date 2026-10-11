#!/usr/bin/env bash
# Workflow-only: checks out remote main, commits the image, and pushes it.
set -euo pipefail
cd "$(dirname "$0")/.."
source_sha=${1:?source commit required}
digest=${2:?image digest required}
[[ "$source_sha" =~ ^[0-9a-f]{40}$ ]] || { echo 'Invalid source commit' >&2; exit 1; }
[[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo 'Invalid digest' >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo 'Promotion requires a clean checkout' >&2; exit 1; }
git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
# ponytail: one main environment; use PR-based promotion when adding environments.
for attempt in {1..3}; do
  git fetch origin main
  # Keep these paths aligned with the workflow build triggers.
  latest_source=$(git log -1 --format=%H origin/main -- app Dockerfile nginx.conf .dockerignore scripts .github/workflows)
  if ! git merge-base --is-ancestor "$latest_source" "$source_sha"; then
    echo 'A newer source commit exists; skipping this older image.'
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then echo 'promoted=false' >> "$GITHUB_OUTPUT"; fi
    exit 0
  fi
  git checkout --detach origin/main
  python3 scripts/set-image.py "$digest"
  if ! git diff --quiet -- deploy/deployment.yaml; then
    git add deploy/deployment.yaml
    git commit -m "deploy: image from $source_sha"
  fi
  if git push origin HEAD:main; then
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then echo 'promoted=true' >> "$GITHUB_OUTPUT"; fi
    exit 0
  fi
done
echo 'Promotion failed after three attempts; check branch permissions and concurrent pushes.' >&2
exit 1
