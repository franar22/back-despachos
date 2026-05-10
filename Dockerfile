# ═══════════════════════════════════════════════════════════════
# STAGE 1 — BUILD
# Compila el proyecto Spring Boot con Maven + JDK 17
# ═══════════════════════════════════════════════════════════════
FROM maven:3.9.6-eclipse-temurin-17-alpine AS builder

WORKDIR /app

# Copiar pom.xml primero → Docker cachea las dependencias por separado.
# Si solo cambia el código fuente, esta capa se reutiliza (ahorra tiempo).
COPY Springboot-API-REST-DESPACHO/pom.xml .
RUN mvn dependency:go-offline -B

# Copiar el código fuente
COPY Springboot-API-REST-DESPACHO/src ./src

# Compilar y empaquetar sin ejecutar tests
RUN mvn clean package -DskipTests -B

# ═══════════════════════════════════════════════════════════════
# STAGE 2 — RUNTIME
# Imagen final liviana: solo JRE Alpine (~180MB vs ~600MB con JDK)
# Sin Maven, sin código fuente, sin dependencias de compilación
# ═══════════════════════════════════════════════════════════════
FROM eclipse-temurin:17-jre-alpine

LABEL maintainer="innovatech-chile"
LABEL app="back-despachos"
LABEL version="1.0"

# Crear grupo y usuario sin privilegios root (seguridad: principio mínimo privilegio)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copiar solo el JAR compilado desde el stage builder
COPY --from=builder /app/target/*.jar app.jar

# Asignar propiedad al usuario no root
RUN chown appuser:appgroup app.jar

# Cambiar al usuario sin privilegios
USER appuser

# Puerto según application.properties: server.port=8081
EXPOSE 8081

# Health check: Docker/Compose detecta cuando la app está lista
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget -qO- http://localhost:8081/actuator/health || exit 1

# Opciones JVM optimizadas para contenedores:
# -XX:+UseContainerSupport → respeta los límites de CPU/RAM del contenedor
# -XX:MaxRAMPercentage=75.0 → usa hasta el 75% de la RAM asignada
# -Djava.security.egd → acelera el arranque en Linux
ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-jar", "app.jar"]
