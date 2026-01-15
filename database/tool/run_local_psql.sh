#!/usr/bin/env bash
# Run psql against local PostgreSQL with credentials from Doppler.
#
# Usage:
#   ./run_local_psql.sh                        # Interactive session
#   ./run_local_psql.sh -c "SELECT * FROM sites"  # Run a query
#
# Doppler provides DB_PASSWORD, which is passed to psql via PGPASSWORD.
# The _ is a placeholder for $0 in bash -c; "$@" forwards script arguments.

doppler run -- bash -c 'PGPASSWORD=$DB_PASSWORD psql -h localhost -U postgres -d sponsor_portal "$@"' _ "$@"
