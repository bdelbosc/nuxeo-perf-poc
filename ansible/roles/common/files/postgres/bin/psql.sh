#!/usr/bin/env bash

# Run psql client
set -x
docker exec -it postgres psql postgresql://{{pg_user}}:{{pg_password}}@postgres:5432/{{pg_db}}
