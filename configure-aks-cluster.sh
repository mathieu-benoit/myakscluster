#Apply configs for Azure Monitor for Containers
kubectl apply -f container-azm-ms-agentconfig.yaml

#Install kured
kuredVersion=1.4.0
KURED_WEB_HOOK_URL=TO_REPLACE
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo update
helm install kured stable/kured \
            --version 1.5.0
            -n kured \
            --create-namespace \
            --set image.tag=$kuredVersion \
            --set nodeSelector."kubernetes\.io/os"=linux \
            --set extraArgs.start-time=9am \
            --set extraArgs.end-time=5pm \
            --set extraArgs.time-zone=America/Toronto \
            --set extraArgs.reboot-days="mon\,tue\,wed\,thu\,fri" \
            --set tolerations[0].effect=NoSchedule \
            --set tolerations[0].key=node-role.kubernetes.io/master \
            --set tolerations[1].operator=Exists \
            --set tolerations[1].key=CriticalAddonsOnly \
            --set tolerations[2].operator=Exists \
            --set tolerations[2].effect=NoExecute \
            --set tolerations[3].operator=Exists \
            --set tolerations[3].effect=NoSchedule \
            --set extraArgs.slack-hook-url=$KURED_WEB_HOOK_URL

# Install Azure Pipelines agent
AZP_TOKEN=REPLACE_ME
AZP_URL=https://dev.azure.com/REPLACE_ME
AZP_AGENT_NAME=REPLACE_ME
AZP_POOL=$AZP_AGENT_NAME

kubectl create ns ado-agent
kubectl create secret generic azp \
  -n ado-agent
  --from-literal=AZP_URL=$AZP_URL \
  --from-literal=AZP_TOKEN=$AZP_TOKEN \
  --from-literal=AZP_AGENT_NAME=$AZP_AGENT_NAME \
  --from-literal=AZP_POOL=$AZP_POOL
kubectl apply -n ado-agent -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ado-agent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ado-agent
  template:
    metadata:
      labels:
        app: ado-agent
    spec:
      containers:
      - name: ado-agent
        image: mabenoit/ado-agent:latest
        env:
          - name: AZP_URL
            valueFrom:
              secretKeyRef:
                name: azp
                key: AZP_URL
          - name: AZP_TOKEN
            valueFrom:
              secretKeyRef:
                name: azp
                key: AZP_TOKEN
          - name: AZP_AGENT_NAME
            valueFrom:
              secretKeyRef:
                name: azp
                key: AZP_AGENT_NAME
          - name: AZP_POOL
            valueFrom:
              secretKeyRef:
                name: azp
                key: AZP_POOL
        volumeMounts:
          - mountPath: /var/run/docker.sock
            name: docker-socket-volume
      volumes:
        - name: docker-socket-volume
          hostPath:
            path: /var/run/docker.sock
      nodeSelector:
        kubernetes.io/os: linux
        kubernetes.azure.com/mode: user
EOF
