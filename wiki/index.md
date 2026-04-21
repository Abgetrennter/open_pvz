# Open PVZ Wiki

> 本 Wiki 以 2026-04-21 的仓库现状为准，目标是把"当前已经落地的实现"和"仍然只是规划或归档的内容"明确分开。

---

## 当前项目状态

当前 `Open PVZ` 已经不是概念验证骨架，而是一个可运行、可验证、可扩展的 PVZ-like 战斗引擎主干。

已经可以确认的事实包括：

- 默认启动场景是 [`scenes/main/main.tscn`](../scenes/main/main.tscn)，进入 Showcase Hub。
- 仓库包含一个可操作的最小可玩关卡 [`scenes/demo/demo_level.tscn`](../scenes/demo/demo_level.tscn)。
- `data/combat/` 已经形成正式内容目录：`battlefields / cards / entity_templates / height_bands / levels / projectile_profiles / projectile_templates / trigger_bindings / waves`。
- 当前主仓正式内容已经具备第一轮基线：
  - 16 个植物模板
  - 9 个僵尸模板
  - 10 个投射物模板
  - 10 张卡片
  - 3 个 Phase 6 战场 / 波次 / 关卡模板
- 扩展侧已经有 3 个明确入口：`extensions/minimal_chaos_pack`、`phase5_chaos_pack`、`phase5_guardrail_pack`。
- 验证体系已经进入持续回归状态：[`tools/validation_scenarios.json`](../tools/validation_scenarios.json) 当前共 53 个场景，分层 `smoke / core / extension / guardrail` 计数 `9 / 38 / 10 / 5`。

一句话判断：

> 第一到第六阶段已经沉淀为当前主干，项目当前处于"第七阶段输入准备"语境，主线是继续扩展正式关卡、正式内容组合与回归覆盖，而不是回到早期主干搭建阶段。

---

## 推荐阅读顺序

第一次进入仓库，建议按下面顺序看：

1. [15 分钟上手路径](01-overview/03-15分钟上手路径.md)
2. [架构总览](01-overview/00-架构总览.md)
3. [系统版图与规划分层](01-overview/34-Open%20PVZ%20系统版图与规划分层.md)
4. [当前阶段与实现路线](01-overview/23-当前阶段与实现路线.md)
5. [开发路线图](04-roadmap-reference/26-开发路线图.md)
6. [验证清单](03-content-validation/15-验证清单.md)
7. [验证矩阵](03-content-validation/32-验证矩阵.md)

---

## 文档分层

### 1. 当前主文档

这些页面描述"现在仓库里已经成立的事实"：

- [15 分钟上手路径](01-overview/03-15分钟上手路径.md)
- [架构总览](01-overview/00-架构总览.md)
- [核心设计哲学](01-overview/01-核心设计哲学.md)
- [当前阶段与实现路线](01-overview/23-当前阶段与实现路线.md)
- [系统版图与规划分层](01-overview/34-Open%20PVZ%20系统版图与规划分层.md)
- [开发路线图](04-roadmap-reference/26-开发路线图.md)
- [完整工作流](03-content-validation/12-完整工作流.md)
- [验证清单](03-content-validation/15-验证清单.md)
- [验证矩阵](03-content-validation/32-验证矩阵.md)
- [调试与日志观察](02-runtime-protocol/12-调试与日志观察.md)
- [性能基线实测](02-runtime-protocol/13-性能基线实测.md)

### 2. 协议与运行时文档

- [触发器系统](02-runtime-protocol/03-触发器系统.md)
- [效果系统](02-runtime-protocol/04-效果系统.md)
- [执行机制](02-runtime-protocol/06-执行机制.md)
- [事件模型](02-runtime-protocol/07-事件模型.md)
- [连续行为模型](02-runtime-protocol/08-连续行为模型.md)
- [性能与安全防护](02-runtime-protocol/10-性能与安全防护.md)
- [模板与装配边界](02-runtime-protocol/11-模板与装配边界.md)

### 3. 参考与规划文档

- [扩展性与社区生态](04-roadmap-reference/11-扩展性与社区生态.md)
- [扩展系统总体规划](04-roadmap-reference/38-扩展系统总体规划.md)
- [外部项目调研：PVZ-Godot-Dream](04-roadmap-reference/24-外部项目调研-PVZ-Godot-Dream.md)
- [参考实现迁移策略](04-roadmap-reference/25-参考实现迁移策略.md)
- [参考项目综合对比分析](04-roadmap-reference/42-参考项目综合对比分析.md)

### 4. 治理与维护文档

- [项目开发方法论](05-governance/27-项目开发方法论.md)
- [文档规范与维护约定](05-governance/29-文档规范与维护约定.md)
- [重大决策记录模板](05-governance/31-重大决策记录模板.md)
- [决策记录目录](decisions/README.md)
- [术语表](05-governance/33-术语表.md)
- [模板编写约定](05-governance/35-模板编写约定.md)

### 5. 阶段归档与历史资料

这里保留"为什么会演进成今天这样"的历史语境：

- [第一至第四阶段归档总览](../plans/archive/第一至第四阶段归档总览.md)
- [第五阶段阶段总结](../plans/archive/第五阶段/第五阶段阶段总结.md)
- [第六阶段-阶段总结](../plans/archive/第六阶段/第六阶段-阶段总结.md)
- [第七阶段输入清单](../plans/archive/第七阶段输入清单.md)
- [Wiki 自审归档（28、30）](../plans/archive/wiki-governance/)
- [扩展系统草案目录](../plans/draft/extension-system/README.md)

---

## 当前实现索引

### 运行与展示入口

- [`project.godot`](../project.godot)
- [`scenes/main/main.tscn`](../scenes/main/main.tscn)
- [`scenes/demo/demo_level.tscn`](../scenes/demo/demo_level.tscn)
- [`scenes/showcase/README.md`](../scenes/showcase/README.md)

### 核心运行时

- [`autoload/`](../autoload)
- [`scripts/core/`](../scripts/core)
- [`scripts/entities/`](../scripts/entities)
- [`scripts/projectile/`](../scripts/projectile)
- [`scripts/components/`](../scripts/components)

### 正式内容资源

- [`data/combat/README.md`](../data/combat/README.md)
- [`data/combat/entity_templates/`](../data/combat/entity_templates)
- [`data/combat/projectile_templates/`](../data/combat/projectile_templates)
- [`data/combat/cards/`](../data/combat/cards)
- [`data/combat/battlefields/`](../data/combat/battlefields)
- [`data/combat/waves/`](../data/combat/waves)
- [`data/combat/levels/`](../data/combat/levels)

### 验证与回归

- [`scenes/validation/`](../scenes/validation)
- [`tools/run_validation.ps1`](../tools/run_validation.ps1)
- [`tools/run_all_validations.ps1`](../tools/run_all_validations.ps1)
- [`tools/validation_scenarios.json`](../tools/validation_scenarios.json)
- [`tools/formal_content_validation_map.json`](../tools/formal_content_validation_map.json)

### 扩展包

- [`extensions/minimal_chaos_pack`](../extensions/minimal_chaos_pack)
- [`extensions/phase5_chaos_pack`](../extensions/phase5_chaos_pack)
- [`extensions/phase5_guardrail_pack`](../extensions/phase5_guardrail_pack)

---

## 维护原则

- 当前主文档优先描述"已落地实现"，不要混入历史阶段切换叙事。
- 规划文档可以保留，但必须明确是规划、草案还是归档。草案默认进入 `plans/draft/`，只有实装后才提升至 wiki。
- 历史阶段总结只作为背景资料，不覆盖当前状态判断。
- 验证事实以 [`tools/validation_scenarios.json`](../tools/validation_scenarios.json) 和相关脚本为准。
- 正式内容事实以 `data/combat/` 与 `extensions/` 当前资源树为准。
- 文档不写元文档：不再新增"审查 wiki 的 wiki"，治理议题以 `27-项目开发方法论` / `29-文档规范与维护约定` 为唯一入口。

---

## 来源与补充阅读

- [项目 README](../README.md)
- [早期引擎设计稿](../plans/pvz_like_engine_design_doc_v_1.md)
- [整合版设计稿](../plans/错误技系统完整设计思路（整合版）.md)
