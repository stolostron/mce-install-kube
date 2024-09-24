
{{/* Define the images. */}}
{{- define "governance_policy_propagator" }}
{{- with .Values.global }}
{{- if .imageOverrides.governance_policy_propagator }}
{{- printf "%s" .imageOverrides.governance_policy_propagator }}
{{- else }}
{{- printf "%s/governance-policy-propagator:%s" .registry .tag }}
{{- end }}
{{- end }}
{{- end }}

{{- define "governance_policy_addon_controller" }}
{{- with .Values.global }}
{{- if .imageOverrides.governance_policy_addon_controller }}
{{- printf "%s" .imageOverrides.governance_policy_addon_controller }}
{{- else }}
{{- printf "%s/governance-policy-addon-controller:%s" .registry .tag }}
{{- end }}
{{- end }}
{{- end }}

{{- define "config_policy_controller" }}
{{- with .Values.global }}
{{- if .imageOverrides.config_policy_controller }}
{{- printf "%s" .imageOverrides.config_policy_controller }}
{{- else }}
{{- printf "%s/config-policy-controller:%s" .registry .tag }}
{{- end }}
{{- end }}
{{- end }}

{{- define "governance_policy_framework_addon" }}
{{- with .Values.global }}
{{- if .imageOverrides.governance_policy_framework_addon }}
{{- printf "%s" .imageOverrides.governance_policy_framework_addon }}
{{- else }}
{{- printf "%s/governance-policy-framework-addon:%s" .registry .tag }}
{{- end }}
{{- end }}
{{- end }}