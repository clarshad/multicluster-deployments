## Install with Helm

#### Prerequistes

- below binary installed
    - kubectl
    - helm
    - liqoctl
- kubeconfig of clusters to be peered

#### Steps

1. To install chart on your cluster

```
helm install liqo liqo --namespace liqo --create-namespace 
```
Note: Update `podCIDR` and `serviceCIDR` accordingly

2. Liqo peering

```
liqoctl peer --kubeconfig demo-cluster1-kubeconfig --remote-kubeconfig demo-cluster2-kubeconfig --in-band
```
