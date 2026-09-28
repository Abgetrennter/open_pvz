# vendor 参考实现：游戏模式系统分析

> **reference_only（2026-09-28，P3.8b）**：本文主体（第 1-9 节，Godot-PVZ / PVZ-Godot-Dream 模式实现事实）已迁移至知识层主文档：
>
> **E:/Code/pvz-ws/knowledge/external-gamemode-implementations.md**（页面 ID external/gamemode-implementations）
>
> 本页只保留第 10 节「对 Open PVZ 的架构迁移启示」（项目层设计推论）。关联子系列 pvz-godot-dream/（5 篇 PGD 架构分析）经同一判据判定为知识层候选，尚未迁移，迁移前仍在本目录维护。

---

## 10. 对 Open PVZ 的架构迁移启示

### 10.1 PVZ-Godot-Dream 的设计优点

1. **完全数据驱动**：所有模式参数通过 `ResourceLevelData` 的 `@export` 在编辑器中配置，无需改代码
2. **高度复用**：僵尸模式复用植物卡牌系统、大脑复用 `sun_cost`、手持管理器统一处理植物/僵尸放置
3. **Alias Method O(1) 采样**：传送带卡片随机池性能优秀
4. **碎片物理轻量级**：重力+弹跳+旋转衰减，无物理引擎依赖

### 10.2 PVZ-Godot-Dream 的设计问题

1. **散弹枪修改**：`is_zombie_mode` 布尔开关散布在 20+ 个文件中，修改一个模式需要检查所有相关文件
2. **巨类 Resource**：`ResourceLevelData` 承载了 8 个参数组、数十个字段，职责过重
3. **布尔组合爆炸**：模式差异通过大量布尔开关的组合表达，缺少正交分类
4. **运行时 if 链**：`MainGameManager` 中大量 `if is_zombie_mode` / `if is_pot_mode` 分支

### 10.3 Open PVZ 的 Mechanic-first 架构优势

Open PVZ 的 Mechanic-first 架构天然适合解决上述问题：

| PVZ-Godot-Dream 方式 | Open PVZ 方式 |
|---------------------|---------------|
| `is_zombie_mode` 散布 20+ 文件 | Mechanic 组合在编译时一次性注入 |
| 运行时 `if is_pot_mode` | `PotMechanic` 编译为 `RuntimeSpec` 的一部分 |
| 卡槽策略 switch | `CardSlotStrategy` 注册表分发 |
| `game_round = -1` + `curr_round` 比较 | `BattleFlowState` 阶段机扩展循环 |

### 10.4 推荐的模式抽象

```
GameModeDefinition : Resource
  ├── mode_id: StringName
  ├── category: ModeCategory         # adventure / survival / challenge / puzzle
  ├── scene_type: SceneType          # front / back / roof
  ├── seed_strategy: SeedStrategy    # choose / conveyor / fixed / none
  ├── zombie_wave_policy: WavePolicy # fixed / dynamic / survival
  ├── stage_policy: StagePolicy      # single / multi / endless
  ├── win_condition: WinCondition    # all_zombies_dead / all_brains_eaten / all_pots_open
  ├── grid_items: GridItemDef[]      # 罐子/大脑/传送门/墓碑
  ├── mechanics: Mechanic[]          # 模式专属 Mechanic 组合
  └── special_rules: Resource        # 模式特定参数（保龄球/锤子等）
```

各模式差异封装为不同 Mechanic 组合，通过 Archetype 编译链一次性注入，运行时无需检查布尔标志。

### 10.5 关键迁移要点

1. **罐子系统**：需要新的 Mechanic family 或 Entity 子系统，罐子作为 GridItem 存在而非 PlantCell 特殊状态
2. **僵尸放置**：`EntityFactory` 已支持双路径实例化，扩展为支持"从种子栏放置僵尸"
3. **传送带**：需要 `CardSlotStrategy` 接口 + Alias Method 随机池
4. **多轮循环**：`BattleFlowState` 阶段机扩展，`WaveRunner` 增加轮次递增和强度缩放
5. **存档**：需要跨轮次的状态快照/恢复机制
