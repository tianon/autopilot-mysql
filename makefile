MAKEFLAGS += --warn-undefined-variables
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail
.DEFAULT_GOAL := build

build:
	docker build -t="0x74696d/triton-mysql" .

ship:
	docker push 0x74696d/triton-mysql

# -------------------------------------------------------
# for testing against Docker locally

stop-local:
	docker-compose -p my -f local-compose.yml stop || true
	docker-compose -p my -f local-compose.yml rm -f || true

build-local:
	docker-compose -p my -f local-compose.yml build

cleanup:
	-mrm -r /${SDC_ACCOUNT}/stor/triton-mysql/
	mmkdir /${SDC_ACCOUNT}/stor/triton-mysql
	mchmod -- +triton_mysql /${SDC_ACCOUNT}/stor/triton-mysql

test: stop-local build-local
	docker-compose -p my -f local-compose.yml up -d
	docker ps
	docker logs -f my_mysql_1

replica:
	docker-compose -p my -f local-compose.yml scale mysql=3
	docker ps
	docker logs -f my_mysql_2

# -------------------------------------------------------

# create user and policies for backups
# usage:
# make manta EMAIL=example@example.com PASSWORD=strongpassword
manta:
	ssh-keygen -t rsa -b 4096 -C "${EMAIL}" -f manta
	sdc-user create --login=triton_mysql --password=${PASSWORD} --email=${EMAIL}
	sdc-user upload-key $(ssh-keygen -E md5 -lf ./manta | awk -F' ' '{gsub("MD5:","");{print $2}}') --name=triton-mysql-key triton_mysql ./manta.pub
	sdc-policy create --name=triton_mysql \
		--rules='CAN getobject' \
		--rules='CAN putobject' \
		--rules='CAN putmetadata' \
		--rules='CAN putsnaplink' \
		--rules='CAN getdirectory' \
		--rules='CAN putdirectory'
	sdc-role create --name=triton_mysql \
		--policies=triton_mysql \
		--members=triton_mysql
	mmkdir ${SDC_ACCOUNT}/stor/triton-mysql
	mchmod -- +triton_mysql /${SDC_ACCOUNT}/stor/triton-mysql