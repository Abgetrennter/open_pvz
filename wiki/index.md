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

这四篇负责回答最重要的问题：

- 项目到底要做什么
- 错误技和规则引擎是什么关系
- 当前架构怎么理解
- 当前阶段到底该先做什么

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

### C. 内容与验证层

- [三层生成器](03-content-validation/05-三层生成器.md)
- [命名与可视化](03-content-validation/09-命名与可视化.md)
- [完整工作流](03-content-validation/12-完整工作流.md)
- [验证清单](03-content-validation/15-验证清单.md)
- [验证矩阵](03-content-validation/32-验证矩阵.md)

### D. 路线、扩展与外部参考

- [扩展与数据包](04-roadmap-reference/11-扩展性与社区生态.md)
- [开发路线图](04-roadmap-reference/26-开发路线图.md)
- [外部项目调研：PVZ-Godot-Dream](04-roadmap-reference/24-外部项目调研-PVZ-Godot-Dream.md)
- [参考实现迁移策略](04-roadmap-reference/25-参考实现迁移策略.md)

### E. 开发治理与规范

- [项目开发方法论](05-governance/27-项目开发方法论.md)
- [Wiki 审查与规范化建议](05-governance/28-Wiki审查与规范化建议.md)
- [文档规范与维护约定](05-governance/29-文档规范与维护约定.md)
- [Wiki 内容审查报告](05-governance/30-Wiki内容审查报告.md)
- [重大决策记录模板](05-governance/31-重大决策记录模板.md)
- [术语表](05-governance/33-术语表.md)

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
- [事件模型](02-runtime-protocol/07-事件模型.md)
- [连续行为模型](02-runtime-protocol/08-连续行为模型.md)

### 如果你要看错误技怎么接到引擎上

- [三层生成器](03-content-validation/05-三层生成器.md)
- [完整工作流](03-content-validation/12-完整工作流.md)
- [验证清单](03-content-validation/15-验证清单.md)
- [验证矩阵](03-content-validation/32-验证矩阵.md)

### 如果你要看后续扩展边界

- [Open PVZ 系统版图与规划分层](01-overview/34-Open PVZ 系统版图与规划分层.md)
- [开发路线图](04-roadmap-reference/26-开发路线图.md)
- [扩展与数据包](04-roadmap-reference/11-扩展性与社区生态.md)
- [外部项目调研：PVZ-Godot-Dream](04-roadmap-reference/24-外部项目调研-PVZ-Godot-Dream.md)
- [参考实现迁移策略](04-roadmap-reference/25-参考实现迁移策略.md)

### 如果你要规范项目开发方式

- [项目开发方法论](05-governance/27-项目开发方法论.md)
- [Wiki 审查与规范化建议](05-governance/28-Wiki审查与规范化建议.md)
- [文档规范与维护约定](05-governance/29-文档规范与维护约定.md)
- [重大决策记录模板](05-governance/31-重大决策记录模板.md)
- [术语表](05-governance/33-术语表.md)

### 如果你要维护或新增 wiki

- [项目开发方法论](05-governance/27-项目开发方法论.md)
- [Wiki 审查与规范化建议](05-governance/28-Wiki审查与规范化建议.md)
- [文档规范与维护约定](05-governance/29-文档规范与维护约定.md)
- [Wiki 内容审查报告](05-governance/30-Wiki内容审查报告.md)
- [重大决策记录模板](05-governance/31-重大决策记录模板.md)
- [术语表](05-governance/33-术语表.md)

---

## 文档维护原则

- 先区分“引擎层”“内容层”“当前阶段”，再写文档
- 先区分概念层、协议层、实现层、验证层、内容层，再决定文档位置
- 明确区分“已决定”“当前建议”“未来方向”
- 不要把错误技写成整个项目的全部定义
- 不要把未来愿景写成当前已经决定的实现方案
- 不要让 ECS、渲染、社区平台等远期主题继续主导当前主线

---

## 来源文档

- [早期引擎设计稿](../plans/pvz_like_engine_design_doc_v_1.md)
- [整合版设计稿](../plans/错误技系统完整设计思路（整合版）.md)
- [项目 README](../README.md)
