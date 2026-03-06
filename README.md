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

## Dockerfile Explanation

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

## Build Docker Image

Build the Docker image:

``` bash
docker build -t employee-management-app .
```

Check available images:

``` bash
docker images
```

------------------------------------------------------------------------

## Run Container

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

# Docker Compose

Before you begin, you can change the settings for the application in the .env file, such as the application port, database names, and so on.

Docker Compose is used to run the application together with a **MySQL
database** for local testing.

The stack includes:

-   **app** --- Spring Boot application
-   **db** --- MySQL 8.4 database
-   **mysql_data** --- Docker volume used for persistent database
    storage

------------------------------------------------------------------------

## Start the Stack

Build and start the environment:

``` bash
docker compose up --build
```

Run in background:

``` bash
docker compose up -d --build
```

------------------------------------------------------------------------

## Check Services

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

## Stop and Clean Environment

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
