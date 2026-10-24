#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Starting Floci & Deploying Patient-Management ==="

# 1. Ensure Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker daemon is not running. Please start Docker Desktop."
    exit 1
fi

# 2. Ensure internal network exists
if ! docker network ls -q -f "name=^internal$" | grep -q .; then
    echo "Creating Docker network 'internal'..."
    docker network create internal >/dev/null
fi

# 3. Start Floci container with port 80 (for ALB) and 4566 (for AWS API)
if [ -z "$(docker ps -q -f name=^/floci$)" ]; then
    if [ "$(docker ps -aq -f name=^/floci$)" ]; then
        docker rm -f floci >/dev/null 2>&1 || true
    fi
    echo "Starting Floci emulator container..."
    docker run -d --name floci \
        --label "com.docker.compose.project=patient-management" \
        -p 127.0.0.1:4566:4566 \
        -p 80:80 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -e FLOCI_SERVICES_DOCKER_NETWORK=internal \
        --network internal \
        floci/floci:latest >/dev/null
fi

# 4. Wait for Floci to be healthy
echo "Waiting for Floci emulator to be healthy..."
until [ "$(docker inspect -f '{{.State.Health.Status}}' floci 2>/dev/null)" = "healthy" ]; do
    sleep 1
done

export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_ENDPOINT_URL="http://localhost:4566"

# 5. Ensure MSK Kafka Cluster is running
MSK_ARN=$(aws --endpoint-url=http://localhost:4566 --region us-east-1 kafka list-clusters --query "ClusterInfoList[?ClusterName=='kafka-cluster'].ClusterArn" --output text 2>/dev/null || true)
if [ -z "$MSK_ARN" ] || [ "$MSK_ARN" = "None" ]; then
    echo "Creating Floci MSK Kafka cluster..."
    aws --endpoint-url=http://localhost:4566 --region us-east-1 kafka create-cluster \
        --cluster-name "kafka-cluster" \
        --broker-node-group-info '{"InstanceType":"kafka.m5.xlarge","ClientSubnets":["subnet-12345678"]}' \
        --kafka-version "2.8.0" \
        --number-of-broker-nodes 1 >/dev/null
    sleep 3
fi

# Alias & rename MSK container to end with -kafka-cluster
for cid in $(docker ps -q --filter "label=io.floci.service=msk"); do
    cname=$(docker inspect "$cid" --format '{{.Name}}' | sed 's|^/||')
    docker network connect --alias kafka-cluster --alias kafka internal "$cid" 2>/dev/null || true
    if [[ "$cname" != *"kafka-cluster"* ]]; then
        docker rename "$cname" "${cname}-kafka-cluster" 2>/dev/null || true
    fi
done

# 6. Deploy CloudFormation Stack
TEMPLATE_FILE="./cdk.out/localstack.template.json"
echo "Deploying CloudFormation stack..."
aws --endpoint-url=http://localhost:4566 --region us-east-1 cloudformation deploy \
    --stack-name patient-management \
    --template-file "$TEMPLATE_FILE"

# 7. Rename DB containers to end with their names
for cid in $(docker ps -q --filter "label=io.floci.service=rds"); do
    cname=$(docker inspect "$cid" --format '{{.Name}}' | sed 's|^/||')
    res_id=$(docker inspect "$cid" --format '{{json .Config.Labels}}' | sed -n 's/.*"io.floci.resource-id":"\([^"]*\)".*/\1/p')
    if [ -n "$res_id" ] && [[ "$cname" != *"$res_id"* ]]; then
        docker rename "$cname" "${cname}-${res_id}" 2>/dev/null || true
    fi
done

# 8. Print Application Load Balancer endpoint
ALB_DNS=$(aws --endpoint-url=http://localhost:4566 --region us-east-1 elbv2 describe-load-balancers \
    --query "LoadBalancers[0].DNSName" --output text 2>/dev/null | tr -d '\r\n')

echo ""
echo "=== Containers Started Successfully! ==="
echo "Application Load Balancer DNS: $ALB_DNS"
echo ""
echo "Send HTTP requests to (Port 80):"
echo "POST http://${ALB_DNS}/auth/login"
