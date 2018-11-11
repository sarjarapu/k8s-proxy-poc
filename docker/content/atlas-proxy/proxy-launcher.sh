#!/usr/bin/env bash
set -o nounset
set -o errexit
set -o pipefail

CONFIG_PATH=/opt/atlas-proxy/config.json

AP_HOME=/opt/atlas-proxy
AP_LOG_DIR=/var/log/mongodb-mms-atlas-proxy
BIND_ADDRESS=0.0.0.0
BIND_PORT=28000

if [ -e "${AP_HOME}/mongodb-mms-atlas-proxy.pid" ]; then
    echo "-- Atlas Proxy is running"
else
    echo "-- Launching atlas proxy with following arguments:
    -mongoURI ${MONGODB_URI}"
    # -mongoURI "mongodb://u:p@ip-172-31-41-49.us-west-2.compute.internal:27000/?ssl=true" -bindAddress  0.0.0.0 -bindPort 28000 -configPath /opt/mongodb-mms-atlas-proxy/config.json -sslPEMKeyFile /etc/ssl/certs/mongodb/mongodb.pem -sslCAFile /etc/ssl/certs/mongodb/rootCA.crt -v -logPath=/var/log/mongodb-mms-atlas-proxy/proxy.log -vv > /var/log/mongodb-mms-atlas-proxy/proxy-fatal.log 2>&1 &'

    "${AP_HOME}/mongodb-mms-atlas-proxy" \
        -mongoURI "${MONGODB_URI}" \
        -bindAddress "${BIND_ADDRESS}" \
        -bindPort "${BIND_PORT}" \
        -sslPEMKeyFile /opt/certs/mongodb/mongodb.pem \
        -sslCAFile /opt/certs/mongodb/ca.crt \
        -configPath ${CONFIG_PATH} \
        -v \
        -logPath "${AP_LOG_DIR}/proxy.log" \
        -vv > "${AP_LOG_DIR}/proxy-stderr.log" 2>&1 &
fi

echo
echo "Waiting until logs are created..."
while [ ! -f "${AP_LOG_DIR}/proxy.log" ] || [ ! -f "${AP_LOG_DIR}/proxy-stderr.log" ]; do
    sleep 1
done

echo
echo "Atlas Proxy logs:"
tail -n 1000 -F "${AP_LOG_DIR}/proxy.log" "${AP_LOG_DIR}/proxy-stderr.log" 2>/dev/null
