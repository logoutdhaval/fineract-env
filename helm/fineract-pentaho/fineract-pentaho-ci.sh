#!/bin/bash
# Fineract deploy CI pipeline for pentaho

set -e
Repos="https://github.com/apache/fineract https://github.com/openMF/fineract-pentaho"
CodeDir="/var/lib/jenkins/workspace/Pentaho/"

# for each repo, check if it exists locally
# if dir exists, pull, if not, clone the remote git repo into it
for gitRepo in $Repos
do
  RepoDir=$(echo ${CodeDir}$(echo ${gitRepo}|rev|cut -d'/' -f1|rev))
  echo ${RepoDir}
  if [ -d $RepoDir ]; then
                cd $RepoDir
                git pull $gitRepo
                cd -
        else
                git clone $gitRepo $RepoDir
        fi
done



# Subham changes to directory structure, reporting class and build file.
cd $CodeDir && cd ./fineract-pentaho
git checkout ef0729e3ec34015d83b68b34e801d9cc1b75d00c
cd $CodeDir && cd ./fineract
git checkout d82560d7b34cbdf9075f5b2d3a39080f23c2e133
mv ../fineract-pentaho ./
sed -i 's/compileOnly(/compileOnly(\nfiles(\"..\/fineract-provider\/build\/classes\/java\/main\/\"),\n/g' ./fineract-pentaho/build.gradle
sed -i 's/testImplementation(/testImplementation(\nfiles(\"..\/fineract-client\/build\/classes\/java\/main\/\"),\n/2' ./fineract-pentaho/build.gradle
sed -i 's/private static final Logger logger = LoggerFactory.getLogger(PentahoReportingProcessServiceImpl.class);/private static final Logger logger = LoggerFactory.getLogger(PentahoReportingProcessServiceImpl.class);\npublic static final String MIFOS_BASE_DIR = System.getProperty(\"user.dir\") + File.separator + \".mifosx\";\n/2' ./fineract-pentaho/src/main/java/org/apache/fineract/infrastructure/report/service/PentahoReportingProcessServiceImpl.java
rm Dockerfile

# Create Dockerfile for pentaho build
tee -a Dockerfile <<EOF

FROM azul/zulu-openjdk-debian:15 AS builder

RUN apt-get update -qq && apt-get install -y wget unzip

COPY . fineract
WORKDIR /fineract

RUN ./gradlew --no-daemon  bootJar

WORKDIR /fineract/target
RUN jar -xf /fineract/fineract-provider/build/libs/fineract-provider.jar

WORKDIR /fineract/fineract-pentaho
RUN ./gradlew distZip
RUN unzip build/distributions/fineract-pentaho.zip -d unzipped/

WORKDIR /fineract/target/BOOT-INF/libs
RUN wget -q https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.23/mysql-connector-java-8.0.23.jar

# =========================================

FROM azul/zulu-openjdk-alpine:15 AS fineract

COPY --from=builder /fineract/target/BOOT-INF/lib /app/lib
COPY --from=builder /fineract/target/META-INF /app/META-INF
COPY --from=builder /fineract/target/BOOT-INF/classes /app
COPY --from=builder /fineract/fineract-pentaho/pentahoReports /app/.mifosx/pentahoReports
COPY --from=builder /fineract/fineract-pentaho/pentahoReports /root/.mifosx/pentahoReports
COPY --from=builder /fineract/fineract-pentaho/unzipped/lib /app/lib

WORKDIR /

COPY entrypoint.sh /entrypoint.sh

RUN chmod 775 /entrypoint.sh

EXPOSE 8443

ENTRYPOINT ["/entrypoint.sh"]



EOF

# Build image
docker build -t us.icr.io/phee-ns/fineract:pentaho-enabled-fineract .

cd ..
rm -rf ./*