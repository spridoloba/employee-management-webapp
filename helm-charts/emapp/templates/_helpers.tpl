{{/*
Expand the name of the chart.
*/}}
{{- define "emapp.name" -}}
{{- default .Chart.Name .Values.app.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a fully qualified app name (release + chart).
*/}}
{{- define "emapp.fullname" -}}
{{- if .Values.app.fullnameOverride -}}
{{- .Values.app.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.app.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Chart label value.
*/}}
{{- define "emapp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Standard labels applied to every resource.
*/}}
{{- define "emapp.labels" -}}
helm.sh/chart: {{ include "emapp.chart" . }}
{{ include "emapp.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.app.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: emapp
{{- end -}}

{{/*
Selector labels — narrow set used in Service/Deployment selectors.
*/}}
{{- define "emapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "emapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Name of the ServiceAccount.
*/}}
{{- define "emapp.serviceAccountName" -}}
{{- if .Values.app.serviceAccount.create -}}
{{- default (include "emapp.fullname" .) .Values.app.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.app.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Name of the Secret that holds DB credentials. In dev it's created by this
chart; in prod it's materialised by the sealed-secrets controller — the
reference is the same so the Deployment envFrom doesn't have to branch.
*/}}
{{- define "emapp.secretName" -}}
{{- default (printf "%s-secret" (include "emapp.fullname" .)) .Values.app.config.mysql.secretName -}}
{{- end -}}

{{/*
Image reference with sensible fallback to Chart.AppVersion.
*/}}
{{- define "emapp.image" -}}
{{- $tag := default .Chart.AppVersion .Values.app.image.tag -}}
{{- printf "%s:%s" .Values.app.image.repository $tag -}}
{{- end -}}
