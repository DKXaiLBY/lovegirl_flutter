# LoveGirl 外部输入收集表

更新时间：2026-07-17
适用阶段：进入实现阶段后，准备真机验收与正式发布前使用

## 1. 文档目的

这份文档把后续还需要你提供、确认或最终定板的外部信息，集中整理成一张可填写的表。

它不是新的方案，而是把这些问题从“散落在文档里”变成“可逐项补齐的输入包”。

## 2. 当前仓库中已能直接确认的信息

以下内容来自当前仓库证据，已经可以先记下来：

### Android / App 基本信息

- App 名称：`LoveGirl`
- Flutter 包名工程名：`lovegirl_flutter`
- Android `applicationId`：`com.lovegirl.lovegirl_flutter`
- Android `namespace`：`com.lovegirl.lovegirl_flutter`
- 当前 `pubspec.yaml` 版本：`3.22.0+150`

证据来源：

- `D:/lovegirl_flutter/pubspec.yaml`
- `D:/lovegirl_flutter/android/app/build.gradle`

### 当前 Manifest 中可见的高德 Android Key

当前仓库 `AndroidManifest.xml` 里可见：

- `com.amap.api.v2.apikey = 2209d350da6804c16673f5c36d52f64b`

说明：

- 这只是“当前仓库里写着的值”
- 不代表它已经和最终 release 签名、正式发布环境完全匹配

证据来源：

- `D:/lovegirl_flutter/android/app/src/main/AndroidManifest.xml`

### 当前 Release 签名状态

当前 `android/app/build.gradle` 里仍然写着：

- `release` 使用 `signingConfigs.debug`

说明：

- 这意味着正式发布签名信息目前还没有在工程里稳定接入
- 后续发布前必须改成正式签名方案

## 3. 你后续需要补齐的外部输入

下面这些项，后续实现可以先推进，但到真机验收或发布前一定要补齐。

## 3.1 高德相关

### A. Android 地图 SDK Key

- 用途：真地图显示
- 当前仓库已有值：`2209d350da6804c16673f5c36d52f64b`
- 是否确认可用于正式发布：`待确认`
- 对应包名：`com.lovegirl.lovegirl_flutter`
- 对应 debug SHA1：`待补`
- 对应 release SHA1：`待补`

### B. Android 导航 SDK Key

- 用途：原生导航
- 当前状态：`待补`
- 是否本轮一定接入真实导航：`待确认`

### C. 高德 Web 服务 Key

- 用途：POI / 地理编码 / 路线 / 天气
- 当前状态：`待补`
- 后续放置位置：`服务器 .env`

## 3.2 Android 签名与发布

### A. Debug SHA1

- 当前状态：`待补`

### B. Release SHA1

- 当前状态：`待补`

### C. Release 签名文件位置

- 当前状态：`待补`

### D. Release 签名别名 / 密码管理方式

- 当前状态：`待补`

说明：

- 这些值不需要写进公开文档正文
- 但至少要确认“是否已准备好、存放在哪、谁来接入”

## 3.3 服务器与部署

### A. 线上后端实际部署目录

- 当前已知背景：`47.121.119.191`
- 实际部署目录：`待确认`

### B. 线上 APK 静态资源目录

- 当前状态：`待确认`

### C. 版本接口最终读取的 APK 下载地址

- 当前状态：`待确认`

### D. 服务器 `.env` 是否已具备这些变量

- 数据库连接：`待确认`
- JWT / 认证密钥：`待确认`
- 高德 Web 服务 Key：`待确认`
- CORS 来源：`待确认`
- 上传路径：`待确认`

## 3.4 真机验收

### A. 可用 Android 真机

- 当前状态：`待确认`

### B. 真机是否可安装调试包

- 当前状态：`待确认`

### C. 真机主要验收人

- 当前状态：`待确认`

## 3.5 发布信息

### A. 下一次正式发布版本号

- 当前仓库版本：`3.22.0+150`
- 下一次正式发布版本：`待确认`

### B. 更新链路目标

- 是否需要 App 内检测并更新：`是（已确认目标）`
- 最终下载地址：`待确认`

## 4. 推荐填写格式

后续如果需要快速收集这些信息，建议按下面格式补齐：

```text
Android 地图 SDK Key:
Android 导航 SDK Key:
高德 Web 服务 Key:
debug SHA1:
release SHA1:
release 签名文件位置:
线上后端部署目录:
APK 静态资源目录:
版本接口下载地址:
真机型号:
下一次发布版本号:
```

## 5. 哪些项不补也能先开工

这些可以先不补：

- 导航 SDK Key
- 最终下载地址
- 发布版本号
- 真机型号细节

因为前期可以先做：

- 基线清理
- 设计系统
- 核心页面重构
- Provider / Service 拆分

## 6. 哪些项不补会直接卡住后面

这些如果不补，会在关键节点卡住：

- release SHA1
- 正式签名方案
- 高德 Web 服务 Key
- 线上部署目录
- APK 下载地址
- 真机设备

## 7. 当前阶段结论

这份文档的意义不是让你现在立刻去补所有值，而是：

- 后续一旦需要真机或发布
- 我们可以直接按这张表追缺口

这样比临时到处翻文档省事很多。
