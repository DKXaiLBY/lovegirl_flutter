# LoveGirl 全面修复与重构目标文档

最后更新：2026-07-17

## 一、这份文档的定位

这份文档现在作为 LoveGirl 本轮全面重构的“唯一目标入口”。

如果后面继续推进，请优先看这份文档，再按下面这个顺序进入正式规划集：

- [规划索引](D:/lovegirl_flutter/docs/planning/README.md)

如果只想先抓住主骨架，再优先看这 3 份核心文档：

- [总方案](D:/lovegirl_flutter/docs/planning/lovegirl_full_rebuild_master_plan.md)
- [模块审计](D:/lovegirl_flutter/docs/planning/lovegirl_module_audit_and_target_structure.md)
- [实施路线与验收](D:/lovegirl_flutter/docs/planning/lovegirl_execution_roadmap_and_acceptance.md)

如果已经准备从方案切入实现，建议直接看这 5 份“开工文档”：

- [实现启动简报](D:/lovegirl_flutter/docs/planning/lovegirl_implementation_kickoff_brief.md)
- [Phase 1 工程基线清理工单](D:/lovegirl_flutter/docs/planning/lovegirl_phase1_baseline_cleanup_worklist.md)
- [M1-M12 主控交付清单](D:/lovegirl_flutter/docs/planning/lovegirl_master_delivery_control_board.md)
- [实现证据模板](D:/lovegirl_flutter/docs/planning/lovegirl_implementation_evidence_templates.md)
- [M1 首次工作会话作战卡](D:/lovegirl_flutter/docs/planning/lovegirl_m1_first_session_playbook.md)

如果想先用一份文档把“这轮到底做什么、按什么顺序做、做到什么程度才算完成”快速拉齐，请优先看：

- [冻结执行目标与实施契约](D:/lovegirl_flutter/docs/planning/lovegirl_goal_lock_and_execution_contract_2026-07-18.md)

## 二、当前总目标

把 LoveGirl 从“功能很多但体验分散、中文不稳定、模块关系松散”的私人情侣 App，重构成一套：

- UI 统一
- 中文干净
- 核心链路可信
- 模块边界清楚
- 后续容易继续加功能
- 可真机验收
- 可发布上线

这次不是零碎修补，而是一次有主线的收口重构。

## 三、当前阶段边界

当前阶段只做两件事：

1. 把完整方案沉淀清楚
2. 把后续执行目标、顺序、验收标准写成文档

当前阶段明确不做：

- 不在这一步直接写业务代码
- 不在这一步直接构建正式 APK
- 不在没有真机验收前直接发布新版本

## 四、这轮重构的核心主线

### 主线 1：把 4 个核心体验做对

- 首页
- 投喂站
- 旅行地图
- 我的

### 主线 2：把模块关系理顺

- 保留真正有灵魂的模块
- 合并重复模块
- 删除无意义模块
- 让后续新功能方便接入

### 主线 3：把结构做成以后还能继续长

- 前端按 domain 重组
- 状态管理按模块补齐
- 后端路由与服务分层
- 联动不再靠散落逻辑硬写

## 五、当前已经确认的产品决定

### 强保留

- 投喂站
- 旅行地图
- 首页
- 我的页
- 私密聊天
- 伴侣绑定
- 经期管理
- 记账
- 课程表
- 心情日记
- 恋爱时光轴

### 合并

- `纪念日 + 倒数日`
- `相册 + 照片`

### 不强行合并

- `待办 + 愿望清单`

说明：

- 两者同属 Life 域
- 共用部分能力
- 但保留两种不同心智模型

### 删除

- 全局搜索
- 卡路里追踪

## 六、这轮确认的技术方向

### UI 方向

统一采用已经确认的“回忆票根 / 专属菜单 / 纸感卡片 / 关系资料夹”方向。

### 地图方向

彻底废弃 `flutter_map + 高德瓦片`，统一改走：

- 高德 Android 原生地图 SDK
- 高德 Web 服务 API
- 后端代理 Key 和查询

### 扩展性方向

以后新增功能时，必须优先满足：

- 有明确所属 domain
- 有独立 model / service / provider
- 能说明是否接首页摘要
- 能说明是否联动爱心豆 / 记账 / 时光轴

## 七、当前阶段产出的正式文档

### 1. 总方案

[docs/planning/lovegirl_full_rebuild_master_plan.md](D:/lovegirl_flutter/docs/planning/lovegirl_full_rebuild_master_plan.md)

作用：

- 定总目标
- 定最终架构
- 定联动和爱心豆方向
- 定高德地图方案
- 定完成定义

### 2. 模块审计

[docs/planning/lovegirl_module_audit_and_target_structure.md](D:/lovegirl_flutter/docs/planning/lovegirl_module_audit_and_target_structure.md)

作用：

- 定哪些模块保留
- 哪些合并
- 哪些删除
- 目标信息架构怎么收口

### 3. 实施路线与验收

[docs/planning/lovegirl_execution_roadmap_and_acceptance.md](D:/lovegirl_flutter/docs/planning/lovegirl_execution_roadmap_and_acceptance.md)

作用：

- 定实施顺序
- 定每阶段验收点
- 定最终发布门槛

## 八、下一阶段真正执行时的顺序

后续一旦开始写代码，必须按这个顺序推进：

1. 工程基线清理
2. 设计系统统一
3. 首页重构
4. 投喂站重构
5. 旅行地图重构
6. 我的页重构
7. 生活域收口
8. 回忆域收口
9. 模块联动与爱心豆
10. 后端统一与迁移
11. 对抗式审查
12. 真机验收与发布

## 九、最终完成标准

只有同时满足下面这些条件，这一轮目标才算真正完成：

- UI 与确认方向一致
- 核心中文文案无乱码
- 首页天气稳定且不溢出
- 投喂站主流程可用
- 旅行地图高德模式真机不崩
- 核心联动成立
- 删除模块清理干净
- 后端已部署正确版本
- 版本可以正常更新

在这些条件同时满足前，都不能算“已经做完”。

## 十、当前阶段结论（2026-07-17）

截至 2026 年 7 月 17 日，LoveGirl 当前这一步“先输出详细方案，不写代码”的阶段，已经完成到足够稳定的程度。

当前已经具备：

- 根目标入口
- `docs/planning/README.md` 规划索引
- `docs/planning/` 下完整的正式规划文档集（截至 2026-07-18 共 31 份正式规划文档，含 `README.md`）
- 方案阶段退场检查单
- 实现启动简报
- 实施就绪度与阻塞项说明
- 实现阶段主控交付清单
- 实现证据模板
- `M1` 首次工作会话作战卡

这意味着：

- 继续补抽象规划的收益已经很低
- 当前最合理的下一步是进入实现阶段
- 实现阶段建议从 `M1 工程基线清理` 开始

真正开始实现时，建议直接按下面这条最短入口链推进：

1. [实现启动简报](D:/lovegirl_flutter/docs/planning/lovegirl_implementation_kickoff_brief.md)
2. [Phase 1 工程基线清理工单](D:/lovegirl_flutter/docs/planning/lovegirl_phase1_baseline_cleanup_worklist.md)
3. [M1-M12 主控交付清单](D:/lovegirl_flutter/docs/planning/lovegirl_master_delivery_control_board.md)
4. [实现证据模板](D:/lovegirl_flutter/docs/planning/lovegirl_implementation_evidence_templates.md)
5. [M1 首次工作会话作战卡](D:/lovegirl_flutter/docs/planning/lovegirl_m1_first_session_playbook.md)

需要特别说明的是：

- 这不等于整个 LoveGirl 重构目标已经完成
- 代码实现、真机验收、服务器部署、APK 发布都还没有开始

换句话说：

- **方案阶段：已基本收口**
- **总目标：仍未完成**
