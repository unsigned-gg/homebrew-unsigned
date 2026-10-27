#!/usr/bin/env bash
# Logic test for decide.sh with a fake `gh`. Each case names the facts, runs the script, and
# asserts whether `gh pr merge --auto` (arm) or `--disable-auto` (disarm) was called.
# Run: bash .github/auto-merge/test-decide.sh [path-to-decide.sh]
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DECIDE="${1:-$HERE/decide.sh}"
ROOT_REAL="$(cd "$HERE/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/root/.github"
cp "$ROOT_REAL/.github/auto-merge-paths.txt" "$ROOT_REAL/.github/CODEOWNERS" "$T/root/.github/"

cat > "$T/bin/gh" <<'FAKE'
#!/usr/bin/env bash
echo "gh $*" >> "$FAKE_LOG"
a="$*"
case "$a" in
  *"rules/branches/main"*) echo "${F_RULES:-1}" ;;
  *"--json autoMergeRequest"*) echo "${F_AUTOMERGE_BY:-}" ;;
  *"--json latestReviews"*) echo "${F_CHANGES:-0}" ;;
  *"--json reviewRequests"*) printf '%s' "${F_REVIEW_REQ:-}" ;;
  *"collaborators/"*) case "$a" in *"/collaborators/${F_LABEL_ACTOR:-nobody}/"*) echo "${F_LABEL_PERM:-write}" ;; *) echo "${F_PERM:-write}" ;; esac ;;
  *"issues/"*"/events"*) printf '[[{"event":"labeled","label":{"name":"automerge-deploy"},"actor":{"login":"%s"}}]]' "${F_LABEL_ACTOR:-nobody}" ;;
  *"/files"*) printf '%s' "${F_FILES:-docs/a.md}" ;;
  *"pr merge"*"--disable-auto"*) : ;;
  *"pr merge"*) : ;;
  *) echo "unexpected gh call: $a" >&2; exit 99 ;;
esac
FAKE
chmod +x "$T/bin/gh"

pass=0; fail=0
run() { # name expect(arm|none|disarm) -- env assignments...
  local name="$1" expect="$2"; shift 2
  : > "$T/log"
  ( export PATH="$T/bin:$PATH" FAKE_LOG="$T/log" ROOT="$T/root" REPO=o/r PR=7 BASE_REF=main HEAD_REF=feat/x HEAD_REPO=o/r \
      AUTHOR=alice HEAD_SHA=abc123 TITLE="docs: a" AUTHOR_TYPE=User DRAFT=false CHANGED_FILES=1 LABELS='[]' APP_SLUG=relbot
    for kv in "$@"; do export "$kv"; done
    bash "$DECIDE" > "$T/out" 2>&1 ) ; local rc=$?
  local got=none
  grep -q 'pr merge .*--auto' "$T/log" && got=arm
  grep -q 'pr merge .*--disable-auto' "$T/log" && got=disarm
  if [ "$got" = "$expect" ] && [ "$rc" -eq 0 ]; then pass=$((pass+1)); printf 'ok   %s\n' "$name"
  else fail=$((fail+1)); printf 'FAIL %s: expected %s, got %s (rc=%s)\n' "$name" "$expect" "$got" "$rc"; sed 's/^/     /' "$T/out" | head -5; fi
}

run "docs PR by a writer arms"              arm
run "no required-checks rule: inert"        none  F_RULES=0
run "base is not main"                      none  BASE_REF=release
run "draft"                                 none  DRAFT=true
run "HOLD in the title"                     none  'TITLE=fix: HOLD this'
run "hold label"                            none  'LABELS=["hold"]'
run "needs-review label"                    none  'LABELS=["needs-review"]'
run "do-not-merge label"                    none  'LABELS=["do-not-merge"]'
run "release-please branch"                 none  HEAD_REF=release-please--branches--main
run "changes requested"                     none  F_CHANGES=1
run "fork PR"                               none  HEAD_REPO=evil/r
run "bot author"                            none  AUTHOR=some-bot 'AUTHOR_TYPE=Bot'
run "author without write access"           none  F_PERM=read
run "dependabot major"                      none  AUTHOR='dependabot[bot]' AUTHOR_TYPE=Bot DEP_UPDATE_TYPE=version-update:semver-major
run "dependabot minor arms"                 arm   AUTHOR='dependabot[bot]' AUTHOR_TYPE=Bot DEP_UPDATE_TYPE=version-update:semver-minor
run "review requested from a non-owner"     none  F_REVIEW_REQ=$'@mallory\n'
run "review requested from the owner arms"  arm   F_REVIEW_REQ=$'@todie\n'
# NEVER cases carry a valid automerge-deploy label, so only the NEVER rule can stop them.
run "NEVER path (workflow)"                 none  F_FILES=$'.github/workflows/ci.yml\n' 'LABELS=["automerge-deploy"]' F_LABEL_ACTOR=bob
run "NEVER path among safe ones"            none  F_FILES=$'docs/a.md\n.github/CODEOWNERS\n' 'LABELS=["automerge-deploy"]' F_LABEL_ACTOR=bob
run "NEVER path (agent hooks)"              none  F_FILES=$'.claude/settings.json\n' 'LABELS=["automerge-deploy"]' F_LABEL_ACTOR=bob
run "outside the allow-list, no label"      none  F_FILES=$'Dockerfile\n'
run "outside the allow-list, label by writer arms" arm F_FILES=$'Dockerfile\n' 'LABELS=["automerge-deploy"]' F_LABEL_ACTOR=bob
run "outside the allow-list, label by reader" none F_FILES=$'Dockerfile\n' 'LABELS=["automerge-deploy"]' F_LABEL_ACTOR=bob F_LABEL_PERM=read
run "held PR disarms an App-enabled auto-merge" disarm DRAFT=true F_AUTOMERGE_BY=app/relbot
run "held PR leaves a person's auto-merge" none DRAFT=true F_AUTOMERGE_BY=todie
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
