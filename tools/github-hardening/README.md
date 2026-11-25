# GitHub repo hardening

A safe baseline for personal GitHub repositories, built for a solo maintainer who pushes straight to `main` (including pushes made by AI coding agents).

GitHub has **no account-wide "default ruleset" for personal accounts**. Organisation-wide rulesets need a paid GitHub Team or Enterprise plan. So the baseline is applied in three layers:

| Layer | When | How |
|-------|------|-----|
| **A. Account settings** | Once | Click through the checklist below |
| **B. Per-repo baseline** | Every new repo, and once for each existing repo | Run [`harden-repo.sh`](harden-repo.sh), or import the ruleset JSON files in the UI |
| **C. Periodic review** | Quarterly | Checklist at the end |

---

## A. One-time account settings

1. **Settings → Password and authentication**
   - Two-factor authentication on, preferably with a **passkey or security key**. Keep the recovery codes offline.
2. **Settings → Code security**
   - Dependency graph, Dependabot alerts and Dependabot security updates: **Enable all**, and tick **automatically enable for new repositories**.
   - Make sure push protection for yourself is on. It blocks you from pushing known secret formats to any public repo.
   - New public repos on personal accounts already get secret scanning and push protection by default.
3. **Settings → Applications** (*Installed GitHub Apps* and *Authorized OAuth Apps*)
   - Review every app. For AI agents and other GitHub Apps that can push code (e.g. Claude), set **Repository access → Only select repositories**, not *All repositories*. These apps often hold **admin** rights on the repos they can reach.
4. **Settings → Developer settings → Personal access tokens**
   - Prefer **fine-grained** tokens scoped to specific repos, with an expiry date. Delete classic tokens you don't use.
5. **Settings → SSH and GPG keys**
   - Remove keys from machines you no longer use. Optional: add a signing key and turn on **vigilant mode** (see the trade-off below).

## B. Per-repo baseline

### Option 1: script (recommended)

Needs the [GitHub CLI](https://cli.github.com) signed in as you (`gh auth login`).

```bash
# New repo
gh repo create jfang88/NewRepo --public --license apache-2.0 --add-readme
./harden-repo.sh jfang88/NewRepo

# Existing repo (safe to re-run)
./harden-repo.sh jfang88/AgenticSecurity

# Preview without changing anything
./harden-repo.sh jfang88/AgenticSecurity --dry-run
```

What it applies:

| # | Setting | Why |
|---|---------|-----|
| 1 | Ruleset `protect-default-branch`: **block deletion** and **block force-push** on the default branch | Stops history rewrites or loss of `main`, by you, a leaked token or an over-eager agent. This clears GitHub's "branch isn't protected" warning |
| 2 | Ruleset `protect-release-tags`: block deletion, force-push and moving `v*` tags | Release tags can't be quietly repointed to different code |
| 3 | Secret scanning + push protection (public repos) | Known secret formats are blocked at push and alerted if found |
| 4 | Dependabot alerts + security update PRs | Vulnerable dependencies are flagged and fix PRs are opened |
| 5 | Private vulnerability reporting (public repos) | People can report issues privately rather than in a public issue |
| 6 | Actions: `GITHUB_TOKEN` read-only by default; workflows can't approve PRs | Limits the damage from a compromised or malicious workflow |
| 7 | Delete head branches after merge; wiki and projects off (keep them with `--keep-wiki`) | Less clutter and attack surface |

Options: `--require-pr` (changes must come through a pull request, with 0 approvals so you can still merge your own) · `--restrict-actions` (only GitHub-owned and verified-creator Actions) · `--keep-wiki` · `--dry-run`.

### Option 2: click through the UI

1. Repo → **Settings → Rules → Rulesets → New ruleset → Import a ruleset**, and choose [`ruleset-protect-default-branch.json`](ruleset-protect-default-branch.json). Repeat with [`ruleset-protect-release-tags.json`](ruleset-protect-release-tags.json).
   - Or create it by hand: **New branch ruleset** → name it → Enforcement **Active** → Target **Include default branch** → tick **Restrict deletions** and **Block force pushes** → **Create**.
2. **Settings → Advanced Security** (called *Code security* on some accounts): turn on Dependabot alerts, Dependabot security updates, secret scanning, push protection and private vulnerability reporting.
3. **Settings → Actions → General → Workflow permissions**: choose **Read repository contents and packages permissions** and untick **Allow GitHub Actions to create and approve pull requests**.

### Trade-offs for a solo maintainer

| Rule | Recommendation | Why |
|------|----------------|-----|
| Block force-push / deletion | **Always** | No downside for normal work |
| Require pull request | Optional (`--require-pr`) | Adds a PR step to every change. AI agents must push to a branch and open a PR. Worth it once others contribute |
| Require approvals (≥ 1) | **No**, while you're the only maintainer | You can't approve your own PR, so you'd be locked out |
| Require signed commits | Only if **every** pusher signs | Commits pushed by tools or agents that can't sign would be rejected |
| Bypass list | Leave empty | If you ever need to force-push, temporarily set the ruleset to *Disabled*, then switch it back |

## C. Quarterly review

- [ ] Security tab of each repo: open Dependabot and secret scanning alerts triaged
- [ ] Installed apps and authorised OAuth apps still needed; repository access still *selected*
- [ ] Personal access tokens: unused or expiring tokens removed
- [ ] Rulesets still **Active** on every repo (`gh api repos/OWNER/REPO/rulesets`)
- [ ] Security log (**Settings → Security log**) has no unexpected events

## Status of repos in this project

| Repo | Secret scanning + push protection | Branch / tag rulesets | Dependabot | Private vuln. reporting | Secrets found in history |
|------|-----------------------------------|-----------------------|-----------|-------------------------|--------------------------|
| `jfang88/AgenticSecurity` | ✅ On | ❌ None (run the script) | ⚠️ Not verified | ❌ Off | None (3 commits scanned, 2026-11-25) |
| `jfang88/copilot-threat-model-agent` | ✅ On | ❌ None (run the script) | ⚠️ Not verified | ❌ Off | None (7 commits + Office files scanned, 2026-11-25) |
