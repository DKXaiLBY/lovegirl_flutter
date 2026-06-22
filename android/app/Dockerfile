FROM gradle:7.6-jdk11 AS builder
WORKDIR /workspace
COPY . /workspace
WORKDIR /workspace/android
RUN chmod +x ./gradlew || true
# build only the app module
RUN ./gradlew :app:assembleRelease -x lint --no-daemon || ./gradlew :app:assembleDebug --no-daemon

FROM alpine:3.18 AS output
RUN mkdir -p /out
COPY --from=builder /workspace/android/app/build/outputs/apk/release/ /out/

LABEL org.opencontainers.image.source="lovegirl-flutter/android/app"
