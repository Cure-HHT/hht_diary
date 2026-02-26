# Database Tools

Scripts for managing the PostgreSQL database and Identity Platform users.

## Prerequisites

- [Doppler CLI](https://docs.doppler.com/docs/install-cli) configured for the target environment
- `psql` (PostgreSQL client)
- `gcloud` authenticated (`gcloud auth login`)
- `curl`, `jq`

## Scripts

### `add_user.sh`

Add portal users from CSV input. Inserts into the database, assigns roles,
and creates Google Identity Platform accounts.

**CSV format** (no header row):

```
email,name,role
```

Valid roles: `Investigator`, `Sponsor`, `Auditor`, `Analyst`, `Administrator`,
`Developer Admin`

**Usage:**

```bash
# Single user
echo "alice@example.com,Alice Smith,Investigator" | doppler run -- ./database/tool/add_user.sh

# Multiple users from heredoc
cat <<CSV | doppler run -- ./database/tool/add_user.sh
alice@example.com,Alice Smith,Investigator
bob@example.com,Bob Jones,Developer Admin
CSV

# From a file
cat users.csv | doppler run -- ./database/tool/add_user.sh
```

**What it does:**

1. Reads CSV records from stdin
2. Inserts into `portal_users` with `ON CONFLICT (email) DO NOTHING`
3. Looks up actual user IDs (handles pre-existing rows)
4. Inserts into `portal_user_roles` with `ON CONFLICT (user_id, role) DO NOTHING`
5. Creates or updates each user in Identity Platform (`accounts:signUp` / `accounts:update`)
6. Links `firebase_uid` back to `portal_users`

**Doppler secrets used:** `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`,
`DB_PASSWORD`, `DEFAULT_USER_PWD`, `SPONSOR`, `ENVIRONMENT`

### `run_local_psql.sh`

Open a psql session against local PostgreSQL using Doppler for credentials.

```bash
# Interactive session
./database/tool/run_local_psql.sh

# Run a query
./database/tool/run_local_psql.sh -c "SELECT * FROM portal_users"
```

### `consolidate-schema.sh`

Consolidate database schema files into a single SQL file for Cloud SQL
deployment. Resolves `\ir` includes and strips psql-specific commands.

```bash
# Default output: database/init-consolidated.sql
./database/tool/consolidate-schema.sh

# Custom output path
./database/tool/consolidate-schema.sh /tmp/schema.sql
```
