{{- define "rustfs.podTemplate" -}}
metadata:
  labels:
    {{- include "rustfs.selectorLabels" . | nindent 6 }}
    {{- with .Values.podLabels }}
    {{- toYaml . | nindent 6 }}
    {{- end }}
spec:
  enableServiceLinks: {{ .Values.enableServiceLinks }}
  {{- with include "rustfs.imagePullSecrets" . }}
  imagePullSecrets:
    {{- . | nindent 4 }}
  {{- end }}
  {{- if and .Values.nodeSelector (not .Values.affinity.nodeAffinity) }}
  nodeSelector:
    {{- toYaml .Values.nodeSelector | nindent 4 }}
  {{- end }}
  {{- if .Values.affinity }}
  affinity:
    nodeAffinity:
    {{- toYaml .Values.affinity.nodeAffinity | nindent 6 }}
    {{- if .Values.affinity.podAntiAffinity.enabled }}
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                  - {{ include "rustfs.name" . }}
          topologyKey: {{ .Values.affinity.podAntiAffinity.topologyKey }}
    {{- end }}
  {{- end }}
  {{- with .Values.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.podSecurityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.initContainers }}
  initContainers:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  containers:
    - name: rustfs
      image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
      imagePullPolicy: {{ .Values.image.pullPolicy }}
      {{- with .Values.containerSecurityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      ports:
        - name: endpoint
          containerPort: {{ .Values.service.endpoint.port }}
        - name: console
          containerPort: {{ .Values.service.console.port }}
      envFrom:
        - configMapRef:
            name: {{ include "rustfs.fullname" . }}-config
        - secretRef:
            name: {{ include "rustfs.secretName" . }}
      {{- with .Values.resources }}
      resources:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.livenessProbe }}
      livenessProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.readinessProbe }}
      readinessProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      volumeMounts:
        {{- if .Values.mtls.enabled }}
        {{- if not .Values.mtls.serverOnly }}
        - name: client-cert
          mountPath: /opt/tls/client_cert.pem
          subPath: client_cert.pem
        - name: client-cert
          mountPath: /opt/tls/client_key.pem
          subPath: client_key.pem
        - name: client-cert
          mountPath: /opt/tls/client_ca.crt
          subPath: client_ca.crt
        {{- end }}
        - name: server-cert
          mountPath: /opt/tls/rustfs_cert.pem
          subPath: rustfs_cert.pem
        - name: server-cert
          mountPath: /opt/tls/rustfs_key.pem
          subPath: rustfs_key.pem
        - name: server-cert
          mountPath: /opt/tls/ca.crt
          subPath: ca.crt
        {{- end }}
        {{- with .Values.persistence.logs }}
        - name: logs
          mountPath: {{- include "rustfs.obsLogDirectory" . }}
        {{- end }}
        {{- range $i, $vol :=  .Values.persistence.data }}
        - name: data-rustfs-disk-{{ $i }}
          mountPath: /data/rustfs{{ $i }}
        {{- end }}
  {{- if (include "rustfs.modeStandalone?" . ) }}
  volumes:
    {{- if .Values.persistence.logs }}
    - name: logs
      persistentVolumeClaim:
        claimName: {{ include "rustfs.standaloneLogsClaimName" . }}
    {{- end }}
    {{- if eq (len .Values.persistence.data) 1 }}
    - name: data-rustfs-disk-0
      persistentVolumeClaim:
        claimName: {{ include "rustfs.standaloneDataClaimName" . }}
    {{- else }}
      {{ fail "When mode.type is set to standalone, persistence.data must define only one volume" }}
    {{- end }}
  {{- else }}
  {{- if .Values.mtls.enabled }}
  volumes:
  {{- end }}
  {{- if .Values.mtls.enabled }}
    - name: server-cert
      secret:
        secretName: rustfs-server-tls
        items:
          - key: tls.crt
            path: rustfs_cert.pem
          - key: tls.key
            path: rustfs_key.pem
          - key: ca.crt
            path: ca.crt
    {{- if not .Values.mtls.serverOnly }}
    - name: client-cert
      secret:
        secretName: rustfs-client-tls
        items:
          - key: tls.crt
            path: client_cert.pem
          - key: tls.key
            path: client_key.pem
          - key: ca.crt
            path: client_ca.crt
    {{- end }}
  {{- end }}
  {{- end }}
{{- end }}
