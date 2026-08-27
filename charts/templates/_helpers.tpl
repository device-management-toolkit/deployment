{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "installServersChart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "installServersChart.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "installServersChart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "installServersChart.labels" -}}
helm.sh/chart: {{ include "installServersChart.chart" . }}
{{ include "installServersChart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "installServersChart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "installServersChart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Public host[:port] that browser clients use to reach the gateway.
Falls back to the Console common name so charts that predate gateway.publicUrl
keep working, and fails with a clear message when neither is set.
*/}}
{{- define "installServersChart.publicUrl" -}}
{{- $url := default .Values.console.commonName .Values.gateway.publicUrl -}}
{{- required "Set gateway.publicUrl (or console.commonName) when webui.enabled is true" $url -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "installServersChart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "installServersChart.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}
