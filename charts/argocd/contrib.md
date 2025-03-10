# Contrib/Dev

## About

This is a `Kubee`:
* [kustomization chart](../../../docs/bin/kubee-helm-post-renderer.md#kustomization) because this is the official supported installation (ie [Helm is community maintained](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/#helm))
* and [Jsonnet chart](../../../docs/bin/kubee-helmet#what-is-a-jsonnet-kubee-chart) to install the monitoring mixin


## Dependency Script

Run [utilties/dl-dependency-scripts](utilties/dl-dependency-scripts) to update to the last [mixin library](jsonnet/kubee/mixin.libsonnet)

## How to


### Test/Check values before installation

With Helmet For instance, to check the [repo creation](templates/resources/argocd-secret-repo.yaml)
```bash
export BASHLIB_ECHO_LEVEL=4;
kubee helmet -c clusterName template argocd | grep 'name: argocd-secret-repo' -A 2 -B 11
```

## Namespace

https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/#installing-argo-cd-in-a-custom-namespace

### Debug Notifications

* Apply the patch
```bash
kubectl patch cm argocd-notifications-cm -n argocd --type merge --patch-file argo/patches/argocd-notifications-config-map-patch.yml
```
* Test
```bash
kubectl config set-context --current --namespace=argocd
argocd admin notifications template get
```

### JsonNet Prometheus Mixin

To get the Jsonnet Manifest in `jsonnet/out` 

```bash
# Debug to not delete them on exit
export BASHLIB_ECHO_LEVEL=4;
# Run
kubee helmet \
  --cluster clusterName \
  template \
  argocd
  > /dev/null
```


### ArgoCd Version

The ArgoCd version is:
* in the [URL path of the kustomization file](kustomization.yml)
* in the [appVersion of the Chart manifest](Chart.yaml)