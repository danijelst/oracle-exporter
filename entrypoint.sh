#!/usr/bin/env sh

exec /app -configfile=/etc/oracle_exporter/oracle.conf -web.listen-address :9161
