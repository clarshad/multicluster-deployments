# namutech

This is a collection of yaml files for Kubernetes mutli-cluster provisioning and management.

## Setup Management Cluster

1. Bring up a single EC2 instance with alteast 2 CPU core and 8GB RAM. Preferrable with Ubuntu OS. Make sure below ports are open for inbound traffic.

    - 80 (HTTP)
    - 443 (HTTPS)
    - 22 (SSH)
    - 6443 (Kubernetes API server port)
    - 32443 (Karmada node port)
    - 31564 (argocd node port for http) 
    - 30504 (argocd node port for https)

2. Install [k3s](https://rancher.com/docs/k3s/latest/en/installation/) by running below command on the EC2 instance.

```
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--tls-san k3s.example.com --tls-san 192.168.1.10" sh -
```
Note: Replace with correct IP and hostname.

3. Copy the kubeconfig from /etc/rancher/k3s/k3s.yaml to your local machine. Replace with correct IP and hostname in kubeconfig file.

4. To access your k3s cluster, setup below env var in your local machine.

```
export KUBECONFIG=/location/to/kubeconfig/k3s.yaml
```
Note: Make sure you have kubectl binary installed in your local machine.

5. Install cert-manager by running below command.

```
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.2/cert-manager.yaml
```
6. Install ClusterAPI by referring [official docs](https://cluster-api-aws.sigs.k8s.io/getting-started). Below are the commands to install ClusterAPI. (considering linux ARM64 as the local machine)

``` 
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.10.1/clusterctl-linux-arm64 -o clusterctl
clusterctl version
curl -L https://github.com/kubernetes-sigs/cluster-api-provider-aws/releases/download/v0.0.0/clusterawsadm-linux-amd64 -o clusterawsadm
chmod +x clusterawsadm
sudo mv clusterawsadm /usr/local/bin
clusterawsadm version

export AWS_REGION=us-east-1 # This is used to help encode your environment variables
export AWS_ACCESS_KEY_ID=<your-access-key>
export AWS_SECRET_ACCESS_KEY=<your-secret-access-key>

# The clusterawsadm utility takes the credentials that you set as environment
# variables and uses them to create a CloudFormation stack in your AWS account
# with the correct IAM resources.
clusterawsadm bootstrap iam create-cloudformation-stack

# Create the base64 encoded credentials using clusterawsadm.
# This command uses your environment variables and encodes
# them in a value to be stored in a Kubernetes Secret.
export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm bootstrap credentials encode-as-profile)

# Finally, initialize the management cluster
clusterctl init --infrastructure aws
```

7. Install CAPI related custom resource `ClusterResourceSet` by running below command. This will ensure every cluster that comes up by CAPI will have calico CNI and AWS cloud controller manager installed in the cluster.

```
kubectl apply -f capi-sample-files/resource-set.yaml
```
Note: For installing cluster in AWS via CAPA CAPI, make sure you have VPC and ssh key pair created. Also verify the ami ID before setting it in the CAPI related custom resource.

8. To install Karmada, install Karmadactl binary in your local machine.

```
curl -s https://raw.githubusercontent.com/karmada-io/karmada/master/hack/install-cli.sh | sudo bash
```

9. Run below command to install Karmada on your management cluster.

```
sudo karmadactl init --kubeconfig /path/to/k3/mgmt/cluster/kubeconfig/file --karmada-apiserver-advertise-address=public-ip-of-mgmt-cluster
```

10. Update command line option in `karmada-controller-manager` in `karmada-system` namespace to include `--feature-gates=Failover=true` to enable failover feature. Refrence [docs](https://karmada.io/docs/userguide/failover/failover-overview#how-do-i-enable-the-feature).

## Setup Liqo Peering on Prod Clusters

1. Install [liqoctl](https://docs.liqo.io/en/v0.5.3/installation/liqoctl.html) binary in your local machine. 

2. Install liqo helm chart on the clusters to be peered by running below command.

```
helm install liqo liqo/liqo --namespace liqo --create-namespace \
  --set discovery.config.clusterID="demo-cluster3" \
  --set apiServer.address="https://default-demo-cluster3-apiserver-e53a72881fd6da80.elb.eu-west-1.amazonaws.com:6443" \
  --set ipam.podCIDR="192.168.20.0/24" \
  --set ipam.serviceCIDR="10.96.20.0/24"
  
```
Note: Make sure to update set values for each cluster accordingly

3. Run below command to create peering

```
liqoctl peer --kubeconfig demo-cluster1-kubeconfig --remote-kubeconfig demo-cluster2-kubeconfig
```
 
4. To offload resources in cluster1 to cluster2, run below command

```
kubectl create ns liqo-demo
liqoctl offload namespace liqo-demo \
  --namespace-mapping-strategy EnforceSameName \
  --pod-offloading-strategy LocalAndRemote
```
5. Verify that pods are offloaded to cluster2

```
liqoctl info
kubectl run --image nginx nginx -n liqo-demo
kubectl get pods -n liqo-demo -o wide
```
Verify pod is scheduled on cluster2 and running on virtual node


## Setup Multi Cluster Environment via Karmada

1. With Karmada installed on management cluster and a couple of prod cluster up, run below command to add member clusters.

```
sudo karmadactl --kubeconfig /etc/karmada/karmada-apiserver.config join demo-cluster1 --cluster-kubeconfig=demo-cluster1-kubeconfig
sudo karmadactl --kubeconfig /etc/karmada/karmada-apiserver.config join demo-cluster2 --cluster-kubeconfig=demo-cluster2-kubeconfig
```

2. Test propagation policy by running below command.

```
sudo karmadactl --kubeconfig /etc/karmada/karmada-apiserver.config apply -f karmada-sample-files/sample-propagationpolicy.yaml
sudo karmadactl --kubeconfig /etc/karmada/karmada-apiserver.config apply -f karmada-sample-files/sample2-propagationpolicy.yaml
```
3. Connect individually on member clusters and verify pods running.

4. To remove member cluster from Karmada, run below command.

```
sudo karmadactl --kubeconfig /etc/karmada/karmada-apiserver.config unjoin demo-cluster1
sudo karmadactl --kubeconfig /etc/karmada/karmada-apiserver.config unjoin demo-cluster2
```

## Setup ArgoCD on Management Cluster

1. Run below command to install ArgoCD on management cluster. This for application deployment across member clusters added via Karmada.

```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
kubectl patch service argocd-server -n argocd \
  -p '{
    "spec": {
      "ports": [
        {
          "name": "http",
          "port": 80,
          "protocol": "TCP",
          "targetPort": 8080,
          "nodePort": 31564
        },
        {
          "name": "https",
          "port": 443,
          "protocol": "TCP",
          "targetPort": 8080,
          "nodePort": 30504
        }
      ]
    }
  }'
```

2. Download argocd CLI binary from argocd [site](https://argo-cd.readthedocs.io/en/stable/getting_started/#2-download-argo-cd-cli)

3. Connect argocd CLI to argocd server and register Karmada control plane.

``` 
argocd admin initial-password -n argocd
argocd login 54.235.71.18:31564
sudo kubectl config --kubeconfig /etc/karmada/karmada-apiserver.config  get-contexts -o name
sudo argocd --kubeconfig /etc/karmada/karmada-apiserver.config cluster add karmada-apiserver
```
Note: For argocd login use management IP along with port number of argocd server port, by listing `kubectl get svc -n argocd argocd-server`
Also make sure the port number assigned by Kubernetes is open on EC2 instance (K3s management cluster) security group.

4. Verification - Deploy a sample app via argocd UI and verify it is deployed on member clusters.

  (a) Connect to argocd UI via browser on https://54.235.71.18:31564 and login with admin user and password from step 3.

  (b) Create a new application and select Karmada control plane API as Destination cluster URL. Reference [official docs](https://karmada.io/docs/userguide/cicd/working-with-argocd/#creating-apps-via-ui).

  (c) Set below values while creating the application, while keeping other values same as default.

```
REPO URL: https://github.com/clarshad/multicluster-deployments.git
PATH: argocd-sample-files/guestbook-example-app
TARGET REVISION: main
Project: default
Destination Cluster URL: karmada-apiserver (https://54.235.71.18:32443)
```

  (d) Once sync completed, verify app is deployed on member clusters. 

