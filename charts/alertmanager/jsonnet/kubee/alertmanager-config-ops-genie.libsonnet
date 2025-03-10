/*
      The opsgenie alert manager config
      https://github.com/prometheus/alertmanager/blob/main/config/testdata/conf.opsgenie-both-file-and-apikey.yml
      https://prometheus.io/docs/alerting/latest/configuration/#opsgenie_config
      One receiver by priority as stated here:
      https://support.atlassian.com/opsgenie/docs/integrate-opsgenie-with-prometheus/
*/
local defaultValues = {
  alert_manager_opsgenie_apikey: error 'OpsGenie Api Key should be provided',
};

// Opsgenie
function(params) {
  local values = defaultValues + params,
  // Alert manager Global
  AlertmanagerGlobal: {
    opsgenie_api_key: values.alert_manager_opsgenie_apikey,
    opsgenie_api_url: 'https://api.opsgenie.com/',
  },
  // CRD
  AlertmanagerConfig: {
    apiVersion: 'monitoring.coreos.com/v1alpha1',
    kind: 'AlertmanagerConfig',
    metadata: {
      name: 'opsgenie',
      labels: {
        'app.kubernetes.io/name': 'alertmanager',
      },
    },
    spec: {
      /*
        Route
        https://prometheus-operator.dev/docs/api-reference/api/#monitoring.coreos.com/v1alpha1.Route
      */
      route: {
        // The default
        receiver: 'opsgenie-critical',
        // Only warning and critical alert can enter here
        matchers: [{
          name: 'severity',
          value: 'critical|warning',
          matchType: '=~',
        }],
        routes: [
          {
            // We send to the opsgenie-warning to set the correct priority
            receiver: 'opsgenie-warning',
            matchers: [{
              name: 'severity',
              value: 'warning',
              matchType: '=',
            }],
          },
        ],
      },
      receivers: [
        {
          name: 'opsgenie-critical',
          opsgenieConfigs: [{ priority: 'P1' }],
        },
        {
          name: 'opsgenie-warning',
          opsgenieConfigs: [{ priority: 'P2' }],
        },
        {
          //  Not used for info
          name: 'opsgenie-info',
          opsgenieConfigs: [{ priority: 'P3' }],
        },
      ],
    },
  },
}
