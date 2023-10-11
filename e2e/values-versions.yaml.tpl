kibana:
  enabled: true

managementPod:
  enabled: true

# Add the function server
extraDeploy:
  - apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: function-server
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: function-server
      template:
        metadata:
          labels:
            app: function-server
        spec:
          imagePullSecrets:
          - name: "registry-token"
          containers:
          - name: function-server
            image: 485790562880.dkr.ecr.us-east-2.amazonaws.com/akamas/tests/function-server:1.1.0
            env:
            - name: AWS_REGION
              value: us-east-2
          restartPolicy: Always
  - apiVersion: v1
    kind: Service
    metadata:
      name: function-server
    spec:
      selector:
        app: function-server
      ports:
      - name: ssh
        port: 22
        targetPort: 22
      type: ClusterIP