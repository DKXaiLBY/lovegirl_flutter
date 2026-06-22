FROM gradle:7.6-jdk11 AS builder
WORKDIR /workspace
# copy entire repo to allow gradle wrapper and dependencies
COPY . /workspace
WORKDIR /workspace/android
RUN chmod +x ./gradlew || true
# assemble all Android modules (release builds). Adjust or change tasks as needed.
RUN ./gradlew assembleRelease -x lint --no-daemon || ./gradlew assembleDebug --no-daemon

FROM alpine:3.18 AS output
RUN mkdir -p /out
# copy APK artifacts (may vary depending on build variant)
COPY --from=builder /workspace/android/app/build/outputs/apk/release/ /out/

LABEL org.opencontainers.image.source="lovegirl-flutter/android"
