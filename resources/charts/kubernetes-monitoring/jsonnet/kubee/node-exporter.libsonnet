// node-exporter metrics customization
// that delete Rbac container
//
// Note: The dashoard is not the dashboard of the mixin because it does not take account the cluster
// It's a node alone dashboard. Kubernetes Monitoring has a node dashboard.

local defaults = {
  node_exporter_scrape_interval: error 'node_exporter_scrape_interval is not specified',
  node_exporter_scrape_metrics_optimization: error 'node_exporter_scrape_metrics_optimization is not specified',
};


function(params)

  local values = defaults + params;

  local newScheme = 'http';

  // The kube-prometheus lib
  local kpNodeExporter = (import '../kube-prometheus/components/node-exporter.libsonnet')(params);
  kpNodeExporter {

    // The original daemonset
    // https://github.com/prometheus-operator/kube-prometheus/blob/main/manifests/nodeExporter-daemonset.yaml
    daemonset+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              container {
                ports: [{
                  containerPort: 9100,
                  hostPort: 9100,
                  name: newScheme,
                }],
              }
              for container in kpNodeExporter.daemonset.spec.template.spec.containers
              if container.name == 'node-exporter'
            ],
          },
        },
      },
    },
    serviceMonitor+: {
      spec+: {
        endpoints: [
          endpoint {
            port: newScheme,
            scheme: newScheme,
            // Not overwridden but we can see where the data comes from
            interval: values.node_exporter_scrape_interval,
            relabelings+: if !values.node_exporter_scrape_metrics_optimization then [] else [
              //{
              //
              // Deprecated as Kube prometheus
              // replacec the instance already by `__meta_kubernetes_pod_node_name`
              //
              // New Relic and other remote write endpoint takes the instance as node name
              // By default, the instance value is `IP:PORT` and is then replaced by `hostname`
              //
              // see https://prometheus.io/docs/prometheus/latest/configuration/configuration/#kubernetes_sd_config
              //sourceLabels: ['__meta_kubernetes_endpoint_node_name'],
              //targetLabel: 'instance',
              //},
              {
                // Drop the discovery service label
                // We keep service to be able to get the kb by service
                action: 'labeldrop',
                regex: '(container|endpoint|namespace|pod|job)',
              },
            ],
            metricRelabelings+: if !values.node_exporter_scrape_metrics_optimization then [] else [
              // Keep only what we need based on summary graph (New Relic, ...)
              // CPU: node_cpu_seconds_total
              // Memory: node_memory_MemAvailable_bytes, node_memory_MemTotal_bytes
              // Storage and Disk Usage: node_filesystem_avail_bytes, node_filesystem_size_bytes (device label is needed)
              // Network Traffic: node_network_transmit_bytes_total, node_network_receive_bytes_total
              // Load average: node_load1, node_load5, node_load15
              {
                sourceLabels: ['__name__'],
                regex: 'node_cpu_seconds_total|node_memory_MemAvailable_bytes|node_memory_MemTotal_bytes|node_filesystem_avail_bytes|node_filesystem_size_bytes|node_network_transmit_bytes_total|node_network_receive_bytes_total|node_load.*',
                action: 'keep',
              },
              // {
              //
              // Depreacted by Kube Promtheus that uses
              // the node exporter flags: --collector.netdev.device-exclude=^(veth.*|[a-f0-9]{15})$
              //
              // High Cardinality
              // Drop the high cardinality vethxxxx label device (High Cardinality label: cni, eth0, vethxxx, lo, flannel, ...)
              // We rename because newrelic rely on it in query
              // Example: File System Available query: `device != 'tmpfs'`
              // sourceLabels: ['device'],
              // regex: 'veth.*',
              // targetLabel: 'device',
              // replacement: 'vethxxxxxx',
              // },
            ],
          }
          for endpoint in kpNodeExporter.serviceMonitor.spec.endpoints
        ],
      },
    },
  }
