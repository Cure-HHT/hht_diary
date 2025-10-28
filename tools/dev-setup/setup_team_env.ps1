# ==========================================================
# CONFIGURATION — Edit this section before running
# ==========================================================

# Repositories to clone into VMs (owner/repo or full URL)
$RepoList = @(
  "yourorg/yourapp"
  # "yourorg/another-repo"
)

# Windows host folder to share into every VM (scratch only; NOT for Git repos)
$WindowsShare       = "C:\VM-Exchange"             # will be created if missing
$WindowsMountPoint  = "/home/ubuntu/Windows"       # appears inside each VM

# Role identities + optional SSH public key (imported into authorized_keys)
$RoleConfig = @{
  dev   = @{ name="Developer";          email="dev@example.com";   sshKey="$env:USERPROFILE\.ssh\id_ed25519.pub" }
  qa    = @{ name="QA Automation Bot";  email="qa@example.com";    sshKey="$env:USERPROFILE\.ssh\qa_key.pub" }
  ops   = @{ name="DevOps Engineer";    email="ops@example.com";   sshKey="$env:USERPROFILE\.ssh\ops_key.pub" }
  mgmt  = @{ name="Manager";            email="mgmt@example.com";  sshKey="$env:USERPROFILE\.ssh\mgmt_key.pub" }
}

# VM sizing
$roles = @(
  @{ name="dev";  cpus=4; mem="6G"; disk="40G" },
  @{ name="qa";   cpus=4; mem="6G"; disk="40G" },
  @{ name="ops";  cpus=2; mem="4G"; disk="30G" },
  @{ name="mgmt"; cpus=2; mem="2G"; disk="20G" }
)

# ==========================================================
# END CONFIGURATION — Do not edit below this line
# ==========================================================

$ErrorActionPreference = "Stop"

function Ensure-Multipass {
  if (-not (Get-Command multipass -ErrorAction SilentlyContinue)) {
    Write-Host "Multipass not found. Installing via winget..." -ForegroundColor Yellow
    winget install Canonical.Multipass --accept-package-agreements --accept-source-agreements
    Write-Host "If this is the first install, open a NEW PowerShell window and rerun."
  }
}

function In-VM {
  param([string]$Name,[string]$Cmd)
  multipass exec $Name -- bash -lc $Cmd
}

Ensure-Multipass

# Create or reuse VMs
foreach ($r in $roles) {
  if (-not (multipass list | Select-String -SimpleMatch " $($r.name) ")) {
    Write-Host "Creating VM: $($r.name)" -ForegroundColor Cyan
    multipass launch 24.04 --name $r.name --cpus $r.cpus --memory $r.mem --disk $r.disk
  } else {
    Write-Host "VM exists: $($r.name)" -ForegroundColor DarkGray
  }
}

# ---------- Base setup for all VMs ----------
$BaseSetup = @'
set -e
sudo apt update -y
sudo apt install -y git curl unzip ca-certificates gnupg lsb-release \
  openssh-server python3-pip python3-venv docker.io jq zip
sudo usermod -aG docker ubuntu
sudo systemctl enable --now ssh

# Node.js 20
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt install -y nodejs
fi

# GitHub CLI
if ! command -v gh >/dev/null 2>&1; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt update -y && sudo apt install -y gh
fi

# Claude Code CLI + SDK
pip3 install --upgrade pip anthropic
npm install -g @anthropic-ai/claude-code

# Persist Anthropic key if provided (not exported globally)
[ -n "$ANTHROPIC_API_KEY" ] && echo "export ANTHROPIC_API_KEY='$ANTHROPIC_API_KEY'" >> ~/.profile

# Git defaults
git config --global pull.rebase false
git config --global init.defaultBranch main
'@

# Flutter + Android (dev & qa)
$FlutterAndroid = @'
set -e
sudo apt install -y openjdk-17-jdk wget unzip
# Flutter
if [ ! -d /opt/flutter ]; then
  FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.0-stable.tar.xz"
  sudo mkdir -p /opt && cd /opt
  sudo wget -q "$FLUTTER_URL" -O flutter.tar.xz
  sudo tar -xJf flutter.tar.xz && sudo rm flutter.tar.xz
  echo 'export PATH=/opt/flutter/bin:$PATH' | sudo tee /etc/profile.d/flutter.sh >/dev/null
  echo 'export PATH=$HOME/.pub-cache/bin:$PATH' >> ~/.profile
fi
# Android CLI
if [ ! -d /opt/android/cmdline-tools/latest ]; then
  sudo mkdir -p /opt/android/cmdline-tools
  cd /opt/android
  wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdtools.zip
  sudo unzip -q cmdtools.zip -d /opt/android/cmdline-tools
  sudo rm cmdtools.zip
  [ -d /opt/android/cmdline-tools/cmdline-tools ] && sudo mv /opt/android/cmdline-tools/cmdline-tools /opt/android/cmdline-tools/latest
  echo 'export ANDROID_HOME=/opt/android' | sudo tee /etc/profile.d/android.sh >/dev/null
  echo 'export ANDROID_SDK_ROOT=/opt/android' | sudo tee -a /etc/profile.d/android.sh >/dev/null
  echo 'export PATH=$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/tools/bin:$PATH' | sudo tee -a /etc/profile.d/android.sh >/dev/null
fi
source /etc/profile
yes | sdkmanager --licenses >/dev/null
sdkmanager "platform-tools" "build-tools;34.0.0" "platforms;android-34"
source /etc/profile
flutter --version
flutter config --no-analytics
flutter precache --web --linux --android
'@

# Supabase CLI (dev, qa, ops)
$SupabaseCLI = @'
set -e
npm install -g supabase
'@

# Ops: Terraform + Supabase
$OpsInfra = @'
set -e
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
sudo apt update -y && sudo apt install -y terraform
npm install -g supabase
'@

# QA extras: Playwright + PDF toolchain
$QAExtras = @'
set -e
npm install -g playwright
npx playwright install --with-deps
sudo apt install -y wkhtmltopdf pandoc ghostscript
'@

# Apply base setup & identities
foreach ($r in $roles) {
  In-VM $r.name $BaseSetup
  $rc = $RoleConfig[$r.name]
  In-VM $r.name "git config --global user.name '$($rc.name)'; git config --global user.email '$($rc.email)'"
}

In-VM dev  $FlutterAndroid
In-VM qa   $FlutterAndroid
In-VM qa   $QAExtras
In-VM dev  $SupabaseCLI
In-VM qa   $SupabaseCLI
In-VM ops  $OpsInfra

# Import SSH public keys (optional)
foreach ($r in $roles) {
  $rc = $RoleConfig[$r.name]
  if ($rc -and $rc.sshKey -and (Test-Path $rc.sshKey)) {
    $pub = Get-Content $rc.sshKey -Raw
    In-VM $r.name "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$pub' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
  }
}

# ---------------- Per-role GitHub login with PATs (best practices) ----------------
$RolePATs = @{
  dev  = $env:GH_TOKEN_DEV
  qa   = $env:GH_TOKEN_QA
  ops  = $env:GH_TOKEN_OPS
  mgmt = $env:GH_TOKEN_MGMT
}

foreach ($r in $roles) {
  $tok = $RolePATs[$r.name]
  if ($tok) {
    # Auth gh via stdin, then remove token file; harden gh config
    In-VM $r.name "printf '%s' '$tok' > ~/gh_token.txt && gh auth login --with-token < ~/gh_token.txt && rm ~/gh_token.txt"
    In-VM $r.name "mkdir -p ~/.config/gh && chmod 700 ~/.config/gh; [ -f ~/.config/gh/hosts.yml ] && chmod 600 ~/.config/gh/hosts.yml || true"
  }
  # Verify (non-fatal)
  In-VM $r.name "gh auth status >/dev/null 2>&1 || echo '[WARN] gh not authenticated for $($r.name)'"
}

# Shared Windows exchange mount (scratch zone)
if (-not (Test-Path $WindowsShare)) {
  Write-Host "Creating Windows exchange folder: $WindowsShare"
  New-Item -ItemType Directory -Path $WindowsShare | Out-Null
}
foreach ($r in $roles) {
  try { multipass unmount "$($r.name):$WindowsMountPoint" 2>$null } catch {}
  In-VM $r.name "mkdir -p $WindowsMountPoint"
  multipass mount "$WindowsShare" "$($r.name):$WindowsMountPoint"
}

# --- Clean, role-aware Git branch prompt (no user@host) ---
$PromptScript = @'
# Function to show current git branch, if any
parse_git_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null | sed "s/^/ (/;s/$/)/"
}

ROLE_LABEL="{ROLE}"

# Colors
RED="\[\033[0;31m\]"
GREEN="\[\033[0;32m\]"
YELLOW="\[\033[1;33m\]"
BLUE="\[\033[0;34m\]"
CYAN="\[\033[0;36m\]"
RESET="\[\033[0m\]"

# Role color map
case "$ROLE_LABEL" in
  dev)   ROLE_COLOR=$GREEN ;;
  qa)    ROLE_COLOR=$YELLOW ;;
  ops)   ROLE_COLOR=$CYAN ;;
  mgmt)  ROLE_COLOR=$BLUE ;;
  *)     ROLE_COLOR=$RED ;;
esac

# Prompt: [role] path (branch)
export PS1="${ROLE_COLOR}[${ROLE_LABEL}]${RESET} \w\$(parse_git_branch)\n$ "
'@

foreach ($r in $roles) {
  $content = $PromptScript.Replace("{ROLE}", $r.name)
  In-VM $r.name "echo '$content' >> ~/.bashrc; echo '$content' >> ~/.profile"
}

# ---------- Clone repos inside VMs under ~/repos ----------
function Clone-Repos {
  param([string]$VmName)
  $cloneCmd = @"
set -e
mkdir -p ~/repos
cd ~/repos
"@
  foreach ($repo in $RepoList) {
    $safe = $repo.Replace("`"", "")
    $cloneCmd += "gh repo clone $safe || true`n"
  }
  In-VM $VmName $cloneCmd
}
Clone-Repos "dev"
Clone-Repos "qa"
# Clone-Repos "ops"   # uncomment if ops needs code
# Clone-Repos "mgmt"  # usually not needed

# ---------- QA automation with durable evidence + GitHub Checks ----------
$qaRunner = @'
#!/usr/bin/env bash
set -euo pipefail

RETENTION_DAYS=90
BUCKET="qa-reports"        # public bucket
REPORT_ROOT="/home/ubuntu/qa_reports"
RUNS_ROOT="/home/ubuntu/qa_runs"
LOG_DIR="/home/ubuntu/qa_logs"
mkdir -p "$REPORT_ROOT" "$RUNS_ROOT" "$LOG_DIR"

[ -f /etc/profile ] && source /etc/profile
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/flutter/bin:/opt/android/cmdline-tools/latest/bin:/opt/android/platform-tools:$HOME/.pub-cache/bin:$PATH"

if ! gh auth status >/dev/null 2>&1; then
  echo "[QA] gh not authenticated (set GH_TOKEN_QA before provisioning)."
  exit 0
fi

SUPABASE_URL=""
if [ -n "${SUPABASE_AUDIT_REF:-}" ]; then
  SUPABASE_URL="https://${SUPABASE_AUDIT_REF}.supabase.co"
fi

ensure_bucket() {
  if [ -n "${SUPABASE_SERVICE_TOKEN:-}" ] && [ -n "$SUPABASE_URL" ]; then
    curl -sf -X POST "${SUPABASE_URL}/storage/v1/bucket" \
      -H "apikey: ${SUPABASE_SERVICE_TOKEN}" \
      -H "Authorization: Bearer ${SUPABASE_SERVICE_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"name\":\"${BUCKET}\",\"public\":true}" >/dev/null 2>&1 || true
  fi
}

sign_url() {
  local key="$1"
  if [ -z "${SUPABASE_SERVICE_TOKEN:-}" ] || [ -z "$SUPABASE_URL" ]; then echo ""; return; fi
  curl -sf -X POST "${SUPABASE_URL}/storage/v1/object/sign/${BUCKET}/${key}" \
    -H "apikey: ${SUPABASE_SERVICE_TOKEN}" \
    -H "Authorization: Bearer ${SUPABASE_SERVICE_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"expiresIn":2592000}' | jq -r '.signedURL' || true
}

upload_file() {
  local file="$1"; local key="$2"
  if [ -z "${SUPABASE_SERVICE_TOKEN:-}" ] || [ -z "$SUPABASE_URL" ]; then return; fi
  curl -sf -X POST "${SUPABASE_URL}/storage/v1/object/${BUCKET}/${key}" \
    -H "apikey: ${SUPABASE_SERVICE_TOKEN}" \
    -H "Authorization: Bearer ${SUPABASE_SERVICE_TOKEN}" \
    -F "file=@${file}" >/dev/null 2>&1 || true
}

discover_repos() {
  find /home/ubuntu/repos -maxdepth 3 -type d -name ".git" 2>/dev/null | sed 's|/\.git$||'
}

generate_pdfs() {
  local dir="$1"
  local repo="$2"; local pr="$3"; local branch="$4"; local commit="$5"; local result="$6"
  local dt=$(date -u +"%Y-%m-%d %H:%M:%SZ")

  cat > "${dir}/summary_onepager.html" <<EOF
<html><head><meta charset="utf-8"><style>
body{font-family:Arial,Helvetica,sans-serif;margin:24px}
h1{margin:0 0 8px 0}.k{color:#555}.ok{color:#2e7d32}.bad{color:#c62828}
table{border-collapse:collapse;margin-top:12px}td{padding:6px 10px;border:1px solid #ddd}
</style></head><body>
<h1>QA Summary — PR #${pr} (${repo})</h1>
<div class="k">Date (UTC): ${dt}</div>
<div class="k">Branch: <code>${branch}</code> &nbsp; Commit: <code>${commit}</code></div>
<div class="${result=='passed' ? 'ok' : 'bad'}"><strong>Result: ${result^^}</strong></div>
<table>
<tr><td>Flutter</td><td>See attached flutter_report.html / .pdf</td></tr>
<tr><td>Playwright</td><td>See attached playwright report (HTML/PDF)</td></tr>
</table>
<p>This PDF contains this 1-page summary followed by detailed sections.</p>
</body></html>
EOF

  [ -f "${dir}/flutter_report.html" ]   && wkhtmltopdf --enable-local-file-access "${dir}/flutter_report.html"   "${dir}/flutter_report.pdf"   >/dev/null 2>&1 || true
  [ -f "${dir}/playwright/index.html" ] && wkhtmltopdf --enable-local-file-access "${dir}/playwright/index.html" "${dir}/playwright_report.pdf" >/dev/null 2>&1 || true

  cat > "${dir}/details.html" <<EOF
<html><head><meta charset="utf-8"><style>body{font-family:Arial,Helvetica,sans-serif;margin:24px} h2{margin-top:24px}</style></head><body>
<h2>Flutter Details</h2>
<p><a href="flutter_report.html">flutter_report.html</a> &nbsp; <a href="flutter_report.pdf">flutter_report.pdf</a></p>
<pre>$(sed -n '1,500p' "${dir}/flutter.log" 2>/dev/null)</pre>
<h2>Playwright Details</h2>
<p><a href="playwright/index.html">playwright HTML report</a> &nbsp; <a href="playwright_report.pdf">playwright_report.pdf</a></p>
<pre>$(sed -n '1,500p' "${dir}/playwright.log" 2>/dev/null)</pre>
</body></html>
EOF

  wkhtmltopdf --enable-local-file-access "${dir}/summary_onepager.html" "${dir}/details.html" "${dir}/summary.pdf" >/dev/null 2>&1 || true
}

run_flutter_tests() {
  local flog="$1"
  if [ -f "pubspec.yaml" ]; then
    flutter pub get >>"$flog" 2>&1 || true
    flutter test integration_test --machine > flutter_results.json 2>>"$flog" || true
    flutter pub global activate junitreport >>"$flog" 2>&1 || true
    "~/.pub-cache/bin/tojunit" --input flutter_results.json --output flutter/report.xml >>"$flog" 2>&1 || true
    "~/.pub-cache/bin/html" --input flutter/report.xml --output flutter_report.html >>"$flog" 2>&1 || true
    grep -q "<failure" flutter/report.xml && return 1 || return 0
  fi
  echo "No Flutter project." >>"$flog"
  return 0
}

run_playwright_tests() {
  local plog="$1"
  if [ -f "package.json" ]; then
    (npm ci --prefer-offline >/dev/null 2>&1 || npm install >/dev/null 2>&1)
    npx playwright install --with-deps >/dev/null 2>&1 || true
    npx playwright test | tee "$plog"
    return ${PIPESTATUS[0]}
  fi
  echo "No Playwright project." >>"$plog"
  return 0
}

post_check_run() {
  local ownerRepo="$1"; local sha="$2"; local conclusion="$3"; local details="$4"; local title="Automated QA"; local summary="Flutter + Playwright"
  gh api repos/$ownerRepo/check-runs \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -f name="$title" -f head_sha="$sha" -f status=completed -f conclusion="$conclusion" -f details_url="$details" \
    -f output[title]="$title" -f output[summary]="$summary" >/dev/null 2>&1 || true
}

is_production_target() {
  local ownerRepo="$1"; local sha="$2"
  local branches; branches=$(gh api repos/$ownerRepo/commits/$sha/branches-where-head --jq '.[].name' 2>/dev/null || true)
  echo "$branches" | grep -E -q '^(main|master|release/)' && return 0
  local tags; tags=$(gh api repos/$ownerRepo/git/refs/tags --jq '.[].ref' 2>/dev/null || true)
  [ -n "$tags" ] && return 0
  return 1
}

process_repo() {
  local repo_dir="$1"; cd "$repo_dir"
  local origin=$(git remote get-url origin 2>/dev/null || true)
  [[ "$origin" =~ github.com[:/](.+)/(.+?)(\.git)?$ ]] || { echo "[QA] Not GitHub: $origin"; return; }
  local ownerRepo="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"

  local prs=$(gh pr list --repo "$ownerRepo" --state open --json number,headRefName,headRefOid 2>/dev/null || echo "[]")
  echo "$prs" | jq -c '.[]' | while read -r pr; do
    local number=$(echo "$pr" | jq -r '.number')
    local branch=$(echo "$pr"  | jq -r '.headRefName')
    local commit=$(echo "$pr"  | jq -r '.headRefOid')

    local stamp=$(date -u +"%Y-%m-%d__%H-%M-%S")
    local label="${stamp}__${ownerRepo//\//__}__pr_${number}"
    local run_dir="${RUNS_ROOT}/${ownerRepo//\//__}/pr_${number}"
    local rep_dir="${REPORT_ROOT}/${label}"
    mkdir -p "$run_dir" "$rep_dir"
    cd "$run_dir"; rm -rf ./*

    gh pr checkout "$number" --repo "$ownerRepo" >/dev/null

    local flog="${rep_dir}/flutter.log"
    local plog="${rep_dir}/playwright.log"
    : > "$flog"; : > "$plog"

    local res="passed"
    run_flutter_tests "$flog" || res="failed"
    [ -f "flutter_report.html" ] && mv "flutter_report.html" "${rep_dir}/flutter_report.html" || true
    [ -f "flutter/report.xml" ] && cp -r "flutter" "${rep_dir}/" || true

    run_playwright_tests "$plog" || res="failed"
    [ -d "playwright-report" ] && mkdir -p "${rep_dir}/playwright" && cp -r "playwright-report/"* "${rep_dir}/playwright/" || true

    generate_pdfs "$rep_dir" "$ownerRepo" "$number" "$branch" "$commit" "$res"

    cat > "${rep_dir}/summary.json" <<JSON
{
  "repo": "$ownerRepo",
  "pr_number": $number,
  "branch": "$branch",
  "commit": "$commit",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "result": "$res",
  "retention": "ephemeral"
}
JSON

    (cd "$rep_dir" && zip -qr "artifacts.zip" .) || true

    ensure_bucket
    rel="ephemeral/pr_${number}/${label}"
    for f in summary.pdf summary_onepager.html details.html flutter_report.html flutter_report.pdf playwright_report.pdf summary.json artifacts.zip; do
      [ -f "${rep_dir}/$f" ] && upload_file "${rep_dir}/$f" "${rel}/$f"
    done
    sp=$(sign_url "${rel}/summary.pdf")
    [ -n "$sp" ] && sp="${SUPABASE_URL}${sp}" || sp=""

    gh pr comment "$number" --repo "$ownerRepo" --body "QA ${res^^}  
• Branch: \`$branch\`  
• Commit: \`$commit\`  
• 📄 **PDF Summary:** ${sp:-"(uploaded)"}" >/dev/null 2>&1 || true
    post_check_run "$ownerRepo" "$commit" "$( [ "$res" = "passed" ] && echo success || echo failure )" "${sp:-$SUPABASE_URL}"
  done
}

mark_production_runs() {
  for d in $(find "$REPORT_ROOT" -maxdepth 1 -type d -name "20*__*__pr_*" | sort); do
    if [ -f "$d/summary.json" ]; then
      repo=$(jq -r '.repo' "$d/summary.json")
      commit=$(jq -r '.commit' "$d/summary.json")
      if [ -n "$repo" ] && [ -n "$commit" ]; then
        if is_production_target "$repo" "$commit"; then
          jq '.retention="permanent"' "$d/summary.json" > "$d/summary.tmp" && mv "$d/summary.tmp" "$d/summary.json"
          dest="permanent/$(date -u +%Y-%m-%d)__${repo//\//__}__commit_${commit:0:7}"
          for f in summary.pdf summary_onepager.html details.html flutter_report.html flutter_report.pdf playwright_report.pdf summary.json artifacts.zip; do
            [ -f "$d/$f" ] && upload_file "$d/$f" "${dest}/$f"
          done
        fi
      fi
    fi
  done
}

main() {
  for repo in $(discover_repos); do
    process_repo "$repo"
  done
  mark_production_runs
}
main
'@

# Install runner on QA VM
In-VM qa "sudo tee /usr/local/bin/qa_runner.sh >/dev/null << 'EOF'
$qaRunner
EOF
sudo chmod +x /usr/local/bin/qa_runner.sh"

# Export Supabase env to QA VM if provided
if ($env:SUPABASE_SERVICE_TOKEN) { In-VM qa "echo 'export SUPABASE_SERVICE_TOKEN=\"$env:SUPABASE_SERVICE_TOKEN\"' >> ~/.profile" }
if ($env:SUPABASE_AUDIT_REF)     { In-VM qa "echo 'export SUPABASE_AUDIT_REF=\"$env:SUPABASE_AUDIT_REF\"' >> ~/.profile" }

# Cron for runner (every 5 min)
In-VM qa @'
set -e
sudo tee /etc/cron.d/qa_runner >/dev/null <<'CRON'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/flutter/bin:/opt/android/cmdline-tools/latest/bin:/opt/android/platform-tools:/home/ubuntu/.pub-cache/bin
*/5 * * * * ubuntu /usr/local/bin/qa_runner.sh >> /var/log/qa_runner.log 2>&1
CRON
sudo chmod 644 /etc/cron.d/qa_runner
sudo service cron restart
'@

# ---------- Summary ----------
Write-Host ""
Write-Host "✅ Provisioning complete. Per-VM independent clones are ready." -ForegroundColor Green
Write-Host "Repos cloned under:  ~/repos  (inside dev/qa VMs)"
Write-Host "Windows exchange:    $WindowsShare  →  $WindowsMountPoint (all VMs)"
Write-Host "QA automation:       active (every 5 min) — scans ~/repos on qa VM"
Write-Host "Artifacts (QA VM):   ~/qa_reports  → Supabase public bucket 'qa-reports' (permanent for prod/tagged)"
Write-Host ""
Write-Host "Git Identities:"
$RoleConfig.GetEnumerator() | ForEach-Object {
  Write-Host ("  [{0}] {1} <{2}>" -f $_.Key, $_.Value.name, $_.Value.email)
}
