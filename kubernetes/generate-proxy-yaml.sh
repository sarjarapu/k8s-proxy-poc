#!/bin/sh

RS_PREFIX="my-replica-set"
IMAGE_VERSION=0.0.5

tee proxy.yaml <<EOF
---
apiVersion: v1
kind: Pod
metadata:
  name: atlas-proxy-${RS_PREFIX}-0
  namespace: mongodb
  labels:
    app: ${RS_PREFIX}
    atlas-proxy: my-replica-set
    rs-member: ${RS_PREFIX}-0
  name: atlas-proxy-${RS_PREFIX}-0
spec:
  containers:
  - name: atlas-proxy-${RS_PREFIX}-0
    image: sarjarapu/mdb-k8s-proxy:${IMAGE_VERSION}
    tty: true
    stdin: true
    env:
    - name: MONGODB_URI
      value: "mongodb://${RS_PREFIX}-0.${RS_PREFIX}-svc.mongodb.svc.cluster.local:27017/"
    volumeMounts:
      - name: "atlas-proxy-${RS_PREFIX}-conf"
        mountPath: "/opt/atlas-proxy/config.json"
        subPath: "config.json"
  volumes:
  - name: atlas-proxy-${RS_PREFIX}-conf
    configMap:
      name: "atlas-proxy-${RS_PREFIX}"
      items:
      - key: config.json
        path: config.json

---
apiVersion: v1
kind: Pod
metadata:
  name: atlas-proxy-${RS_PREFIX}-1
  namespace: mongodb
  labels:
    app: ${RS_PREFIX}
    atlas-proxy: my-replica-set
    rs-member: ${RS_PREFIX}-1
  name: atlas-proxy-${RS_PREFIX}-1
spec:
  containers:
  - name: atlas-proxy-${RS_PREFIX}-1
    image: sarjarapu/mdb-k8s-proxy:${IMAGE_VERSION}
    tty: true
    stdin: true
    env:
    - name: MONGODB_URI
      value: "mongodb://${RS_PREFIX}-1.${RS_PREFIX}-svc.mongodb.svc.cluster.local:27017/"
    volumeMounts:
      - name: "atlas-proxy-${RS_PREFIX}-conf"
        mountPath: "/opt/atlas-proxy/config.json"
        subPath: "config.json"
  volumes:
  - name: atlas-proxy-${RS_PREFIX}-conf
    configMap:
      name: "atlas-proxy-${RS_PREFIX}"
      items:
      - key: config.json
        path: config.json

---
apiVersion: v1
kind: Pod
metadata:
  name: atlas-proxy-${RS_PREFIX}-2
  namespace: mongodb
  labels:
    app: ${RS_PREFIX}
    atlas-proxy: my-replica-set
    rs-member: ${RS_PREFIX}-2
  name: atlas-proxy-${RS_PREFIX}-2
spec:
  containers:
  - name: atlas-proxy-${RS_PREFIX}-2
    image: sarjarapu/mdb-k8s-proxy:${IMAGE_VERSION}
    tty: true
    stdin: true
    env:
    - name: MONGODB_URI
      value: "mongodb://${RS_PREFIX}-2.${RS_PREFIX}-svc.mongodb.svc.cluster.local:27017/"
    volumeMounts:
      - name: "atlas-proxy-${RS_PREFIX}-conf"
        mountPath: "/opt/atlas-proxy/config.json"
        subPath: "config.json"
  volumes:
  - name: atlas-proxy-${RS_PREFIX}-conf
    configMap:
      name: "atlas-proxy-${RS_PREFIX}"
      items:
      - key: config.json
        path: config.json
EOF

echo ""
echo "Done generating the proxy.yaml"
echo "kubectl create configmap atlas-proxy-${RS_PREFIX} --from-file=files/config.json"
echo "ka proxy.yaml"