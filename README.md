# oracle-exporter
Oracle exporter docker based on https://github.com/floyd871/prometheus_oracle_exporter

## Usage
```
# run docker instance with passing connection details
docker run -d -p 9161:9161 \
           -v /path/to/trace:/trace \
           -e DATA_SOURCE_NAME=system/password@//localhost:1521/db \
           -e ORACLE_DATABASE=db \
           -e ORACLE_INSTANCE=db \
           -e ORACLE_ALERTLOG=/trace/alert_db.log \
           danijelst/oracle-exporter

# run docker instance and with a config file
# see https://github.com/floyd871/prometheus_oracle_exporter/blob/master/oracle.conf.example
docker run -d -p 9161:9161 \
           -v /path/to/trace:/trace \
           -v /path/to/template_file:/etc/confd/templates/oracle.confg.tmpl
           -e DATA_SOURCE_NAME=system/password@//localhost:1521/db \
           -e ORACLE_DATABASE=db \
           -e ORACLE_INSTANCE=db \
           -e ORACLE_ALERTLOG=/trace/alert_db.log \
           danijelst/oracle-exporter

```
