# LoveGirl M1 基线清理记录

日期：2026-07-18
阶段：M1 工程基线清理

## 本次已完成

### 1. 清理已确认删除或废弃的残留入口

- `lib/screens/search/` 已移除
- `lib/screens/search/search_screen.dart` 已不再保留
- `lib/screens/health/widgets/calorie_tracker.dart` 已不再保留
- 代码层已不再继续引用 `search_screen`、`/api/search`、`calorie_records`、`calorieSynced`、`calorie_tracker`

### 2. 记账后端去掉旧兼容入口

文件：

- `D:/lovegirl_flutter/server_fixes/finance.js`

处理：

- 删除旧版 `/api/finance/records` 兼容路由
- 删除依赖旧未加密字段 `amount / description` 的遗留写法
- 保留当前主路由 `/api/finance` 与加密字段链路

### 3. 修正 `server_fixes` 入口挂载

文件：

- `D:/lovegirl_flutter/server_fixes/app.js`

处理：

- 不再引用不存在的 `./routes/*`
- 改为挂载当前仓库里真实存在的平铺路由文件
- 清理旧的 `calorie`、`search` 挂载残留
- 明确补齐本轮需要的基础路由落点：`auth / user / chat / sync / activity / aliases / daily / exam`

### 4. 补齐现有后端文件依赖的基础模块

新增文件：

- `D:/lovegirl_flutter/config/database.js`
- `D:/lovegirl_flutter/config/encrypt.js`
- `D:/lovegirl_flutter/middleware/auth.js`

作用：

- 承接当前 `server_fixes/*.js` 对 `../config/*` 与 `../middleware/auth` 的真实引用
- 避免现有路由因为基础依赖缺失而无法继续整理与运行

## 本次验证结果

- `node -c server_fixes/app.js` 通过
- `node -c server_fixes/finance.js` 通过
- `node -c config/database.js` 通过
- `node -c config/encrypt.js` 通过
- `node -c middleware/auth.js` 通过
- 本地 `require('./server_fixes/app')` 可正常启动服务

## 当时遇到的主要阻塞

### 阻塞 1：本地 Node 依赖缺失

最初验证时，本地缺少 `express` 等运行依赖，因此 `server_fixes` 无法直接启动。

后续处理：

- 新增根目录 `package.json`
- 安装本轮后端运行所需依赖

### 阻塞 2：后端基础模块不完整

当时虽然已有大量 `server_fixes/*.js`，但不少文件依赖的基础模块并不存在，导致“看起来像有后端，实际一跑就断”。

后续处理：

- 补齐认证、用户、聊天与基础占位路由
- 先把服务拉到“可启动、可继续联调”的状态，再往上做页面与链路修复

## 这一阶段的意义

M1 的目标不是一次性把后端做完，而是先把下面这些会持续绊脚的东西清掉：

- 假入口
- 旧残留
- 路由挂载错位
- 基础依赖缺失

这样后面继续推进首页、投喂站、旅行地图、我的页，以及高德地图真机链路时，才不会反复踩到同一批基础问题。
