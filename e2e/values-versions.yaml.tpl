toolbox:
  enabled: true
  sshPassword:
    enabled: true
  persistence:
    storageClass: gp3

airflow: {enabled: false}
analyzer: {enabled: false}
campaign: {enabled: false}
curator: {enabled: false}
elasticsearch: {replicas: 0}
initializer: {enabled: false}
keycloak: {enabled: false}
kibana: {enabled: false}
kong: {enabled: false}
license: {enabled: false}
log: {enabled: false}
logstash: {enabled: false}
metrics: {enabled: false}
optimizer: {enabled: false}
orchestrator: {enabled: false}
store: {enabled: false}
system: {enabled: false}
telemetry: {enabled: false}
ui: {enabled: false}
users: {enabled: false}

postgresql:
  primary:
    resources:
      limits:
        cpu: "100m"
        memory: "100Mi"
      requests:
        cpu: "100m"
        memory: "100Mi"
