# 僵尸速度区间随机采样（Z-01）设计与落地

- 状态：已实施（2026-09-29，Batch J）
- 关联文件：`plans/original-zombie-protocol-gaps.md`（Z-01/Z-12/Z-18/Z-21）
- 创建日期：2026-09-29

## 原版依据（de-pvz `Zombie.cpp:1096-1155` PickRandomSpeed）

每次速度重采样（出生、状态切换）按类型/阶段从区间取值：

| 分支 | 区间/固定值 | 覆盖类型 |
|------|-------------|----------|
| 默认 | RandRange(0.23, 0.32) | 普通/路障/铁桶/纱门门/报纸(阅读)/鸭子圈/气球/小鬼(冒险)/巨人/红眼/投石车等全部未特判步行僵尸 |
| 快跑 | RandRange(0.66, 0.68) | 橄榄球/潜水/小丑/撑杆(起跳前)/矿工(挖掘中) |
| 搬梯 | RandRange(0.79, 0.81) | 梯子僵尸（PHASE_LADDER_CARRYING） |
| 狂暴/海豚落地 | RandRange(0.89, 0.91) | 报纸狂暴/海豚骑手落地步行 |
| 固定 0.45 | 旗子/舞王/伴舞/跳跳 | — |
| 固定 0.4 / 0.8 | Yeti 常速/逃跑 | — |
| 固定 0.12 / 0.3 | 矿工出土右行/海豚池中步行 | — |

数值口径沿用既有结论：mVelX 数值 ≈ slots/s（1 slot = 96px，原版 ~100 tick/s）。

## 设计

**区间表达**：任意速度参数 `key` 可携带 `key_min` / `key_max`（如 `move_speed_slots_per_sec_min/max`）。解析处（`MovementRegistry._resolve_slots_speed`、`zombie_root._resolve_move_speed`）遇区间键时，经 `GameState.resolve_ranged_value` 采样一次并替换为具体值再做单位换算。

**确定性**：复用既有种子派生设施——`derive_entity_seed(battle_seed, entity_id)` + `derive_mechanic_seed(entity_seed, "range_roll__<key>__<min>__<max>")`。同一实体同一键在 movement spec 与 bite 回退两条消费路径得到**同一采样值**（缓存于实体 meta），同 seed 复跑同结果。

**采样时机**：懒采样（首次消费时），不引入出生钩子；无区间键零开销（一次字典查询）。

**数据面**：archetype `default_params` 与 mechanic params（state set_movement、leap post_landing 等嵌套 spec）均可声明区间；`mechanic_compiler` 的 movement/bite merge 列表已透传区间键。具体值（区间中点）保留为兜底字面量，供导出属性与探针自省。

## 有意保留的近似

- **Zamboni 固定 0.25 起点**：Z-12 两段减速近似以 0.25 锚定（Batch G 核证），不随默认区间采样。
- **共享 bite 控制器 post-climb 0.25**：梯子翻越后步行原版应回到各僵尸自身速度，共享 mechanic 无法按 archetype 取值；0.25 在默认区间内，留精度项。
- **Z-18/Z-21 后续精确化**：撑杆跳跃距离公式、小丑按行走距离引爆，现在速度区间已落地，可在后续批次转精确语义。

## 验证

- 探针 `zombie_original_speed_range`：12 个同类 walker 采样全部落在 [0.23, 0.32] 且至少 2 个不同值（直接读生产路径缓存于实体的 roll）。
- 场景 `zombie_original_speed_range_validation`；formal map 组 `original_zombies_batch_j`。
- 报纸狂暴/海豚落地探针断言改为区间断言（0.89–0.91）。
