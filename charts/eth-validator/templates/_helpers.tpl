{{/*
Expand the name of the chart.
*/}}
{{- define "eth-validator.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Naming contract: <release>-eth-validator
*/}}
{{- define "eth-validator.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-eth-validator" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "eth-validator.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "eth-validator.labels" -}}
helm.sh/chart: {{ include "eth-validator.chart" . }}
{{ include "eth-validator.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "eth-validator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "eth-validator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Geth specific labels
*/}}
{{- define "eth-validator.geth.labels" -}}
{{ include "eth-validator.labels" . }}
app.kubernetes.io/component: execution
{{- end }}

{{- define "eth-validator.geth.selectorLabels" -}}
{{ include "eth-validator.selectorLabels" . }}
app.kubernetes.io/component: execution
{{- end }}

{{/*
Lighthouse Beacon specific labels
*/}}
{{- define "eth-validator.beacon.labels" -}}
{{ include "eth-validator.labels" . }}
app.kubernetes.io/component: consensus
{{- end }}

{{- define "eth-validator.beacon.selectorLabels" -}}
{{ include "eth-validator.selectorLabels" . }}
app.kubernetes.io/component: consensus
{{- end }}

{{/*
Lighthouse Validator specific labels
*/}}
{{- define "eth-validator.validator.labels" -}}
{{ include "eth-validator.labels" . }}
app.kubernetes.io/component: validator
{{- end }}

{{- define "eth-validator.validator.selectorLabels" -}}
{{ include "eth-validator.selectorLabels" . }}
app.kubernetes.io/component: validator
{{- end }}

{{/*
Return the storage class
*/}}
{{- define "eth-validator.storageClass" -}}
{{- $storageClass := .storageClass -}}
{{- if .global -}}
{{- $storageClass = default .global.storageClass .storageClass -}}
{{- end -}}
{{- if $storageClass -}}
storageClassName: {{ $storageClass | quote }}
{{- end -}}
{{- end }}

{{/*
Geth name
*/}}
{{- define "eth-validator.geth.fullname" -}}
{{- printf "%s-geth" (include "eth-validator.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Beacon name
*/}}
{{- define "eth-validator.beacon.fullname" -}}
{{- printf "%s-beacon" (include "eth-validator.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Validator name
*/}}
{{- define "eth-validator.validator.fullname" -}}
{{- printf "%s-validator" (include "eth-validator.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Image pull secrets
*/}}
{{- define "eth-validator.imagePullSecrets" -}}
{{- if .Values.imagePullSecrets }}
imagePullSecrets:
{{- range .Values.imagePullSecrets }}
  - name: {{ . }}
{{- end }}
{{- end }}
{{- end }}
