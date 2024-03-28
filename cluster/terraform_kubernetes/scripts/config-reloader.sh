#!/bin/sh
# Monitor a config file for updates and reload the service if it has changed
#

###
### Main
###

sleep 60

touch /tmp/last-reload

while true; do
    find -H /etc/prometheus/prometheus.yml -newer /tmp/last-reload -exec wget -O- --post-data '' http://127.0.0.1:9090/-/reload \;
    find -H /etc/prometheus/prometheus.yml -newer /tmp/last-reload -exec touch /tmp/last-reload \;
    sleep 60
    done
