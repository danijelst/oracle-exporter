FROM golang:1.14 AS build

ARG ORACLE_VERSION
ENV ORACLE_VERSION=${ORACLE_VERSION}
ENV LD_LIBRARY_PATH "/usr/lib/oracle/${ORACLE_VERSION}/client64/lib"

RUN apt-get -qq update && apt-get install --no-install-recommends -qq libaio1 rpm
COPY oci8.pc.template /usr/share/pkgconfig/oci8.pc
RUN sed -i "s/@ORACLE_VERSION@/$ORACLE_VERSION/g" /usr/share/pkgconfig/oci8.pc
COPY oracle*${ORACLE_VERSION}*.rpm /
RUN rpm -Uh --nodeps /oracle-instantclient*.x86_64.rpm && rm /*.rpm
RUN echo $LD_LIBRARY_PATH >> /etc/ld.so.conf.d/oracle.conf && ldconfig

WORKDIR /go/src/oracle-exporter
COPY . .
RUN go get -d -v

ARG VERSION
ENV VERSION ${VERSION:-0.1.0}

ENV PKG_CONFIG_PATH /go/src/oracle-exporter
ENV GOOS            linux

RUN go build -v -ldflags "-X main.Version=${VERSION} -s -w"

FROM ubuntu:20.04
LABEL authors="Seth Miller,Yannig Perré"
LABEL maintainer="Danijel Fischer <danijel@stojnic.com>"

ENV VERSION ${VERSION:-0.1.0}
ENV DEBIAN_FRONTEND=noninteractive

COPY oracle-instantclient*${ORACLE_VERSION}*basic*.rpm /

RUN apt-get -qq update && \
  apt-get -qq install --no-install-recommends tzdata libaio1 rpm -y && rpm -Uvh --nodeps /oracle*${ORACLE_VERSION}*rpm && \
    rm -f /oracle*rpm

RUN adduser --system --uid 1000 --group appuser \
  && usermod -a -G 0,appuser appuser

ARG ORACLE_VERSION
ENV ORACLE_VERSION=${ORACLE_VERSION}
ENV LD_LIBRARY_PATH "/usr/lib/oracle/${ORACLE_VERSION}/client64/lib"
RUN echo $LD_LIBRARY_PATH >> /etc/ld.so.conf.d/oracle.conf && ldconfig

COPY --chown=appuser:appuser --from=build /go/src/oracle-exporter/oracle-exporter /app/oracle-exporter

EXPOSE 9161

USER appuser

COPY ./oracle.conf.example /etc/oracle-exporter/oracle.conf
ENTRYPOINT ["/app/oracle-exporter", "-configfile", "/etc/oracle-exporter/oracle.conf"]