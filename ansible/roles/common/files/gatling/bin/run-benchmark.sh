#!/usr/bin/env bash

set -e
cd $(dirname $0)
HERE=`readlink -e .`
TARGET=http://nuxeo1:8080/nuxeo
NUXEO_GIT=https://github.com/nuxeo/nuxeo.git
SCRIPT_ROOT="/ssd/nuxeo.git"
SCRIPT_DIR="nuxeo-distribution/nuxeo-jsf-ui-gatling-tests"
SCRIPT_PATH="$SCRIPT_ROOT/$SCRIPT_DIR"
SCRIPT_BRANCH=master
REDIS_DB=7
REDIS_PORT=16379
REPORT_PATH="/ssd/static/reports"
GAT_REPORT_VERSION=3.0-SNAPSHOT
GAT_REPORT_JAR=/ssd/data/maven/repository/org/nuxeo/tools/gatling-report/${GAT_REPORT_VERSION}/gatling-report-${GAT_REPORT_VERSION}-capsule-fat.jar
REDIS_CLI="docker exec -i redis redis-cli"
MVN="docker run -it --rm --name my-maven-project -v /etc/hosts:/etc/hosts:ro -v /ssd/data/maven:/root/.m2 -v /ssd/nuxeo.git:/usr/src/mymaven -w /usr/src/mymaven/nuxeo-distribution/nuxeo-jsf-ui-gatling-tests -e MAVEN_OPTS=-Xms3g maven:3.3-jdk-8 mvn"

function clone_bench_source() {
  if [[ -e ${SCRIPT_ROOT} ]]; then
    return;
  fi
  echo "Cloning bench script using $SCRIPT_BRANCH"
  git clone https://github.com/nuxeo/nuxeo.git ${SCRIPT_ROOT}
  pushd ${SCRIPT_ROOT}
  ${MVN} -nsu install -N
  # is this necessary ?
  # python clone.py master -a
  popd
}

function load_data_into_redis() {
  echo "Load bench data into Redis"
  pushd ${SCRIPT_PATH}
  echo flushdb | ${REDIS_CLI} -n ${REDIS_DB}
  set +e
  wget -nc https://maven-eu.nuxeo.org/nexus/service/local/repositories/public-releases/content/org/nuxeo/tools/testing/data-test-les-arbres/1.1/data-test-les-arbres-1.1.zip -O data.zip
  unzip -o data.zip
  set -e
  # redis-cli don't like unbuffered input
  unset PYTHONUNBUFFERED
  cat data-test*.csv | python ./scripts/inject-arbres.py | ${REDIS_CLI} -n ${REDIS_DB} --pipe
  export PYTHONUNBUFFERED=1
  popd
}

function gatling() {
  ${MVN} -nsu test gatling:test -Pbench -Durl=${TARGET} -DredisPort=${REDIS_PORT} -DredisDb=${REDIS_DB} -Dgatling.simulationClass=$@
}


function run_simulations() {
  echo "Run simulations"
  set -x
  pushd ${SCRIPT_PATH} || exit 2
  ${MVN} -nsu clean
  gatling "org.nuxeo.cap.bench.Sim00Setup"
  # init user ws and give some chance to graphite to init all metrics before mass import
  gatling "org.nuxeo.cap.bench.Sim25WarmUsersJsf"
  gatling "org.nuxeo.cap.bench.Sim10MassImport" -DnbNodes=100000
  gatling "org.nuxeo.cap.bench.Sim20CSVExport"
  gatling "org.nuxeo.cap.bench.Sim15BulkUpdateDocuments"
  #gatling "org.nuxeo.cap.bench.Sim10MassImport" -DnbNodes=1000000 -Dusers=32
  gatling "org.nuxeo.cap.bench.Sim10CreateFolders"
  gatling "org.nuxeo.cap.bench.Sim20CreateDocuments" -Dusers=32
  gatling "org.nuxeo.cap.bench.Sim25WaitForAsync"
  gatling "org.nuxeo.cap.bench.Sim25BulkUpdateFolders" -Dusers=32 -Dduration=180 -Dpause_ms=0
  gatling "org.nuxeo.cap.bench.Sim30UpdateDocuments" -Dusers=32 -Dduration=180
  #gatling "org.nuxeo.cap.bench.Sim30UpdateDocuments" -Dusers=32 -Dduration=400
  gatling "org.nuxeo.cap.bench.Sim35WaitForAsync"
  gatling "org.nuxeo.cap.bench.Sim30Navigation" -Dusers=48 -Dduration=180
  gatling "org.nuxeo.cap.bench.Sim30Search" -Dusers=48 -Dduration=180
  gatling "org.nuxeo.cap.bench.Sim30NavigationJsf" -Dduration=180
  gatling "org.nuxeo.cap.bench.Sim50Bench" -Dnav.users=80 -Dnavjsf=5 -Dupd.user=15 -Dnavjsf.pause_ms=1000 -Dduration=180
  gatling "org.nuxeo.cap.bench.Sim50CRUD" -Dusers=32 -Dduration=120
  gatling "org.nuxeo.cap.bench.Sim55WaitForAsync"
  gatling "org.nuxeo.cap.bench.Sim80ReindexAll"
  # gatling "org.nuxeo.cap.bench.Sim30Navigation" -Dusers=100 -Dduration=120 -Dramp=50
  popd
}

function download_gatling_report_tool() {
  if [ ! -f ${GAT_REPORT_JAR} ]; then
    ${MVN} -DgroupId=org.nuxeo.tools -DartifactId=gatling-report -Dversion=${GAT_REPORT_VERSION} -Dclassifier=capsule-fat -DrepoUrl=http://maven.nuxeo.org/nexus/content/groups/public-snapshot dependency:get
  fi
}

function build_report() {
  report_root="${1%-*}"
  if [ -d ${report_root} ]; then
    report_root = "${report_root}-bis"
  fi
  mkdir ${report_root} || true
  mv $1 ${report_root}/detail
  java -jar ${GAT_REPORT_JAR} -o ${report_root}/overview -g ${GRAPHITE_DASH} ${report_root}/detail/simulation.log
  find ${report_root} -name simulation.log -exec gzip {} \;
}

function build_reports() {
  echo "Building reports"
  download_gatling_report_tool
  for report in `find ${SCRIPT_PATH}/target/gatling -name simulation.log`; do
    build_report `dirname ${report}`
  done
}

function move_reports() {
  echo "Moving reports"
  if [ -d ${SCRIPT_PATH}/target/gatling/results ]; then
    # Gatling 2.1 use a different path for reports
    mv ${SCRIPT_PATH}/target/gatling/results/* ${REPORT_PATH}
  else
    mv ${SCRIPT_PATH}/target/gatling/* ${REPORT_PATH}
  fi
}

function build_stat() {
  # create a yml file with all the stats
  set -x
  java -jar ${GAT_REPORT_JAR} -f -o ${REPORT_PATH} -n data.yml -t ${MUSTACHE_TEMPLATE} \
    -m import,bulk,mbulk,exportcsv,create,createasync,nav,navjsf,search,update,updateasync,bench,crud,crudasync,reindex \
    ${REPORT_PATH}/sim10massimport/detail/simulation.log.gz \
    ${REPORT_PATH}/sim15bulkupdatedocuments/detail/simulation.log.gz \
    ${REPORT_PATH}/sim25bulkupdatefolders/detail/simulation.log.gz \
    ${REPORT_PATH}/sim20csvexport/detail/simulation.log.gz \
    ${REPORT_PATH}/sim20createdocuments/detail/simulation.log.gz \
    ${REPORT_PATH}/sim25waitforasync/detail/simulation.log.gz \
    ${REPORT_PATH}/sim30navigation/detail/simulation.log.gz \
    ${REPORT_PATH}/sim30navigationjsf/detail/simulation.log.gz \
    ${REPORT_PATH}/sim30search/detail/simulation.log.gz \
    ${REPORT_PATH}/sim30updatedocuments/detail/simulation.log.gz \
    ${REPORT_PATH}/sim35waitforasync/detail/simulation.log.gz \
    ${REPORT_PATH}/sim50bench/detail/simulation.log.gz \
    ${REPORT_PATH}/sim50crud/detail/simulation.log.gz \
    ${REPORT_PATH}/sim55waitforasync/detail/simulation.log.gz \
    ${REPORT_PATH}/sim80reindexall/detail/simulation.log.gz
  echo "build_number: $BUILD_NUMBER" >> ${REPORT_PATH}/data.yml
  echo "build_url: \"$BUILD_URL\"" >> ${REPORT_PATH}/data.yml
  echo "job_name: \"$JOB_NAME\"" >> ${REPORT_PATH}/data.yml
  echo "dbprofile: \"$dbprofile\"" >> ${REPORT_PATH}/data.yml
  echo "bench_suite: \"$benchsuite\"" >> ${REPORT_PATH}/data.yml
  echo "nuxeonodes: $nbnodes" >> ${REPORT_PATH}/data.yml
  echo "esnodes: $esnodes" >> ${REPORT_PATH}/data.yml
  echo "classifier: \"$classifier\"" >> ${REPORT_PATH}/data.yml
  echo "distribution: \"$distribution\"" >> ${REPORT_PATH}/data.yml
  echo "default_category: \"$category\"" >> ${REPORT_PATH}/data.yml
  echo "kafka: $kafka" >> ${REPORT_PATH}/data.yml
  # Calculate benchmark duration between import and reindex
  d1=$(grep import_date ${REPORT_PATH}/data.yml| sed -e 's,^[a-z\_]*\:\s,,g')
  d2=$(grep reindex_date ${REPORT_PATH}/data.yml | sed -e 's,^[a-z\_]*\:\s,,g')
  dd=$(grep reindex_duration ${REPORT_PATH}/data.yml | sed -e 's,^[a-z\_]*\:\s,,g')
  t1=$(date -d "$d1" +%s)
  t2=$(date -d "$d2" +%s)
  benchmark_duration=$(echo "($t2 - $t1) + $dd" | bc)
  echo "benchmark_duration: $benchmark_duration" >> ${REPORT_PATH}/data.yml
  echo "" >> ${REPORT_PATH}/data.yml
  set +x
}

function clean() {
  rm -rf ${REPORT_PATH} || true
  mkdir ${REPORT_PATH}
}

# -------------------------------------------------------
# main
#
clean
clone_bench_source
#load_data_into_redis
run_simulations

#build_reports
move_reports
#build_stat
