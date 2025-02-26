# Kubee Helmet Chart


A Kubee Chart may be:
* a Helm Chart
* a [Jsonnet Chart](jsonnet-chart.md)
* a [Kustomize Chart](kustomize-project.md)
* a [Cluster Chart](cluster-chart.md)

A `Kubee Helmet Chart`:
* is a Chart
    * that installs only one application
    * with the name of the app installed (ie grafana, not grafana operator)
    * that depends on:
        * the [kubee Cluster Library Chart](../../resources/charts/cluster/README.md) to share cluster and installation wide
            * `values.yaml` file
            * and `library`
        * and optionally:
            * cross dependency Charts:
                * to bring cross values to create cross conditional expression. Example:
                    * conditional: `if cert_manager.enabled then create_certificate_request`
                    * cross: `if prometheus.enabled then create_grafana_data_source with promtheus.name`
                * with a mandatory false condition `kubee_internal.dont_install_dependency: false`
            * direct/wrapped dependency Chart (for instance, `kubee-external-secrets` wraps the `external-secret` Chart)
    * with optional:
      * [Jsonnet](jsonnet-project.md) 
      * or [kustomize](kustomize-project.md)

* installs only one application as `kubee` is a platform.
    * For instance, installing an application such as grafana can be done via:
        * a raw deployment manifest
        * or the grafana operator
    * Only one chart is going to supports this 2 methods.

    
# Values file

Each `values.yaml` file should contain at least the following properties:
* `namespace = name`: the namespace where to install the chart
* `enabled = false`: if the chart is used or not. The value should be false. It's used to:
    * conditionally applied manifest. If there is no grafana, don't install the dashboard
    * cluster bootstrapping (ie install all charts at once)

> [!Info]
> The `enabled` property comes from the [Helm best practices](https://helm.sh/docs/chart_best_practices/dependencies/#conditions-and-tags)

The values file should contain different nodes for:
* the chart itself
* the external services (opsgenie, new relic, grafana cloud, ...) - making clear what the parameters are for.


## FAQ: Why not multiple sub-chart by umbrella chart?

SubChart cannot by default be installed in another namespace than the umbrella chart.
This is a [known issue with helm and sub-charts](https://github.com/helm/helm/issues/5358)

That's why:
* the unit of execution is one sub-chart by umbrella chart
* `kubee-cluster` is a common sub-chart of all umbrella chart


## Dev: Cross dependency

Cross Dependency are only used to share values.

When developing a Chart, you should:
* add them in `Chart.yml` and disable them with a condition
```yaml
- name: kubee-traefik-forward-auth
  version: 0.0.1
  alias: traefik_forward_auth
  condition: kubee_internal.install_cross_dependency
```
* add them as symlink
* add the cross-dependency sub-charts directory in the `helmignore` file to avoid symlink recursion

Example: The chart `kubee-dex` depends on the `kubee-traefik-forward-auth` that depends on the `kubee-dex` chart
creating a recursion.

To avoid this recursion, add the `kubee-traefik-forward-auth/charts` in the `helmignore` file
```ignore
charts/kubee-traefik-forward-auth/charts
```