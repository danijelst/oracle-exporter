VERSION        ?= 0.3.2
ORACLE_VERSION ?= 19.10
LDFLAGS        := -X main.Version=$(VERSION)
GOFLAGS        := -ldflags "$(LDFLAGS) -s -w"
ARCH           ?= $(shell uname -m)
GOARCH         ?= $(subst x86_64,amd64,$(patsubst i%86,386,$(ARCH)))
RPM_VERSION    ?= $(ORACLE_VERSION).0.0.0-1
ORA_RPM         = oracle-instantclient$(ORACLE_VERSION)-devel-$(RPM_VERSION).$(ARCH).rpm oracle-instantclient$(ORACLE_VERSION)-basic-$(RPM_VERSION).$(ARCH).rpm
LD_LIBRARY_PATH = /usr/lib/oracle/$(ORACLE_VERSION)/client64/lib
BUILD_ARGS      = --build-arg VERSION=$(VERSION) --build-arg ORACLE_VERSION=$(ORACLE_VERSION)
DIST_DIR        = oracle-exporter.$(VERSION)-ora$(ORACLE_VERSION).linux-${GOARCH}
ARCHIVE         = oracle-exporter.$(VERSION)-ora$(ORACLE_VERSION).linux-${GOARCH}.tar.gz
DOCKER_IMAGE    = danijelst/oracle-exporter

export LD_LIBRARY_PATH ORACLE_VERSION

%.rpm:
	wget -q http://yum.oracle.com/repo/OracleLinux/OL7/oracle/instantclient/$(ARCH)/getPackage/$@

download-rpms: $(ORA_RPM)

prereq: download-rpms
	@echo deps
	sudo apt-get update
	sudo apt-get install --no-install-recommends -qq libaio1 rpm
	sudo rpm -Uvh --nodeps --force oracle*rpm
	echo $(LD_LIBRARY_PATH) | sudo tee /etc/ld.so.conf.d/oracle.conf
	sudo ldconfig

oci.pc:
	sed "s/@ORACLE_VERSION@/$(ORACLE_VERSION)/g" oci8.pc.template > oci8.pc

linux: oci.pc
	@echo build linux
	mkdir -p ./dist/$(DIST_DIR)
	PKG_CONFIG_PATH=${PWD} GOOS=linux go build $(GOFLAGS) -o ./dist/$(DIST_DIR)/oracle-exporter
	(cd dist ; tar cfz $(ARCHIVE) $(DIST_DIR))

darwin: oci.pc
	@echo build darwin
	mkdir -p ./dist/oracle-exporter.$(VERSION).darwin-${GOARCH}
	PKG_CONFIG_PATH=${PWD} GOOS=darwin go build $(GOFLAGS) -o ./dist/oracle-exporter.$(VERSION).darwin-${GOARCH}/oracle-exporter
	(cd dist ; tar cfz oracle-exporter.$(VERSION).darwin-${GOARCH}.tar.gz oracle-exporter.$(VERSION).darwin-${GOARCH})

local-build:  linux

build: docker

deps:
	@PKG_CONFIG_PATH=${PWD} go get

test:
	@echo test
	@PKG_CONFIG_PATH=${PWD} go test $$(go list ./... | grep -v /vendor/)

clean:
	rm -rf ./dist sgerrand.rsa.pub glibc-2.29-r0.apk oci8.pc

docker: ubuntu-image alpine-image oraclelinux-image

sgerrand.rsa.pub:
	wget -q -O sgerrand.rsa.pub  https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub

glibc-2.29-r0.apk:
	wget -q -O glibc-2.29-r0.apk https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.29-r0/glibc-2.29-r0.apk

oraclelinux-image: $(ORA_RPM)
	docker build -f ./Dockerfile_oraclelinux $(BUILD_ARGS) -t "$(DOCKER_IMAGE):$(VERSION)-oraclelinux" .
	docker tag "$(DOCKER_IMAGE):$(VERSION)-oraclelinux" "$(DOCKER_IMAGE):oraclelinux"

ubuntu-image: $(ORA_RPM)
	docker build $(BUILD_ARGS) -t "$(DOCKER_IMAGE):$(VERSION)" .
	docker tag "$(DOCKER_IMAGE):$(VERSION)" "$(DOCKER_IMAGE):latest"

alpine-image: $(ORA_RPM) sgerrand.rsa.pub glibc-2.29-r0.apk
	docker build -f ./Dockerfile_alpine $(BUILD_ARGS) -t "$(DOCKER_IMAGE):$(VERSION)-alpine" .
	docker tag "$(DOCKER_IMAGE):$(VERSION)-alpine" "$(DOCKER_IMAGE):alpine"

travis: oci.pc prereq deps test linux docker
	@true

.PHONY: build deps test clean docker travis oci.pc
