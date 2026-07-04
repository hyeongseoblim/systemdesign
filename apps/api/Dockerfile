# ── build stage ──
FROM gradle:8.10-jdk21 AS build
WORKDIR /app
# 의존성 캐시 레이어
COPY build.gradle.kts settings.gradle.kts ./
RUN gradle dependencies --no-daemon > /dev/null 2>&1 || true
# 소스 복사 후 빌드
COPY src ./src
RUN gradle bootJar --no-daemon

# ── runtime stage ──
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/build/libs/*.jar app.jar
EXPOSE 8080
# 컨테이너 메모리에 맞춘 JVM 힙 (Oracle A1.Flex 여유롭지만 보수적으로)
ENV JAVA_OPTS="-XX:MaxRAMPercentage=70"
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
