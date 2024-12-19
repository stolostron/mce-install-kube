
{{/* Create secret to access docker registry */}}
{{- define "imagePullSecret" }}
{{- with .Values.images }}
{{- if and .imageCredentials.userName .imageCredentials.password }}
{{- printf "{\"auths\": {\"%s\": {\"auth\": \"%s\"}}}" .imageCredentials.registry (printf "%s:%s" .imageCredentials.userName .imageCredentials.password | b64enc) | b64enc }}
{{- else if .imageCredentials.dockerConfigJson }}
{{- printf "%s" .imageCredentials.dockerConfigJson | b64enc }}
{{- else }}
{{- printf "{}" | b64enc }}
{{- end }}
{{- end }}
{{- end }}


{{- define "backplaneOperatorImage" }}
{{- if and .Values.images.registry .Values.images.tag }}
{{- printf "%s/backplane-rhel9-operator:%s" .Values.images.registry .Values.images.tag }}
{{- else }}
{{- printf "%s" .Values.images.overrides.backplane_operator }}
{{- end }}
{{- end }}

{{- define "registrationOperatorImage" }}
{{- if and .Values.images.registry .Values.images.tag }}
{{- printf "%s/registration-operator-rhel9:%s" .Values.images.registry  .Values.images.tag }}
{{- else }}
{{- printf "%s" .Values.images.overrides.registration_operator }}
{{- end }}
{{- end }}

{{- define "hypershiftAddonOperatorImage" }}
{{- if and .Values.images.registry .Values.images.tag }}
{{- printf "%s/hypershift-addon-rhel9-operator:%s" .Values.images.registry  .Values.images.tag }}
{{- else }}
{{- printf "%s" .Values.images.overrides.hypershift_addon_operator }}
{{- end }}
{{- end }}

{{- define "hypershiftOperatorImage" }}
{{- if and .Values.images.registry .Values.images.tag }}
{{- printf "%s/hypershift-rhel9-operator:%s" .Values.images.registry  .Values.images.tag }}
{{- else }}
{{- printf "%s" .Values.images.overrides.hypershift_operator }}
{{- end }}
{{- end }}

{{- define "managedclusterImportControllerImage" }}
{{- if and .Values.images.registry .Values.images.tag }}
{{- printf "%s/managedcluster-import-controller-rhel9:%s" .Values.images.registry .Values.images.tag }}
{{- else }}
{{- printf "%s" .Values.images.overrides.managedcluster_import_controller }}
{{- end }}
{{- end }}

{{- define "multicloudManagerImage" }}
{{- if and .Values.images.registry .Values.images.tag }}
{{- printf "%s/multicloud-manager-rhel9:%s" .Values.images.registry .Values.images.tag }}
{{- else }}
{{- printf "%s" .Values.images.overrides.multicloud_manager }}
{{- end }}
{{- end }}

{{- define "addonManagerImage" }}
{{- if and .Values.images.registry .Values.images.tag }}
{{- printf "%s/addon-manager-rhel9:%s" .Values.images.registry .Values.images.tag }}
{{- else }}
{{- printf "%s" .Values.images.overrides.addon_manager }}
{{- end }}
{{- end }}

{{- define "workImage" }}
{{- if and .Values.images.registry .Values.images.tag }}
{{- printf "%s/work-rhel9:%s" .Values.images.registry .Values.images.tag }}
{{- else }}
{{- printf "%s" .Values.images.overrides.work }}
{{- end }}
{{- end }}

{{- define "registrationImage" }}
{{- if and .Values.images.registry .Values.images.tag }}
{{- printf "%s/registration-rhel9:%s" .Values.images.registry .Values.images.tag }}
{{- else }}
{{- printf "%s" .Values.images.overrides.registration }}
{{- end }}
{{- end }}

{{- define "placementImage" }}
{{- if and .Values.images.registry .Values.images.tag }}
{{- printf "%s/placement-rhel9:%s" .Values.images.registry .Values.images.tag }}
{{- else }}
{{- printf "%s" .Values.images.overrides.placement }}
{{- end }}
{{- end }}

{{- define "kubeRbacProxyMceImage" }}
{{- if and .Values.images.registry .Values.images.tag }}
{{- printf "%s/kube-rbac-proxy-mce-rhel9:%s" .Values.images.registry .Values.images.tag }}
{{- else }}
{{- printf "%s" .Values.images.overrides.kube_rbac_proxy_mce }}
{{- end }}
{{- end }}

{{- define "clusterlifecycleStateMetricsImage" }}
{{- if and .Values.images.registry .Values.images.tag }}
{{- printf "%s/clusterlifecycle-state-metrics-rhel9:%s" .Values.images.registry .Values.images.tag }}
{{- else }}
{{- printf "%s" .Values.images.overrides.clusterlifecycle_state_metrics }}
{{- end }}
{{- end }}
