# PowerShell Floci Deployment Script for Patient-Management
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Host "=== Floci Deployment Script for Patient-Management ===" -ForegroundColor Cyan

# 1. Check if Docker is running
try {
    docker info | Out-Null
} catch {
    Write-Error "Docker daemon is not running. Please start Docker Desktop first."
    exit 1
}

# Ensure user-defined internal Docker network exists
$networkExists = docker network ls -q -f "name=^internal$"
if (-not $networkExists) {
    Write-Host "Creating Docker network 'internal'..." -ForegroundColor Yellow
    docker network create internal | Out-Null
}

# 2. Check / Start Floci AWS Emulator Container
$flociContainer = "floci"
$running = docker ps -q -f "name=^/${flociContainer}$"
$exists = docker ps -aq -f "name=^/${flociContainer}$"

if ($running) {
    Write-Host "Floci container is already running." -ForegroundColor Green
} elseif ($exists) {
    Write-Host "Starting existing Floci container..." -ForegroundColor Yellow
    docker start $flociContainer | Out-Null
} else {
    Write-Host "Starting new Floci container on 'internal' network with project grouping label..." -ForegroundColor Yellow
    docker run -d --name $flociContainer `
        --label "com.docker.compose.project=patient-management" `
        -p 127.0.0.1:4566:4566 `
        -v /var/run/docker.sock:/var/run/docker.sock `
        -e FLOCI_SERVICES_DOCKER_NETWORK=internal `
        --network internal `
        floci/floci:latest | Out-Null
}

# 3. Wait for Floci to be ready
Write-Host "Waiting for Floci emulator to be healthy..." -ForegroundColor Cyan
$maxWait = 30
$count = 0
do {
    $status = (docker inspect -f "{{.State.Health.Status}}" $flociContainer 2>$null)
    if ($status -eq "healthy") { break }
    Start-Sleep -Seconds 1
    $count++
} while ($count -lt $maxWait)

Write-Host "Floci is ready!" -ForegroundColor Green

# 4. Set AWS credentials for Floci emulator
$env:AWS_ACCESS_KEY_ID = "test"
$env:AWS_SECRET_ACCESS_KEY = "test"
$env:AWS_DEFAULT_REGION = "us-east-1"
$env:AWS_ENDPOINT_URL = "http://localhost:4566"

# 5. Provision dedicated Floci MSK Kafka Cluster
Write-Host "Checking Floci MSK Kafka cluster..." -ForegroundColor Cyan
$mskArn = aws --endpoint-url=http://localhost:4566 --region us-east-1 kafka list-clusters --query "ClusterInfoList[?ClusterName=='kafka-cluster'].ClusterArn" --output text 2>$null
if (-not $mskArn -or $mskArn -eq "None") {
    Write-Host "Creating dedicated Floci MSK Kafka cluster..." -ForegroundColor Yellow
    $brokerJsonPath = "$env:TEMP\msk-broker-info.json"
    '{"InstanceType":"kafka.m5.xlarge","ClientSubnets":["subnet-12345678"]}' | Set-Content -Path $brokerJsonPath
    aws --endpoint-url=http://localhost:4566 --region us-east-1 kafka create-cluster `
        --cluster-name "kafka-cluster" `
        --broker-node-group-info "file://$brokerJsonPath" `
        --kafka-version "2.8.0" `
        --number-of-broker-nodes 1 | Out-Null
    Start-Sleep -Seconds 3
}

# Alias & rename MSK container to end with -kafka-cluster
$mskContainers = docker ps -q --filter "label=io.floci.service=msk"
foreach ($cid in $mskContainers) {
    try {
        $info = docker inspect $cid | ConvertFrom-Json
        $cname = $info.Name.TrimStart('/')
        docker network connect --alias kafka-cluster --alias kafka internal $cid 2>$null
        if ($cname -notlike "*-kafka-cluster*") {
            $newName = "$cname-kafka-cluster"
            Write-Host "Renaming MSK container $cname -> $newName" -ForegroundColor Cyan
            docker rename $cname $newName 2>$null
        }
    } catch {}
}

# 6. Resolve CloudFormation template file
$templateFile = "$PSScriptRoot\infrastructure\cdk.out\localstack.template.json"
if (-not (Test-Path $templateFile)) {
    $templateFile = "$PSScriptRoot\infrastructure\cdk.out\localstask.template.json"
}

if (-not (Test-Path $templateFile)) {
    Write-Host "Template not found. Synthesizing CDK stack in infrastructure..." -ForegroundColor Yellow
    Push-Location "$PSScriptRoot\infrastructure"
    mvn compile exec:java "-Dexec.mainClass=com.pm.stack.LocalStack"
    Pop-Location
    $templateFile = "$PSScriptRoot\infrastructure\cdk.out\localstack.template.json"
}

Write-Host "Using CloudFormation template: $templateFile" -ForegroundColor Cyan

# 7. Deploy CloudFormation Stack to Floci
$stackName = "patient-management"
Write-Host "Deploying stack '$stackName' to Floci emulator..." -ForegroundColor Yellow

aws --endpoint-url=http://localhost:4566 --region us-east-1 cloudformation deploy `
    --stack-name $stackName `
    --template-file $templateFile

Write-Host "=== Deployment Successful ===" -ForegroundColor Green

# 8. Rename RDS database containers to include their names at the end
Write-Host "Giving names to RDS database containers at the end..." -ForegroundColor Yellow
$rdsContainers = docker ps -q --filter "label=io.floci.service=rds"
foreach ($cid in $rdsContainers) {
    try {
        $info = docker inspect $cid | ConvertFrom-Json
        $cname = $info.Name.TrimStart('/')
        $resId = $info.Config.Labels.'io.floci.resource-id'
        if ($resId -and ($cname -notlike "*$resId*")) {
            $newName = "$cname-$resId"
            Write-Host "Renaming $cname -> $newName" -ForegroundColor Cyan
            docker rename $cname $newName 2>$null
        }
    } catch {}
}

# 9. Print Load Balancer & Service Endpoints
$albDns = aws --endpoint-url=http://localhost:4566 --region us-east-1 elbv2 describe-load-balancers `
    --query "LoadBalancers[0].DNSName" --output text 2>$null

Write-Host "Application Load Balancer DNS: $albDns" -ForegroundColor Green
Write-Host "Endpoint URL: http://localhost:4566 (Host: $albDns)" -ForegroundColor Cyan
Write-Host "MSK Kafka Cluster: kafka-cluster:9092 (Floci MSK)" -ForegroundColor Green
