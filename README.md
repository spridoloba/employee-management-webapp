# Employee Management Web App Infrastructure

This repository demonstrates the infrastructure created for the **Employee Management application** (fork) and provides complete instructions.

The project is structured in stages to gradually build a full DevOps environment.

---

# Table of Contents

- [Prerequisites](#prerequisites)
- [Docker](#docker)
  - [Build Application Manually](#build-application-manually)
  - [Dockerfile Explanation](#dockerfile-explanation)
  - [Build Docker Image](#build-docker-image)
  - [Run Container](#run-container)
- [Docker Compose](#docker-compose)
  - [Start the Stack](#start-the-stack)
  - [Check Services](#check-services)
  - [Stop and Clean Environment](#stop-and-clean-environment)
- [Kubernetes](#kubernetes)
  - [Cluster Setup](#cluster-setup)
  - [Namespaces](#namespaces)
  - [Configuration Management](#configuration-management)
  - [Persistent Storage](#persistent-storage)
  - [Database Deployment](#database-deployment)
  - [Application Deployment](#application-deployment)
  - [Services](#services)
  - [Horizontal Pod Autoscaling](#horizontal-pod-autoscaling)
- [Helm](#helm)
  - [What is Helm](#what-is-helm)
  - [Local Testing with Kind](#local-testing-with-kind)
  - [Install Kind](#install-kind)
  - [Create Kubernetes Cluster](#create-kubernetes-cluster)
  - [Deploy the Application with Helm](#deploy-the-application-with-helm)
  - [Access the Application](#access-the-application)
  - [Cleanup](#cleanup)
- [Terraform](#terraform)
  - [Initialize and Apply](#initialize-and-apply)
  - [Key Variables](#key-variables)
  - [Destroy](#destroy)
- [Deploying to AKS with Helm](#deploying-to-aks-with-helm)
  - [Connect kubectl to AKS](#connect-kubectl-to-aks)
  - [Deploy MySQL and the Application](#deploy-mysql-and-the-application)
  - [Access the Application on AKS](#access-the-application-on-aks)

---

# Prerequisites

The following tools must be installed before following any section of this guide:

| Tool | Purpose | Required For |
|---|---|---|
| [Docker](https://docs.docker.com/get-docker/) | Container runtime | All sections |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Kubernetes CLI | Kubernetes, Helm |
| [Kind](https://kind.sigs.k8s.io/) | Local Kubernetes cluster | Kubernetes, Helm (Kind) |
| [Helm](https://helm.sh/docs/intro/install/) | Kubernetes package manager | Helm |
| [Azure CLI (`az`)](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) | Azure resource management | Terraform / AKS |
| [Terraform](https://developer.hashicorp.com/terraform/install) | Infrastructure provisioning | Terraform / AKS |

> **AKS authentication:** Before running any Terraform commands, authenticate with Azure:
> ```bash
> az login
> ```

---

# Docker

This stage explains how the application is packaged into a Docker image using a **multi-stage build**.

The Dockerfile compiles the Spring Boot application with Maven and then runs the resulting `.jar` file inside a lightweight Java runtime container.

---

## Build Application Manually

You can build and run the application locally without Docker.

Build the project:

```bash
mvn clean package -DskipTests
```

After the build completes, the generated `.jar` file will appear in:

```
target/employee-management-webapp-0.0.1-SNAPSHOT.jar
```

Run the application manually:

```bash
java -jar target/employee-management-webapp-0.0.1-SNAPSHOT.jar
```

The application will start on `http://localhost:8080`.

However, for this to work, the MySQL server must be running. The application reads its configuration from `src/main/resources/application.properties`, which expects values from `.env`. It is highly recommended to start locally via Docker Compose instead (see below).

---

## Dockerfile Explanation

The project uses a **multi-stage Docker build** to reduce the final image size.

### Stage 1 — Build

The first stage uses a Maven image to compile the application.

```dockerfile
FROM maven:3.9.12-eclipse-temurin-17-alpine AS build
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn -DskipTests package
```

- `FROM maven:3.9.12-eclipse-temurin-17-alpine` — Maven + Java 17 image used for building the application.
- `WORKDIR /build` — sets the working directory inside the container.
- `COPY pom.xml .` and `COPY src ./src` — copies project files into the container.
- `RUN mvn -DskipTests package` — compiles the application and produces a `.jar` file.

### Stage 2 — Runtime

The second stage runs the compiled application inside a lightweight Java runtime container.

```dockerfile
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=build /build/target/*.jar /app/app.jar
CMD ["java", "-jar", "/app/app.jar"]
```

- `FROM eclipse-temurin:21-jre-alpine` — lightweight Java runtime image.
- `WORKDIR /app` — working directory for the runtime container.
- `COPY --from=build` — copies the built `.jar` file from the previous build stage.
- `CMD` — command used to start the application.

---

## Build Docker Image

Build the Docker image:

```bash
docker build -t employee-management-app .
```

Check available images:

```bash
docker images
```

---

## Run Container

The application depends on a **MySQL database**, therefore running the container alone is not recommended.

This repository includes a **Docker Compose configuration** that starts both the application and the MySQL database together. It is intended **only for running the application locally on your machine in order to explore and test the functionality**.

The application configuration (`application.properties`) expects environment variables such as database credentials and ports. These values are provided through a `.env` file, which already contains default values for local testing.

All configuration used by Docker Compose is stored in `.env`. Docker Compose reads this file automatically and injects the variables into the containers.

Docker Compose in this repository is used **only for local testing and demonstration** of the application. In a real deployment scenario, the infrastructure is defined using **Kubernetes manifests** (see the Kubernetes section below).

---

# Docker Compose

Before you begin, you can change the settings for the application in the `.env` file, such as the application port, database names, and so on.

Docker Compose is used to run the application together with a **MySQL database** for local testing.

The stack includes:

- **app** — Spring Boot application
- **db** — MySQL 8.4 database
- **mysql_data** — Docker volume used for persistent database storage

---

## Start the Stack

Build and start the environment:

```bash
docker compose up --build
```

Run in background:

```bash
docker compose up -d --build
```

---

## Check Services

List running services:

```bash
docker compose ps
```

View logs:

```bash
docker compose logs
```

Application logs:

```bash
docker compose logs app
```

Database logs:

```bash
docker compose logs db
```

Open the application in a browser:

```
http://localhost:8080
```

---

## Stop and Clean Environment

Stop all services:

```bash
docker compose down
```

Stop and remove volumes (reset the database):

```bash
docker compose down -v
```

List Docker volumes:

```bash
docker volume ls
```

The MySQL database stores data inside the following volume:

```
mysql_data
```

Removing this volume will delete all stored database data.

---

# Kubernetes

This stage demonstrates how the application is deployed into a Kubernetes cluster.

The infrastructure is defined using Kubernetes manifests and includes:

- Namespaces
- ConfigMaps
- Secrets
- Persistent Volumes
- StatefulSets
- Deployments
- Services
- Horizontal Pod Autoscaler

The setup separates the **application** and **database** into different namespaces and provides persistent storage for MySQL.

> **Note:** The manifests in `k8s/app/` cover the **application side only** (Deployment, Service, HPA, Secret).
> The MySQL-side resources (Namespace, PersistentVolume, PersistentVolumeClaim, StatefulSet, Services, ConfigMap) are described below for reference but are **not included as standalone files** in this repository.
> For a complete, runnable deployment use the **Helm** section, which packages and manages all these resources automatically.

---

## Cluster Setup

A local Kubernetes cluster is created using **Kind (Kubernetes in Docker)**.

The cluster configuration defines two nodes:

- **Control Plane**
- **Worker Node**

The worker node mounts a host directory to store MySQL data, allowing the database to persist data even if the pod is recreated.

---

## Namespaces

Two namespaces are used to logically separate components:

- **mysql** — contains the database resources
- **emapp** — contains the application resources

This separation helps organize the cluster and isolate services.

---

## Configuration Management

Application configuration is managed using ConfigMaps and Secrets.

### ConfigMap

Used for non-sensitive configuration values such as:

- application port
- runtime configuration values

### Secrets

Used for sensitive data such as:

- database username
- database password
- database name
- root password

Secrets are injected into containers as environment variables.

The application secret is defined in `k8s/app/secretsapp.yaml`. All values must be **base64-encoded** before being placed in the manifest.

Encode a value:

```bash
echo -n "your-value" | base64
```

The secret expects the following keys:

| Key | Description |
|---|---|
| `database_username` | MySQL username the application uses to connect |
| `database_password` | Password for the above user |
| `database_root_password` | MySQL root password |
| `database_name` | Name of the MySQL database |

Fill in all four values in `k8s/app/secretsapp.yaml` before applying the manifest.

---

## Persistent Storage

To ensure MySQL data persists between pod restarts, the project uses:

- **PersistentVolume (PV)**
- **PersistentVolumeClaim (PVC)**

The PV maps a directory from the host machine to the cluster, while the PVC allows the MySQL pod to request and use that storage.

---

## Database Deployment

MySQL runs inside a **StatefulSet**.

StatefulSets are used instead of Deployments because databases require:

- stable network identity
- persistent storage
- predictable pod naming

A **Headless Service** is used so the StatefulSet can manage the MySQL pod network identity.

An additional **ClusterIP Service** provides internal cluster access to MySQL.

---

## Application Deployment

The Spring Boot application runs in a **Deployment**.

The container image is pulled from Docker Hub and configured using environment variables provided by:

- ConfigMaps
- Secrets

The application connects to MySQL through the internal Kubernetes service.

---

## Services

Two service types are used:

### ClusterIP

Used for **internal communication** inside the cluster.

Example: MySQL service accessible only from other pods.

### NodePort

Used to expose the application externally.

The application becomes accessible via:

```
http://localhost:30080
```

---

## Horizontal Pod Autoscaling

A **Horizontal Pod Autoscaler (HPA)** configuration is included as an example.

It automatically scales the application pods based on:

- CPU usage
- Memory usage

Example scaling policy:

- Minimum pods: 1
- Maximum pods: 5

> **Note:** HPA requires the **Kubernetes Metrics Server** to be installed.

**Kind** does not include Metrics Server by default. Install it on a Kind cluster with:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Kind uses self-signed TLS certificates, so patch the deployment to allow insecure kubelet connections:

```bash
kubectl patch deployment metrics-server -n kube-system \
  --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

> **AKS** ships with Metrics Server pre-installed — no additional steps are needed.

---

# Helm

## What is Helm

Helm is a **package manager for Kubernetes**. It allows you to define, install and manage Kubernetes applications using **Helm Charts**.

Configuration values for the Spring Boot application are stored in `helm-charts/emapp/values.yaml`, which allows you to customize deployments without modifying the manifests themselves. Configuration values for MySQL are stored in `helm-charts/sqlvalues.yaml`.

---

## Local Testing with Kind

For local testing this project uses **Kind (Kubernetes IN Docker)**.

Kind allows running a full Kubernetes cluster locally using Docker containers.

---

## Install Kind

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

Verify installation:

```bash
kind --version
```

---

## Create Kubernetes Cluster

The cluster configuration is located in the repository at `k8s/cluster.yaml`.

The worker node mounts `/home/kind-storage/mysql` from the host machine to provide persistent MySQL storage. **This directory must exist before creating the cluster**, otherwise the worker node will fail to start:

```bash
sudo mkdir -p /home/kind-storage/mysql
```

Create the cluster using the configuration file:

```bash
kind create cluster --config ./k8s/cluster.yaml
```

This will create a Kubernetes cluster consisting of:

- **1 control-plane node**
- **1 worker node**

---

## Deploy the Application with Helm

Run the following commands from the `./helm-charts` directory.

### Install MySQL

Add the Bitnami Helm repository:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

Install MySQL with your credentials. Make sure the username and database name match those in `emapp/values.yaml`:

```bash
helm install mysql bitnami/mysql \
  --set auth.rootPassword=rootpassword \
  --set auth.username=user \
  --set auth.password=apppassword \
  --set auth.database=mysql \
  -n emapp \
  --create-namespace \
  -f sqlvalues.yaml
```

### Install the Application

Before installing, open `helm-charts/emapp/values.yaml` and fill in the credentials under `config.mysql` to match what you passed to the MySQL install command:

```yaml
config:
  mysql:
    databaseUsername: "user"     # must match --set auth.username
    databaseName: "mysql"        # must match --set auth.database
```

The application reads `databaseUsername` and `databaseName` directly from `values.yaml`. The password is read automatically from the Kubernetes secret that the Bitnami MySQL chart creates (`mysql` / `mysql-password`).

```bash
helm install emapp ./emapp/ -n emapp
```

Resource requests and limits are specified in `values.yaml`. By default they are empty and not applied. Example:

```yaml
resources:
  requests:
    cpu:
    memory:
  limits:
    memory:
```

---

## Access the Application

The application is exposed using **NodePort 30080**.

However, when using **Kind**, NodePort is not always easily accessible from the host machine. It is recommended to use **port forwarding** instead:

```bash
kubectl port-forward service/emapp-service 8080:8080 -n emapp
```

After running the command, the application will be available at:

```
http://localhost:8080
```

---

## Cleanup

Check all running pods:

```bash
kubectl get pods -A
```

Check services:

```bash
kubectl get svc -A
```

Check Helm releases:

```bash
helm list -A
```

Delete the charts:

```bash
helm uninstall mysql -n emapp
helm uninstall emapp -n emapp
```

---

# Terraform

The `terraform/` directory provisions the Azure infrastructure for this project using Terraform.

**What it creates:**

- Azure Resource Group
- AKS cluster with a dedicated system node pool (kube-system workloads only) and a worker node pool (application workloads)

Azure fully manages the Kubernetes control plane (API server, etcd).

---

## Initialize and Apply

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values, then:

```bash
terraform init
terraform plan
terraform apply
```

**Connect kubectl after apply:**

```bash
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw cluster_name)
```

---

## Key Variables

Set these in `terraform.tfvars`:

| Variable | Description | Default |
|---|---|---|
| `subscription_id` | **Required.** Your Azure Subscription ID | — |
| `resource_group_name` | Resource group to create | `emapp-rg` |
| `cluster_name` | AKS cluster name | `emapp-aks` |
| `location` | Azure region | `East US` |
| `kubernetes_version` | Must be LTS (`1.27`, `1.30`, `1.31`) | `1.31` |
| `worker_node_vm_size` | VM size for application nodes | `Standard_DC2s_v3` |
| `worker_node_count` | Number of worker nodes | `1` |

> `terraform.tfvars` is git-ignored — never commit it.

---

## Destroy

```bash
terraform destroy
```

Deletes all resources including the resource group. PVC data will be lost.

---

# Deploying to AKS with Helm

After provisioning the AKS cluster with Terraform, connect `kubectl` to it and then run the same Helm commands from the [Helm](#helm) section.

---

## Connect kubectl to AKS

```bash
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw cluster_name)
```

Verify the connection:

```bash
kubectl get nodes
```

---

## Deploy MySQL and the Application

Run the Helm commands from the [Install MySQL](#install-mysql) and [Install the Application](#install-the-application) sections exactly as written — they work on both Kind and AKS.

---

## Access the Application on AKS

On AKS, **NodePort services are not reachable from outside the cluster** without additional configuration. Use one of the following methods:

### Option 1 — Port forwarding (for testing)

```bash
kubectl port-forward service/emapp-service 8080:8080 -n emapp
```

Application is available at:

```
http://localhost:8080
```

### Option 2 — LoadBalancer service (recommended)

Change `serviceType` in `helm-charts/emapp/values.yaml`:

```yaml
serviceType: LoadBalancer
```

Upgrade the release:

```bash
helm upgrade emapp ./emapp/ -n emapp
```

Wait for the external IP to be assigned by Azure:

```bash
kubectl get svc emapp-service -n emapp --watch
```

Once `EXTERNAL-IP` is populated, the application is available at:

```
http://<EXTERNAL-IP>:8080
```

### Option 3 — Ingress (advanced)

The Helm chart includes an Ingress template. Enable it in `helm-charts/emapp/values.yaml`:

```yaml
ingress:
  enabled: true
  host: "your-domain.example.com"
  className: nginx
```

You must also install an Ingress Controller (e.g., NGINX) separately before enabling Ingress.
