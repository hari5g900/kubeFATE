# kubeFATE
## Deploy fate clusters on a multi-node kubernetes cluster 

cluster.yml for deploying Kubernetes cluster with 1 control and 2 worker nodes.

cluster_copy.yml for deploying Kubernetes cluster with 1 control and 1 worker node.

fate-9999.yml contains cluster config for party-9999.

fate-10000.yml contains cluster config for party-10000.

# Tutorial(that works) to deploy KubeFATE on a (or multiple) k8s cluster(s).

The first thing to do is to deploy the k8s cluster on your system. I recommend rancher (rke) as it is very easy to deploy and take down the cluster (single or multinode). Minikube is another alternative but it only really supports single node clusters.

This tutorial follows the official kubefate deployment guide, [https://github.com/FederatedAI/KubeFATE/blob/master/docs/tutorials/Build_Two_Parties_FATE_Cluster_in_One_Linux_Machine_with_MiniKube.md].

## Setup Kubefate
### Install KubeFATE CLI
Go to [KubeFATE Release](https://github.com/FederatedAI/KubeFATE/releases), and find the latest kubefate-k8s release 
pack, which is `v1.10.0` as set to ENVs before. (replace ${fate_version} with the newest version available)
```
curl -LO https://github.com/FederatedAI/KubeFATE/releases/download/${fate_version}/kubefate-k8s-${fate_version}.tar.gz && tar -xzf ./kubefate-k8s-${fate_version}.tar.gz
```
Then we will get the release pack of KubeFATE, verify it,
```
kubefate@machine:~/demo cd kubefate
kubefate@machine:~/kubefate ls
cluster-serving.yaml cluster-spark-rabbitmq.yaml cluster.yaml examples rbac-config.yaml
cluster-spark-pulsar.yaml cluster-spark-slim.yaml config.yaml kubefate.yaml
```
Move the KubeFATE executable binary to path,
```
chmod +x ./kubefate && sudo mv ./kubefate /usr/bin
```
Try to verify if the KubeFATE CLI works,
```
kubefate@machine:~/kubefate$ kubefate version
* kubefate commandLine version=v1.4.5
* kubefate service connection error, resp¬.StatusCode=404, error: <?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
         "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
        <head>
                <title>404 - Not Found</title>
        </head>
        <body>
                <h1>404 - Not Found</h1>
                <script type="text/javascript" src="//wpc.75674.betacdn.net/0075674/www/ec_tpm_bcon.js"></script>
        </body>
</html>
```
It is fine that only the command line version shows up but get an error on KubeFATE service's version because we have not 
deployed the KubeFATE service yet.

#### 1. Create kube-fate namespace and account for KubeFATE service
We have prepared the yaml for creating kube-fate namespace, as well as creating a service account in rbac-config.yaml in your working folder. Just apply it,
```
kubefate@machine:~/kubefate kubectl apply -f ./rbac-config.yaml
```

In the official tutorial, there is a mention of deploying the kubefate service manually. This is not required if rke is used as service will be created automatically during the next step.

#### 2. Deploy KubeFATE serving to kube-fate Namespace

Apply the KubeFATE deployment YAML.

```
kubectl apply -f ./kubefate.yaml
```

We can verify it with `kubectl get all,ingress -n kube-fate`, if everything looks like,
```

kubefate@machine:~/demo$ kubectl get all,ingress -n kube-fate
NAME                            READY   STATUS    RESTARTS   AGE
pod/kubefate-5d97d65947-7hb2q   1/1     Running   0          51s
pod/mariadb-69484f8465-44dlw    1/1     Running   0          51s

NAME               TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/kubefate   ClusterIP   192.168.0.111   <none>        8080/TCP   50s
service/mariadb    ClusterIP   192.168.0.112   <none>        3306/TCP   50s

NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/kubefate   1/1     1            1           51s
deployment.apps/mariadb    1/1     1            1           51s

NAME                                  DESIRED   CURRENT   READY   AGE
replicaset.apps/kubefate-5d97d65947   1         1         1       51s
replicaset.apps/mariadb-69484f8465    1         1         1       51s

NAME                          HOSTS          ADDRESS          PORTS   AGE
ingress.extensions/kubefate   example.com   192.168.100.123   80      50s
```

It means KubeFATE service has been deployed. 

#### 3. (Optional) Add example.com to host file
Note: if we have a dns service (such as AWS Route53) setup, which can help to mapping
`example.com` to`192.168.100.123`, then this step can be skipped.

Map the machine IP `192.168.100.123` （which is also the 'ADDRESS' field of 'ingress.extensions/kubefate'） above to `example.com`

```
sudo -- sh -c "echo \"192.168.100.123 example.com\"  >> /etc/hosts"
```

Verify if it works,
```
kubefate@machine:~/demo$ ping -c 2 example.com
PING example.com (192.168.100.123) 56(84) bytes of data.
64 bytes from example.com (192.168.100.123): icmp_seq=1 ttl=64 time=0.080 ms
64 bytes from example.com (192.168.100.123): icmp_seq=2 ttl=64 time=0.054 ms

--- example.com ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1006ms
rtt min/avg/max/mdev = 0.054/0.067/0.080/0.013 ms
```

When `example.com` well set, KubeFATE service version can be shown,
```
kubefate@machine:~/kubefate$ kubefate version
* kubefate service version=v1.4.5
* kubefate commandLine version=v1.4.5
```
Note: The `kubefate` CLI can only work in the same directory of config.yaml

Okay. The preparation has been done. Let's install FATE.

## Install the Fate clusters
### Preparation
Firstly, we need to prepare two namespaces: fate-9999 for party 9999, while fate-10000 for party 10000.
```
kubectl create namespace fate-9999
kubectl create namespace fate-10000
```
In this tutorial, we will take the Spark+Pulsar architecture as the example 

For `/kubefate/examples/party-9999/cluster-spark-pulsar.yaml`, modify it as following:
```
name: fate-9999
namespace: fate-9999
chartName: fate
chartVersion: v1.10.0
partyId: 9999
registry: ""
pullPolicy:
imagePullSecrets:
- name: myregistrykey
persistence: false
istio:
  enabled: false
podSecurityPolicy:
  enabled: false
ingressClassName: nginx
modules:
  - python
  - mysql
  - fateboard
  - client
  - spark
  - hdfs
  - nginx
  - pulsar

computing: Spark
federation: Pulsar
storage: HDFS
algorithm: Basic
device: CPU

ingress:
  fateboard:
    hosts:
    - name: party9999.fateboard.example.com
  client:
    hosts:
    - name: party9999.notebook.example.com
  spark:
    hosts:
    - name: party9999.spark.example.com
  pulsar:
    hosts:
    - name: party9999.pulsar.example.com

python:
  type: NodePort
  httpNodePort: 30097
  grpcNodePort: 30092
  logLevel: INFO

servingIp: 192.168.100.123
servingPort: 30095

nginx:
  type: NodePort
  httpNodePort: 30093
  grpcNodePort: 30098
  route_table:
    10000:
      fateflow:
        - host: 192.168.100.123
          http_port: 30103
          grpc_port: 30108

pulsar:
  type: NodePort
  httpNodePort: 30094
  httpsNodePort: 30099
  publicLB:
    enabled: false
  route_table:
    9999:
      host: pulsar
      port: 6650
      sslPort: 6651
    10000:
      host: 192.168.100.123
      port: 30104
      sslPort: 30109
      proxy: ""
```
and for fate-10000:
```
name: fate-10000
namespace: fate-10000
chartName: fate
chartVersion: v1.10.0
partyId: 10000
registry: ""
pullPolicy:
imagePullSecrets:
- name: myregistrykey
persistence: false
istio:
  enabled: false
ingressClassName: nginx
podSecurityPolicy:
  enabled: false
modules:
  - python
  - mysql
  - fateboard
  - client
  - spark
  - hdfs
  - nginx
  - pulsar

computing: Spark
federation: Pulsar
storage: HDFS
algorithm: Basic
device: CPU

ingress:
  fateboard:
    hosts:
    - name: party10000.fateboard.example.com
  client:
    hosts:
    - name: party10000.notebook.example.com
  spark:
    hosts:
    - name: party10000.spark.example.com
  pulsar:
    hosts:
    - name: party10000.pulsar.example.com

python:
  type: NodePort
  httpNodePort: 30107
  grpcNodePort: 30102
  logLevel: INFO

servingIp: 192.168.100.123
servingPort: 30105

nginx:
  type: NodePort
  httpNodePort: 30103
  grpcNodePort: 30108
  route_table:
    9999:
      fateflow:
        - host: 192.168.100.123
          http_port: 30093
          grpc_port: 30098

pulsar:
  type: NodePort
  httpNodePort: 30104
  httpsNodePort: 30109
  publicLB:
    enabled: false
  route_table:
    9999:
      host: 192.168.100.123
      port: 30094
      sslPort: 30099
      proxy: ""
    10000:
      host: pulsar
      port: 6650
      sslPort: 6651
```
For the two files, pay extra attention of modify the partyId to the correct number otherwise you are not able to access
the notebook or the fateboard.

**NOTE: strongly recommend reading the following document**
For more what each field means, please refer to: 
https://githubcom/FederatedAI/KubeFATE/blob/master/docs/configurations/FATE_cluster_configuration.md.

### Install the FATE clusters
Okay, we can start to install these two FATE cluster via KubeFATE with the following command:
```
kubefate@machine:~/kubefate$ kubefate cluster install -f examples/party-9999/cluster-spark-pulsar.yaml
create job success, job id=2c1d926c-bb57-43d3-9127-8cf3fc6deb4b
kubefate@machine:~/kubefate$ kubefate cluster install -f examples/party-10000/cluster-spark-pulsar.yaml
create job success, job id=7752db70-e368-41fa-8827-d39411728d1b
```

There are two jobs created for deploying the FATE clusters. we can check the status of them with `kubefate job ls`,
or watch the clusters till their STATUS changing to `Running`:
```
kubefate@machine:~/kubefate$ watch kubefate cluster ls
UUID                                    NAME            NAMESPACE       REVISION        STATUS  CHART   ChartVERSION    AGE
29878fa9-aeee-4ae5-a5b7-fd4e9eb7c1c3    fate-9999       fate-9999       1               Running fate    v1.10.0          88s
dacc0549-b9fc-463f-837a-4e7316db2537    fate-10000      fate-10000      1               Running fate    v1.10.0          69s
```
We have about 10G Docker images that need to be pulled, this step will take a while for the first time.
An alternative way is offline loading the images to the local environment.

To check the status of the loading, use the command,
```
kubectl get po -n fate-9999
kubectl get po -n fate-10000
```

When finished applying the image, the result will be similar to this,
```
NAME                           READY   STATUS    RESTARTS   AGE
client-0                       1/1     Running   0          53m
datanode-0                     1/1     Running   0          53m
datanode-1                     1/1     Running   0          40m
datanode-2                     1/1     Running   0          40m
mysql-0                        1/1     Running   0          53m
namenode-0                     1/1     Running   0          53m
nginx-75b7565846-kpj86         1/1     Running   5          53m
pulsar-0                       1/1     Running   1          53m
python-0                       2/2     Running   0          53m
spark-master-fc67d9b57-99sjx   1/1     Running   1          53m
spark-worker-f74f94fdb-44248   1/1     Running   1          53m
spark-worker-f74f94fdb-bx2jv   1/1     Running   1          53m
```

### Verify the deployment
From above `kubefate cluster ls` command, we know the cluster UUID of `fate-9999` is 
`29878fa9-aeee-4ae5-a5b7-fd4e9eb7c1c3`, while cluster UUID of `fate-10000` is `dacc0549-b9fc-463f-837a-4e7316db2537`.
Thus, we can query there access information by:
```
kubefate@machine:~/demo$ kubefate cluster describe 29878fa9-aeee-4ae5-a5b7-fd4e9eb7c1c3
UUID        	29878fa9-aeee-4ae5-a5b7-fd4e9eb7c1c3
Name        	fate-9999
NameSpace   	fate-9999
ChartName   	fate
ChartVersion	v1.10.0
Revision    	1
Age         	54m
Status      	Running
Spec        	algorithm: Basic
            	chartName: fate
            	chartVersion: v1.10.0
            	computing: Spark
            	device: CPU
            	federation: Pulsar
            	imagePullSecrets:
            	- name: myregistrykey
            	ingress:
            	  client:
            	    hosts:
            	    - name: party9999.notebook.example.com
            	  fateboard:
            	    hosts:
            	    - name: party9999.fateboard.example.com
            	  pulsar:
            	    hosts:
            	    - name: party9999.pulsar.example.com
            	  spark:
            	    hosts:
            	    - name: party9999.spark.example.com
            	ingressClassName: nginx
            	istio:
            	  enabled: false
            	modules:
            	- python
            	- mysql
            	- fateboard
            	- client
            	- spark
            	- hdfs
            	- nginx
            	- pulsar
            	name: fate-9999
            	namespace: fate-9999
            	nginx:
            	  grpcNodePort: 30098
            	  httpNodePort: 30093
            	  route_table:
            	    "10000":
            	      fateflow:
            	      - grpc_port: 30108
            	        host: 192.168.100.123
            	        http_port: 30103
            	  type: NodePort
            	partyId: 9999
            	persistence: false
            	podSecurityPolicy:
            	  enabled: false
            	pullPolicy: null
            	pulsar:
            	  httpNodePort: 30094
            	  httpsNodePort: 30099
            	  publicLB:
            	    enabled: false
            	  route_table:
            	    "9999":
            	      host: pulsar
            	      port: 6650
            	      sslPort: 6651
            	    "10000":
            	      host: 192.168.100.123
            	      port: 30104
            	      proxy: ""
            	      sslPort: 30109
            	  type: NodePort
            	python:
            	  grpcNodePort: 30092
            	  httpNodePort: 30097
            	  logLevel: INFO
            	  type: NodePort
            	registry: ""
            	servingIp: 192.168.100.123
            	servingPort: 30095
            	storage: HDFS

Info        	dashboard:
            	- party9999.notebook.example.com
            	- party9999.fateboard.example.com
            	- party9999.pulsar.example.com
            	- party9999.spark.example.com
            	ip: 192.168.100.124
            	status:
            	  containers:
            	    client: Running
            	    datanode: Running
            	    fateboard: Running
            	    fateflow: Running
            	    mysql: Running
            	    namenode: Running
            	    nginx: Running
            	    pulsar: Running
            	    spark-master: Running
            	    spark-worker: Running
            	  deployments:
            	    nginx: Available
            	    spark-master: Available
            	    spark-worker: Available          
```
In `Info->dashboard` field, we can see there are 4 dashboards in the current deployment: 
* Notebook in `party9999.notebook.example.com`, which is the Jupyter Notebook integrated, 
where data scientists can write python or access shell. We have pre-installed FATE-clients to the Notebook.
* FATEBoard in `party9999.fateboard.example.com`, which we can use to check the status, job flows in FATE.
* Pulsar in `party9999.pulsar.example.com`, which is the UI console of Pulsar, the message queue for transferring the gradients during FML.
* Spark in `party9999.spark.example.com`, which is the UI console of Spark,

With similar command, we can check the dashboards for fate-10000.

### (Optional) Configure the dashboards' URLs in hosts
#### Note: if we have the dns service setup, this step can be skipped.

If no DNS service configured, we have to add these two url to our hosts file. In a Linux or macOS machine, 

```
sudo -- sh -c "echo \"192.168.100.123 party9999.notebook.example.com\"  >> /etc/hosts"
sudo -- sh -c "echo \"192.168.100.123 party9999.fateboard.example.com\"  >> /etc/hosts"
sudo -- sh -c "echo \"192.168.100.123 party10000.notebook.example.com\"  >> /etc/hosts"
sudo -- sh -c "echo \"192.168.100.123 party10000.fateboard.example.com\"  >> /etc/hosts"
```

In a Windows machine, you have to add them to `C:\WINDOWS\system32\drivers\etc\hosts`, please refer to
[add host for Windows](https://github.com/ChrisChenSQ/KubeFATE/blob/master/docs/tutorials/Windows_add_host_tutorial.md).




