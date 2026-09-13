#with maven and jdk 25
FROM maven:3-eclipse-temurin-25 AS builder

WORKDIR /app

COPY pom.xml .

RUN mvn dependency:go-offline -B

COPY src ./src

RUN mvn clean package

FROM eclipse-temurin:25-jdk AS runner

WORKDIR /app

COPY --from=builder ./app/target/patient-service-1.0.jar ./app.jar

EXPOSE 4000

ENTRYPOINT ["java", "-jar", "app.jar"]