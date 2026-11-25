#!/usr/bin/env bash
# harden-repo.sh — apply a safe baseline to a GitHub repository you own.
#
# Usage:
#   ./harden-repo.sh OWNER/REPO [--require-pr] [--restrict-actions] [--keep-wiki] [--dry-run]
#
# Typical new-repo flow:
#   gh repo create jfang88/NewRepo --public --license apache-2.0 --add-readme
#   ./harden-repo.sh jfang88/NewRepo
#
# Needs: GitHub CLI (gh) signed in as the repo owner (`gh auth login`), with admin rights on the repo.
# Safe to re-run: rulesets are matched by name and updated in place.
#
# What it applies (defaults suit a solo maintainer who pushes straight to main):
#   1. Default-branch ruleset: block deletion and force-push            (fixes GitHub's "branch isn't protected" banner)
#   2. Release-tag ruleset (v*): block deletion, force-push and moving tags
#   3. Secret scanning + push protection on                              (free for public repos)
#   4. Dependabot alerts + Dependabot security update PRs on
#   5. Private vulnerability reporting on                               (lets people report issues privately)
#   6. Actions: GITHUB_TOKEN read-only by default; workflows can't approve PRs
#   7. Repo hygiene: delete head branches after merge; wiki and projects off unless --keep-wiki
#
# Options:
#   --require-pr        Also require changes to main to arrive via pull request (0 approvals, so a solo
#                       maintainer can still merge). Direct pushes to main will then be rejected.
#   --restrict-actions  Only allow GitHub-owned and verified-creator Actions (may break third-party workflows)
#   --keep-wiki         Leave wiki and projects settings as they are
#   --dry-run           Print what would be done without changing anything

set -euo pipefail

REPO="${1:-}"
[[ -z "$REPO" || "$REPO" != */* ]] && { sed -n '2,30p' "$0"; exit 1; }
shift
REQUIRE_PR=0; RESTRICT_ACTIONS=0; KEEP_WIKI=0; DRY=0
for a in "$@"; do
  case "$a" in
    --require-pr) REQUIRE_PR=1 ;;
    --restrict-actions) RESTRICT_ACTIONS=1 ;;
    --keep-wiki) KEEP_WIKI=1 ;;
    --dry-run) DRY=1 ;;
    *) echo "Unknown option: $a" >&2; exit 1 ;;
  esac
done

command -v gh >/dev/null || { echo "GitHub CLI (gh) not found: https://cli.github.com" >&2; exit 1; }

ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }

# run DESCRIPTION -- gh api ARGS...   (optional stdin JSON via --input -)
run() {
  local desc="$1"; shift; [[ "$1" == "--" ]] && shift
  if (( DRY )); then echo "  [dry-run] $desc: gh $*"; return 0; fi
  if out=$(gh "$@" 2>&1); then ok "$desc"; else warn "$desc: ${out//$'\n'/ }"; fi
}

# Create or update a ruleset by name, from JSON on stdin
upsert_ruleset() {
  local name="$1" body; body=$(cat)
  local id
  id=$(gh api "repos/$REPO/rulesets" --jq ".[] | select(.name==\"$name\") | .id" 2>/dev/null || true)
  if [[ -n "$id" ]]; then
    run "Update ruleset '$name'" -- api -X PUT "repos/$REPO/rulesets/$id" --input - <<<"$body"
  else
    run "Create ruleset '$name'" -- api -X POST "repos/$REPO/rulesets" --input - <<<"$body"
  fi
}

echo "Hardening $REPO"
VIS=$(gh api "repos/$REPO" --jq .visibility)
echo "  visibility: $VIS"
(( DRY )) && echo "  (dry run — nothing will change)"

# 1. Default branch ruleset
PR_RULE=""
if (( REQUIRE_PR )); then
  PR_RULE=',{"type":"pull_request","parameters":{"required_approving_review_count":0,"dismiss_stale_reviews_on_push":true,"require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":false}}'
fi
upsert_ruleset "protect-default-branch" <<EOF
{
  "name": "protect-default-branch",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [ {"type":"deletion"}, {"type":"non_fast_forward"}${PR_RULE} ],
  "bypass_actors": []
}
EOF

# 2. Release tags ruleset
upsert_ruleset "protect-release-tags" <<'EOF'
{
  "name": "protect-release-tags",
  "target": "tag",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/tags/v*"], "exclude": [] } },
  "rules": [ {"type":"deletion"}, {"type":"non_fast_forward"}, {"type":"update"} ],
  "bypass_actors": []
}
EOF

# 3. Secret scanning + push protection (free on public repos; paid add-on for private)
if [[ "$VIS" == "public" ]]; then
  run "Secret scanning + push protection" -- api -X PATCH "repos/$REPO" --input - <<'EOF'
{ "security_and_analysis": {
    "secret_scanning": { "status": "enabled" },
    "secret_scanning_push_protection": { "status": "enabled" } } }
EOF
else
  warn "Private repo: secret scanning needs GitHub Secret Protection (paid). Skipped."
fi

# 4. Dependabot
run "Dependabot alerts"           -- api -X PUT "repos/$REPO/vulnerability-alerts"
run "Dependabot security updates" -- api -X PUT "repos/$REPO/automated-security-fixes"

# 5. Private vulnerability reporting (public repos)
if [[ "$VIS" == "public" ]]; then
  run "Private vulnerability reporting" -- api -X PUT "repos/$REPO/private-vulnerability-reporting"
fi

# 6. Actions hardening
run "Actions: read-only GITHUB_TOKEN, no PR approvals" -- \
  api -X PUT "repos/$REPO/actions/permissions/workflow" \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false
if (( RESTRICT_ACTIONS )); then
  run "Actions: allow selected only" -- api -X PUT "repos/$REPO/actions/permissions" -F enabled=true -f allowed_actions=selected
  run "Actions: GitHub-owned + verified creators" -- api -X PUT "repos/$REPO/actions/permissions/selected-actions" \
    -F github_owned_allowed=true -F verified_allowed=true
fi

# 7. Repo hygiene
if (( KEEP_WIKI )); then
  run "Delete head branches after merge" -- api -X PATCH "repos/$REPO" -F delete_branch_on_merge=true
else
  run "Delete head branches after merge; wiki and projects off" -- \
    api -X PATCH "repos/$REPO" -F delete_branch_on_merge=true -F has_wiki=false -F has_projects=false
fi

echo "Done. Review: https://github.com/$REPO/settings/rules and https://github.com/$REPO/settings/security_analysis"
