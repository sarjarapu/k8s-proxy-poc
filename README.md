# External connectivity to MongoDB on Kubernetes via Atlas Proxy

## Introduction

The default behavior of service endpoints in Kubernetes randomly forwards the requests to any of the backing pods. This works well for stateless web services. However, for the stateful databases like MongoDB, the client connection is not guaranteed to be on primary. When the client executes`rs.isMaster().hosts` after successful connection to any of the MongoDB pod members, the clients does not know how to resolve them from outside of Kubernetes. So this requires out external service to be much more intelligent about forwarding the connections to members based on the *readPreference*.

AFAIK the [atlasproxy](https://github.com/10gen/atlasproxy) is the only tool that understands the MongoDB wired protocol and does the mapping of multiple Atlas Free Tier clusters onto one backing cluster. So this proof of concept leverages the atlasproxy on configured with mapping of internal pod names to AWS external IPs. This not helped successful connection to primary from outside of Kubernetes, but also mapped the `rs.isMaster().hosts` to external IP addresses that the clients can resolve.

Here is a quick video showing you the demo of connectivity to MongoDB replica set via Atlas-Proxy.

If you are getting started, I strong recommend using the `my-replica-set` as the replica set name as this poc is not tweaked 100% to fit custom names. With that said let's try to understand the current setup and configuration needed for this proof of concept.

## Existing setup - A MongoDB replica set in Kubernetes

Below set of pods are created via MongoDB Kubernetes Operator. Please note that there are two services created as part of it

- Internal service with ClusterPort 27017
- External service with NodePort 30990

```bash
# display kubernetes resources
kubectl get all -n mongodb
# NAME                                              READY     STATUS    RESTARTS   AGE
# pod/mongodb-enterprise-operator-89dbf6949-6hlb9   1/1       Running   1          4d
# pod/my-replica-set-0                              1/1       Running   0          17h
# pod/my-replica-set-1                              1/1       Running   0          17h
# pod/my-replica-set-2                              1/1       Running   0          17h

# NAME                                  TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)           AGE
# service/my-replica-set-svc            ClusterIP   None            <none>        27017/TCP         17h
# service/my-replica-set-svc-external   NodePort    10.100.168.13   <none>        27017:30990/TCP   17h

# NAME                                          DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
# deployment.apps/mongodb-enterprise-operator   1         1         1            1           18d

# NAME                                                    DESIRED   CURRENT   READY     AGE
# replicaset.apps/mongodb-enterprise-operator-89dbf6949   1         1         1         18d

# NAME                              DESIRED   CURRENT   AGE
# statefulset.apps/my-replica-set   3         3         17h
```

## Connectivity tests within Kubernetes

As long as the MongoDB clients are within the Kubernetes, the connectivity to the replica sets is straight forward. Below example shows you that the connection string with  
`?replicaSet=my-replica-set` always redirects you to the primary, *my-replica-set-0*.

Also the `rs.isMaster().hosts` command lists all the names of the replica set members with MongoDB pod names, which are internal and can be resolved only within the Kubernetes.

```bash
# ssh to pod my-replica-set-0
kubectl exec -it my-replica-set-0 -- /bin/bash

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

/var/lib/mongodb-mms-automation/mongodb-linux-x86_64-4.0.4/bin/mongo "mongodb://my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local,my-replica-set-1.my-replica-set-svc.mongodb.svc.cluster.local,my-replica-set-2.my-replica-set-svc.mongodb.svc.cluster.local/?replicaSet=my-replica-set" --quiet
# my-replica-set:PRIMARY>
rs.isMaster().hosts
# [
# 	"my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local:27017",
# 	"my-replica-set-1.my-replica-set-svc.mongodb.svc.cluster.local:27017",
# 	"my-replica-set-2.my-replica-set-svc.mongodb.svc.cluster.local:27017"
# ]
```

## Connectivity tests from outside of Kubernetes

Since the MongoDB clients are outside of the Kubernetes, the connectivity to the replica sets should be made to the NodePort, 30990 in my case. Also make sure that the *NodePort* is allowed in the security group of the EC2 Node instances.

Note: You could potentially create an ingress controller to avoid this manual whitelisting of NodePort, but for simplicity of this PoC I just white listed the NodePort.

Below example shows you that when the connection string to external service endpoint is not using  
`?replicaSet=my-replica-set`, you are redirected to any of the 3 members at random. So if your intent is to make a write, you must be connected to the primary, *my-replica-set-0*.

Please note that when the connection string to external service endpoint with  
`?replicaSet=my-replica-set`, is made the client driver issues `rs.isMaster().hosts` and gets all the names of the replica set members. Since these members are MongoDB pod names, they cannot be resolved from outside of the Kubernetes.

```bash
# connect directly external ip address. note that behaving like roundrobin
for i in {1..10}; do /var/lib/mongodb-mms-automation/mongodb-linux-x86_64-4.0.4/bin/mongo "mongodb://ec2-18-236-242-86.us-west-2.compute.amazonaws.com:30990/" --quiet --eval "rs.isMaster().me" | grep "^my-"; done
# my-replica-set-2.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-1.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-1.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-2.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-2.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-1.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local:27017
# my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local:27017

# connect using the replicaset name in connection string to connect to primary
mongo "mongodb://ec2-18-236-242-86.us-west-2.compute.amazonaws.com:30990,ec2-54-244-201-226.us-west-2.compute.amazonaws.com:30990,ec2-34-222-162-168.us-west-2.compute.amazonaws.com:30990/?replicaSet=my-replica-set-proxy"
# 2018-11-10T08:31:27.562-0600 I NETWORK  [js] Successfully connected to ec2-18-236-242-86.us-west-2.compute.amazonaws.com:30990 (1 connections now open to ec2-18-236-242-86.us-west-2.compute.amazonaws.com:30990 with a 5 second timeout)
# 2018-11-10T08:31:27.625-0600 I NETWORK  [js] changing hosts to my-replica-set/my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local:27017,my-replica-set-1.my-replica-set-svc.mongodb.svc.cluster.local:27017,my-replica-set-2.my-replica-set-svc.mongodb.svc.cluster.local:27017 from my-replica-set/ec2-18-236-242-86.us-west-2.compute.amazonaws.com:30990,ec2-34-222-162-168.us-west-2.compute.amazonaws.com:30990,ec2-54-244-201-226.us-west-2.compute.amazonaws.com:30990
# 2018-11-10T08:31:27.625-0600 W NETWORK  [js] Unable to reach primary for set my-replica-set-proxy
# 2018-11-10T08:31:27.625-0600 I NETWORK  [js] Cannot reach any nodes for set my-replica-set-proxy. Please check network connectivity and the status of the set. This has happened for 2 checks in a row.
```

## Create & configure the Atlas-Proxy pods

### Configure the atlasproxy config file

To be highly available, I would be creating 3 Atlas-Proxy pods for my replica set. Technically these should be run as *Deployment*, but for now I am just running them as 3 Pod.

The Atlas-Proxy Pod requires a config file containing the mapping of source replica set members to target replica set members. I used the below helper script to get the Pod DNS name -> AWS External DNS name mappings and I have manually updated the `kubernetes/files/config.json` based on the output.

```bash
for pod in $(kubectl get pod -l app=my-replica-set-svc | grep "my-" | cut -d' ' -f1);
do
  MTM="${pod}.my-replica-set-svc.mongodb.svc.cluster.local:27017"
  INTERNAL_DNS="$(kubectl describe pod/${pod} | grep Node: | awk '{print $2}' | cut -d'/' -f1)"
  EXTERNAL_DNS=$(aws ec2 describe-instances --filters Name=private-dns-name,Values=${INTERNAL_DNS} --query "Reservations[0].Instances[0].PublicDnsName")
  SNI="${EXTERNAL_DNS}:28000"
  echo "  { \"mtm\" : \"${MTM}\", \"sni\" : \"${SNI}\" }, ";
done
# { "mtm" : "my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local:27017", "sni" : ""ec2-18-236-242-86.us-west-2.compute.amazonaws.com":28000" },
# { "mtm" : "my-replica-set-1.my-replica-set-svc.mongodb.svc.cluster.local:27017", "sni" : ""ec2-54-244-201-226.us-west-2.compute.amazonaws.com":28000" },
# { "mtm" : "my-replica-set-2.my-replica-set-svc.mongodb.svc.cluster.local:27017", "sni" : ""ec2-34-222-162-168.us-west-2.compute.amazonaws.com":28000" },
```

### Create the atlas-proxy pods

The below scripts help you create 3 new external service endpoints at port *30010-30012*. Each of these ports map to the atlas-proxy pod listening on port *28000*.

```bash
# create the services and proxy pods
cd <repo-dir>/kubernetes
sh generate-proxy-yaml.sh
kubectl create configmap atlas-proxy-my-replica-set --from-file=files/config.json
kubectl apply -f service.yaml
kubectl apply -f proxy.yaml
kubectl get all
```

## Connectivity tests from outside of Kubernetes via atlas-proxy

Since the MongoDB clients are outside of the Kubernetes, the connectivity to the replica sets should be made to the NodePorts similar to previous run but for the new service endpoints where the atlas-proxy is listening, NodePort: *30010-30012*. Please make sure that the above *NodePort* range is allowed in the security group of the EC2 Node instances.

Below example shows you that when the connection string to external service endpoint is using  
`?replicaSet=my-replica-set` and ou are redirected to *Primary* even if you are redirected to any other replica set member. When the client driver issues `rs.isMaster().hosts`, replica set members are mapped to external DNS names rather than the internal Kubernetes DNS names. Since these members can be resolved from outside of the Kubernetes, the client could successfully connect to Primary all the time.

```bash
# connect directly external ip address.
for i in {1..10}; do mongo "mongodb://ec2-18-236-242-86.us-west-2.compute.amazonaws.com:30010,ec2-54-244-201-226.us-west-2.compute.amazonaws.com:30011,ec2-34-222-162-168.us-west-2.compute.amazonaws.com:30012/?replicaSet=my-replica-set-proxy"  --ssl --sslCAFile ../docker/content/certs/mongodb/ca.crt --quiet --eval "rs.isMaster().me" | grep "^ec2-"; done
# ec2-54-244-201-226.us-west-2.compute.amazonaws.com:30011
# ec2-54-244-201-226.us-west-2.compute.amazonaws.com:30011
# ec2-54-244-201-226.us-west-2.compute.amazonaws.com:30011
# ec2-54-244-201-226.us-west-2.compute.amazonaws.com:30011
# ec2-54-244-201-226.us-west-2.compute.amazonaws.com:30011
# ec2-54-244-201-226.us-west-2.compute.amazonaws.com:30011
# ec2-54-244-201-226.us-west-2.compute.amazonaws.com:30011
# ec2-54-244-201-226.us-west-2.compute.amazonaws.com:30011
# ec2-54-244-201-226.us-west-2.compute.amazonaws.com:30011
# ec2-54-244-201-226.us-west-2.compute.amazonaws.com:30011

```

### Testing the operations on atlas-proxy pods

Connect to the MongoDB replica set from your laptop. To help you differentiate internal / external I have suffixed `-proxy` to the replica set name. This is intentional and not required.

```bash
mongo "mongodb://ec2-18-236-242-86.us-west-2.compute.amazonaws.com:30010,ec2-54-244-201-226.us-west-2.compute.amazonaws.com:30011,ec2-34-222-162-168.us-west-2.compute.amazonaws.com:30012/social?replicaSet=my-replica-set-proxy" --ssl --sslCAFile ../docker/content/certs/mongodb/ca.crt -u user -p pencil --authenticationDatabase admin
# my-replica-set-proxy:PRIMARY>
```

```js
rs.isMaster().hosts
// [
// 	"ec2-18-236-242-86.us-west-2.compute.amazonaws.com:30010",
// 	"ec2-54-244-201-226.us-west-2.compute.amazonaws.com:30011",
// 	"ec2-34-222-162-168.us-west-2.compute.amazonaws.com:30012"
// ]

show dbs
// admin   0.000GB
// local   0.001GB
// social  0.000GB

db
// social

show collections

db.people.insertOne({fname: 'Shyam', lname: 'Arjarapu'})
// {
// 	"acknowledged" : true,
// 	"insertedId" : ObjectId("5be701df00c8679c5fd03271")
// }

db.people.find()
// { "_id" : ObjectId("5be701df00c8679c5fd03271"), "fname" : "Shyam", "lname" : "Arjarapu" }
```

### Testing the operations on MongoDB Kubernetes Pod

SSH to the MongoDB replica set Pod in Kubernetes and connect to the backing replica set via mongo shell.

```bash
kubectl exec -it my-replica-set-0 -- /bin/bash
# mongodb@my-replica-set-0:/$

# open mongo shell
/var/lib/mongodb-mms-automation/mongodb-linux-x86_64-4.0.4/bin/mongo "mongodb://my-replica-set-0.my-replica-set-svc.mongodb.svc.cluster.local,my-replica-set-1.my-replica-set-svc.mongodb.svc.cluster.local,my-replica-set-2.my-replica-set-svc.mongodb.svc.cluster.local/proxy-social?replicaSet=my-replica-set" --quiet
# my-replica-set:PRIMARY>
```

When you `show dbs`, you will notice that the underlying replic set has database `proxy-social` where as it was just `social` when connected via proxy. The collections in the database will show the same content added via proxy.

```js
show dbs
// admin         0.000GB
// config        0.000GB
// local         0.001GB
// proxy-social  0.000GB

db.people.find()
// { "_id" : ObjectId("5be701df00c8679c5fd03271"), "fname" : "Shyam", "lname" : "Arjarapu" }
```

## Conclusions

This proof of concept illustrates, how MongoDB Atlas-Proxy can be leveraged to respect the *readPreference* and/or always connect to the primary even when connecting from outside of Kubernetes. This primary works because of atlas-proxy managing the mapping of internal Kubernetes DNS names to external node DNS names.

Here are a few points I would like to highlight.

- The connection string is different for clients internal / external to Kubernetes
- SSL connectivity is required for external clients
- Authentication is required for external clients
- Since the authentication mechanisms are not mapped the users created via Ops Manager on backing database are not available via proxy.
- The management of the auth users and roles to the external clients is not easy and requires updating the config file
- Potentially we could have a atlas-proxy manage mappings to multiple underlying databases. However, we would have to think about process for rolling the updated config file and restarting the proxy while being highly available
- The atlas-proxy also puts cap on connections, database size etc. So, if we strip some of the functionality it may further boost some performance.
- As shown in the video, the connectivity speed within the Kubernetes to outside of Kubernetes is quite noticeable.
- Proper benchmarks should be based on clients connecting from your laptop to publicly exposed MongoDB replica sets and MongoDB replica set via Atlas-Proxy rather than comparing to the client running inside Kubernetes connected to MongoDB replica set in the Kubernetes.
