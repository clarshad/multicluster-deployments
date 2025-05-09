# namutech
Namutech Kubernetes Cluster

This is a collection of yaml files to create a simple Kubernetes cluster with CAPI (Cluster API) and Calico (Network Policy).

## Setup Management Cluster

1. Bring up a single EC2 instance with alteast 2 CPU core and 8GB RAM. Preferrable with Ubuntu OS.

2. Install [k3s](https://rancher.com/docs/k3s/latest/en/installation/) by running below command.

```
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--tls-san k3s.example.com --tls-san 192.168.1.10" sh -
```
Note: Replace with correct IP and hostname.

3. Cop the kubeconfig from /etc/rancher/k3s/k3s.yaml to your local machine. Replace with correct IP and hostname in kubeconfig file.

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


