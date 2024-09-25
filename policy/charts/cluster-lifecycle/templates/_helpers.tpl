
{{/* Define the images. */}}
{{- define "klusterlet_addon_controller" }}
{{- with .Values.global }}
{{- if .imageOverrides.klusterlet_addon_controller }}
{{- printf "%s" .imageOverrides.klusterlet_addon_controller }}
{{- else }}
{{- printf "%s/klusterlet-addon-controller:%s" .registry .tag }}
{{- end }}
{{- end }}
{{- end }}
