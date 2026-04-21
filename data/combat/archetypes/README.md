# Archetypes

> 该目录承载 `Mechanic-first` 重构阶段的顶层作者资源入口。

当前仍处于第一版骨架阶段：

- archetype 已可被 `SceneRegistry` 注册
- archetype 已可被 `BattleSpawnEntry` 解析
- archetype 已可被 `MechanicCompiler` 编译为最小 `RuntimeSpec`

当前实现仍然通过 backend entity template 复用旧运行时主链，因此这里的 archetype 主要用于：

- 验证新作者模型骨架
- 建立未来迁移目录
- 为后续 `Mechanic` family/type 正式落地预留资源入口

建议目录：

- `plants/`
- `zombies/`
- `projectiles/`
