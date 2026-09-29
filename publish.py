# 已弃用（2026-09-29 安全清理）
#
# 本脚本为早期本地一键发布脚本，已被服务器端发布流程取代：
# 现行发布方式 = flutter build apk --release
#             → POST /api/deploy/publish（服务器端脚本执行，令牌规程见本地记忆 lovegirl-deploy-protocol）
#             → 修正 app_versions 表
#
# 弃用原因：subprocess shell=True 命令注入 + 输出文件路径拼接（安全扫描 high）。
# 历史版本可在 git 历史/备份中找回。请勿恢复本文件——发布一律走现行流程。
print("此脚本已弃用：请使用服务器端发布流程（见 AGENTS.md / 本地记忆 lovegirl-deploy-protocol）")
