local validation = import './kube-x/validation.libsonnet';

local kxExtValues = std.extVar('values');
// Values are flatten, so that we can:
// * use the + operator and the error pattern in called library
// * we can easily rename
local kxValues = {

  kubernetes_monitoring_namespace: validation.notNullOrEmpty(kxExtValues, 'namespace'),
  grafana_enabled: validation.notNullOrEmpty(kxExtValues, 'grafana.enabled'),
  grafana_name: validation.notNullOrEmpty(kxExtValues, 'grafana.name'),
  grafana_folder: 'kubernetes-monitoring',
  grafana_data_source: validation.notNullOrEmpty(kxExtValues, 'grafana.data_sources.prometheus.name'),
  kube_state_metrics_enabled: validation.notNullOrEmpty(kxExtValues, 'kube_state_metrics.enabled'),
  kube_state_metrics_scrape_interval: validation.notNullOrEmpty(kxExtValues, 'kube_state_metrics.scrape_interval'),
  kube_state_metrics_memory: validation.notNullOrEmpty(kxExtValues, 'kube_state_metrics.memory'),
  kube_state_metrics_version: validation.notNullOrEmpty(kxExtValues, 'kube_state_metrics.version'),

};

local k3sConfigPatch = {
  // Kubernetes Scheduler, Controller manager and proxy metrics comes from the api server endpoint
  // in k3s
  kubeApiserverSelector: 'job="apiserver"',  // the default value
  kubeSchedulerSelector: self.kubeApiserverSelector,
  kubeControllerManagerSelector: self.kubeApiserverSelector,
  kubeProxySelector: self.kubeApiserverSelector,
  kubeletSelector: 'job="kubelet"',
  cadvisorSelector: self.kubeletSelector,  // the default is 'job="cadvisor"'
};

local stripLeadingV(value) =
  if std.type(value) != 'string' then
    value
  else if std.startsWith(value, 'v') then
    std.substr(value, 1, std.length(value) - 1)
  else
    value;


// The kube-prometheus values
// Adapted from main https://github.com/prometheus-operator/kube-prometheus/blob/main/jsonnet/kube-prometheus/main.libsonnet#L18
local kpValues = {
  common: {
    namespace: kxValues.kubernetes_monitoring_namespace,
    // to allow automatic upgrades of components, we store versions in autogenerated `versions.json` file and import it here
    versions: {
      nodeExporter: error 'must provide version',
      // RbacProxy is used by kube-prometheus to protect exporter endpoints
      kubeRbacProxy: error 'must provide version',
    } + (import 'kube-prometheus/versions.json') + {
      kubeStateMetrics: stripLeadingV(kxValues.kube_state_metrics_version),
    },
    images: {
      kubeStateMetrics: 'registry.k8s.io/kube-state-metrics/kube-state-metrics:v' + $.common.versions.kubeStateMetrics,
      nodeExporter: 'quay.io/prometheus/node-exporter:v' + $.common.versions.nodeExporter,
      kubeRbacProxy: 'quay.io/brancz/kube-rbac-proxy:v' + $.common.versions.kubeRbacProxy,
    },
  },
  kubeStateMetrics: {
    namespace: $.common.namespace,
    version: $.common.versions.kubeStateMetrics,
    image: $.common.images.kubeStateMetrics,
    mixin+: {
      _config+:: k3sConfigPatch,
    },
    kubeRbacProxyImage: $.common.images.kubeRbacProxy,
    resources:: {
      requests: { cpu: '10m', memory: kxValues.kube_state_metrics_memory },
      limits: { memory: kxValues.kube_state_metrics_memory },
    },
    scrapeInterval: kxValues.kube_state_metrics_scrape_interval,
  },
  kubernetesControlPlane: {
    namespace: $.common.namespace,
    mixin+: {
      _config+:: k3sConfigPatch,
    },
  },
  nodeExporter: {
    namespace: $.common.namespace,
    version: $.common.versions.nodeExporter,
    image: $.common.images.nodeExporter,
    mixin+: {
      _config+:: k3sConfigPatch,
    },
    kubeRbacProxyImage: $.common.images.kubeRbacProxy,
  },
};
// k8s-control-plane.libsonnet is a function
local kubernetesControlPlane = (import './kube-prometheus/components/k8s-control-plane.libsonnet')(kpValues.kubernetesControlPlane);
// custom.libsonnet is a function that does not have its node
local custom = (import './kube-prometheus/components/mixin/custom.libsonnet')({
  namespace: kpValues.common.namespace,
  mixin+: { _config+:: k3sConfigPatch },
});


// mixin is not a function but an object
local mixin = (import 'github.com/kubernetes-monitoring/kubernetes-mixin/mixin.libsonnet') {
  _config+:: k3sConfigPatch {
    // the name of the data source (in place of default)
    datasourceName: kxValues.grafana_data_source,
  },
};

// Returned Object
{ 'kubernetes-monitoring-custom-prometheusRule': custom.prometheusRule } +
{
  ['kubernetes-monitoring-' + name]:
    (
      if name == 'prometheusRule'
      then
        local prometheusRule = kubernetesControlPlane[name];
        prometheusRule {
          spec: {
            groups: [
              group
              for group in prometheusRule.spec.groups
              // We filter out the following groups
              if !std.member([
                    // The api server endpoint gives you metrics from controller manager and scheduler as well.
                    // You have all the metrics but rules and dashboard don't expect them to be tagged with job=apiserver.
                    // Ref: https://github.com/k3s-io/k3s/issues/425#issuecomment-813017614
                    'kubernetes-system-controller-manager',  // k3s does not have any controller-manager, no need to alert
                    'kubernetes-system-scheduler',  // k3s does not have any scheduler, no need to alert
                    ], group.name)
            ],
          },
        }
      else if name == 'serviceMonitorKubelet' then
        local serviceMonitorKubelet = kubernetesControlPlane[name];
        serviceMonitorKubelet {
          spec+: {
            endpoints: [
              endpoint
              for endpoint in serviceMonitorKubelet.spec.endpoints
              // We filter out the /metrics/slis target
              // https://github.com/k3s-io/k3s/discussions/11637
              if !(std.objectHas(endpoint, 'path') && endpoint.path == '/metrics/slis')
            ],
          },
        }
      else kubernetesControlPlane[name]
    )
  for name in std.objectFields(kubernetesControlPlane)
  // k3s is only one binary
  // and does not need to scrape KubeScheduler and KubeControllerManager
  // The metrics are gathered with the api server scrape
  if !std.member(['serviceMonitorKubeScheduler', 'serviceMonitorKubeControllerManager'], name)
} +
// kube-state metrics
(
  if !kxValues.kube_state_metrics_enabled then {} else
    local kubeStateMetrics = (import './kube-x/kube-state-metrics.libsonnet')(kpValues.kubeStateMetrics);
    {
      ['kubernetes-monitoring-state-metrics-' + name]: kubeStateMetrics[name]
      for name in std.objectFields(kubeStateMetrics)
    }
)
+
// Dashboard and Folder
(
  if !kxValues.grafana_enabled then {} else (import 'kube-x/mixin-grafana.libsonnet')(kxValues {
    mixin: mixin,
    mixin_name: 'kubernetes-monitoring',
    grafana_folder_label: 'Kubernetes Monitoring',
  })
)
