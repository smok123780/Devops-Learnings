#!/bin/bash
set -o errexit  # make your script exit when a command fails
set -o pipefail # to exit when the status of the last command that threw a non-zero exit code is returned
set -o nounset  # to exit when your script tries to use undeclared variables
set -o xtrace   # to trace what gets executed. Useful for debugging

# This script is used to setup the GCP project

# Variables
PROJECT_ID="directed-curve-490918-v8"
REGION="europe-central2"
ZONE="$REGION-a"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_INIT_FILE="${SQL_INIT_FILE:-$SCRIPT_DIR/sql/javaapp_init.sql}"
CPU_ALERT_POLICY_FILE="${CPU_ALERT_POLICY_FILE:-$SCRIPT_DIR/cpu-alert-policy.json}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-password}"
OPS_EMAIL="${OPS_EMAIL:-smok123780@gmail.com}"
SQL_IMPORT_BUCKET="${SQL_IMPORT_BUCKET:-${PROJECT_ID}-sql-import}"
ARTIFACT_REPOSITORY="${ARTIFACT_REPOSITORY:-maven-releases}"

echo "Setting active project and enabling required APIs"
# gcloud config set project "$PROJECT_ID"
gcloud services enable \
  compute.googleapis.com \
  sqladmin.googleapis.com \
  servicenetworking.googleapis.com \
  monitoring.googleapis.com \
  logging.googleapis.com \
  iam.googleapis.com \
  artifactregistry.googleapis.com \
  --project="$PROJECT_ID"

### VPC and Networking
## VPC Creation
# Create a primary VPC
echo "Creating primary VPC"
gcloud compute networks create primary-vpc \
  --subnet-mode=custom \
  --project="$PROJECT_ID"

# Create a secondary VPC
echo "Creating secondary VPC"
gcloud compute networks create secondary-vpc \
  --subnet-mode=custom \
  --project="$PROJECT_ID"

## Subnet Configuration
# Create public subnet
echo "Creating public subnet"
gcloud compute networks subnets create public-subnet-1 \
  --network=primary-vpc \
  --range=192.168.1.0/24 \
  --region="$REGION" \
  --project="$PROJECT_ID"

# Create private subnet
echo "Creating private subnet"
gcloud compute networks subnets create private-subnet-1 \
  --network=primary-vpc \
  --range=192.168.2.0/24 \
  --region="$REGION" \
  --project="$PROJECT_ID"

## Gateway Setup
# Create Cloud Router
echo "Creating Cloud Router"
gcloud compute routers create primary-router \
  --network=primary-vpc \
  --region="$REGION" \
  --project="$PROJECT_ID"

## Security Configuration
# Firewall Rules
echo "Creating firewall rules"
gcloud compute firewall-rules create allow-http-https \
  --network=primary-vpc \
  --allow=tcp:80,tcp:443 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=frontend \
  --project="$PROJECT_ID"

# Allow backend traffic from frontend
echo "Allowing backend traffic from frontend"
gcloud compute firewall-rules create allow-backend-8080 \
  --network=primary-vpc \
  --allow=tcp:8080 \
  --source-tags=frontend \
  --target-tags=backend \
  --project="$PROJECT_ID"

## IAM Roles and Policies
echo "Ensuring app service account exists"
gcloud iam service-accounts create app-sa \
  --project="$PROJECT_ID"

gcloud iam service-accounts create sql-sa --project="$PROJECT_ID"

echo "Adding IAM policy binding"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:app-sa@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:sql-sa@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

## Database Layer
# Create Cloud SQL Instance
echo "Configuring Private Service Access for Cloud SQL"
gcloud compute addresses create google-managed-services-primary-vpc \
  --global \
  --purpose=VPC_PEERING \
  --prefix-length=16 \
  --network=primary-vpc \
  --project="$PROJECT_ID"

gcloud services vpc-peerings connect \
  --service=servicenetworking.googleapis.com \
  --ranges=google-managed-services-primary-vpc \
  --network=primary-vpc \
  --project="$PROJECT_ID"

gcloud services vpc-peerings update \
  --service=servicenetworking.googleapis.com \
  --ranges=google-managed-services-primary-vpc \
  --network=primary-vpc \
  --project="$PROJECT_ID"

echo "Creating Cloud SQL Instance"
gcloud sql instances create prod-mysql \
  --database-version=MYSQL_8_0 \
  --tier=db-custom-2-7680 \
  --region="$REGION" \
  --availability-type=regional \
  --enable-bin-log \
  --storage-size=20GB \
  --storage-type=SSD \
  --network="projects/$PROJECT_ID/global/networks/primary-vpc" \
  --no-assign-ip \
  --project="$PROJECT_ID"

gcloud sql users set-password root \
  --host='%' \
  --instance=prod-mysql \
  --project="$PROJECT_ID" \
  --password="$DB_ROOT_PASSWORD"

# Database Initialization
echo "Initializing database"
gcloud sql databases create javaapp \
  --instance=prod-mysql \
  --project="$PROJECT_ID"

echo "Applying schema to javaapp database"
if [[ ! -f "$SQL_INIT_FILE" ]]; then
  echo "SQL initialization file not found: $SQL_INIT_FILE"
  exit 1
fi

SQL_IMPORT_SA="$(gcloud sql instances describe prod-mysql \
  --project="$PROJECT_ID" \
  --format='value(serviceAccountEmailAddress)')"

gcloud storage buckets create "gs://${SQL_IMPORT_BUCKET}" \
  --project="$PROJECT_ID" \
  --location="$REGION"
gcloud storage buckets add-iam-policy-binding "gs://${SQL_IMPORT_BUCKET}" \
  --member="serviceAccount:${SQL_IMPORT_SA}" \
  --role="roles/storage.objectViewer"

SQL_IMPORT_OBJECT="gs://${SQL_IMPORT_BUCKET}/javaapp_init.sql"
gcloud storage cp "$SQL_INIT_FILE" "$SQL_IMPORT_OBJECT"
gcloud sql import sql prod-mysql "$SQL_IMPORT_OBJECT" \
  --project="$PROJECT_ID" \
  --database=javaapp \
  --quiet

## Application Configuration and Build
echo "Building Java application"
gcloud artifacts repositories create "$ARTIFACT_REPOSITORY" \
  --project="$PROJECT_ID" \
  --location="$REGION" \
  --repository-format=maven \
  --description="Maven repository for Java-Login-App"

sh "${SCRIPT_DIR}/build_app.sh"

## Load Balancing and Auto Scaling
# Backend tier (Tomcat) + internal load balancer
BACKEND_TEMPLATE_NAME="backend-template"
BACKEND_MIG_NAME="backend-mig"
BACKEND_HEALTH_CHECK_NAME="backend-tcp-hc"
BACKEND_SERVICE_NAME="backend-ilb-service"
BACKEND_FORWARDING_RULE_NAME="backend-ilb-fr"
BACKEND_ILB_IP_NAME="backend-ilb-ip"
BACKEND_ILB_IP="${BACKEND_ILB_IP:-192.168.2.10}"

gcloud compute instance-templates create "$BACKEND_TEMPLATE_NAME" \
  --project="$PROJECT_ID" \
  --machine-type=e2-micro \
  --tags=backend \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --network-interface=network=primary-vpc,subnet=projects/$PROJECT_ID/regions/$REGION/subnetworks/private-subnet-1,no-address \
  --metadata-from-file startup-script="${SCRIPT_DIR}/setup_tomcat.sh"

gcloud compute instance-groups managed create "$BACKEND_MIG_NAME" \
  --project="$PROJECT_ID" \
  --template="$BACKEND_TEMPLATE_NAME" \
  --size=2 \
  --zone="$ZONE"

gcloud compute instance-groups managed set-named-ports "$BACKEND_MIG_NAME" \
  --project="$PROJECT_ID" \
  --zone="$ZONE" \
  --named-ports=http:8080

gcloud compute health-checks create tcp "$BACKEND_HEALTH_CHECK_NAME" \
  --project="$PROJECT_ID" \
  --global \
  --port=8080

gcloud compute backend-services create "$BACKEND_SERVICE_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --load-balancing-scheme=INTERNAL \
  --protocol=TCP \
  --health-checks="$BACKEND_HEALTH_CHECK_NAME"

gcloud compute backend-services add-backend "$BACKEND_SERVICE_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --instance-group="$BACKEND_MIG_NAME" \
  --instance-group-zone="$ZONE"

gcloud compute addresses create "$BACKEND_ILB_IP_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --subnet=private-subnet-1 \
  --addresses="$BACKEND_ILB_IP"

gcloud compute forwarding-rules create "$BACKEND_FORWARDING_RULE_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --load-balancing-scheme=INTERNAL \
  --network=primary-vpc \
  --subnet=private-subnet-1 \
  --address="$BACKEND_ILB_IP" \
  --ip-protocol=TCP \
  --ports=8080 \
  --backend-service="$BACKEND_SERVICE_NAME" \
  --backend-service-region="$REGION"

# Frontend tier template/MIG (Nginx)
WEB_SERVER_TEMPLATE_NAME="webserver-template"
gcloud compute instance-templates create "$WEB_SERVER_TEMPLATE_NAME" \
  --project="$PROJECT_ID" \
  --machine-type=e2-micro \
  --tags=frontend \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --network-interface=network=primary-vpc,subnet=projects/$PROJECT_ID/regions/$REGION/subnetworks/public-subnet-1 \
  --metadata=BACKEND_UPSTREAM="${BACKEND_ILB_IP}:8080" \
  --metadata-from-file startup-script="${SCRIPT_DIR}/vm_startup_script.sh"

# Managed Instance Group
gcloud compute instance-groups managed create webserver-mig \
  --project="$PROJECT_ID" \
  --template="$WEB_SERVER_TEMPLATE_NAME" \
  --size=2 \
  --zone="$ZONE"

gcloud compute instance-groups managed set-named-ports webserver-mig \
  --project="$PROJECT_ID" \
  --zone="$ZONE" \
  --named-ports=http:80

# Health check
gcloud compute health-checks create http webserver-hc \
  --project="$PROJECT_ID" \
  --global \
  --port=80 \
  --request-path=/ \
  --check-interval=30s \
  --timeout=10s \
  --healthy-threshold=2 \
  --unhealthy-threshold=3

# MIG autohealing policy
gcloud compute instance-groups managed update webserver-mig \
  --project="$PROJECT_ID" \
  --zone="$ZONE" \
  --health-check="projects/$PROJECT_ID/global/healthChecks/webserver-hc" \
  --initial-delay=300

# Backend service (target group equivalent)
gcloud compute backend-services create webserver-backend-service \
  --project="$PROJECT_ID" \
  --global \
  --protocol=HTTP \
  --port-name=http \
  --health-checks=webserver-hc \
  --timeout=30s

gcloud compute backend-services add-backend webserver-backend-service \
  --project="$PROJECT_ID" \
  --global \
  --instance-group=webserver-mig \
  --instance-group-zone="$ZONE" \
  --balancing-mode=UTILIZATION \
  --max-utilization=0.8

gcloud compute instance-groups managed set-autoscaling webserver-mig \
  --project="$PROJECT_ID" \
  --zone="$ZONE" \
  --min-num-replicas=2 \
  --max-num-replicas=6 \
  --target-cpu-utilization=0.6

## Cloud Monitoring
# Metrics
# Create email channel
gcloud beta monitoring channels create \
  --project="$PROJECT_ID" \
  --display-name="Ops Email" \
  --type=email \
  --channel-labels=email_address="$OPS_EMAIL"

# Capture existing/new channel resource name
CHANNEL_NAME="$(gcloud beta monitoring channels list \
  --project="$PROJECT_ID" \
  --filter='displayName="Ops Email" AND type="email"' \
  --format='value(name)' | head -n 1)"

# Create policy using that channel
gcloud beta monitoring policies create \
  --project="$PROJECT_ID" \
  --notification-channels="${CHANNEL_NAME}" \
  --policy-from-file="$CPU_ALERT_POLICY_FILE"

## Log Management
# Read recent application logs from Compute Engine
gcloud logging read 'resource.type="gce_instance" AND textPayload:"tomcat"' \
  --project="$PROJECT_ID" \
  --limit=50
