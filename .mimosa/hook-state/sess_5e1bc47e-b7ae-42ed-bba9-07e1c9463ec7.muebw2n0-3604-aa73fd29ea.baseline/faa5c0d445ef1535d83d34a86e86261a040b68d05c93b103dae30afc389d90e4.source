/**
 * 修复版本记录 API
 * 添加到 version.js 路由中
 *
 * PUT /api/version/fix — 修复版本记录（管理员用）
 */

// 在 version.js 中添加以下路由：

router.put("/fix", async (req, res) => {
  try {
    const { version_code, changelog, apk_url } = req.body;

    if (!version_code) {
      return res.status(400).json({ code: 400, message: "缺少 version_code" });
    }

    const updates = [];
    const values = [];

    if (changelog !== undefined) {
      updates.push("changelog = ?");
      values.push(changelog);
    }
    if (apk_url !== undefined) {
      updates.push("apk_url = ?");
      values.push(apk_url);
    }

    if (updates.length === 0) {
      return res.status(400).json({ code: 400, message: "没有需要更新的字段" });
    }

    values.push(version_code);
    await pool.query(
      `UPDATE app_versions SET ${updates.join(", ")} WHERE version_code = ?`,
      values
    );

    res.json({ code: 200, message: "修复成功" });
  } catch (err) {
    console.error("Version fix error:", err);
    res.status(500).json({ code: 500, message: "服务器错误" });
  }
});
