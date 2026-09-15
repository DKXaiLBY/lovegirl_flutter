# LoveGirl 规划文档索引

更新时间：2026-07-17

这个目录现在存放 LoveGirl 本轮全面重构的正式规划文档。

## 1. 阅读顺序

建议按这个顺序看：

1. [根目标入口](D:/lovegirl_flutter/LoveGirl-全面修复与重构目标文档.md)
2. [总方案](D:/lovegirl_flutter/docs/planning/lovegirl_full_rebuild_master_plan.md)
3. [模块审计与目标结构](D:/lovegirl_flutter/docs/planning/lovegirl_module_audit_and_target_structure.md)
4. [实施路线与验收清单](D:/lovegirl_flutter/docs/planning/lovegirl_execution_roadmap_and_acceptance.md)
5. [需求追踪矩阵](D:/lovegirl_flutter/docs/planning/lovegirl_requirements_traceability_matrix.md)
6. [实施待办与里程碑](D:/lovegirl_flutter/docs/planning/lovegirl_delivery_backlog_and_milestones.md)
7. [当前状态审计](D:/lovegirl_flutter/docs/planning/lovegirl_current_state_audit_2026-07-17.md)
8. [清理、合并、删除清单](D:/lovegirl_flutter/docs/planning/lovegirl_cleanup_merge_delete_manifest.md)
9. [Phase 1 工程基线清理工单](D:/lovegirl_flutter/docs/planning/lovegirl_phase1_baseline_cleanup_worklist.md)
10. [核心 UI 页面落点映射](D:/lovegirl_flutter/docs/planning/lovegirl_core_ui_screen_mapping.md)
11. [风险登记与缓解方案](D:/lovegirl_flutter/docs/planning/lovegirl_risk_register_and_mitigation.md)
12. [外部依赖与发布前置条件](D:/lovegirl_flutter/docs/planning/lovegirl_external_dependencies_and_release_prerequisites.md)
13. [安全与数据完整性方案](D:/lovegirl_flutter/docs/planning/lovegirl_security_and_data_integrity_plan.md)
14. [迁移与回滚策略](D:/lovegirl_flutter/docs/planning/lovegirl_migration_and_rollback_strategy.md)
15. [Domain 前后端契约映射](D:/lovegirl_flutter/docs/planning/lovegirl_domain_contract_map.md)
16. [规划覆盖审计](D:/lovegirl_flutter/docs/planning/lovegirl_planning_coverage_audit.md)
17. [文档权威性与历史资料处置说明](D:/lovegirl_flutter/docs/planning/lovegirl_document_authority_and_legacy_map.md)
18. [实现启动简报](D:/lovegirl_flutter/docs/planning/lovegirl_implementation_kickoff_brief.md)
19. [实施就绪度与阻塞项](D:/lovegirl_flutter/docs/planning/lovegirl_implementation_readiness_and_blockers.md)
20. [方案阶段退场检查单](D:/lovegirl_flutter/docs/planning/lovegirl_planning_phase_exit_checklist.md)
21. [外部输入收集表](D:/lovegirl_flutter/docs/planning/lovegirl_required_external_inputs_packet.md)
22. [可扩展架构与新功能接入规范](D:/lovegirl_flutter/docs/planning/lovegirl_extensibility_architecture_and_feature_onboarding.md)
23. [冻结执行目标与实施契约](D:/lovegirl_flutter/docs/planning/lovegirl_goal_lock_and_execution_contract_2026-07-18.md)
24. [首批实现波次执行包（M1-M3）](D:/lovegirl_flutter/docs/planning/lovegirl_first_implementation_wave_execution_packet.md)
25. [核心体验执行包（M4 投喂站 / M5 旅行地图）](D:/lovegirl_flutter/docs/planning/lovegirl_core_experience_execution_packet_m4_m5.md)
26. [后半程执行包（M6-M12）](D:/lovegirl_flutter/docs/planning/lovegirl_completion_execution_packet_m6_m12.md)
27. [方案阶段证据链审计](D:/lovegirl_flutter/docs/planning/lovegirl_planning_phase_evidence_chain_audit.md)
28. [M1-M12 主控交付清单](D:/lovegirl_flutter/docs/planning/lovegirl_master_delivery_control_board.md)
29. [实现证据模板](D:/lovegirl_flutter/docs/planning/lovegirl_implementation_evidence_templates.md)
30. [M1 首次工作会话作战卡](D:/lovegirl_flutter/docs/planning/lovegirl_m1_first_session_playbook.md)

## 2. 每份文档负责什么

### 根目标入口

告诉你：

- 这轮重构到底要完成什么
- 当前阶段做到哪里
- 后续执行时以什么为准

### 总方案

告诉你：

- 最终产品应该长成什么样
- 前后端结构怎么收口
- UI、地图、联动、爱心豆怎么定方向

### 模块审计

告诉你：

- 哪些模块强保留
- 哪些模块合并
- 哪些模块删除
- 信息架构怎么收束

### 实施路线与验收清单

告诉你：

- 真正开工后先做什么、后做什么
- 每一阶段如何验收
- 什么情况下才能构建 APK、部署服务器、发布版本

### 需求追踪矩阵

告诉你：

- 这轮到底有哪些明确需求
- 每条需求来自哪里
- 以后该拿什么证据证明它完成了

### 实施待办与里程碑

告诉你：

- 这轮重构可以怎么排期
- 每个里程碑的主要待办是什么
- 依赖关系和发布门槛是什么

### 当前状态审计

告诉你：

- 当前仓库真实的起点结构是什么
- 为什么要做结构收口
- 哪些问题是当前状态直接暴露出来的

### 清理、合并、删除清单

告诉你：

- 哪些模块保留
- 哪些模块要合并
- 哪些模块要删除
- 删到什么程度才算真的清理干净

### Phase 1 工程基线清理工单

告诉你：

- 第一阶段要从哪些真实文件和目录下手
- 先清什么
- 每块清理要产出什么结果

### 核心 UI 页面落点映射

告诉你：

- 首页、投喂站、旅行地图、我的页分别对应哪些真实文件
- 相关 widget / provider / service 在哪里
- 后续 UI 落地时该从哪几个文件展开

### 风险登记与缓解方案

告诉你：

- 后续最容易出问题的点在哪里
- 哪些风险是 P0
- 应该怎么提前压住

### 外部依赖与发布前置条件

告诉你：

- 代码之外还需要准备什么
- 高德、服务器、签名、版本发布链路各自缺什么
- 什么条件没满足时不能发布

### 安全与数据完整性方案

告诉你：

- 哪些加密、鉴权、上传、通知一致性要求不能退
- 哪些历史保护链路必须完整迁移
- 删除旧模块时不能误伤哪些核心数据

### 迁移与回滚策略

告诉你：

- 后续结构切换怎么分批做
- 哪些地方必须留回滚点
- 什么时候应该触发回滚评估

### Domain 前后端契约映射

告诉你：

- 每个业务域前端落在哪些文件
- 后端接哪些路由和表
- 域与域之间怎么联动

### 规划覆盖审计

告诉你：

- 这轮方案阶段到底覆盖了多少原始要求
- 哪些已经进入正式文档
- 哪些还属于后续实现阶段

### 文档权威性与历史资料处置说明

告诉你：

- 现在哪些文档才是唯一权威依据
- 哪些旧文档只是参考
- 哪些历史资料不该再当主执行依据

### 实现启动简报

告诉你：

- 如果现在要从方案切到实现，第一步该看什么
- 哪些决定已经冻结
- 先做什么最不容易走偏

### 实施就绪度与阻塞项

告诉你：

- 哪些工作现在就能开始
- 哪些工作做到关键节点前要补外部条件
- 哪些问题会直接阻断最终发布

### 方案阶段退场检查单

告诉你：

- 现在是否已经应该停止补方案
- 哪些退出条件已经满足
- 为什么下一步该切入实现阶段

### 外部输入收集表

告诉你：

- 后续还需要补哪些 Key、SHA1、签名、服务器和发布信息
- 哪些值仓库里已经能确认
- 哪些缺口会在真机或发布阶段卡住

### 可扩展架构与新功能接入规范

告诉你：

- 以后新功能该往哪里接
- 哪些公共能力应该复用
- 联动、数据、首页摘要、删除路径该怎么提前设计
- 如何避免项目继续膨胀成难维护的拼接体

### 首批实现波次执行包（M1-M3）

告诉你：

- 真正开工后的第一波任务要按什么顺序做
- 每个工作包的输入文件、目标产出和验证方式是什么
- 什么证据能证明 M1、M2、M3 没有走偏

### 核心体验执行包（M4 投喂站 / M5 旅行地图）

告诉你：

- 投喂站和旅行地图真正开工时要怎么拆工作包
- 哪些链路优先保证成立，哪些细节可以后置
- 如何逐项验证这两条灵魂主线没有走偏

### 后半程执行包（M6-M12）

告诉你：

- 我的页、Life 域、Memory 域、联动、后端统一、审查、发布要怎么继续做
- 后半程每个阶段要产出什么、拿什么验收
- 如何把这轮重构真正走到真机验收与发布，而不是停在半路

### 方案阶段证据链审计

告诉你：

- 方案阶段的每一类要求当前具体落在哪些正式文档
- 哪些内容已经可以视为规划完成
- 哪些事情仍然必须留到实现、真机、部署和发布阶段

### M1-M12 主控交付清单

告诉你：

- 每个里程碑开始前要满足什么条件
- 每个里程碑结束时必须留下什么证据
- 什么情况下允许进入下一个里程碑

### 实现证据模板

告诉你：

- 后续实现、真机、QA、部署、发布记录该按什么格式留痕
- 如何把“要留证据”变成可以直接套用的模板

### M1 首次工作会话作战卡

告诉你：

- 真正进入实现后的第一工作会话该按什么顺序推进
- 第一天先查什么、先记什么、先不要做什么
- 什么情况下才算已经顺利进入 M1

## 3. 使用规则

后续如果继续推进实现，请遵守下面这些规则：

- 先对照这套文档，再决定改代码
- 不再以旧的零散提示词作为主依据
- 新功能必须考虑可添加性，不能靠到处补丁接入
- 没有达到真机验收和发布门槛前，不算完成

## 4. 文档权威性

后续实现时请优先遵守：

- `LoveGirl-全面修复与重构目标文档.md` 是总目标入口
- `docs/planning/README.md` 是正式规划索引
- `docs/planning/` 下的文档是当前重构唯一权威规划集
- `docs/ui/` 与根目录其他历史文档主要作为参考，不再覆盖 planning 目录

## 5. 当前阶段说明

截至 2026-07-17，LoveGirl 当前处于：

- 方案阶段已基本收口
- 已具备切入实现阶段的条件
- 但实现、真机验收、部署与发布尚未开始

这意味着：

- 继续补抽象方案的收益已经很低
- 下一步最合理的动作是按 `M1` 开始实现
