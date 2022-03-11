FROM golang:stretch AS builder

RUN apt-get -qq update && \
    apt-get install --no-install-recommends --allow-unauthenticated -qq libaio1 rpm wget && \
    wget --no-check-certificate https://raw.githubusercontent.com/bumpx/oracle-instantclient/master/oracle-instantclient12.2-basic-12.2.0.1.0-1.x86_64.rpm && \
    wget --no-check-certificate https://raw.githubusercontent.com/bumpx/oracle-instantclient/master/oracle-instantclient12.2-devel-12.2.0.1.0-1.x86_64.rpm && \
    rpm -Uvh --nodeps oracle*rpm && \
    echo /usr/lib/oracle/12.2/client64/lib | tee /etc/ld.so.conf.d/oracle.conf && \
    ldconfig

COPY oci8.pc /usr/share/pkgconfig/oci8.pc
ADD https://github.com/floyd871/prometheus_oracle_exporter/releases/download/1.1.5/prometheus_oracle_exporter-amd64 /app

FROM ubuntu:18.04
MAINTAINER Seth Miller <seth@sethmiller.me>
RUN apt-get -qq update && \
    apt-get install --no-install-recommends -qq libaio1 rpm wget -y && \
    wget --no-check-certificate https://raw.githubusercontent.com/bumpx/oracle-instantclient/master/oracle-instantclient12.2-basic-12.2.0.1.0-1.x86_64.rpm && \
    rpm -Uvh --nodeps oracle*rpm && \
    rm -f oracle*rpm && \
    apt-get remove -y rpm && \
    apt-get -y autoremove && apt-get -y autoclean && rm -rf /var/lib/apt/lists/*

ENV LD_LIBRARY_PATH /usr/lib/oracle/12.2/client64/lib
ENV NLS_LANG=AMERICAN_AMERICA.UTF8

COPY --from=builder /app /

ADD oracle.conf /etc/oracle_exporter/
ADD entrypoint.sh /

RUN chmod +x /entrypoint.sh /app

EXPOSE 9161
ENTRYPOINT ["/entrypoint.sh"]