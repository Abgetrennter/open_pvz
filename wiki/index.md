# Open PVZ Wiki

- 状态：当前事实

> 本 Wiki 只保留当前成立的实现事实、当前有效的路线判断，以及必要的治理入口。阶段任务单、旧路线叙事和退役正文统一进入归档区。

---

## 当前快照

截至当前仓库状态，可以统一确认：

- 正式 archetype 总数为 `50`：`38` 植物、`10` 僵尸、`2` 场上物件。
- 验证场景总数为 `73`，其中包含 `9` 个 `smoke`、`57` 个 `core`、`10` 个 `extension`、`6` 个 `guardrail`、`3` 个 `migration` 分层标签。
- Mechanic 一级 family 已冻结为 `10` 个；正文当前按 `9/10` 已建立正式编译覆盖理解，`Placement` 仍视为待补完 family。
- `EntityTemplate / TriggerBinding` 仍存在于仓库中，但仅作为 legacy 兼容层和后端资源层，不再作为正式作者入口。
- 当前全部 `50` 个 archetype 仍保留 `backend_entity_template*` 字段，说明 legacy 收口尚未完成，但主线入口已经切换到 `Archetype + Mechanic[]`。

一句话判断：

> Open PVZ 当前是一个以 `Archetype + Mechanic[]` 为正式作者模型、以批量验证为回归基线、仍在继续收口 legacy 兼容层的 PVZ-like 战斗引擎。

---

## 推荐阅读

第一次进入仓库，建议按下面顺序阅读：

1. [15 分钟上手路径](01-overview/03-15分钟上手路径.md)
2. [架构总览](01-overview/00-架构总览.md)
3. [当前阶段与实现路线](01-overview/23-当前阶段与实现路线.md)
4. [开发路线图](04-roadmap-reference/26-开发路线图.md)
5. [编译链与 Mechanic 系统](02-runtime-protocol/11-编译链与Mechanic系统.md)
6. [验证矩阵](03-content-validation/32-验证矩阵.md)
7. [决策记录索引](decisions/README.md)
8. [历史归档与退役文档索引](05-governance/37-历史归档与退役文档索引.md)

---

## 文档接口

本轮收口后，Wiki 的几个固定入口如下：

- [当前阶段与实现路线](01-overview/23-当前阶段与实现路线.md)
  - 唯一状态快照页，只回答“现在做到哪一步”。
- [开发路线图](04-roadmap-reference/26-开发路线图.md)
  - 唯一前进路线页，只回答“接下来优先做什么”。
- [决策记录索引](decisions/README.md)
  - 原始 ADR 与讨论记录区，不并入正文。
- [历史归档与退役文档索引](05-governance/37-历史归档与退役文档索引.md)
  - `plans/archive/` 与 `plans/draft/` 的统一导航入口。

---

## 当前主文档

### 总览与路线

- [架构总览](01-overview/00-架构总览.md)
- [核心设计哲学](01-overview/01-核心设计哲学.md)
- [系统版图与规划分层](01-overview/34-Open PVZ 系统版图与规划分层.md)
- [当前阶段与实现路线](01-overview/23-当前阶段与实现路线.md)
- [开发路线图](04-roadmap-reference/26-开发路线图.md)

### 运行时与协议

- [触发器系统](02-runtime-protocol/03-触发器系统.md)
- [效果系统](02-runtime-protocol/04-效果系统.md)
- [执行机制](02-runtime-protocol/06-执行机制.md)
- [事件模型](02-runtime-protocol/07-事件模型.md)
- [连续行为模型](02-runtime-protocol/08-连续行为模型.md)
- [编译链与 Mechanic 系统](02-runtime-protocol/11-编译链与Mechanic系统.md)
- [调试与日志观察](02-runtime-protocol/12-调试与日志观察.md)

### 内容与验证

- [完整工作流](03-content-validation/12-完整工作流.md)
- [验证清单](03-content-validation/15-验证清单.md)
- [验证矩阵](03-content-validation/32-验证矩阵.md)

### 治理与维护

- [项目开发方法论](05-governance/27-项目开发方法论.md)
- [文档规范与维护约定](05-governance/29-文档规范与维护约定.md)
- [重大决策记录模板](05-governance/31-重大决策记录模板.md)
- [术语表](05-governance/33-术语表.md)
- [Archetype 编写约定](05-governance/35-模板编写约定.md)
- [原版实体复刻工作流](05-governance/36-原版实体复刻工作流.md)
- [历史归档与退役文档索引](05-governance/37-历史归档与退役文档索引.md)

---

## 当前事实来源

正文中的事实默认以下列仓库对象为准：

- 内容事实以 `data/combat/` 与 `extensions/` 当前资源树为准。
- 验证事实以 `tools/validation_scenarios.json` 与 `tools/formal_content_validation_map.json` 为准。
- 编译链与运行时事实以 `autoload/`、`scripts/core/`、`scripts/components/`、`scripts/projectile/` 为准。
- 决策边界以 `wiki/decisions/` 下已决定的 ADR 为准。

---

## 维护约束

- 当前正文优先写“已成立事实”和“当前有效路线”，不再承载阶段任务单。
- 任何新 ADR 完成后，必须同步回写至少一篇当前正文和一篇运行时/验证文档。
- `EntityTemplate / TriggerBinding` 在当前正文中只能以 legacy/兼容层语义出现。
- 历史材料统一进入 `plans/archive/`，未来方向草案统一进入 `plans/draft/`。

---

## 相关入口

- [项目 README](../README.md)
- [历史归档与退役文档索引](05-governance/37-历史归档与退役文档索引.md)
- [扩展系统草案目录](../plans/draft/extension-system/README.md)
