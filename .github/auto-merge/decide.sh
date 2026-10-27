#!/usr/bin/env bash
# Decide whether a pull request gets GitHub auto-merge, and enable it or disarm it.
# Run by .github/workflows/auto-merge.yml from the BASE checkout; it reads the PR through
# the API and never runs PR content. All PR-controlled values arrive as environment variables.
#
# Armed by default, no label (Christian 2026-10-27, as unsigned-paas): a non-draft PR to main from a
# branch of this repo whose author has write access, or a Dependabot patch/minor update.
# Held, any one of: draft; HOLD in the title; labels hold, do-not-merge, needs-review,
# review-requested; a CHANGES_REQUESTED review; a review request to anyone who is not a
# CODEOWNERS owner. Paths: .github/auto-merge-paths.txt (NEVER lines are absolute; a file outside
# the safe lines needs the `automerge-deploy` label from a writer).
# GitHub merges when every required check passes on the exact head. This script never decides green.
set -euo pipefail

ROOT="${ROOT:-.}"
: "${REPO:?}" "${PR:?}" "${BASE_REF:?}" "${HEAD_REF:?}" "${HEAD_REPO:?}" "${AUTHOR:?}" "${HEAD_SHA:?}"
TITLE="${TITLE:-}" AUTHOR_TYPE="${AUTHOR_TYPE:-User}" DRAFT="${DRAFT:-false}" CHANGED_FILES="${CHANGED_FILES:-0}"
LABELS="${LABELS:-[]}" DEP_UPDATE_TYPE="${DEP_UPDATE_TYPE:-}" APP_SLUG="${APP_SLUG:-}"

disarm() {
  local by
  by=$(gh pr view "$PR" -R "$REPO" --json autoMergeRequest --jq '.autoMergeRequest.enabledBy.login // empty')
  case "$by" in
    "$APP_SLUG"|"${APP_SLUG}[bot]"|"app/$APP_SLUG")
      [ -n "$APP_SLUG" ] || return 0
      gh pr merge "$PR" -R "$REPO" --disable-auto
      echo "::notice::disabled the auto-merge this workflow enabled earlier" ;;
  esac
}
skip() { echo "::notice::auto-merge not enabled: $1"; disarm; exit 0; }
has_label() { jq -e --arg l "$1" 'index($l) != null' <<<"$LABELS" >/dev/null; }
is_writer() {
  local perm
  perm=$(gh api "repos/$REPO/collaborators/$1/permission" --jq .permission 2>/dev/null) || perm=none
  case "$perm" in admin|maintain|write) return 0 ;; *) return 1 ;; esac
}
label_by_writer() {
  local who
  who=$(gh api --paginate --slurp "repos/$REPO/issues/$PR/events" \
    | jq -r --arg l "$1" '[.[][] | select(.event=="labeled" and .label.name==$l)] | last | .actor.login // empty')
  [ -n "$who" ] && is_writer "$who"
}

[ "$BASE_REF" = "main" ] || skip "base is $BASE_REF, not main"

# Inert until main has a required-status-checks rule: without one a clean PR merges at once.
n=$(gh api "repos/$REPO/rules/branches/main" --jq '[.[] | select(.type=="required_status_checks")] | length')
[ "$n" -ge 1 ] || skip "main has no required_status_checks rule (merging would not wait for CI)"

[ "$DRAFT" = "true" ] && skip "draft"
shopt -s nocasematch
[[ "$TITLE" =~ (^|[^[:alpha:]])hold([^[:alpha:]]|$) ]] && skip "title contains HOLD"
shopt -u nocasematch
[[ "$HEAD_REF" == release-please--* ]] && skip "release-please PR is merged by the operator"
for l in hold do-not-merge needs-review review-requested; do
  has_label "$l" && skip "label $l"
done
changes=$(gh pr view "$PR" -R "$REPO" --json latestReviews --jq '[.latestReviews[] | select(.state=="CHANGES_REQUESTED")] | length')
[ "$changes" -eq 0 ] || skip "a reviewer requested changes"
[ "$CHANGED_FILES" -lt 3000 ] || skip "diff too large to inspect (API lists 3000 files at most)"

[ "$HEAD_REPO" = "$REPO" ] || skip "PR from a fork"
if [ "$AUTHOR" = "dependabot[bot]" ]; then
  case "$DEP_UPDATE_TYPE" in
    version-update:semver-patch|version-update:semver-minor) ;;
    *) skip "dependabot update type '${DEP_UPDATE_TYPE:-unknown}' is not patch or minor" ;;
  esac
elif [ "$AUTHOR_TYPE" = "Bot" ]; then
  skip "bot author $AUTHOR"
else
  is_writer "$AUTHOR" || skip "author $AUTHOR has no write access"
fi

# A review request to anyone who is not a CODEOWNERS owner is an opt-in to review. Owners come
# from the base ref; their automatic requests do not hold.
owners=$(grep -vE '^\s*(#|$)' "$ROOT/.github/CODEOWNERS" | grep -oE '@[A-Za-z0-9_./-]+' | tr 'A-Z' 'a-z' | sort -u || true)
requested=$(gh pr view "$PR" -R "$REPO" --json reviewRequests --jq '.reviewRequests[] | "@" + (.login // .slug) | ascii_downcase')
extra=$(comm -23 <(sort -u <<<"$requested" | grep -v '^$' || true) <(printf '%s\n' "$owners") | paste -sd, -)
[ -z "$extra" ] || skip "review requested from $extra"

# Paths. The allow-list is read from the base checkout, never from the PR.
mapfile -t safe  < <(grep -vE '^\s*(#|!|$)' "$ROOT/.github/auto-merge-paths.txt")
mapfile -t never < <(grep -E '^!' "$ROOT/.github/auto-merge-paths.txt" | sed 's/^!//')
mapfile -t files < <(gh api --paginate "repos/$REPO/pulls/$PR/files" --jq '.[] | .filename, (.previous_filename // empty)')
[ "${#files[@]}" -gt 0 ] || skip "no changed files returned"
deploy=false
for f in "${files[@]}"; do
  for p in "${never[@]}"; do
    # shellcheck disable=SC2053
    [[ "$f" == $p ]] && skip "protected path $f"
  done
  hit=false
  for p in "${safe[@]}"; do
    # shellcheck disable=SC2053
    [[ "$f" == $p ]] && { hit=true; break; }
  done
  $hit || deploy=true
done
if $deploy; then
  has_label automerge-deploy || skip "touches paths outside the allow-list; needs the automerge-deploy label"
  label_by_writer automerge-deploy || skip "automerge-deploy label not applied by a writer"
fi

if out=$(gh pr merge "$PR" -R "$REPO" --auto --merge --match-head-commit "$HEAD_SHA" 2>&1); then
  echo "$out"
elif grep -qi 'clean status' <<<"$out"; then
  # Already mergeable with the required rule present: the required checks passed.
  gh pr merge "$PR" -R "$REPO" --merge --match-head-commit "$HEAD_SHA"
else
  echo "$out" >&2
  exit 1
fi
