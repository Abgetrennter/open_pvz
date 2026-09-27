# OpenPVZ 公开引擎、受限素材与 worktree 治理草案

- 日期：2026-08-21
- 状态：设计讨论，不是当前实现依据
- 目标：在不引入公开/私有投影的前提下，收敛素材发布分类、双仓依赖、worktree 隔离与工具职责。
- 相关文档：
  - [扩展包边界与依赖规则](../../wiki/04-roadmap-reference/43-扩展包边界与依赖规则.md)
  - [素材包系统与本地私有包](../../wiki/04-roadmap-reference/44-素材包系统与本地私有包.md)
  - [扩展包 Manifest 规范](../../wiki/04-roadmap-reference/45-扩展包Manifest规范.md)
  - [项目开发方法论](../../wiki/05-governance/27-项目开发方法论.md)

## TL;DR

OpenPVZ 保持一个公开产品真相源，另以一个可选的受限素材仓保存原版素材及其派生物，不做公开/私有投影。是否可公开由权利来源与许可决定，不由 `.reanim` 等文件格式决定。

worktree 采用“共享只读、隔离可写”原则：SDK 可以物理共享，参考项目以各 worktree 固定的只读 checkout 为准，受限素材在纯消费时可挂载共享干净 checkout，但只要任务会写入素材，就必须为该任务配对独立的私有素材 worktree。

## 一句话方向

> 以公开 OpenPVZ 契约统一 SDK、参考项目和素材包的逻辑入口，但只共享不受任务修改的内容，对所有可写产物保留 worktree 级隔离。

## 背景与问题

OpenPVZ 已经具备正确的大部分基础：

- 主仓可在缺少 `local_extensions/` 时运行。
- `classic_original_assets` 已是被忽略的嵌套 Git 仓库。
- `asset_index.json` 和 `AssetRegistry` 已将逻辑表现 ID 与真实素材路径分离。
- `local_private` 验证层与公开发布守卫已存在。
- `.codex/scripts/setup_openpvz_worktree.ps1` 已能解析 Godot、初始化参考子模块并通过 junction 挂载私有素材。

当前混乱集中在三点：

1. “素材包”容易被误解为“私有包”，实际上素材格式与发布权利是两个维度。
2. 现有 `link` 模式同时覆盖只读消费和可写导入，无法表达 worktree 隔离意图。
3. SDK、参考项目、私有素材和导入产物都被统称为“公用内容”，但它们的可写性、版本定位和发布边界完全不同。

## 非目标

本草案不：

- 将私有开发仓投影或导出为公开仓。
- 设计元项目或跨项目通用治理平台。
- 在公开仓中记录私有远端 URL、本机绝对路径或必需的私有 commit。
- 以“私有 Git 仓”代替权利授权审查。
- 修改 Mechanic-first 运行时、冻结 Mechanic family 或扩展注册协议。
- 在本草案阶段创建远端仓、迁移文件或改造脚本。

## 当前事实与目标模型对照

| 来源 | 当前事实 | 本草案的处理 |
|------|----------|------------------|
| OpenPVZ 素材包文档 | 已区分 `public` 与 `local_private`，原版素材及派生物不可进公开发布物 | 保留两个最终发布策略，另增加发布前审核状态，不将所有 asset pack 等同于私有包 |
| `classic_original_assets/extension.json` | 已标记 `local_private`、`contains_original_assets = true`、`generated_from_private_source = true` | 继续作为受限素材仓，不反向影响公开主仓的可运行性 |
| worktree setup 脚本 | 私有素材支持 `none/check/link` | 将挂载拓扑明确为 `none/shared_read/paired_write`，`check` 改为校验动作 |
| Git submodule | 默认初始化 `de-pvz` 与 `PVZ-Godot-Dream`，`full` 则初始化全部 | 保留按 gitlink 固定版本的每 worktree checkout，不通过 junction 共用可变 vendor 工作目录 |
| EA 公开内容政策 | 格式中立不等于内容可自由分发，同人项目和游戏内容使用仍受限 | 采用保守默认值，权利不明的素材不进公开发布物 |

EA 政策引用：[EA's content policy](https://help.ea.com/en/articles/security-and-rules/ea-content-policy/)。本草案只定义工程默认边界，不对具体素材作法律结论。

## 素材分类模型

### 两个最终发布策略

manifest 仍保留现有两种可执行发布策略：

- `public`：可进入公开 Git、CI 和发布物。
- `local_private`：只在本地或受控私有环境消费，不进公开发布物。

### 两个治理状态

以下是仓库收录前的治理状态，不是运行时 manifest 新枚举：

- `restricted_pending_review`：权利来源、衍生关系或发布许可尚未审核完成；审核前按 `local_private` 处理。
- `ephemeral`：缓存、`.import`、临时报告、实验输出；不进任何源码或素材仓历史。

### 决策表

| 素材 | 默认策略 | 公开前最小证据 |
|------|----------|------------------|
| 项目自有原创素材 | `public` | 作者与项目许可记录 |
| 第三方原创素材 | `restricted_pending_review` | 许可文本、作者、来源、署名与修改/再分发权利 |
| 基于 PVZ 角色或原美术的同人素材 | `restricted_pending_review` | 不只审核素材作者许可，还需评估底层 IP 与项目发布方式 |
| EA/PopCap 原版素材 | `local_private` | 不进公开发布物 |
| 由原版素材生成的 actor、贴图、音频或报告 | `local_private` | 不因格式转换改变发布边界 |
| Godot 缓存和可重建临时产物 | `ephemeral` | 必须可从已记录输入重建 |

`.reanim`、`.tres`、`.tscn` 和 `.png` 只是容器或运行时格式，不作为发布授权证据。

## 仓库拓扑与依赖方向

### 公开产品仓 `open_pvz`

作为唯一产品真相源，包含：

- Godot 引擎与 Mechanic-first 运行时。
- 公开扩展契约、素材索引规范和导入器。
- 验证、发布守卫和 worktree 环境工具。
- 项目 wiki、ADR、计划和不含私有来源细节的项目知识。
- 自有原创或经证据确认可公开的素材包。
- 无私有素材时的合法占位与回退表现。

公开仓不得要求某个私有 URL、本机路径或私有 commit 才能启动、验证或发布。

### 受限素材仓 `classic_original_assets`

作为可选 asset pack，包含：

- 受限原始输入。
- 由这些输入产生的运行时 actor、profile、FX 和音频。
- 不适合进入公开仓的来源溯源、输入哈希和导入报告。
- `extension.json` 与 `asset_index.json`。
- 与 OpenPVZ 素材契约的兼容声明。

依赖方向固定为：

```text
classic_original_assets -> OpenPVZ 公开素材契约

OpenPVZ -X-> 私有仓 URL / 路径 / commit
```

两个仓分别提交和发布，不做自动投影、双向复制或粗粒度 allowlist 导出。

### 外部参考项目

- 参考项目仍属于上游仓，不并入两个自有仓。
- 每个 OpenPVZ worktree 以当前 gitlink 为版本真相，保持 checkout 只读。
- 可以在 Git 对象库或缓存层复用下载，但不让多个任务通过 junction 共用一个可变 vendor 工作目录。
- 受限原素材不应继续从 `vendor/out_files` 进入正式运行链，其正式边界是私有素材仓。

## worktree 拓扑

### 可以共享的内容

| 对象 | 共享方式 | 条件 |
|------|----------|------|
| Godot SDK | 所有 worktree 共享同一安装目录 | 项目工具只读 SDK |
| Git 对象与上游下载缓存 | Git 自身复用 | 各 worktree 仍保持独立 checkout |
| 干净的私有素材 checkout | `shared_read` 挂载 | 任务不调用任何导入或生成命令 |

### 必须隔离的内容

- OpenPVZ 受 Git 跟踪的代码、文档和数据。
- 私有素材仓的 `sources/`、`generated/`、`data/` 和 `asset_index.json`。
- `.godot/`、验证 artifacts、临时报告与导入中间产物。
- 任何会被当前任务工具改写的 checkout。

### 三种素材挂载模式

#### `none`

- 不挂载受限素材。
- 是公开仓开发、公开 CI 和发布验证的默认模式。
- 公开 smoke 必须在此模式通过。

#### `shared_read`

- 将 `local_extensions/classic_original_assets` 挂载到一个干净、只用于消费的私有素材 checkout。
- 适用于运行演示、查看视觉和执行不生成素材的 `local_private` 验证。
- junction 本身不能强制只读；因此写入型工具必须显式拒绝在此模式执行。
- 共享源必须保持干净；一旦发生写入，就失去跨 worktree 共享资格。

#### `paired_write`

- 当前 OpenPVZ 任务 worktree 挂载一个同任务私有素材 worktree。
- 适用于 Reanim 导入、actor 生成、profile 调整、索引重建和素材报告更新。
- 每个可写任务必须拥有唯一的私有素材 worktree 和分支。
- 不允许 `shared_write`；两个任务不能对同一私有 checkout 生成或修复素材。

示意：

```text
task-a/
├── openpvz/                         # 公开仓 worktree
└── classic-original-assets/          # 私有仓 worktree
    ↑
    └── openpvz/local_extensions/classic_original_assets
        通过 junction 挂载
```

## 工具职责

| 工具 | 唯一职责 | 禁止事项 |
|------|----------|----------|
| worktree setup | 解析 Godot、初始化指定参考子模块、校验并挂载已选素材 checkout | 不自动选择、提交、合并或推送任何分支 |
| task/worktree creator（如后续需要） | 创建任务的公开 worktree，并在 `paired_write` 时创建对应的私有 worktree | 不处理素材导入和 Git 发布 |
| Reanim importer/generator | 从显式输入生成显式 `pack_root` 下的产物 | 不自动跨 worktree 搜索或选择可写素材仓 |
| validation | 消费当前 OpenPVZ checkout 及其挂载包，将报告写入当前 worktree `artifacts/` | 不把验证成功扩大为权利授权或视觉人工验收 |
| public release guard | 仅审查公开候选树的受限素材、私有路径和缓存泄漏 | 不读取或复制私有仓正文 |
| Git | 两仓各自管理历史 | 不默认执行跨仓提交、合并或推送 |

### setup 模式的最小改造方向

现有环境变量可保留，但将其语义收敛为：

```text
OPENPVZ_PRIVATE_ASSET_PACK_MODE=none|shared_read|paired_write
OPENPVZ_PRIVATE_ASSET_PACK_SOURCE=<已选 checkout 的绝对路径>
OPENPVZ_PRIVATE_ASSET_PACK_TARGET=local_extensions/classic_original_assets
```

`check` 变为一个独立校验行为，检查：

- target 是否存在并指向期望 source。
- source 是否为 Git 工作树。
- `shared_read` 的 source 是否干净。
- `paired_write` 的 source 是否与其他活跃任务冲突。

是否新增单一的 ignored 本机配置文件，留待实施计划决定。在此之前，脚本参数与 `OPENPVZ_*` 环境变量已足以承载最小方案。

## 项目知识边界

项目 wiki 继续放在公开 OpenPVZ 仓，因为它是引擎与开发方法的真相源。

以下内容才进入私有素材仓：

- 受限原始文件的精确目录、名称和哈希。
- 不可公开来源的导出方式、输入清单和比对报告。
- 含受限视觉或音频快照的验证证据。

公开 wiki 可保留不含私有细节的稳定事实，例如逻辑表现 ID、导入契约、失败分类与验证流程。

## 跨仓任务与证据单

双仓任务不需要分布式事务，只需在验收时记录最小证据单：

```text
task_id
openpvz_commit
private_asset_commit           # 仅双仓任务需要
asset_contract_version
godot_version
validation_profiles
validation_result
manual_visual_result           # 如适用
known_limitations
```

证据单不自动修改、提交、合并或推送任何仓库。公开证据不记录私有 URL、本机路径或受限文件名；如需完整溯源，由私有仓内的 provenance 记录承担。

## 缺口分类

| 类型 | 当前缺口 |
|------|----------|
| 概念 | 素材格式、素材权利和包发布策略尚未明确解耦 |
| 协议 | `link` 未声明只读/可写意图；写入型工具也未以挂载模式作为前置条件 |
| 实现 | 尚无成对创建产品/素材 worktree 的最小流程 |
| 验证 | 尚未验证 `shared_read` 不污染素材仓、`paired_write` 只写当前配对 worktree |
| 内容 | 尚无公开同人/第三方素材的许可证据模板 |
| 治理 | 公开 wiki 与私有 provenance 的详细分界尚未写入正式规范 |

## 验证思路

实施后至少建立以下验证：

1. **Public clean-clone**：全新公开 checkout 不存在 `local_extensions/` 时，公开 smoke 和发布守卫通过。
2. **Shared-read cleanliness**：运行指定的只读 `local_private` 验证前后，私有素材 checkout 状态不变。
3. **Writer mode guard**：Reanim 导入/生成命令在 `none` 或 `shared_read` 模式下明确失败，在 `paired_write` 下只修改当前配对素材 worktree。
4. **Public boundary guard**：公开候选树不含原版素材、原版派生物、`local_extensions` 引用、私有绝对路径或 junction 对象。
5. **Cross-repo receipt**：双仓变更的验收记录能精确定位两个 commit、Godot 版本和验证结果，但不泄漏私有路径。

## 分阶段路线

### M0：决策固化

- 评审本草案。
- 决定同人素材的审核证据与官方发布默认值。
- 决定受限素材仓采用私有远程还是仅本地保管。

### M1：正式文档对齐

- 修订素材包文档，明确“asset pack 不等于 private pack”。
- 在 manifest 规范中保留 `public/local_private` 最终策略，补充审核状态的文档边界。
- 在项目方法论中补充双仓任务和证据单规则。

### M2：worktree 挂载语义

- 将 `none/check/link` 收敛为 `none/shared_read/paired_write` 与独立 check 动作。
- 让所有写入型 Reanim 工具要求显式 `paired_write` 与 `pack_root`。
- 补充共享干净度和配对 worktree 前置检查。

### M3：验证与发布门禁

- 落地 public clean-clone、shared-read cleanliness 和 writer mode guard。
- 扩展公开发布守卫，覆盖绝对路径、junction、缓存和受限派生物。
- 确定证据单的产出位置与保留策略。

### M4：仓库整理与发布

- 在分别审计公开主仓和受限素材仓的 dirty 状态后分批提交。
- 先从无私有素材的全新 checkout 验证公开仓。
- 再挂载受限素材验证 `local_private` 路径。
- 远端创建、可见性设置和推送仍需单独明确授权。

## 待决策问题

1. `classic_original_assets` 是否应推送到私有远端，还是只保留本地 Git 与受控备份？
2. 对基于 PVZ 角色的同人素材，OpenPVZ 官方索引是否统一采取“只记录外部来源，不随项目分发”的更保守策略？
3. `paired_write` 的私有 worktree 由任务创建工具统一创建，还是 setup 只负责挂载用户已创建的 worktree？
4. 证据单是仅作为本地 artifacts，还是以不含私有细节的摘要进入公开任务记录？
5. 是否需要一个 ignored `openpvz.local.json` 作为本机 SDK/私有素材路径的单一入口，还是继续仅使用现有环境变量？

## 建议评审结论

如果上述方向获得确认，下一步应将 M1–M3 转换为实施计划，再修改正式 wiki 和脚本。在此之前，本草案不改变现有 `local_private` 协议、工具参数或仓库发布方式。
