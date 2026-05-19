# OpenPVZ 文档治理降噪计划

## 摘要

目标是降低 `wiki/`、`plans/`、`wiki/decisions/` 的方法论维护成本，同时保留当前架构纪律、ADR 决策边界和验证优先原则。

本轮只做低风险治理收口：**不移动现有文件、不改架构事实、不重写历史文档**。通过压缩入口、改软 ADR 回写规则、补 `plans/README.md` 和文档健康检查，把“人工同步负担”转为“按影响更新 + 脚本提示”。

## 关键变更

- 精简 `agent.md`
  - 将 `Default Read Order` 从 10 篇必读改为 3 篇默认入口：
    - `wiki/01-overview/03-15分钟上手路径.md`
    - `wiki/01-overview/23-当前阶段与实现路线.md`
    - `wiki/02-runtime-protocol/11-编译链与Mechanic系统.md`
  - 其余文档改为按任务类型读取：runtime、validation、extension、content、visual/audio/ui、governance。
  - 保留“重大变更前查对应协议/验证文档”的要求，但取消默认全量阅读。

- 调整 ADR 回写规则
  - 修改 `wiki/index.md` 与 `wiki/05-governance/29-文档规范与维护约定.md`。
  - 将“任何新 ADR 必须回写至少一篇正文 + 一篇运行时/验证文档”改为：
    - ADR 必须填写影响范围。
    - 只有影响当前事实、路线、协议、验证、术语或目录结构时，才回写对应文档。
    - 若无需回写，必须在 ADR 后续动作中写明“无需回写原因”。
  - 更新 `wiki/05-governance/31-重大决策记录模板.md`，在模板中加入“文档影响矩阵”。

- 梳理 `plans/`
  - 新增 `plans/README.md` 作为唯一计划入口。
  - 将根目录现有计划按状态登记，不移动文件：
    - 当前执行/维护：如原版植物迁移底账、协议缺口、未来计划。
    - 设计讨论：视觉、输入、音频、UI、reanim、错误技等。
    - 历史/待归档候选：已明显完成或被 wiki 正文替代的计划。
  - 明确规则：后续新增计划必须带状态、用途、事实来源、是否可作为当前实现依据。

- 新增文档健康检查
  - 新增 `tools/check_docs_health.ps1`。
  - 检查内容：
    - `agent.md` 默认必读列表是否超过 5 项。
    - `wiki/decisions/README.md` 是否漏列 ADR 文件。
    - `wiki/index.md`、治理页、`plans/README.md` 中的本地 Markdown 链接是否失效。
    - `plans/draft/extension-system/README.md` 是否漏列同目录草案。
    - `plans/archive/wiki-retired/` 是否存在未在退役索引登记的 Markdown。
  - 默认只输出 warning，不阻断开发；后续可再接入 guardrail。

## 测试计划

- 运行文档健康检查：
  - `pwsh tools/check_docs_health.ps1`
- 手动核对：
  - `agent.md` 默认阅读路径不超过 3 个核心入口。
  - `wiki/index.md` 和 `29-文档规范与维护约定.md` 不再包含“任何新 ADR 必须同步回写至少一篇当前正文和一篇运行时/验证文档”的硬规则。
  - `plans/README.md` 能清楚判断根目录每份计划是否是当前事实、执行计划、设计讨论或归档候选。
- 不需要运行 Godot 验证；本计划只改文档治理和检查脚本，不影响运行时。

## 假设与默认选择

- 本轮不移动、删除或批量重命名 Markdown 文件，避免引入链接破坏和高风险文件操作。
- `wiki/decisions/` 继续保留为 ADR 原文区，不合并进正文。
- `plans/archive/`、`plans/draft/`、`plans/archive/wiki-retired/` 的现有结构暂时保留；先通过 `plans/README.md` 降低认知成本。
- 文档健康检查只做提示，不作为强制 CI 门禁，避免把治理成本立刻转化为开发阻塞。
