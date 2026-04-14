# Open PVZ Wiki

> 这套 wiki 现在围绕一个主目标组织：把 `Open PVZ` 作为开放式 PVZ-like 规则引擎来设计，并把“错误技”作为它当前优先实现的旗舰验证场景。

---

## 先读这个

如果你第一次进入这个仓库，建议按下面顺序阅读：

1. [项目定位与总体架构](01-overview/00-核心架构总览.md)
2. [核心设计哲学](01-overview/01-核心设计哲学.md)
3. [系统架构](01-overview/02-系统架构.md)
4. [Open PVZ 系统版图与规划分层](01-overview/34-Open PVZ 系统版图与规划分层.md)
5. [当前阶段与实现路线](01-overview/23-当前阶段与实现路线.md)

这 5 篇负责回答最重要的问题：

- 项目到底要做什么
- 错误技和规则引擎是什么关系
- 当前架构怎么理解
- 当前阶段到底该先做什么

---

## 文档状态说明

阅读这套 wiki 时，建议先区分下面 3 种文档状态：

- 当前主文档：描述当前实现、当前边界和当前建议，是日常开发的优先入口。
- 规划文档：描述未来方向或后续可能接入的能力，不应直接当成当前事实。
- 审查记录：保留治理和整理过程，帮助理解“为什么这样收口”，但不覆盖当前正文。

---

## 物理目录结构

当前 `wiki/` 已按层次拆成物理子目录：

```text
wiki/
├── index.md
├── 01-overview/
├── 02-runtime-protocol/
├── 03-content-validation/
├── 04-roadmap-reference/
└── 05-governance/
```

以后新增文档时，先判断它属于哪一层，再决定放入哪个目录，而不是先写出来再找地方塞。

---

## 文档分层

### A. 项目总纲

- [项目定位与总体架构](01-overview/00-核心架构总览.md)
- [核心设计哲学](01-overview/01-核心设计哲学.md)
- [系统架构](01-overview/02-系统架构.md)
- [Open PVZ 系统版图与规划分层](01-overview/34-Open PVZ 系统版图与规划分层.md)
- [当前阶段与实现路线](01-overview/23-当前阶段与实现路线.md)

### B. 协议与运行时层

- [触发器系统](02-runtime-protocol/03-触发器系统.md)
- [效果系统](02-runtime-protocol/04-效果系统.md)
- [执行机制](02-runtime-protocol/06-执行机制.md)
- [事件模型](02-runtime-protocol/07-事件模型.md)
- [连续行为模型](02-runtime-protocol/08-连续行为模型.md)
- [性能与安全防护](02-runtime-protocol/10-性能与安全防护.md)
- [模板与装配边界](02-runtime-protocol/11-模板与装配边界.md)

### C. 内容与验证层

当前主文档：

- [完整工作流](03-content-validation/12-完整工作流.md)
- [验证清单](03-content-validation/15-验证清单.md)
- [验证矩阵](03-content-validation/32-验证矩阵.md)

规划与辅助文档：

- [三层生成器](03-content-validation/05-三层生成器.md)
- [命名与可视化](03-content-validation/09-命名与可视化.md)

### D. 路线、扩展与外部参考

- [扩展与数据包](04-roadmap-reference/11-扩展性与社区生态.md)
- [扩展包新增效果与效果外置策略](04-roadmap-reference/37-扩展包新增效果与效果外置策略.md)
- [开发路线图](04-roadmap-reference/26-开发路线图.md)
- [第四阶段前置清单](../plans/第四阶段前置清单.md)
- [第四阶段第一批可执行任务清单](../plans/第四阶段第一批可执行任务清单.md)
- [第四阶段-战斗玩法层系统清单](../plans/第四阶段-战斗玩法层系统清单.md)
- [第四阶段-阳光与资源最小概念草案](../plans/第四阶段-阳光与资源最小概念草案.md)
- [第四阶段-棋盘占位放置最小概念草案](../plans/第四阶段-棋盘占位放置最小概念草案.md)
- [第四阶段-卡片手牌费用最小概念草案](../plans/第四阶段-卡片手牌费用最小概念草案.md)
- [第四阶段-波次战局阶段胜负条件最小概念草案](../plans/第四阶段-波次战局阶段胜负条件最小概念草案.md)
- [外部项目调研：PVZ-Godot-Dream](04-roadmap-reference/24-外部项目调研-PVZ-Godot-Dream.md)
- [参考实现迁移策略](04-roadmap-reference/25-参考实现迁移策略.md)
- [PVZ-Godot-Dream 代码索引](04-roadmap-reference/pvz-godot-dream/00-代码索引总表.md)
- **[PVZ-Godot-Dream 代码索引子 Wiki](04-roadmap-reference/pvz-godot-dream/00-代码索引总表.md)** — 面向 AI Agent 的快速查找索引

### E. 开发治理与规范

当前规范与操作文档：

- [项目开发方法论](05-governance/27-项目开发方法论.md)
- [文档规范与维护约定](05-governance/29-文档规范与维护约定.md)
- [重大决策记录模板](05-governance/31-重大决策记录模板.md)
- [术语表](05-governance/33-术语表.md)
- [模板编写约定](05-governance/35-模板编写约定.md)
- [第三阶段协议冻结输入清单](05-governance/36-第三阶段协议冻结输入清单.md)
- [第三阶段第一轮冻结范围与兼容计划](05-governance/37-第三阶段第一轮冻结范围与兼容计划.md)

审查与整理记录：

- [Wiki 审查与规范化建议](05-governance/28-Wiki审查与规范化建议.md)
- [Wiki 内容审查报告](05-governance/30-Wiki内容审查报告.md)

---

## 当前阅读建议

### 如果你要梳理项目方向

- [项目定位与总体架构](01-overview/00-核心架构总览.md)
- [Open PVZ 系统版图与规划分层](01-overview/34-Open PVZ 系统版图与规划分层.md)
- [当前阶段与实现路线](01-overview/23-当前阶段与实现路线.md)

### 如果你要开始搭运行时

- [系统架构](01-overview/02-系统架构.md)
- [触发器系统](02-runtime-protocol/03-触发器系统.md)
- [效果系统](02-runtime-protocol/04-效果系统.md)
- [执行机制](02-runtime-protocol/06-执行机制.md)
- [连续行为模型](02-runtime-protocol/08-连续行为模型.md)
- [模板与装配边界](02-runtime-protocol/11-模板与装配边界.md)

### 如果你要看内容怎么接到引擎和验证上

- [完整工作流](03-content-validation/12-完整工作流.md)
- [验证清单](03-content-validation/15-验证清单.md)
- [验证矩阵](03-content-validation/32-验证矩阵.md)
- [模板编写约定](05-governance/35-模板编写约定.md)
- [三层生成器](03-content-validation/05-三层生成器.md) — 未来内容装配方向

### 如果你要看后续扩展和第四阶段边界

- [Open PVZ 系统版图与规划分层](01-overview/34-Open PVZ 系统版图与规划分层.md)
- [开发路线图](04-roadmap-reference/26-开发路线图.md)
- [第四阶段前置清单](../plans/第四阶段前置清单.md)
- [第四阶段第一批可执行任务清单](../plans/第四阶段第一批可执行任务清单.md)
- [第四阶段-战斗玩法层系统清单](../plans/第四阶段-战斗玩法层系统清单.md)
- [第四阶段-阳光与资源最小概念草案](../plans/第四阶段-阳光与资源最小概念草案.md)
- [第四阶段-棋盘占位放置最小概念草案](../plans/第四阶段-棋盘占位放置最小概念草案.md)
- [第四阶段-卡片手牌费用最小概念草案](../plans/第四阶段-卡片手牌费用最小概念草案.md)
- [第四阶段-波次战局阶段胜负条件最小概念草案](../plans/第四阶段-波次战局阶段胜负条件最小概念草案.md)
- [扩展与数据包](04-roadmap-reference/11-扩展性与社区生态.md)
- [扩展包新增效果与效果外置策略](04-roadmap-reference/37-扩展包新增效果与效果外置策略.md)
- [参考实现迁移策略](04-roadmap-reference/25-参考实现迁移策略.md)

### 如果你要规范项目开发方式

- [项目开发方法论](05-governance/27-项目开发方法论.md)
- [文档规范与维护约定](05-governance/29-文档规范与维护约定.md)
- [术语表](05-governance/33-术语表.md)
- [重大决策记录模板](05-governance/31-重大决策记录模板.md)
- [模板编写约定](05-governance/35-模板编写约定.md)

### 如果你要维护或新增 wiki

- [文档规范与维护约定](05-governance/29-文档规范与维护约定.md)
- [术语表](05-governance/33-术语表.md)
- [重大决策记录模板](05-governance/31-重大决策记录模板.md)
- [Wiki 审查与规范化建议](05-governance/28-Wiki审查与规范化建议.md) — 结构整理背景
- [Wiki 内容审查报告](05-governance/30-Wiki内容审查报告.md) — 审查记录

---

## 文档维护原则

- 先区分“引擎层”“内容层”“当前阶段”，再写文档
- 先区分概念层、协议层、实现层、验证层、内容层，再决定文档位置
- 明确区分“已决定”“当前建议”“未来方向”
- 规划文档和审查记录不得覆盖当前主文档
- 不要把错误技写成整个项目的全部定义
- 不要把未来愿景写成当前已经决定的实现方案
- 不要让 ECS、渲染、社区平台等远期主题继续主导当前主线

---

## 来源文档

- [早期引擎设计稿](../plans/pvz_like_engine_design_doc_v_1.md)
- [整合版设计稿](../plans/错误技系统完整设计思路（整合版）.md)
- [第四阶段前置清单](../plans/第四阶段前置清单.md)
- [项目 README](../README.md)
