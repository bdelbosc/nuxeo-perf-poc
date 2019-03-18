#!/usr/bin/env bash

if [[ ! -e /ssd/.m2 ]]; then
    docker volume create --name maven-repo
fi

docker run -it --rm --name my-maven-project -v maven-repo:/root/data/.m2 -v "$(pwd)":/usr/src/mymaven -w /usr/src/mymaven -e MAVEN_OPTS="-Xms3g -Xmx4g -XX:MaxPermSize=2g" maven:3.3-jdk-8 mvn "$@"

