#!/usr/bin/env bash
set -e
psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" <<-EOSQL
	CREATE ROLE {{pg_user}} PASSWORD '{{pg_password}}' NOSUPERUSER CREATEDB NOCREATEROLE INHERIT LOGIN;
	CREATE DATABASE {{pg_db}} ENCODING 'UTF8' OWNER {{pg_user}};
	GRANT ALL PRIVILEGES ON DATABASE {{pg_db}} TO {{pg_user}};
EOSQL
