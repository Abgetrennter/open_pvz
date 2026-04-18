# Phase 5 Chaos Pack

这个扩展包承接第五阶段里“扩展入口 + 错误技表达力”的正式验证。

当前内容包含：

- `split_projectiles`
  - 命中后分裂出新的追击投射物
- `spawn_entity`
  - 周期生成新实体
- `apply_status`
  - 命中后施加共享状态系统里的控制效果
- `knockback`
  - 命中后对目标施加最小受控位移
- `chain_bounce`
  - 命中后把伤害跳到附近目标并带伤害衰减
- `aura`
  - 周期扫描附近敌人并施加持续范围控制
- `delayed_trigger`
  - 命中后延迟一段时间再触发单体效果
- `delayed_explode`
  - 命中后延迟一段时间再结算范围爆炸
- `mark`
  - 命中后施加独立标记并在持续时间结束后移除
- `plant_extension_splitter`
  - 命中分裂型错误技样例
- `plant_extension_summoner`
  - 周期召唤型错误技样例
- `plant_extension_status_binder`
  - 状态控制型错误技样例
- `plant_extension_knockback_binder`
  - 击退控制型错误技样例
- `plant_extension_chain_bouncer`
  - 跳链伤害型错误技样例
- `plant_extension_aura_keeper`
  - 光环控制型错误技样例
- `plant_extension_delayed_caster`
  - 延迟触发型错误技样例
- `plant_extension_delayed_bomber`
  - 延迟爆炸型错误技样例
- `plant_extension_marker`
  - 标记型错误技样例

当前包的目标不是提供完整生态，而是证明：

- 扩展包可以新增 `EffectDef`
- 扩展包可以携带 effect `strategy`
- 扩展模板和扩展效果仍可复用主仓运行时主链
