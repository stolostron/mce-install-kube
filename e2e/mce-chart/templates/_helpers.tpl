{{/* Create secret to access docker registry */}}
{{- define "imagePullSecret" }}
{{- with .Values.images }}
{{- if .imageCredentials.dockerConfigJson }}
{{- printf "%s" .imageCredentials.dockerConfigJson | b64enc }}
{{- else }}
{{- printf "{}" | b64enc }}
{{- end }}
{{- end }}
{{- end }}



{{/* Define the images. */}}
{{- define "backplane_operator" }}
{{- with .Values.images }}
{{- if .overrides.backplane_operator }}
{{- printf "%s" .overrides.backplane_operator }}
{{- else }}
{{- printf "%s/backplane-operator:%s" .registry .tag }}
{{- end }}
{{- end }}
{{- end }}

{{- define "registration_operator" }}
{{- with .Values.images }}
{{- if .overrides.registration_operator }}
{{- printf "%s" .overrides.registration_operator }}
{{- else }}
{{- printf "%s/registration-operator:%s" .registry .tag }}
{{- end }}
{{- end }}
{{- end }}

{{- define "hypershift_addon_operator" }}
{{- with .Values.images }}
{{- if .overrides.hypershift_addon_operator }}
{{- printf "%s" .overrides.hypershift_addon_operator }}
{{- else }}
{{- printf "%s/hypershift-addon-operator:%s" .registry .tag }}
{{- end }}
{{- end }}
{{- end }}

{{- define "managedcluster_import_controller" }}
{{- with .Values.images }}
{{- if .overrides.managedcluster_import_controller }}
{{- printf "%s" .overrides.managedcluster_import_controller }}
{{- else }}
{{- printf "%s/managedcluster-import-controller:%s" .registry .tag }}
{{- end }}
{{- end }}
{{- end }}

{{- define "multicloud_manager" }}
{{- with .Values.images }}
{{- if .overrides.multicloud_manager }}
{{- printf "%s" .overrides.multicloud_manager }}
{{- else }}
{{- printf "%s/multicloud-manager:%s" .registry .tag }}
{{- end }}
{{- end }}
{{- end }}

{{- define "work" }}
{{- with .Values.images }}
{{- if .overrides.work }}
{{- printf "%s" .overrides.work }}
{{- else }}
{{- printf "%s/work:%s" .registry .tag }}
{{- end }}
{{- end }}
{{- end }}

{{- define "registration" }}
{{- with .Values.images }}
{{- if .overrides.registration }}
{{- printf "%s" .overrides.registration }}
{{- else }}
{{- printf "%s/registration:%s" .registry .tag }}
{{- end }}
{{- end }}
{{- end }}

{{- define "placement" }}
{{- with .Values.images }}
{{- if .overrides.placement }}
{{- printf "%s" .overrides.placement }}
{{- else }}
{{- printf "%s/placement:%s" .registry .tag }}
{{- end }}
{{- end }}
{{- end }}

{{- define "addon_manager" }}
{{- with .Values.images }}
{{- if .overrides.addon_manager }}
{{- printf "%s" .overrides.addon_manager }}
{{- else }}
{{- printf "%s/addon-manager:%s" .registry .tag }}
{{- end }}
{{- end }}
{{- end }}

{{- define "kube_rbac_proxy_mce" }}
{{- with .Values.images }}
{{- if .overrides.kube_rbac_proxy_mce }}
{{- printf "%s" .overrides.kube_rbac_proxy_mce }}
{{- else }}
{{- printf "%s/kube-rbac-proxy-mce:%s" .registry .tag }}
{{- end }}
{{- end }}
{{- end }}
