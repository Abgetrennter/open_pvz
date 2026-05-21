# 原版植物机制移植审查报告

- 日期：2026-05-12
- 范围：当前已实现的 `archetype_original_*` 植物、对应 `card_original_*`、机制资源和验证场景
- 原版依据：`vendor/de-pvz/ConstEnums.h`、`vendor/de-pvz/Lawn/Plant.cpp`、`vendor/de-pvz/Lawn/Plant.h`、`vendor/de-pvz/Lawn/Board.cpp`、`vendor/de-pvz/Lawn/Projectile.cpp`、`vendor/de-pvz/Lawn/SeedPacket.cpp`
- 非范围：动画、音效、reanim 资源、表现精度、外部 Wiki 资料

## 总体结论

当前已实现 46/49 个标准原版 seed 的植物资源与卡片资源，缺失项为 `Garlic`、`Umbrella Leaf`、`Imitater`。已实现内容基本完成了机制优先的资源化迁移，但仍有若干“能通过当前验证、尚未等价原版”的高风险项。

本次执行验证：

```powershell
pwsh -Command "& 'tools/run_all_validations.ps1' -Layers @('smoke','core') -MaxParallel 8"
```

结果：125 个 `smoke/core` 场景全部通过，失败 0 个。批次包含所有 `plant_original_*` 场景和 8 个 `original_*_garden` 场景。

关键发现：

- 卡片费用/冷却已整体对齐 `PlantDefinition gPlantDefs`；本轮已将 `Marigold` 冷却从 7.5s 修正为原版 30s。
- `Cob Cannon` 本轮已去掉错误的 `on_place` 爆炸替代，补上双 Kernel-pult footprint 和一次 manual aim 区域伤害；玉米炮 projectile 表现与原版装填时长精度仍需后续补齐。
- `Gold Magnet` 本轮已从“仅升级放置”推进到可通过共享经济路径收集 `coin_generated` collectible；银币/金币独立 source taxonomy 仍未展开。
- `Sun-shroom` 已补成长状态与成熟后生产值切换；长时长成熟输出仍建议后续用专门场景做精度断言。
- `Scaredy-shroom` 已补近敌缩回停火 liveness controller，并有专项验证覆盖。
- `Magnet-shroom` 以金属标签目标伤害替代吸附/卸甲语义；验证覆盖了目标过滤，但不是原版交互等价。
- `Kernel-pult` 使用 `shuffle_cycle` 替代原版每次攻击 1/4 概率黄油，机制可测但随机分布语义不同。
- `Spikeweed/Spikerock` 已接入持续地面伤害，但缺少对 Zomboni/Catapult 的原版特殊伤害与自损/死亡交互验证。

## 机制评分矩阵

状态含义：

- `通过`：核心机制、数值和验证与当前可表达的原版语义基本一致。
- `部分通过`：核心链路存在，但精度、特殊交互或验证覆盖不足。
- `协议缺口`：当前架构尚缺必要能力，不能视为已移植正常。
- `有意简化`：当前语义可玩且已验证，但不是原版完全复刻。

| 植物 | 状态 | 原版关键机制 | 当前实现与验证结论 |
|---|---|---|---|
| Peashooter | 通过 | 100 阳光，7.5s 冷却，1.5s 同行豌豆 | 费用/冷却/射击周期对齐；由 `plant_original_batch_a_validation` 覆盖。 |
| Sunflower | 通过 | 50 阳光，7.5s 冷却，约 24-25s 产阳光 | 生产周期使用区间参数表达；由批次 A 和生产 garden 覆盖。 |
| Wall-nut | 通过 | 4000 血，30s 冷却，防御占位 | 血量与冷却对齐；由批次 A 覆盖受击承伤。 |
| Snow Pea | 通过 | 豌豆伤害 + slow | 费用/冷却/周期对齐；frost payload 验证在批次 A 与 frost garden 中覆盖。 |
| Repeater | 通过 | 1.5s 周期双发 | 使用 burst emission；批次 A/E 覆盖伤害。 |
| Cabbage-pult | 通过 | 3s 抛物线卷心菜 | 费用/冷却/周期对齐；批次 A 覆盖命中。 |
| Melon-pult | 通过 | 3s 抛物线西瓜 + 范围伤害 | 当前 projectile terminal blast 覆盖核心 splash；批次 A 和 lobber garden 覆盖。 |
| Cherry Bomb | 部分通过 | 放置延迟后 3x3 爆炸 | on_place explode 已覆盖；爆炸半径使用当前世界单位近似，未单独断言原版 115px/邻行范围。 |
| Potato Mine | 部分通过 | 15s 武装，近身触发爆炸 | 武装状态和触发已验证；爆炸范围用当前半径近似，未覆盖跳杆/蹦极等原版特例。 |
| Squash | 有意简化 | 近身检测后跳砸单体/小范围 | 当前用 on_place/proximity 范围伤害表达，专项验证通过，但没有原版跳跃状态机。 |
| Jalapeno | 部分通过 | 整行火焰，清冰，50s 冷却 | 行爆炸已覆盖；清冰语义未见专项验证。 |
| Chomper | 部分通过 | 近身吞噬后长时间消化 | 已补 proximity devour、digesting 状态和消化停火验证；原版咀嚼动画/完整计时精度仍未纳入。 |
| Tall-nut | 通过 | 8000 血，高防御 | 血量/冷却对齐；批次 B 覆盖承伤。 |
| Pumpkin | 通过 | cover 层，4000 血 | cover role 与承伤覆盖存在；未审查 First Aid 重种特例。 |
| Puff-shroom | 通过 | 夜间醒，短射程，0 费 | 睡眠状态、醒来后短射程伤害已由批次 C 覆盖。 |
| Sun-shroom | 部分通过 | 小阳光，成长后普通阳光 | 已补 growth state 和按状态切换产出值；仍缺长时长成熟输出专项断言。 |
| Fume-shroom | 通过 | 夜间醒，穿透短中程喷雾 | direct damage + detected targets 覆盖穿透；专项验证通过。 |
| Grave Buster | 部分通过 | 只能放在墓碑，吞墓后消失 | 放置拒绝/接受和 blocker removal 已验证；原版吞噬延迟/掉落不是当前验证目标。 |
| Hypno-shroom | 部分通过 | 被吃后催眠僵尸 | team_switch 验证通过；未覆盖被吞食触发细节和所有僵尸相位。 |
| Scaredy-shroom | 部分通过 | 远程射击，近敌缩回停火 | 已补近敌 liveness 停火 controller 和专项验证；缩回视觉/恢复动画不在机制验收范围。 |
| Ice-shroom | 部分通过 | 全场冻结/减速，50s 冷却 | on_place + sleep gate 已覆盖批次 C；冻结持续、全体目标和表现状态需专项核对。 |
| Doom-shroom | 部分通过 | 大范围爆炸，留下 crater | 爆炸半径接近原版；crater/禁种持续机制未确认。 |
| Lily Pad | 通过 | 水面 support | 水格 support 放置由 `plant_original_water_pair_validation` 覆盖。 |
| Tangle Kelp | 部分通过 | 水中近身拖拽，击杀并自毁 | lethal consume 和 self consume 已验证；拖拽状态/水中特例仍是简化。 |
| Threepeater | 通过 | 三行发射 | multi_lane emission 由批次 D 覆盖。 |
| Spikeweed | 部分通过 | 地面持续伤害，特殊秒杀车辆后自毁 | ground_damage 已覆盖；Zomboni/Catapult 特殊交互未覆盖。 |
| Torchwood | 部分通过 | 改写经过豌豆为火豌豆并增伤 | projectile_transform 已验证基础 combo；火豌豆范围/视觉/多 projectile 细节未完全审查。 |
| Sea-shroom | 通过 | 水面、夜间、短射程，30s 冷却 | 水面放置、醒来和短射程伤害专项通过。 |
| Plantern | 有意简化 | 驱散雾区 | 当前 reveal hidden enemy 语义通过；未实现完整 fog/visibility 系统。 |
| Cactus | 部分通过 | 普通地面射击，遇气球升高攻击空中 | 已拆分空中/地面目标与 payload，验证覆盖空中 spike 和地面 pea 切换；升降表现状态仍简化。 |
| Blover | 部分通过 | 放置后吹走飞行单位 | air-only dispel 已验证；一次性动画延迟和具体飞行类过滤需继续核对。 |
| Split Pea | 通过 | 前一发、后一发双向攻击 | dual direction emission 专项通过。 |
| Starfruit | 通过 | 五方向星星 | multi_angle emission 专项通过。 |
| Magnet-shroom | 有意简化 | 吸附金属装备并冷却 | 当前以 metal tag targeting + direct damage 表达，验证通过但不是吸附/卸甲等价。 |
| Flower Pot | 通过 | 屋顶 support | roof support 放置和 primary placement 已专项验证。 |
| Kernel-pult | 部分通过 | 3s 抛投，1/4 黄油 stun | corn/butter payload 已验证；当前 shuffle_cycle 不等价原版独立随机概率。 |
| Coffee Bean | 通过 | 只能放在睡眠蘑菇上并唤醒 | targeted wake 和非法目标已专项验证。 |
| Marigold | 部分通过 | 30s 冷却，约 24-25s 产银/金币 | 卡片冷却和生产事件已验证；完整金币/银币经济仍简化为 `coin_generated` collectible。 |
| Gatling Pea | 通过 | Repeater 升级，四连发 | 升级依赖通过 `plant_original_e_upgrade_placement_validation`；批次 E 覆盖可用射击链路。 |
| Twin Sunflower | 通过 | Sunflower 升级，双阳光 | 升级依赖通过；生产链路由 production garden 覆盖。 |
| Gloom-shroom | 部分通过 | Fume-shroom 升级，周围 8 格多段喷雾 | 半径伤害和升级专项通过；睡眠继承/coffee 组合和四段打击精度需补验证。 |
| Cattail | 部分通过 | Lily Pad 升级，全场追踪，优先空中 | 已补全场追踪、空中优先和双发 burst 验证；原版更细的目标排序仍可继续核对。 |
| Winter Melon | 通过 | Melon-pult 升级，西瓜 splash + slow | 升级与 terminal blast/slow 路径已专项验证。 |
| Gold Magnet | 部分通过 | Magnet-shroom 升级，吸金币/银币 | 已补 `core.collectible_magnet`，覆盖 `coin_generated` collectible 收集；银币/金币细分 source taxonomy 尚未展开。 |
| Spikerock | 部分通过 | Spikeweed 升级，450 血，多段地刺，车辆特殊交互 | 升级和 ground_damage 专项通过；车辆特殊交互和自损未验证。 |
| Cob Cannon | 部分通过 | 两格 Kernel-pult 升级，手动瞄准，装填后发射玉米炮 | 已补双 Kernel-pult footprint、manual aim 区域伤害和 reload 状态值；仍缺玉米炮 projectile/飞行表现与原版装填时长精度。 |

## 数值和资源一致性

明确对齐：

- 46/46 个已实现卡片的费用和冷却与 `gPlantDefs` 一致。
- 防御植物血量对齐：Wall-nut/Pumpkin 为 4000，Tall-nut 为 8000，Spikerock 为 450。
- 主流攻击周期对齐：豌豆系 1.5s，蘑菇短射程 1.5s，抛投系 3.0s，Gloom-shroom 2.0s，Cattail 1.5s。

本轮已修正：

- `data/combat/cards/original/card_original_marigold.tres`：`cooldown_seconds` 已从 7.5 修正为 30.0，对齐原版 `SEED_MARIGOLD` 的 `3000` tick。
- `data/combat/archetypes/plants/archetype_original_goldmagnet.tres`：已绑定 `core.collectible_magnet`，通过共享经济路径收集 `coin_generated` collectible。

需要继续核算的近似值：

- 爆炸/近身半径当前多用 world unit 半径表达，原版使用像素矩形、半径和行范围混合判断。Cherry Bomb、Potato Mine、Squash、Chomper 这类植物需要逐个把原版判定换算成 slot/board metric 后再定精度结论。
- `Kernel-pult` 黄油概率当前由 `shuffle_cycle` 表达。若该机制是均匀洗牌，则会改变原版 `Sexy::Rand(4) == 0` 的独立随机分布。
- `Sun-shroom` 成长时间已按 120s 资源表达；现有 core 验证不等待完整 120s，建议另补可控时间推进或专门精度场景。

## 验证覆盖

强覆盖：

- 批次 A-E 均进入 `tools/validation_scenarios.json` 和 `tools/formal_content_validation_map.json`。
- 单植物专项已覆盖：Potato Mine、Squash、Chomper、Coffee Bean、Fume-shroom、Hypno-shroom、Sun-shroom、Scaredy-shroom、Scaredy-shroom cower、Sea-shroom、Split Pea、Starfruit、Cactus、Cactus switch、Blover、Magnet-shroom、Grave Buster、Tangle Kelp/Plantern、Kernel-pult、Marigold、Flower Pot、Gloom-shroom、Cattail、Cattail priority、Winter Melon、Spikerock、Gold Magnet、Cob Cannon。
- Garden 场景覆盖了 shooter、frost/control、lobber、production、mushroom、explosion、defense/support、special 组合回归。

弱覆盖：

- Cob Cannon 已有双格 footprint 和 manual aim 行为专项；弱项收敛为 projectile 表现、真实装填时长和更严格的重复发射/未 ready 拒绝验证。
- Gatling Pea、Twin Sunflower 主要由升级 placement 和 garden/批次场景间接覆盖，没有专门验证四连发/双阳光的单植物场景。
- 基础 A 批多为批次级覆盖，Peashooter、Sunflower、Wall-nut、Snow Pea、Repeater、Cabbage-pult、Melon-pult 没有“一植物一场景”的独立验收。
- Ice-shroom、Doom-shroom、Jalapeno 由批次覆盖，但缺少单独验证冻结持续、crater、清冰等特殊语义。

## 协议缺口和修复优先级

P0：

- Cob Cannon：已补双 Kernel-pult footprint、手动瞄准输入、reload 状态值和专项 validation；后续补玉米炮 projectile、真实装填时长和 ready 前拒绝验证。
- Gold Magnet：已补 `coin_generated` collectible 查询与收集能力；后续只剩银币/金币独立 source taxonomy 和更精细的吸附动画/飞行表现。
- Marigold：已修正卡片冷却为 30s，并由 `plant_original_marigold_validation` 断言。

P1：

- Sun-shroom：已补成长状态与 15 -> 25 阳光生产值切换；后续只剩长时长成熟产出精度验证。
- Scaredy-shroom：已补近敌缩回停火 liveness/state 和专项验证。
- Spikeweed/Spikerock：补 Zomboni/Catapult 特殊交互验证；Spikerock 应覆盖自损耐久。
- Chomper：已补消化状态与消化期间停火；后续核对消化时长精度和动画态。

P2：

- Kernel-pult：确认 `shuffle_cycle` 是否必须改为独立 1/4 黄油概率；若保留洗牌，应标为有意简化。
- Cattail：已补空中优先级、地面追踪、双发节奏验证；后续核对更细目标排序。
- Cactus：已补地面/空中切换验证；升降表现状态保持简化。
- Doom-shroom/Jalapeno/Ice-shroom：补 crater、清冰、冻结持续等精度验证。

## 建议新增验证

- `plant_original_cobcannon_validation`：已覆盖两格 Kernel-pult 升级、footprint 占用、manual aim 区域伤害和 reload 状态；后续扩展 ready 前不可发射与 cob projectile 断言。
- `plant_original_goldmagnet_validation`：已覆盖 Magnet-shroom 升级和 `coin_generated` collectible 收集；后续可扩展 coin/silver/gold 分型断言。
- `plant_original_marigold_validation`：已断言冷却 30s，避免卡片数值回退。
- `plant_original_sunshroom_growth_validation`：先产小阳光，成长后产普通阳光；当前资源已具备能力，仍建议补长时长精度场景。
- `plant_original_scaredyshroom_cower_validation`：已覆盖近敌时不射击；后续可扩展敌人离开后恢复。
- `plant_original_spike_vehicle_interaction_validation`：覆盖 Spikeweed 自毁、Spikerock 自损和车辆高伤害。
- `plant_original_cattail_priority_validation`：已覆盖同场地同时存在空中/地面目标时优先空中，且能追踪非本行目标。
- `plant_original_cactus_switch_validation`：已覆盖 Cactus 空中 spike 与地面 pea 两套目标链路。
