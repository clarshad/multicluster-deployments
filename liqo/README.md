## Install with Helm

#### Prerequistes

- below binary installed
    - kubectl
    - helm
    - liqoctl
- kubeconfig of clusters to be peered
- Clusters to be peered in running state with calico installed

#### Steps

1. Before installing the helm chart, update `apiServer.address` `clusterID` `podCIDR` `serviceCIDR` and `reservedSubnets`

2. Add below annotation for gateway service (this is specifically for AWS)
```
service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
```
3. Install helm chart as below
```
helm install liqo liqo/liqo --namespace liqo --create-namespace 
```
Note: podCIdR and serviceCIDR should not overlap with peered clusters, hence update them while running on each cluster accordingly

4. Run below command to create peering

```
liqoctl peer --kubeconfig demo-cluster1-kubeconfig --remote-kubeconfig demo-cluster2-kubeconfig
```
 
5. To offload resources in cluster1 to cluster2, run below command

```
liqoctl offload namespace liqo-demo \
  --namespace-mapping-strategy EnforceSameName \
  --pod-offloading-strategy LocalAndRemote
```
6. Verify that pods are offloaded to cluster2

```
kubectl run --image nginx nginx -n liqo-demo
kubectl get pods -n liqo-demo -o wide
```
Verify pod is scheduled on cluster2 and running on virtual node