$env:GH_TOKEN_DEV   = "<dev PAT (repo)>"
$env:GH_TOKEN_QA    = "<qa PAT (repo, pull_requests, checks)>"
$env:GH_TOKEN_OPS   = "<ops PAT (workflow, repo_deployment)>"
$env:GH_TOKEN_MGMT  = "<mgmt PAT (read-only scopes)>"

# Optional for Supabase and Claude
$env:SUPABASE_SERVICE_TOKEN = "<supabase service role key>"
$env:SUPABASE_AUDIT_REF     = "<supabase project ref>"
$env:ANTHROPIC_API_KEY      = "<anthropic key>"
