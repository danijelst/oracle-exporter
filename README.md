# oracle-exporter
Oracle exporter docker based on https://github.com/floyd871/prometheus_oracle_exporter

## Usage
```
# run docker instance and with a config file
# see https://github.com/floyd871/prometheus_oracle_exporter/blob/master/oracle.conf.example
docker run -d -p 9161:9161 \
           -v /path/to/database/alert/trace:/trace \
           -v /path/to/template_file/:/etc/oracle_exporter/
           danijelst/oracle-exporter

```
