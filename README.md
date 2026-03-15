# Employee Management Web App Infrastructure

This repository demonstrates the infrastructure created for the
**Employee Management application** (fork) and provides complete instructions.

The project is structured in stages to gradually build a full DevOps
environment.

------------------------------------------------------------------------

# Table of Contents

-   [Docker](#docker)
    -   [Build Application Manually](#build-application-manually)
    -   [Dockerfile Explanation](#dockerfile-explanation)
    -   [Build Docker Image](#build-docker-image)
    -   [Run Container](#run-container)
-   [Docker Compose](#docker-compose)
    -   [Start the Stack](#start-the-stack)
    -   [Check Services](#check-services)
    -   [Stop and Clean Environment](#stop-and-clean-environment)
-   [Kubernetes](#kubernetes)
    -   [Cluster Setup](#cluster-setup)
    -   [Namespaces](#namespaces)
    -   [Configuration Management](#configuration-management)
    -   [ConfigMap](#configmap)
    -   [Secrets](#secrets)
    -   [Persistent Storage](#persistent-storage)
    -   [Database Deployment](#database-deployment)
    -   [Application Deployment](#application-deployment)
    -   [Services](#services)
    -   [ClusterIP](#clusterip)
    -   [NodePort](#nodeport)
    -   [Horizontal Pod Autoscaling](#horizontal-pod-autoscaling)
-   [Helm](#helm)
    -   [What is Helm](#what-is-helm)
    -   [Local Testing with Kind](#local-testing-with-kind)
    -   [Install Kind](#install-kind)
    -   [Create Kubernetes Cluster](#create-kubernetes-cluster)
    -   [Deploy the Application with Helm](#deploy-the-application-with-helm)
    -   [Install MySQL](#install-mysql)
    -   [Install the Application](#install-the-application)
    -   [Access the Application](#access-the-application)
    -   [Cleanup](#cleanup)
------------------------------------------------------------------------

# Docker

This stage explains how the application is packaged into a Docker image
using a **multi-stage build**.

The Dockerfile compiles the Spring Boot application with Maven and then
runs the resulting `.jar` file inside a lightweight Java runtime
container.

------------------------------------------------------------------------

## Build Application Manually

You can build and run the application locally without Docker.

Build the project:

``` bash
mvn clean package -DskipTests
```

After the build completes, the generated `.jar` file will appear in:

    target/employee-management-webapp-0.0.1-SNAPSHOT.jar

Run the application manually:

``` bash
java -jar target/employee-management-webapp-0.0.1-SNAPSHOT.jar
```

The application will start on:

    http://localhost:8080

However, for this to work, the MySQL server must be running, env which the application accepts in:
src/main/resources/application.properties

If you have your own MySQL server, you can enter the data from it in application.properties, but this is not recommended, as the file now expects values from .env, so it is highly recommended to start locally via Docker Compose (See below).
------------------------------------------------------------------------

### Dockerfile Explanation

The project uses a **multi-stage Docker build** to reduce the final
image size.

### Stage 1 --- Build

The first stage uses a Maven image to compile the application.

``` dockerfile
FROM maven:3.9.12-eclipse-temurin-17-alpine AS build
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn -DskipTests package
```

Explanation:

-   `FROM maven:3.9.12-eclipse-temurin-17-alpine` --- Maven + Java 17
    image used for building the application.
-   `WORKDIR /build` --- sets the working directory inside the
    container.
-   `COPY pom.xml .` and `COPY src ./src` --- copies project files into
    the container.
-   `RUN mvn -DskipTests package` --- compiles the application and
    produces a `.jar` file.

------------------------------------------------------------------------

### Stage 2 --- Runtime

The second stage runs the compiled application inside a lightweight Java
runtime container.

``` dockerfile
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=build /build/target/*.jar /app/app.jar
CMD ["java", "-jar", "/app/app.jar"]
```

Explanation:

-   `FROM eclipse-temurin:21-jre-alpine` --- lightweight Java runtime
    image.
-   `WORKDIR /app` --- working directory for the runtime container.
-   `COPY --from=build` --- copies the built `.jar` file from the
    previous build stage.
-   `CMD` --- command used to start the application.

------------------------------------------------------------------------

### Build Docker Image

Build the Docker image:

``` bash
docker build -t employee-management-app .
```

Check available images:

``` bash
docker images
```

------------------------------------------------------------------------

### Run Container

The application depends on a **MySQL database**, therefore running the container alone is not recommended.

This repository includes a **Docker Compose configuration** that starts both the application and the MySQL database together.  
It is intended **only for running the application locally on your machine in order to explore and test the functionality**.

The application configuration (`application.properties`) expects environment variables such as database credentials and ports.  
These values are provided through a `.env` file, which already contains default values for local testing.

All configuration used by Docker Compose is stored in:

```
.env
```

Docker Compose reads this file automatically and injects the variables into the containers.

Docker Compose in this repository is used **only for local testing and demonstration** of the application.

In a real deployment scenario, the infrastructure is defined using **Kubernetes manifests** (You can find it below, in the Kubernetes thread).  

------------------------------------------------------------------------

## Docker Compose

Before you begin, you can change the settings for the application in the .env file, such as the application port, database names, and so on.

Docker Compose is used to run the application together with a **MySQL
database** for local testing.

The stack includes:

-   **app** --- Spring Boot application
-   **db** --- MySQL 8.4 database
-   **mysql_data** --- Docker volume used for persistent database
    storage

------------------------------------------------------------------------

### Start the Stack

Build and start the environment:

``` bash
docker compose up --build
```

Run in background:

``` bash
docker compose up -d --build
```

------------------------------------------------------------------------

### Check Services

List running services:

``` bash
docker compose ps
```

View logs:

``` bash
docker compose logs
```

Application logs:

``` bash
docker compose logs app
```

Database logs:

``` bash
docker compose logs db
```

Open the application in browser:

    http://localhost:8080

------------------------------------------------------------------------

### Stop and Clean Environment

Stop all services:

``` bash
docker compose down
```

Stop and remove volumes (reset the database):

``` bash
docker compose down -v
```

List Docker volumes:

``` bash
docker volume ls
```

The MySQL database stores data inside the following volume:

    mysql_data

Removing this volume will delete all stored database data.

------------------------------------------------------------------------

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

---

## Cluster Setup

A local Kubernetes cluster is created using **Kind (Kubernetes in Docker)**.

The cluster configuration defines two nodes:

- **Control Plane**
- **Worker Node**

The worker node mounts a host directory to store MySQL data, allowing the database to persist data even if the pod is recreated.

---

### Namespaces

Two namespaces are used to logically separate components:

- **mysql** – contains the database resources
- **emapp** – contains the application resources

This separation helps organize the cluster and isolate services.

---

### Configuration Management

Application configuration is managed using:

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

---

### Persistent Storage

To ensure MySQL data persists between pod restarts, the project uses:

- **PersistentVolume (PV)**
- **PersistentVolumeClaim (PVC)**

The PV maps a directory from the host machine to the cluster, while the PVC allows the MySQL pod to request and use that storage.

---

### Database Deployment

MySQL runs inside a **StatefulSet**.

StatefulSets are used instead of Deployments because databases require:

- stable network identity
- persistent storage
- predictable pod naming

A **Headless Service** is used so the StatefulSet can manage the MySQL pod network identity.

An additional **ClusterIP Service** provides internal cluster access to MySQL.

---

### Application Deployment

The Spring Boot application runs in a **Deployment**.

The container image is pulled from Docker Hub and configured using environment variables provided by:

- ConfigMaps
- Secrets

The application connects to MySQL through the internal Kubernetes service.

---

### Services

Two service types are used:

### ClusterIP

Used for **internal communication** inside the cluster.

Example:
- MySQL service accessible only from other pods.

### NodePort

Used to expose the application externally.

The application becomes accessible via:
http://localhost:30080

### Horizontal Pod Autoscaling

A **Horizontal Pod Autoscaler (HPA)** configuration is included as an EXAMPLE.

It automatically scales the application pods based on:

- CPU usage
- Memory usage

Example scaling policy:

- Minimum pods: 1
- Maximum pods: 5

Note: HPA requires the **Kubernetes Metrics Server** to be installed.

------------------------------------------------------------------------

# Helm

## What is Helm

Helm is a **package manager for Kubernetes**.\
It allows you to define, install and manage Kubernetes applications
using **Helm Charts**.

Configuration values for the Spring Boot application are stored in the `helm-charts/emapp/values.yaml` file, which allows you to customize deployments without modifying the manifests themselves. Similarly, configuration values for MySQL are stored in the `helm-charts/sqlvalues.yaml` file

------------------------------------------------------------------------

### Local Testing with Kind

For local testing this project uses **Kind (Kubernetes IN Docker)**.

Kind allows running a full Kubernetes cluster locally using Docker
containers.

------------------------------------------------------------------------

### Install Kind

``` bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

Verify installation:

``` bash
kind --version
```

------------------------------------------------------------------------

### Create Kubernetes Cluster

The cluster configuration is located in the repository:

    k8s/cluster.yaml

Create the cluster using the configuration file:

``` bash
kind create cluster --config ./k8s/cluster.yaml
```

This will create a Kubernetes cluster consisting of:

-   **1 control-plane node**
-   **1 worker node**

------------------------------------------------------------------------

## Deploy the Application with Helm

Run the following commands from the **./helm-charts directory**.

### Install MySQL

``` bash
helm repo add bitnami https://charts.bitnami.com/bitnami
```
``` bash
helm repo update
```
You need to enter the MySQL credentials in --set; see the example below (Make sure the username and database name match those in the emapp/values.yaml config section):  

``` bash
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

``` bash
helm install emapp ./emapp/ -n emapp
```

Deployment limits are specified in `values.yaml`; by default, they are not specified and are not applied. Here is an example of how to use them:
``` bash
resources:
    requests:
      cpu:
      memory:
    limits:
      memory:
```
------------------------------------------------------------------------

### Access the Application

The application is exposed using **NodePort 30080**.

However, when using **Kind**, NodePort is not always easily accessible
from the host machine.\
Therefore it is recommended to use **port forwarding**.

Run:

``` bash
kubectl port-forward service/emapp-service 8080:8080 -n emapp
```

After running the command, the application will be available at:

    http://localhost:8080

------------------------------------------------------------------------

### Cleanup

Check all running pods:

``` bash
kubectl get pods -A
```

Check services:

``` bash
kubectl get svc -A
```

Check Helm releases:

``` bash
helm list -A
```
Delete charts:

``` bash
helm uninstall mysql -n emapp
```

``` bash
helm uninstall emapp -n emapp
```