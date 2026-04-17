# Phase 5 Chaos Pack

这个扩展包承接第五阶段里“扩展入口 + 错误技表达力”的正式验证。

当前内容包含：

- `split_projectiles`
  - 命中后分裂出新的追击投射物
- `spawn_entity`
  - 周期生成新实体
- `plant_extension_splitter`
  - 命中分裂型错误技样例
- `plant_extension_summoner`
  - 周期召唤型错误技样例

当前包的目标不是提供完整生态，而是证明：

- 扩展包可以新增 `EffectDef`
- 扩展包可以携带 effect `strategy`
- 扩展模板和扩展效果仍可复用主仓运行时主链
