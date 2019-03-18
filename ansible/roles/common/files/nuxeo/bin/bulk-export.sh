#!/usr/bin/env bash

# Performs a CSV export of the entire repository
SERVER_URL=${SERVER_URL:-http://localhost:8080}
set -e
SCRIPT_PATH="$(cd "$(dirname "$0")"; pwd -P)"
curl -s -X POST "$SERVER_URL/nuxeo/api/v1/search/pp/default_search/bulk/csvExport" -u Administrator:Administrator -H 'Content-Type: application/json' --compressed | tee /tmp/bulk-command.txt | jq .
${SCRIPT_PATH}/bulk-status.sh
