#!/usr/bin/env bash
set -Eeuo pipefail

# The official entrypoint runs this only on an empty PGDATA. Never enable xtrace.
for name in POSTGRES_PASSWORD DB_MIGRATION_PASSWORD DB_PASSWORD; do
    value="${!name:-}"
    if [[ ${#value} -lt 32 || "$value" == *REPLACE_ME* ]]; then
        printf 'Invalid credential configuration: %s\n' "$name" >&2
        exit 1
    fi
done
if [[ "$POSTGRES_PASSWORD" == "$DB_MIGRATION_PASSWORD" ||
      "$POSTGRES_PASSWORD" == "$DB_PASSWORD" ||
      "$DB_MIGRATION_PASSWORD" == "$DB_PASSWORD" ]]; then
    printf 'Bootstrap, migration and runtime credentials must be distinct.\n' >&2
    exit 1
fi
unset value

PGPASSWORD="$POSTGRES_PASSWORD" psql -X --no-password \
    --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
    --set ON_ERROR_STOP=1 <<'SQL'
\set QUIET on
\getenv migration_password DB_MIGRATION_PASSWORD
\getenv runtime_password DB_PASSWORD
-- Keep statements containing credentials out of diagnostic output.
SET log_statement = 'none';
SET log_min_error_statement = 'panic';
SET password_encryption = 'scram-sha-256';
BEGIN;
CREATE ROLE coti_migrator LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD :'migration_password';
CREATE ROLE coti_runtime LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD :'runtime_password';
REVOKE ALL ON DATABASE coti_conhecimento FROM PUBLIC;
GRANT CONNECT ON DATABASE coti_conhecimento TO coti_migrator, coti_runtime;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;
GRANT USAGE ON SCHEMA public TO coti_migrator, coti_runtime;
CREATE SCHEMA conhecimento AUTHORIZATION coti_migrator;
GRANT USAGE ON SCHEMA conhecimento TO coti_runtime;
ALTER DEFAULT PRIVILEGES FOR ROLE coti_migrator IN SCHEMA conhecimento
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO coti_runtime;
ALTER DEFAULT PRIVILEGES FOR ROLE coti_migrator IN SCHEMA conhecimento
    GRANT USAGE, SELECT ON SEQUENCES TO coti_runtime;
ALTER ROLE coti_migrator IN DATABASE coti_conhecimento SET search_path = conhecimento, public;
ALTER ROLE coti_runtime IN DATABASE coti_conhecimento SET search_path = conhecimento, public;
ALTER ROLE coti_runtime SET statement_timeout = '3s';
ALTER ROLE coti_runtime SET lock_timeout = '3s';
COMMIT;
SQL
