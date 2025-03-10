{{/*
Library of templates created with the define keyword
https://helm.sh/docs/chart_template_guide/named_templates/#declaring-and-using-templates-with-define-and-template
*/}}

{{/*
Encode the admin and a list of users for the basic auth secret
The point as second argument of the include is the context. It's mandatory to get access to the values `.Values...`
Usage: {{ include "basic-auth-list-base64-encode" . }}

Note:
This is equivalent to create a line by user that contains the ouput of:
`htpasswd -nb admin@traefik welcome`

Traefik expects the passwords to be hashed using MD5, SHA1, or BCrypt.

Email is used as the main identifier as Dex does
https://dexidp.io/docs/connectors/local/
*/}}
{{- define "basic-auth-list-base64-encode" }}
{{- $result := list }}
{{/* Add the admin user */}}
{{- $result = append $result (htpasswd .Values.cluster.auth.admin_user.email .Values.cluster.auth.admin_user.password | b64enc)}}
{{/* See https://github.com/helm/helm/issues/7533#issuecomment-1039521776 */}}
{{- range $email, $password := .Values.middlewares.basic_auth.users }}
{{- $result = append $result (htpasswd $email $password | b64enc) }}
{{- end }}
{{- join "\n" $result}}
{{- end }}


{{/*
Name Helper
*/}}
{{- define "traefik-name-prefix" }}
{{- include "kubee-name-prefix" (dict "Release" .Release "Values" .Values.kubee )}}
{{- end }}


{{/*
Name Helper to print the dashboard cert name for consistency
(used for certificate, secret, ...)
*/}}
{{- define "traefik-name-dashboard-cert" }}
{{- printf "%s-%s"
    (include "kubee-name-prefix" (dict "Release" .Release "Values" .Values.kubee ))
    "dashboard-cert"
    }}
{{- end }}