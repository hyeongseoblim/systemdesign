# ── build stage ──
FROM gradle:9-jdk25 AS build
WORKDIR /app
# 의존성 캐시 레이어
COPY build.gradle.kts settings.gradle.kts ./
RUN gradle dependencies --no-daemon > /dev/null 2>&1 || true
# 소스 복사 후 빌드
COPY src ./src
RUN gradle bootJar --no-daemon

# ── runtime stage ──
FROM eclipse-temurin:25-jre
WORKDIR /app
COPY --from=build /app/build/libs/*.jar app.jar
EXPOSE 8080
# 컨테이너 메모리에 맞춘 JVM 기본값. Cloud Run·Docker Compose에서 필요하면 덮어쓴다.
# MaxRAMPercentage는 컨테이너 한도 기준이므로 배포 메모리와 함께 조정한다.
ENV JAVA_OPTS="-XX:MaxRAMPercentage=60 -XX:+UseSerialGC -Xss512k -XX:MaxMetaspaceSize=128m"
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
