#!/bin/bash
set -e # Stops the script if any command fails

aws --endpoint-url=http://localhost:4566 cloudformation delete-stack \
    --stack-name patient-management

aws --endpoint-url=http://localhost:4566 cloudformation deploy \
    --stack-name patient-management \
    --template-file "./cdk.out/localstack.template.json"

# Alias ECS task containers on internal network for direct container-to-container communication
for svc in auth-service patient-service billing-service analytics-service api-gateway; do
  cid=$(docker ps -q --filter "name=-${svc}Container" | head -n 1)
  if [ -n "$cid" ]; then
    docker network disconnect internal "$cid" 2>/dev/null || true
    docker network connect --alias "$svc" internal "$cid" 2>/dev/null || true
  fi
done

aws --endpoint-url=http://localhost:4566 elbv2 describe-load-balancers \
    --query "LoadBalancers[0].DNSName" --output text
