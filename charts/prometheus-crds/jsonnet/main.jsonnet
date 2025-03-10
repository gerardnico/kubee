// To execute
// rm -rf jsonnet/multi/manifests && mkdir -p jsonnet/multi/manifests && jsonnet -J vendor --multi jsonnet/multi/manifests --ext-str "operatorPrometheusVersion=0.76.2" "jsonnet/multi/prometheus-operator-crds.jsonnet"  | xargs -I{} sh -c 'cat {} | gojsontoyaml > "{}.yaml" && rm {}' -- {}

// Get the version from the Chart.yaml
local chart = {
    appVersion: error "prometheusOperator appVersion is required"
} + std.parseYaml(importstr '../../Chart.yaml');

// The version and the mandatory parameters
local params = {
    // version become the following label
    // operator.prometheus.io/version without the v. example: 0.76.2
    // why without the v don't know
    version: std.substr(chart.appVersion, 1, std.length(chart.appVersion) - 1),
    // crds are not namespaced
    namespace: 'whatever',
    // not in crds but mandatory
    configReloaderImage: 'whatever',
    // not in crds but mandatory in code
    image: 'whatever'
};

// Import the function and executes
local prometheusOperator = (import 'vendor/github.com/prometheus-operator/prometheus-operator/jsonnet/prometheus-operator/prometheus-operator.libsonnet')(params);

// Extract only the CRDS
{
 ['prometheus-operator-'+name]: prometheusOperator[name]{
    metadata+:{
      annotations+: {
        // Don't delete
        "helm.sh/resource-policy": "keep"
      }
    }
 }
 for name in std.filter((function(name) prometheusOperator[name].kind == 'CustomResourceDefinition'), std.objectFields(prometheusOperator))
}

// In kube-prometheus, there is also a pyrra CRD
// { 'setup/pyrra-slo-CustomResourceDefinition': kp.pyrra.crd }