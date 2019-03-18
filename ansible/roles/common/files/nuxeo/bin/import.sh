#!/usr/bin/env bash

# Import using the nuxeo-importer-stream addon
# https://github.com/nuxeo/nuxeo-platform-importer/tree/master/nuxeo-importer-stream
SERVER_URL=${SERVER_URL:-http://localhost:8080}
NB_DOCS=${NB_DOCS:-1000}
NB_THREADS=${NB_THREADS:-8}
ROOT_FOLDER=${ROOT_FOLDER:-/default-domain/workspaces}
LOG_PREFIX=nxp-imp-
set -x
# generate random documents into a stream
curl -X POST "$SERVER_URL/nuxeo/site/automation/StreamImporter.runRandomDocumentProducers" -u Administrator:Administrator -H 'content-type: application/json' \
 -d $'{"params":{
      "nbDocuments": '${NB_DOCS}',
      "nbThreads": '${NB_THREADS}',
      "logName": "'${LOG_PREFIX}'docs",
      "avgBlobSizeKB": 1
      }}'
# import the Nuxeo documents from the stream
curl -X POST "$SERVER_URL/nuxeo/site/automation/StreamImporter.runDocumentConsumers" -u Administrator:Administrator -H 'content-type: application/json' \
 -d $'{"params":{
      "rootFolder": "'${ROOT_FOLDER}'",
      "logName": "'${LOG_PREFIX}'docs"
      }}'
