
## Conside demo illustrating the proxy

```bash

## run this on pod
figlet pod
ke pod/my-replica-set-0
# default behavior of service in k8s round robins.
for i in {1..10}; do /var/lib/mongodb-mms-automation/mongodb-linux-x86_64-4.0.4/bin/mongo "mongodb://ec2-18-236-242-86.us-west-2.compute.amazonaws.com:30990/" --quiet --eval "rs.isMaster().me" | grep "^my-"; done
# open mongo shell
/var/lib/mongodb-mms-automation/mongodb-linux-x86_64-4.0.4/bin/mongo "mongodb://my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local,my-replica-set-1.my-replica-set-svc.mongodb.svc.cluster.local,my-replica-set-2.my-replica-set-svc.mongodb.svc.cluster.local/proxy-social?replicaSet=my-replica-set" --quiet

# run this on outside-k8s
figlet outside-k8s
cd /Users/shyamarjarapu/Code/personal/k8s/proxy-test/kubernetes
for i in {1..10}; do mongo "mongodb://ec2-18-236-242-86.us-west-2.compute.amazonaws.com:30010,ec2-54-244-201-226.us-west-2.compute.amazonaws.com:30011,ec2-34-222-162-168.us-west-2.compute.amazonaws.com:30012/?replicaSet=my-replica-set-proxy"  --ssl --sslCAFile ../docker/content/certs/mongodb/ca.crt --quiet --eval "rs.isMaster().me" | grep "^ec2-"; done

mongo "mongodb://ec2-18-236-242-86.us-west-2.compute.amazonaws.com:30010,ec2-54-244-201-226.us-west-2.compute.amazonaws.com:30011,ec2-34-222-162-168.us-west-2.compute.amazonaws.com:30012/social?replicaSet=my-replica-set-proxy" --ssl --sslCAFile ../docker/content/certs/mongodb/ca.crt -u user -p pencil --authenticationDatabase admin
# my-replica-set-proxy:PRIMARY>

```

```js

// run on both backing database and the proxy
rs.isMaster().hosts
show dbs
db
show collections

// run on proxy only
db.people.insertOne({fname: 'Shyam', lname: 'Arjarapu'})

// run on both backing database and the proxy
rs.slaveOk()
show dbs
db
show collections
db.people.find()

// run on proxy only
db.people.drop()
```

## clean up after yourselves

```bash
cd /Users/shyamarjarapu/Code/personal/k8s/proxy-test/kubernetes
kd service.yaml
kd proxy.yaml
rm proxy.yaml
kubectl delete configmap atlas-proxy-my-replica-set
```










## Handy dandy scripts

### Build the docker images

```bash
TAG_VERSION=0.0.5
docker build -t sarjarapu/mdb-k8s-proxy:$TAG_VERSION .
docker push sarjarapu/mdb-k8s-proxy:$TAG_VERSION
```

### Create MongoDB replica set in Kubernetes

```bash
cd /Users/shyamarjarapu/Code/personal/k8s/proxy-test/kubernetes
ka rs.yaml

# get all
kga

# describe the service
kubectl describe service/my-replica-set-svc-external
# Name:                     my-replica-set-svc-external
# Namespace:                mongodb
# Labels:                   app=my-replica-set-svc
# Annotations:              <none>
# Selector:                 app=my-replica-set-svc
# Type:                     NodePort
# IP:                       10.100.168.13
# Port:                     <unset>  27017/TCP
# TargetPort:               27017/TCP
# NodePort:                 <unset>  30990/TCP
# Endpoints:                172.31.14.172:27017,172.31.16.96:27017,172.31.42.57:27017
# Session Affinity:         None
# External Traffic Policy:  Cluster
# Events:                   <none>

# describe the pod 0
kubectl describe pod my-replica-set-0
# Name:           my-replica-set-0
# Namespace:      mongodb
# Node:           ip-172-31-6-207.us-west-2.compute.internal/172.31.6.207
# Start Time:     Fri, 09 Nov 2018 14:53:37 -0600
# Labels:         app=my-replica-set-svc
#                 controller=mongodb-enterprise-operator
#                 controller-revision-hash=my-replica-set-7ddcb4547c
#                 pod-anti-affinity=my-replica-set
#                 statefulset.kubernetes.io/pod-name=my-replica-set-0
# Annotations:    <none>
# Status:         Running
# IP:             172.31.14.172
# Controlled By:  StatefulSet/my-replica-set
# Containers:
#   mongodb-enterprise-database:
#     Container ID:   docker://c80da21b29e1d7f128e12991394e1c478243173c29b0ac5edb14ed064dd7febc
#     Image:          quay.io/mongodb/mongodb-enterprise-database:0.4
#     Image ID:       docker-pullable://quay.io/mongodb/mongodb-enterprise-database@sha256:f27e98b7961cab7f82b597f36b133b884883a33ee8bdff8ce67fb0bf8daf26eb
#     Port:           27017/TCP
#     Host Port:      0/TCP
#     State:          Running
```

### Testing connectivity internally

```bash
# ssh to pod 0
ke pod/my-replica-set-0

# test the connectivity to primary 10 times
for i in {1..10}; do /var/lib/mongodb-mms-automation/mongodb-linux-x86_64-4.0.4/bin/mongo "mongodb://my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local,my-replica-set-1.my-replica-set-svc.mongodb.svc.cluster.local,my-replica-set-2.my-replica-set-svc.mongodb.svc.cluster.local/?replicaSet=my-replica-set" --quiet --eval "rs.isMaster().me" | grep "^my-"; done
# my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local:27017

# exist the pod 0
exit
```

### Testing connectivity externally

```bash
# ssh to node ec2-18-236-242-86.us-west-2.compute.amazonaws.com
ssh -i ~/.ssh/amazonaws_rsa ec2-user@ec2-18-236-242-86.us-west-2.compute.amazonaws.com

# download and extract mongodb binaries
curl -OL https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-rhel70-4.0.4.tgz
tar -xvzf mongodb-linux-x86_64-rhel70-4.0.4.tgz
cd mongodb-linux-x86_64-rhel70-4.0.4/bin

# test the connectivity to primary 10 times
CONN_STR="ip-172-31-6-207.us-west-2.compute.internal:30990"
# CONN_STR="ip-172-31-30-153.us-west-2.compute.internal:30990"
# CONN_STR="ip-172-31-36-240.us-west-2.compute.internal:30990"
# CONN_STR="ip-172-31-6-207.us-west-2.compute.internal:30990,ip-172-31-30-153.us-west-2.compute.internal:30990,ip-172-31-36-240.us-west-2.compute.internal:30990"
OPTIONAL_CONN_STR_ARGS=""
for i in {1..10}; do ~/mongodb-linux-x86_64-rhel70-4.0.4/bin/mongo "mongodb://${CONN_STR}/${OPTIONAL_CONN_STR_ARGS}" --quiet --eval "rs.isMaster().me" | grep "^my-"; done
# my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-2.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-2.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-1.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-1.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-1.my-replica-set-svc.mongodb.svc.cluster.local:27017

OPTIONAL_CONN_STR_ARGS="?replicaSet=my-replica-set"
~/mongodb-linux-x86_64-rhel70-4.0.4/bin/mongo "mongodb://${CONN_STR}/${OPTIONAL_CONN_STR_ARGS}" --quiet --eval "rs.isMaster().me"
# 2018-11-09T21:27:27.019+0000 I NETWORK  [js] Successfully connected to ip-172-31-36-240.us-west-2.compute.internal:30990 (1 connections now open to ip-172-31-36-240.us-west-2.compute.internal:30990 with a 5 second timeout)
# 2018-11-09T21:27:27.526+0000 W NETWORK  [js] Unable to reach primary for set my-replica-set
# 2018-11-09T21:27:27.526+0000 I NETWORK  [js] Cannot reach any nodes for set my-replica-set. Please check network connectivity and the status of the set. This has happened for 1 checks in a row.

# exist the node 0
exit
```

### Creating separate service for each member

```bash
ka service.yaml
```

### Testing direct connectivity externally via proxy

```bash
# ssh to node ec2-18-236-242-86.us-west-2.compute.amazonaws.com
ssh -i ~/.ssh/amazonaws_rsa ec2-user@ec2-18-236-242-86.us-west-2.compute.amazonaws.com

# test the connectivity to primary 10 times
NODE_PORT=30010
CONN_STR="ip-172-31-6-207.us-west-2.compute.internal:$NODE_PORT"
CONN_STR="ip-172-31-30-153.us-west-2.compute.internal:$NODE_PORT"
CONN_STR="ip-172-31-36-240.us-west-2.compute.internal:$NODE_PORT"
CONN_STR="ip-172-31-6-207.us-west-2.compute.internal:$NODE_PORT,ip-172-31-30-153.us-west-2.compute.internal:$NODE_PORT,ip-172-31-36-240.us-west-2.compute.internal:$NODE_PORT"
OPTIONAL_CONN_STR_ARGS=""
for i in {1..10}; do ~/mongodb-linux-x86_64-rhel70-4.0.4/bin/mongo "mongodb://${CONN_STR}/${OPTIONAL_CONN_STR_ARGS}" --quiet --eval "rs.isMaster().me" | grep "^my-"; done
~/mongodb-linux-x86_64-rhel70-4.0.4/bin/mongo "mongodb://${CONN_STR}/${OPTIONAL_CONN_STR_ARGS}"
# my-replica-set-2.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-2.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-2.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-2.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-2.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-2.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-2.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-2.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-2.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-2.my-replica-set-svc.mongodb.svc.cluster.local:27017

OPTIONAL_CONN_STR_ARGS="?replicaSet=my-replica-set"
CONN_STR="ip-172-31-6-207.us-west-2.compute.internal:30010,ip-172-31-30-153.us-west-2.compute.internal:30011,ip-172-31-36-240.us-west-2.compute.internal:30012"
~/mongodb-linux-x86_64-rhel70-4.0.4/bin/mongo "mongodb://${CONN_STR}/${OPTIONAL_CONN_STR_ARGS}" --quiet --eval "rs.isMaster().me"
# # 2018-11-09T21:27:27.019+0000 I NETWORK  [js] Successfully connected to ip-172-31-36-240.us-west-2.compute.internal:30990 (1 connections now open to ip-172-31-36-240.us-west-2.compute.internal:30990 with a 5 second timeout)
# # 2018-11-09T21:27:27.526+0000 W NETWORK  [js] Unable to reach primary for set my-replica-set
# # 2018-11-09T21:27:27.526+0000 I NETWORK  [js] Cannot reach any nodes for set my-replica-set. Please check network connectivity and the status of the set. This has happened for 1 checks in a row.

# # exist the node 0
# exit
```

### Testing direct connectivity externally via atlas-proxy

Script to help compile the config.json

```bash
for pod in $(kgp | grep "my-" | cut -d' ' -f1);
do
  MTM="${pod}.my-replica-set-svc.mongodb.svc.cluster.local:27017"
  SNI="$(kubectl describe pod/${pod} | grep Node: | awk '{print $2}' | cut -d'/' -f1):28000"
  echo "  { \"mtm\" : \"${MTM}\", \"sni\" : \"${SNI}\" }, ";
done
```

### Create certs

```bash
# Generate root CA
openssl genrsa -out rootCA.key 2048
openssl req -x509 -new -nodes -key rootCA.key -days 365 -out rootCA.crt -subj "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Operations/CN=rootCA"

function create_certs() {
  SERVER_NAME=$1
  SUBJECT_ALTERNATE_NAMES=$2

  mkdir $SERVER_NAME
  openssl genrsa -out $SERVER_NAME/host.key 2048
  openssl req -new -sha256 -key $SERVER_NAME/host.key -subj "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Operations/CN=${SERVER_NAME}" -reqexts SAN -config <(cat /etc/pki/tls/openssl.cnf <(printf "[SAN]\nsubjectAltName=${SUBJECT_ALTERNATE_NAMES}")) -out $SERVER_NAME/host.csr
  openssl x509 -req -extfile <(printf "subjectAltName=${SUBJECT_ALTERNATE_NAMES}") -days 365 -in $SERVER_NAME/host.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out $SERVER_NAME/host.crt
  cat $SERVER_NAME/host.crt > $SERVER_NAME/mongodb.pem
  cat $SERVER_NAME/host.key >> $SERVER_NAME/mongodb.pem

  # Print & Verify the subject information
  openssl req -in $SERVER_NAME/host.csr -text -noout
  openssl x509 -in $SERVER_NAME/mongodb.pem -inform PEM -subject -nameopt RFC2253 -noout
  openssl verify -CAfile rootCA.crt $SERVER_NAME/mongodb.pem
}


# Generate Server certs
SERVER_NAME=ec2-34-221-161-145.us-west-2.compute.amazonaws.com
SUBJECT_ALTERNATE_NAMES="DNS:ec2-34-221-161-145.us-west-2.compute.amazonaws.com,DNS:ip-172-31-40-226.us-west-2.compute.internal,IP:34.221.161.145,IP:172.31.40.226,IP:127.0.0.1" 
#DNS:ec2-34-221-161-145.us-west-2.compute.amazonaws.com,DNS:ip-172-31-40-226.us-west-2.compute.internal,IP:34.221.161.145,IP:172.31.40.226,IP:127.0.0.1
create_certs $SERVER_NAME $SUBJECT_ALTERNATE_NAMES

SERVER_NAME="*.us-west-2.compute.amazonaws.com"
SUBJECT_ALTERNATE_NAMES="DNS:*.us-west-2.compute.amazonaws.com,DNS:*.us-west-2.compute.internal,IP:127.0.0.1"
create_certs $SERVER_NAME $SUBJECT_ALTERNATE_NAMES

```

### Ops Manager details

Url: http://ec2-54-70-220-252.us-west-2.compute.amazonaws.com:8080
API Key: a687697f-bc48-4301-be5d-60c7bcd520d4
