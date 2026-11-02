#!/usr/bin/env bash
# test.sh — every check this repo has, in one place; exit 0 = safe to commit.
#
# The repo is documentation only (README + CC0 dedication), so the checks guard what can
# break: the license text stays verbatim, NOTICE names the holder the way the security gate
# expects (dotfiles D43), the .gitignore baseline and the security workflow stay in place,
# and relative links in the markdown resolve.
#
#   ./test.sh          run all checks
set -u
cd "$(dirname "$0")" || exit 1

pass=0 fail=0
ok()  { pass=$((pass + 1)); printf '  \342\234\223 %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  \342\234\227 %s\n' "$1"; }
check() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else bad "$name"; fi; }

# --- license ------------------------------------------------------------------
check "LICENSE is the verbatim CC0 1.0 legal code (header)" \
  grep -qx 'CC0 1.0 Universal' LICENSE
check "LICENSE is the verbatim CC0 1.0 legal code (waiver section)" \
  grep -q '^2\. Waiver\.' LICENSE
check "NOTICE names the holder in the form the gate's license-holder rule accepts" \
  grep -qE '^Copyright \(c\) [0-9]{4}(-[0-9]{4})? Pieter de Jong' NOTICE
check "NOTICE states the CC0 dedication and points to LICENSE" \
  grep -q 'CC0 1.0 Universal' NOTICE

# --- repo baseline ------------------------------------------------------------
check ".gitignore ignores .env and .env.*" \
  sh -c 'grep -qx ".env" .gitignore && grep -qx ".env.\*" .gitignore'
check ".gitignore keeps .env.example trackable" \
  grep -qx '!.env.example' .gitignore
check "the security workflow calls the shared reusable workflow" \
  grep -q 'pieteradejong/dotfiles/.github/workflows/security-reusable.yml' .github/workflows/security.yml
check "no .env file is tracked" \
  sh -c '[ -z "$(git ls-files | grep -E "(^|/)\.env(\.[^/]*)?$" | grep -vE "\.env\.(example|template)$")" ]'

# --- markdown links -----------------------------------------------------------
links_ok() {
  local f target rc=0
  for f in $(git ls-files '*.md'); do
    # [text](target) where target is relative (no scheme, no leading #)
    for target in $(grep -oE '\]\([^)#][^)]*\)' "$f" | sed -E 's/^\]\(//; s/\)$//; s/#.*$//' | grep -vE '^[a-z]+:'); do
      [ -e "$(dirname "$f")/$target" ] || { echo "$f -> $target" >&2; rc=1; }
    done
  done
  return $rc
}
check "relative links in markdown resolve" links_ok

# --- security gate ------------------------------------------------------------
GATE="$HOME/dev/dotfiles/security/gate.sh"
if [ -x "$GATE" ]; then
  check "security gate: scan-tree is clean" "$GATE" scan-tree
else
  printf '  - security gate not found at %s (skipped; CI runs it)\n' "$GATE"
fi

printf '\n  %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
