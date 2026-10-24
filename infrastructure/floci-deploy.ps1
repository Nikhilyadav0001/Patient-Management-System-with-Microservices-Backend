# PowerShell Infrastructure Deployment Script for Floci
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Set-Location $PSScriptRoot

Write-Host "=== Starting Floci & Deploying Patient-Management ===" -ForegroundColor Cyan

# 1. Ensure Docker is running
try {
    docker info | Out-Null
} catch {
    Write-Error "Docker daemon is not running. Please start Docker Desktop."
    exit 1
}

# 2. Ensure internal network exists
$networkExists = docker network ls -q -f "name=^internal$"
if (-not $networkExists) {
    Write-Host "Creating Docker network 'internal'..." -ForegroundColor Yellow
    docker network create internal | Out-Null
}

# 3. Start standalone Floci container with port 80 (ALB) and 4566 (AWS API)
$flociContainer = "floci"
$running = docker ps -q -f "name=^/${flociContainer}$"
if (-not $running) {
    if (docker ps -aq -f "name=^/${flociContainer}$") {
        docker rm -f $flociContainer | Out-Null
    }
    Write-Host "Starting Floci emulator container..." -ForegroundColor Yellow
    docker run -d --name $flociContainer `
        -p 127.0.0.1:4566:4566 `
        -p 80:80 `
        -v /var/run/docker.sock:/var/run/docker.sock `
        -e FLOCI_SERVICES_DOCKER_NETWORK=internal `
        --network internal `
        floci/floci:latest | Out-Null
}

# 4. Wait for Floci to be healthy
Write-Host "Waiting for Floci emulator to be healthy..." -ForegroundColor Cyan
do {
    Start-Sleep -Seconds 1
    $status = (docker inspect -f "{{.State.Health.Status}}" $flociContainer 2>$null)
} while ($status -ne "healthy")

$env:AWS_ACCESS_KEY_ID = "test"
$env:AWS_SECRET_ACCESS_KEY = "test"
$env:AWS_DEFAULT_REGION = "us-east-1"
$env:AWS_ENDPOINT_URL = "http://localhost:4566"

# 5. Ensure MSK Kafka Cluster is running
$mskArn = aws --endpoint-url=http://localhost:4566 --region us-east-1 kafka list-clusters --query "ClusterInfoList[?ClusterName=='kafka-cluster'].ClusterArn" --output text 2>$null
if (-not $mskArn -or $mskArn -eq "None") {
    Write-Host "Creating Floci MSK Kafka cluster..." -ForegroundColor Yellow
    $brokerJsonPath = "$env:TEMP\msk-broker.json"
    '{"InstanceType":"kafka.m5.xlarge","ClientSubnets":["subnet-12345678"]}' | Set-Content -Path $brokerJsonPath
    aws --endpoint-url=http://localhost:4566 --region us-east-1 kafka create-cluster `
        --cluster-name "kafka-cluster" `
        --broker-node-group-info "file://$brokerJsonPath" `
        --kafka-version "2.8.0" `
        --number-of-broker-nodes 1 | Out-Null
    Start-Sleep -Seconds 3
}

# Alias & rename MSK container
$mskContainers = docker ps -q --filter "label=io.floci.service=msk"
foreach ($cid in $mskContainers) {
    try {
        $info = docker inspect $cid | ConvertFrom-Json
        $cname = $info.Name.TrimStart('/')
        docker network connect --alias kafka-cluster --alias kafka internal $cid 2>$null
        if ($cname -notlike "*-kafka-cluster*") {
            docker rename $cname "$cname-kafka-cluster" 2>$null
        }
    } catch {}
}

# 6. Deploy CloudFormation Stack
$templateFile = "$PSScriptRoot\cdk.out\localstack.template.json"
Write-Host "Deploying CloudFormation stack..." -ForegroundColor Yellow
aws --endpoint-url=http://localhost:4566 --region us-east-1 cloudformation deploy `
    --stack-name patient-management `
    --template-file $templateFile

# 7. Rename DB containers
$rdsContainers = docker ps -q --filter "label=io.floci.service=rds"
foreach ($cid in $rdsContainers) {
    try {
        $info = docker inspect $cid | ConvertFrom-Json
        $cname = $info.Name.TrimStart('/')
        $resId = $info.Config.Labels.'io.floci.resource-id'
        if ($resId -and ($cname -notlike "*$resId*")) {
            docker rename $cname "$cname-$resId" 2>$null
        }
    } catch {}
}

# 8. Alias ECS task containers on internal network for inter-service communication
$ecsServices = @("auth-service", "patient-service", "billing-service", "analytics-service", "api-gateway")
foreach ($svc in $ecsServices) {
    $cid = (docker ps -q --filter "name=-${svc}Container" | Select-Object -First 1)
    if ($cid) {
        docker network disconnect internal $cid 2>$null
        docker network connect --alias $svc internal $cid 2>$null
    }
}

# 9. Print Application Load Balancer endpoint
$albDns = (aws --endpoint-url=http://localhost:4566 --region us-east-1 elbv2 describe-load-balancers `
    --query "LoadBalancers[0].DNSName" --output text 2>$null).Trim()

Write-Host ""
Write-Host "=== Containers Started Successfully! ===" -ForegroundColor Green
Write-Host "Application Load Balancer DNS: $albDns" -ForegroundColor Cyan
Write-Host ""
Write-Host "Send HTTP requests to (Port 80):" -ForegroundColor Yellow
Write-Host "POST http://$albDns/auth/login" -ForegroundColor Green
