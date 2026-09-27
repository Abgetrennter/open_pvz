# plans/ 计划入口

活动任务与下一动作以工作区 `tasks.json` / 生成的 `TASKS.md` 为准；本页只管理项目文档归属。计划中的历史勾选不自动证明当前主线已经实现。

## 当前事实与维护底账

| 文件 | 用途 |
|---|---|
| [original-plant-migration-ledger.md](original-plant-migration-ledger.md) | 植物内容与验证底账 |
| [original-plant-protocol-gaps.md](original-plant-protocol-gaps.md) | 已覆盖、部分覆盖和后置协议能力 |
| [original-plant-mechanism-audit.md](original-plant-mechanism-audit.md) | 机制审计依据；外部事实通过知识回流处理 |
| [zombie-design-research-report.md](zombie-design-research-report.md) | 僵尸研究材料；原 vendor 路径按工作区 references/README.md 换算 |

## Reanim：分支成果尚待集成

| 文件 / 位置 | 状态与下一步 |
|---|---|
| [original-plant-visual-bulk-migration-plan.md](original-plant-visual-bulk-migration-plan.md) | 旧批量迁移方案；与分支全量 native 方案对照后再归档，勿重复执行 |
| [reanim-native-runtime-implementation-plan.md](reanim-native-runtime-implementation-plan.md) | 主线仍保留旧计划快照；T0–T6 完成记录在 feature/private-assets，不能提前将主线标成完成 |
| [draft/reanim原生运行时ReanimData方案设计草案.md](draft/reanim原生运行时ReanimData方案设计草案.md) | 与运行时计划一同等待集成验收后归档 |
| `feature/private-assets:plans/reanim-native-full-original-plant-migration-plan.md` | M0–M4 分支成果，M5 GUI 校准/性能基线/归档未完；工作区任务 reanim-visual/integrate-native 与 reanim-visual/m5-archive |
| `feature/private-assets:plans/reanim-native-migration-candidate-matrix.md` | 分支候选矩阵，主线尚无该文件；从分支读取，不当作失效本地链接 |

## 设计讨论与候选方向

以下都是按需恢复的设计材料，不等于待实施承诺。工作区任务按主题登记为 idea 或 parked。

| 文档 | 对应主题 |
|---|---|
| [未来计划.md](未来计划.md) | 有性能/内容证据才启动的基础设施候选 |
| [视觉表现层设计讨论.md](视觉表现层设计讨论.md)、[Open PVZ 视觉反馈层设计与路线图.md](Open PVZ 视觉反馈层设计与路线图.md)、[visual-feedback-layer/](visual-feedback-layer/README.md) | 视觉阶段与现状对照 |
| [输入交互层设计讨论.md](输入交互层设计讨论.md)、[UI 框架层设计方案.md](UI 框架层设计方案.md)、[draft/卡牌供给与行动栏代码结构设计草案.md](draft/卡牌供给与行动栏代码结构设计草案.md) | 输入/UI/行动栏 |
| [音频系统设计.md](音频系统设计.md) | 音频质量与覆盖 |
| [reanim资源转换工具链规划.md](reanim资源转换工具链规划.md) | 工具链历史推导，随 Reanim 集成复核 |
| [attack-chain-family-compile-path.md](attack-chain-family-compile-path.md) | 攻击链协议方向 |
| [draft/动态环境与天气系统设计草案.md](draft/动态环境与天气系统设计草案.md)、[draft/棋盘多样性与地形系统设计草案.md](draft/棋盘多样性与地形系统设计草案.md)、[draft/GridItem子系统设计草案.md](draft/GridItem子系统设计草案.md) | 棋盘、场地物件与环境 |
| [draft/汉字图像默认视觉身份系统草案.md](draft/汉字图像默认视觉身份系统草案.md) | 默认视觉身份 |
| [draft/原版机制未实现项盘点.md](draft/原版机制未实现项盘点.md) | 原版精确语义候选；先核对现有协议缺口底账 |

## 历史归档

见 [archive/README.md](archive/README.md)。已完成阶段记录、被替代的设计、旧 Agent 笔记与历史验证证据在该目录分类保留。原始资料不因重复而删除。

新增计划须在本索引登记状态、用途及对应任务；完成后将耐久规则写入 Wiki，将阶段记录归档。工作区治理文档在工作区根 `docs/governance/`，不在公开引擎仓复制。
