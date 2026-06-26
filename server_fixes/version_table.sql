-- LoveGirl 版本管理表
-- 用于 app 内版本更新检测

CREATE TABLE IF NOT EXISTS app_versions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  version_code INT NOT NULL,
  version_name VARCHAR(20) NOT NULL,
  apk_url VARCHAR(500) DEFAULT '',
  changelog TEXT,
  file_size VARCHAR(20) DEFAULT '未知',
  force_update TINYINT(1) DEFAULT 0,
  is_active TINYINT(1) DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_version_code (version_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 插入 3.13.0 (build 112)
INSERT IGNORE INTO app_versions (version_code, version_name, apk_url, changelog, file_size, force_update, is_active)
VALUES (
  112, '3.13.0', '',
  '✨ 新增投喂站 — 情侣虚拟送礼系统（甜品/饮品/鲜花/零食/礼物）\n🔍 新增全站搜索 — 一键搜索旅行/待办/记账/心情/聊天\n🔄 新增版本更新检测 — 启动自动检查 + 设置页手动检查\n📸 相册支持上传照片\n🗺 旅行地图全新无边全景设计\n🔧 开发者模式 — 点击版本号7次开启角色切换\n🛡 服务器安全加固（限流/安全头/请求日志）\n\n💕 更多细节优化等你发现~',
  '24MB', 0, 1
);

-- 插入 3.14.0 (build 113)
INSERT IGNORE INTO app_versions (version_code, version_name, apk_url, changelog, file_size, force_update, is_active)
VALUES (
  113, '3.14.0', '',
  '💕 新增纪念日 — 记录恋爱周年/生日/第一次等重要的日子\n  • 倒计时卡片，最近纪念日一目了然\n  • 支持恋爱纪念/生日/第一次/自定义四种类型\n  • 农历支持 + 每年重复提醒\n🔒 隐私设置完善 — 对接后端，可分别设置相册/心情/行程/聊天可见性\n📷 头像上传 — 支持相册选择 & 拍照，实时更新\n🔔 通知系统 — 本地推送，支持姨妈/纪念日/待办分类开关\n🔢 版本号显示优化 — 更新弹窗区分当前版本 vs 最新版本\n📋 更新日志二级弹窗 — 滚动查看完整更新内容\n\n🐛 细节修复 & 体验优化',
  '24MB', 0, 1
);
