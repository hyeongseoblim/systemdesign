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
# Cloud Run 1GiB 인스턴스용 힙. 남는 메모리는 JVM 메타스페이스/네이티브 버퍼에 사용한다.
ENV JAVA_TOOL_OPTIONS="-Xms128m -Xmx640m -XX:+ExitOnOutOfMemoryError"
ENTRYPOINT ["java", "-jar", "app.jar"]
