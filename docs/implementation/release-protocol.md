# LoveGirl 发布规程

2026-10-23 用户已长期授权：更新完成且验证通过后，直接发布新版本到现有服务器，供手机内更新。无需逐次询问发布意愿；用户当次明确说不发布时，以当次指令为准。

旧指南引用的本地 lovegirl-deploy-protocol 记忆在当前环境未找到。本文件依据交接文档和线上发布接口重新核验，作为当前仓库的发布依据。

## 凭据

- DEPLOY_TOKEN 只能由服务器上的发布进程从 lovegirl-server 容器环境读取，并直接进入请求头。
- 禁止把令牌输出到聊天、命令输出、日志、临时文件或仓库；禁止输出容器全部环境变量。
- 客户端构建不带测试自动登录参数；不嵌入账号密码。

## 流程

1. 核对线上 app_versions 最大版本码，递增版本。同步 pubspec.yaml 与 AppConstants 的名称和版本码，编写中文 changelog。
2. 跑 analyze、Flutter 测试和相关服务端测试；如本次真机条件缺失，明确记录模拟器与真机的验证边界，不伪报真实双账号联调。
3. 使用项目指定 Java/Flutter SDK，以 lib/main.dart 构建 release APK。
4. 提交、推送代码并保留版本 tag；更新默认分支时先核对远端变化，禁止强推覆盖。
5. APK 备份至 /opt/love-girl/apk-backups/v<版本>.apk，再准备发布用副本。
6. 宿主机接口为 http://127.0.0.1:3001/api/deploy/publish；实际 Docker 映射是宿主机 3001 → 容器 3000。发布进程在容器内执行时使用容器实际监听端口（当前 PORT 未设置，默认 3000），不能使用宿主机端口。上传字段 apk；版本字段 version_name / version_code；变更字段 changelog；大小字段 file_size；默认不强制更新。线上 multer 上限 100MB。
7. 令牌仅在容器内参与请求。容器没有 curl 时，使用 Node 原生 http + 文件流构造 multipart，避免打印请求头或令牌。
8. 发布后核对并显式修正 app_versions.version_name、changelog、file_size 和 md5。可使用容器内 mysql2 参数化更新，中文发布元数据通过 UTF-8/Base64 传入，换行用 SQL CHAR(10) 拼接；也可用 UTF-8 SQL 文件/标准输入执行。不要从 Windows shell 直传未编码的中文 SQL。
9. 验证旧版检查 hasUpdate=true，新版本检查 hasUpdate=false；版本、变更文案与下载大小正确；下载 APK 的散列与构建产物一致。

## 回滚

- 保留前一版本 APK、发布前版本记录和源码 tag。
- 回滚时恢复上一 APK 并切换 app_versions 激活记录，随后重新验证下载与版本检查。
- 本次旅行照片服务端迁移向后兼容。回退客户端时保留安全移除引用的服务端逻辑；不要让旧删除逻辑把引用的相册原图删掉。
