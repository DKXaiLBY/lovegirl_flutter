@echo off
cd /d "D:\lovegirl_build"
set "JAVA_HOME=C:\Program Files\Java\jdk-17.0.3.1"
set "FLUTTER_ROOT=D:\SoftwarePrograms\dev\flutter-sdk"
set "ANDROID_HOME=D:\SoftwarePrograms\dev\android-sdk"
set "PATH=%FLUTTER_ROOT%\bin;%ANDROID_HOME%\platform-tools;%PATH%"
"D:\SoftwarePrograms\dev\flutter-sdk\bin\flutter.bat" build apk --release %*
