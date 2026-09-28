# plans/ 计划入口

活动任务与下一动作以工作区 `tasks.json` / 生成的 `TASKS.md` 为准；本页只管理项目文档归属。计划中的历史勾选不自动证明当前主线已经实现。

## 当前事实与维护底账

| 文件 | 用途 |
|---|---|
| [original-plant-migration-ledger.md](original-plant-migration-ledger.md) | 植物内容与验证底账 |
| [original-plant-protocol-gaps.md](original-plant-protocol-gaps.md) | 已覆盖、部分覆盖和后置协议能力 |
| [original-zombie-protocol-gaps.md](original-zombie-protocol-gaps.md) | 僵尸侧协议缺口底账（Z-01~Z-36）；对应 design/zombie-content 任务 |
| [original-plant-mechanism-audit.md](original-plant-mechanism-audit.md) | 机制审计依据；外部事实通过知识回流处理 |
| [zombie-design-research-report.md](zombie-design-research-report.md) | 僵尸研究材料；原 vendor 路径按工作区 references/README.md 换算 |

## Reanim：集成与剩余校准

| 文件 / 位置 | 状态与下一步 |
|---|---|
| [reanim-native-migration-candidate-matrix.md](reanim-native-migration-candidate-matrix.md) | 原 M0 候选矩阵，保留来源与分批依据 |

Reanim 全量迁移（M0-M5）已于 2026-09-27 完成并归档：全量迁移计划、T0-T6 runtime 实施计划、ReanimData 设计草案与旧批量迁移方案移入 [archive/reanim-native-migration/](archive/reanim-native-migration/)。当前验收证据见 [集成记录](reanim-integration-2026-09-27.md) 与工作区 `docs/baselines/2026-09-27-reanim-m5/`；root_offset 精修视实际游戏场景反馈另起迭代。

## 设计讨论与候选方向

以下都是按需恢复的设计材料，不等于待实施承诺。工作区任务按主题登记为 idea 或 parked。

| 文档 | 对应主题 |
|---|---|
| [未来计划.md](未来计划.md) | 有性能/内容证据才启动的基础设施候选 |
| [输入交互层设计讨论.md](输入交互层设计讨论.md)、[UI 框架层设计方案.md](UI 框架层设计方案.md)、[draft/卡牌供给与行动栏代码结构设计草案.md](draft/卡牌供给与行动栏代码结构设计草案.md) | 输入/UI/行动栏 |
| [音频系统设计.md](音频系统设计.md) | 音频质量与覆盖 |
| [reanim资源转换工具链规划.md](reanim资源转换工具链规划.md) | 工具链历史推导；集成与 M5 校准已实测复用，保留推导记录 |
| [attack-chain-family-compile-path.md](attack-chain-family-compile-path.md) | 攻击链协议方向 |
| [draft/动态环境与天气系统设计草案.md](draft/动态环境与天气系统设计草案.md)、[draft/棋盘多样性与地形系统设计草案.md](draft/棋盘多样性与地形系统设计草案.md)、[draft/GridItem子系统设计草案.md](draft/GridItem子系统设计草案.md) | 棋盘、场地物件与环境 |
| [draft/汉字图像默认视觉身份系统草案.md](draft/汉字图像默认视觉身份系统草案.md) | 默认视觉身份 |
| [draft/原版机制未实现项盘点.md](draft/原版机制未实现项盘点.md) | 原版精确语义候选；先核对现有协议缺口底账 |

## 历史归档

见 [archive/README.md](archive/README.md)。已完成阶段记录、被替代的设计、旧 Agent 笔记与历史验证证据在该目录分类保留。原始资料不因重复而删除。视觉反馈层设计材料（任务包与两份父设计文档）已于 2026-09-28 归档至 [archive/visual-feedback-layer/](archive/visual-feedback-layer/README.md)；协议现状见 [wiki 19 页](../wiki/02-runtime-protocol/19-视觉反馈层.md)。

新增计划须在本索引登记状态、用途及对应任务；完成后将耐久规则写入 Wiki，将阶段记录归档。工作区治理文档在工作区根 `docs/governance/`，不在公开引擎仓复制。

本次集成验收见 [Reanim 集成记录](reanim-integration-2026-09-27.md)。新增的 [工作区治理历史草案](draft/公开引擎受限素材与worktree治理草案.md) 仅作推导记录，当前规则以工作区根合同为准。
