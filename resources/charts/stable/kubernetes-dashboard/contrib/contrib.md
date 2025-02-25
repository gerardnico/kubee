# Dev/Contrib

## Chart Type

This is a umbrella chart because Kubernetes Dashboard [supports only Helm-based installation](https://github.com/kubernetes/dashboard?tab=readme-ov-file#installation)


## Charts dir bootstrap

```bash
mkdir "charts"
ln -s $(realpath ../cluster) charts/kubee-cluster
mkdir "charts/kubee-cert-manager"
ln -s $(realpath ../cert-manager/Chart.yaml) charts/kubee-cert-manager/Chart.yaml
ln -s $(realpath ../cert-manager/values.yaml) charts/kubee-cert-manager/values.yaml
mkdir "charts/kubee-traefik"
ln -s $(realpath ../traefik/Chart.yaml) charts/kubee-traefik/Chart.yaml
ln -s $(realpath ../traefik/values.yaml) charts/kubee-traefik/values.yaml

helm pull https://github.com/kubernetes/dashboard/releases/download/kubernetes-dashboard-7.10.4/kubernetes-dashboard-7.10.4.tgz -d charts --untar
```


## Test

* Verify
```bash
helm lint
# output them all at out 
kubee helmet -c clusertName template kubernetes-dashboard --out
```
## Install

```bash
kubee helmet -c clusertName play kubernetes-dashboard
```


## FAQ


### Why there is no ingress basic auth protection?

The ingress cannot be protected with an authentication mechanism that uses the `Authenticate` HTTP header
such as the `basic auth` otherwise they conflict, and you get a `401` not authorized.

### How to access the dashboard without Ingress
* Via Port forwarding

```bash
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443  
```
You can then access the dashboard at: https://localhost:8443

*  Via Proxy: Via API Service Proxy
```bash
kubectl proxy
```
You can then access the dashboard at http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard-kong-proxy:443/proxy/#/login


## Ref

https://artifacthub.io/packages/helm/k8s-dashboard/kubernetes-dashboard 