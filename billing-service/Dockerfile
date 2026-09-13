# Build Stage
FROM maven:3-eclipse-temurin-25 AS builder

WORKDIR /app

# Copy Maven configuration
COPY pom.xml .

# Download dependencies first
RUN mvn dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the application
RUN mvn clean package -DskipTests

# Runtime
FROM eclipse-temurin:25-jdk AS runner

WORKDIR /app

# Copy generated JAR
COPY --from=builder /app/target/billing-service-0.0.1-SNAPSHOT.jar app.jar

EXPOSE 4001

EXPOSE 9001

# Start application
ENTRYPOINT ["java", "-jar", "app.jar"]