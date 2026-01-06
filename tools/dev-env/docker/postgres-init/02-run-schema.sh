#!/bin/bash
# Run database schema initialization
# This script runs inside the PostgreSQL container during startup

set -e

echo "Initializing Sponsor Portal database schema..."

# Run init.sql which includes all other SQL files
# Note: psql supports \ir (include relative) for proper file includes
cd /database
psql -v ON_ERROR_STOP=1 --username postgres --dbname "${POSTGRES_DB:-sponsor_portal}" -f init.sql

echo "Database schema initialized successfully!"
