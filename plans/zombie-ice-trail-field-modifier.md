# 冰道场地修改器（Z-11）最小设计

- 状态：已实施（2026-10-01，冰道批次：Z-11/Z-14/G-29 一并落地；实施偏差见文末附记）
- 关联文件：`plans/original-zombie-protocol-gaps.md`（Z-11/Z-14）、`plans/original-plant-protocol-gaps.md`（G-29）
- 创建日期：2026-09-29

## 原版依据（de-pvz `Zombie.cpp:3908-3938` UpdateZombieZomboni + Plant.cpp 车辙）

- 冰道是**行级连续 x 区间**，不是逐格物件：Zamboni 经过处 `[mIceMinX, mPosX]` 结冰，`mIceTimer` 3000 ticks 续期；区间随车前进扩展，超时整段消退。
- 冰上效果：僵尸行走速度减半（`Zombie::GetSpeedModifier` 冰面判定）；Zamboni 自身不受影响；植物在冰道上照常（PvZ1 无植物侧效果）。
- Bobsled 依赖：只能在冰道上生成/滑行，脱离冰道减速并弃橇。
- 坑洞（G-29 Doom-shroom）语义同构：行级/格级持续地形，带计时器与占据语义（坑洞占格阻挡种植，冰道不占格只改速度）。

## 现状基座

- GridItem 子系统（Batch I 落地）提供**格级**物件：placement role、tag 派生、放置/移除事件、`get_grid_item_at(lane, slot)` 查询、`remove_grid_item_tags` 火清。
- 慢速目前只有实体级 status（movement_scale），无任何行级/区间级效果。
- Zamboni 已有 `core.drive` 位置驱动减速（Z-12）。

## 最小设计（一条 BoardFieldModifier 通道，两种实例）

1. **新子系统 `battle_field_state`**（仿 grid_item_state）：`apply_modifier(lane_id, kind, x_min, x_max, duration, source)` / `tick` 续期与超时移除 / `query(lane_id, x)` → 命中的 modifier 列表 / 事件 `field.modifier_applied|expired`。不占 slot role、不进 spatial index（非实体）。
2. **kind: `ice_trail`**：Zamboni `core.drive` 每步调用 `apply_modifier` 扩展当前行区间（幂等续期，3000 ticks ≈ 30s）。移动侧在 `core.walk`/`core.drive` 计算速度时 `query` 本格，命中 `ice_trail` 且 owner 非车辆时 speed ×0.5。
3. **kind: `crater`（G-29 复用）**：Doom-shroom 爆炸对行内格区间 apply，`crater` 额外占据 blocker role 阻挡种植（映射到既有 slot 机制，不新建占据系统）。
4. **Bobsled 消费面（Z-14，届时实施）**：spawn 条件 query `ice_trail`；脱离冰道触发弃橇状态。

## 边界与不做

- 不做渲染层（冰面贴图随视觉层任务）。
- 不做植物侧冰面效果（原版无）。
- 不给 GridItem 加区间概念——格级需求继续走 GridItem，行级区间才走 field modifier，两通道并存不合并。

## 验证口径（实施时）

- 行为级场景：Zamboni 过境后同 lane 后续僵尸速度减半、跨 lane 对照不变、3000 ticks 后消退。
- G-29 联动：Doom-shroom 后目标格不可种植。

---

## 实施附记（2026-10-01）

- 落地形态与设计一致：`scripts/battle/battle_field_state.gd` 单区间/行级计时器、`apply_modifier`/`renew_lane_modifier`/`query`/`get_ice_trail_speed_scale`、事件 field.modifier_applied|expired；Zamboni `lay_ice_trail` 3000 ticks；walk 与 bite 回退两路 ×0.5，vehicle 豁免。
- 偏差 1：crater 未走 field modifier 通道，按本文"边界与不做"条款改走 GridItem（`archetype_crater` + explode `crater_at_source_slot` + `schedule_expiry` 寿命）——格级需求归 GridItem。
- 偏差 2：Bobsled 续冰实现为 `ice_renewal_ticks`（只刷新已有冰道计时、不扩区间），比设计的"槽位 span 续期"更贴原版行全局 mIceTimer 语义。
- 新增触发器 `core.when_layer_destroyed`（health.layer_destroyed + required_layer_id）承载橇坏解体，替代设计中留白的"Bobsled 消费面"触发机制。
