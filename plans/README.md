# plans/ 计划入口

本文件是 `plans/` 目录的唯一计划入口。根目录下每份计划按状态登记，新增或变更必须同步更新本文件。

## 状态说明

| 状态 | 含义 |
|------|------|
| **当前执行/维护** | 仍在活跃维护，或作为当前事实来源 |
| **设计讨论** | 非当前规范，记录设计思路与历史讨论 |
| **归档候选** | 已完成或已被 wiki 正文替代，应迁入 `archive/` |

## 当前执行/维护

| 文件 | 用途 | 事实来源 | 可作为当前实现依据 |
|------|------|----------|-------------------|
| `original-plant-migration-ledger.md` | 原版植物迁移底账 | 迁移底账本身，按需更新 | 是 |
| `original-plant-protocol-gaps.md` | 原版植物协议缺口追踪 | 协议缺口追踪，维护中 | 是 |
| `original-plant-mechanism-audit.md` | 原版植物机制审计 | 审计记录，按需更新 | 是 |
| `original-plant-visual-bulk-migration-plan.md` | 原版植物视觉批量迁移执行方案 | 当前私有素材包、原版图像移植工作文档、验证脚本与展示场景 | 是 |
| `reanim-native-full-original-plant-migration-plan.md` | 48 株原版植物 Reanim 原生视觉全量迁移 | 当前 archetype 清单、私有 manifest/semantic reports、原生 Reanim 运行时与 local_private 验证 | 是（执行计划） |
| `reanim-native-migration-candidate-matrix.md` | 30 株待迁移植物的候选矩阵（M0 产出，含 source/flags/批次/阻塞） | scan_reanim_feature_flags.ps1 输出 + 各 semantic report；M1 首批 4 株已落地 | 是（M1/M2 执行依据） |
| `未来计划.md` | 前进方向概要 | 与 `wiki/04-roadmap-reference/26-开发路线图.md` 对齐 | 是（路线图方向） |
| `zombie-design-research-report.md` | 僵尸设计研究报告（三源综合分析） | `vendor/de-pvz/` + `vendor/PVZ-Godot-Dream/` + 本项目代码 | 是 |

## 设计讨论

| 文件 | 用途 | 备注 |
|------|------|------|
| `视觉表现层设计讨论.md` | 视觉层设计讨论 | wiki 已有正式文档 |
| `输入交互层设计讨论.md` | 输入层设计讨论 | 历史讨论 |
| `音频系统设计.md` | 音频系统设计讨论 | 历史讨论 |
| `Open PVZ 视觉反馈层设计与路线图.md` | 视觉反馈层设计 | wiki 已有正式文档 |
| `UI 框架层设计方案.md` | UI 框架设计讨论 | 历史讨论 |
| `reanim资源转换工具链规划.md` | reanim 工具链规划 | 历史讨论 |
| `attack-chain-family-compile-path.md` | 攻击链编译路径讨论 | 历史讨论 |
| `draft/原版机制未实现项盘点.md` | 原版机制未实现项盘点 | 草案，基于 de-pvz / PVZ-Godot-Dream / 当前 validation 对齐；P0 章节已拆分为 `p0-original-plant-blockers-plan.md` |
| `draft/公开引擎受限素材与worktree治理草案.md` | 公开引擎、受限素材双仓边界与 worktree 挂载治理 | 草案，不是当前实现依据 |
| `pvz_like_engine_design_doc_v_1.md` | 引擎设计文档 v1 | 早期设计，已被实际实现超越 |

## 设计讨论（子目录）

| 目录 | 用途 |
|------|------|
| `visual-feedback-layer/` | 视觉反馈层设计讨论子目录，包含多份视觉层方案草稿 |

## 归档候选

| 文件 | 用途 | 归档理由 |
|------|------|----------|
| `错误技系统完整设计思路（整合版）.md` | 错误技系统设计 | 已落地实施 |
| `原版植物移植详细路线图.md` | 原版植物路线图 | 已被迁移底账替代 |
| `原版图像移植工作文档.md` | 原版图像移植 | 历史材料 |
| `reanim-native-runtime-implementation-plan.md` | Reanim 原生运行时实施计划 | T0-T6 已完成且验证通过，待确认后移入 `archive/` |
| `draft/reanim原生运行时ReanimData方案设计草案.md` | Reanim 原生运行时设计草案 | 已由实施计划、运行时代码与素材包 wiki 吸收，待归档 |

## 子目录

| 目录 | 用途 |
|------|------|
| `archive/` | 已完成阶段归档总览，已归档的不再在根目录登记；近期归档包含 `wave-runner-2026-05/` 与 `p0-original-plant-blockers-2026-07/`（P0 原版植物阻塞项执行计划，2026-07-29 完成） |
| `draft/` | 未来方向草案区 |
| `visual-feedback-layer/` | 视觉反馈层设计讨论子目录 |

## 规则

1. 后续新增计划必须在本文件登记，注明状态（执行/讨论/归档候选）、用途说明、事实来源（关联 wiki 或代码）、是否可作为当前实现依据。
2. 归档计划统一进入 `archive/`，不留在根目录。
3. 设计讨论文档一旦被 wiki 正文替代或内容过时，应移至"归档候选"并最终归档。

---

### 新增计划登记格式

- 文件名：
- 状态：（当前执行 / 设计讨论 / 归档候选）
- 用途：
- 事实来源：
- 可作为当前实现依据：（是 / 否）
| `../docs/governance/2026-09-26-workspace-governance-implementation-plan.md` | 工作区治理体系实施计划 v2（阶段 0–4；裁决 D1–D9 全部落盘） | 治理设计 + 审查 + 裁决记录三文档（已迁根仓 docs/governance/） | 是（阶段 1、2 均可执行） |
