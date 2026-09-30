#!/usr/bin/env bash
#
# Bitrise step: fail the build if the branch being built is behind its base branch.
#
# Inputs (provided by Bitrise as environment variables, see step.yml):
#   base_branch    The branch that represents "main" (required).
#   source_branch  The branch being built. Defaults to $BITRISE_GIT_BRANCH.
#   skip_branches  Extra branches to skip the check on, space or comma separated.
#
# Output:
#   BRANCH_CHECK_COMMITS_BEHIND  Number of base-branch commits missing from the source branch.

set -euo pipefail

log()  { printf '[branch-check] %s\n' "$*"; }
fail() { log "ERROR: $*"; exit 1; }

export_output() {
  if command -v envman >/dev/null 2>&1; then
    envman add --key BRANCH_CHECK_COMMITS_BEHIND --value "$1"
  fi
}

BASE_BRANCH="${base_branch:-}"
SOURCE_BRANCH="${source_branch:-${BITRISE_GIT_BRANCH:-}}"
SKIP_BRANCHES="$(printf '%s' "${skip_branches:-}" | tr ',' ' ')"

[ -n "$BASE_BRANCH" ] || fail "base_branch input is required."

cd "${BITRISE_SOURCE_DIR:-.}"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not inside a git repository: $(pwd)"

if [ -z "$SOURCE_BRANCH" ]; then
  SOURCE_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
fi

log "Source branch: $SOURCE_BRANCH"
log "Base branch:   $BASE_BRANCH"

# Skip when building the base branch itself or any explicitly skipped branch.
for skip in "$BASE_BRANCH" $SKIP_BRANCHES; do
  if [ "$SOURCE_BRANCH" = "$skip" ]; then
    log "Building '$SOURCE_BRANCH', which is exempt from the check. Skipping."
    export_output 0
    exit 0
  fi
done

# Bitrise clones can be shallow; merge-base needs full history.
if [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]; then
  log "Repository is shallow, fetching full history..."
  git fetch --quiet --unshallow origin
fi

git ls-remote --exit-code --heads origin "$BASE_BRANCH" >/dev/null 2>&1 \
  || fail "base branch '$BASE_BRANCH' does not exist on origin."

git fetch --quiet origin "+refs/heads/$BASE_BRANCH:refs/remotes/origin/$BASE_BRANCH"
BASE_REF="refs/remotes/origin/$BASE_BRANCH"

# Prefer the remote tip of the source branch; fall back to HEAD if it can't be fetched.
if git fetch --quiet origin "+refs/heads/$SOURCE_BRANCH:refs/remotes/origin/$SOURCE_BRANCH" 2>/dev/null; then
  SOURCE_REF="refs/remotes/origin/$SOURCE_BRANCH"
else
  log "Could not fetch origin/$SOURCE_BRANCH, comparing HEAD instead."
  SOURCE_REF="HEAD"
fi

if git merge-base --is-ancestor "$BASE_REF" "$SOURCE_REF"; then
  log "'$SOURCE_BRANCH' is up to date with '$BASE_BRANCH'."
  export_output 0
  exit 0
fi

BEHIND_COUNT="$(git rev-list --count "$SOURCE_REF..$BASE_REF")"
export_output "$BEHIND_COUNT"

log "FAILED: '$SOURCE_BRANCH' is $BEHIND_COUNT commit(s) behind '$BASE_BRANCH'."
log "Commits on '$BASE_BRANCH' missing from '$SOURCE_BRANCH':"
git --no-pager log --oneline --no-decorate "$SOURCE_REF..$BASE_REF" | sed 's/^/[branch-check]   /'
log "Merge or rebase '$BASE_BRANCH' into '$SOURCE_BRANCH' and push again."
exit 1
