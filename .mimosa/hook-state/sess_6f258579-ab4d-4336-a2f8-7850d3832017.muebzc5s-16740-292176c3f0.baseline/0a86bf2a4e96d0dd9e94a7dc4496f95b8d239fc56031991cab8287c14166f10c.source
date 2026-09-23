const express = require("express");
const router = express.Router();
const { authRequired } = require("../middleware/auth");
const pool = require("../config/database");

// 版本检查 — 公开接口，仅返回是否需要更新（不含完整下载链接）
router.get("/check", async (req, res) => {
  try {
    const clientCode = parseInt(req.query.version_code) || 0;
    const [rows] = await pool.query(
      "SELECT version_code, version_name, apk_url, changelog, file_size, force_update FROM app_versions WHERE is_active = 1 ORDER BY version_code DESC LIMIT 1"
    );
    if (rows.length === 0) {
      return res.json({ code: 200, data: { hasUpdate: false } });
    }
    const latest = rows[0];
    res.json({
      code: 200,
      data: {
        hasUpdate: latest.version_code > clientCode,
        needUpdate: latest.force_update === 1 && latest.version_code > clientCode,
        version: {
          code: latest.version_code,
          name: latest.version_name,
          url: latest.apk_url,
          changelog: latest.changelog,
          size: latest.file_size
        }
      }
    });
  } catch (err) {
    console.error("Version check error:", err);
    res.status(500).json({ code: 500, message: "Server error" });
  }
});

// 最新版本详情 — 需要认证
router.get("/latest", authRequired, async (req, res) => {
  try {
    const [rows] = await pool.query(
      "SELECT * FROM app_versions WHERE is_active = 1 ORDER BY version_code DESC LIMIT 1"
    );
    res.json({ code: 200, data: rows[0] || null });
  } catch (err) {
    res.status(500).json({ code: 500, message: "Server error" });
  }
});

module.exports = router;
