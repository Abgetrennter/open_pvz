# 07-Phase 0 实现对照与差距清单

- 状态：Phase 0 盘点结论（2026-09-28）
- 方法：全部结论来自仓库实测（文件存在性、代码结构、验证 manifest），未使用推测
- 结论一句话：**视觉反馈层的协议/注册/宿主/验证骨架已全部实现且部分超出任务书；真实剩余差距只有 4 项，其中仅 2 项值得立执行计划。**

## 一、对照总表

判定口径：✓ 已实现（有代码/资源/场景证据）；◐ 部分实现；✗ 未实现；N/A 判定为超出 v1 范围。

### Phase 1 VisualCue（01-VisualCue事件反馈层任务.md）

| 任务 | 状态 | 证据 |
|---|---|---|
| VF-CUE-01 VisualCueDef | ✓ | `scripts/core/defs/visual_cue_def.gd`（extends RegistryContributorDef） |
| VF-CUE-02 VisualFxDef | ✓ | `scripts/core/defs/visual_fx_def.gd` |
| VF-CUE-03 AudioCueDef | ✓ | `scripts/core/defs/audio_cue_def.gd` |
| VF-CUE-04 VisualCueRegistry | ✓ | `autoload/VisualCueRegistry.gd`，slot `visual_cues`，trust `data_only` |
| VF-CUE-05 VisualFeedbackHost | ✓ | `scripts/visual/visual_feedback_host.gd`（124 行）；FIXED_EVENTS 为任务书 7 事件 + `combat_action.phase`；filter 支持任务书全部 7 种 + `core_values` 任意字段精确匹配（超出任务书） |
| VF-CUE-06 VisualActionRunner | ✓ | `scripts/visual/visual_action_runner.gd`（807 行）；任务书 6 内置 action 全部实现，另超出实现 `play_actor_action / play_actor_action_sequence / play_actor_state / visual_actor_command` |
| VF-CUE-07 首批 core.* cue | ✓ | 6/6：`projectile_hit_splat / projectile_expired_puff / entity_damaged_flash / entity_died_fade / placement_accepted_pop / status_removed_clear_overlay` |

### Phase 2 VisualProfile（02-VisualProfile实体表现层任务.md）

| 任务 | 状态 | 证据 |
|---|---|---|
| VF-PROFILE-01 VisualProfileDef | ✓ | 字段齐（含任务书未列的 `default_scale / ground_offset`） |
| VF-PROFILE-02 VisualProfileRegistry | ✓ | 3 个 `core.placeholder_*` 内置 |
| VF-PROFILE-03 VisualActorComponent | ✓ | `scripts/components/visual_actor_component.gd`（bind_profile / damage stages / flash / shadow / state→animation 全链） |
| VF-PROFILE-04 EntityFactory 可选挂载 | ✓ | `scripts/battle/entity_factory.gd` 引用绑定；plant_root / zombie_root 亦接入 |
| VF-PROFILE-05 状态→动画映射 | ✓ | `play_state` + `state_animation_map`；actor 自带方法优先（reanim actor 已对接） |
| VF-PROFILE-06 血量阶段 | ✓ | `damage_stage_defs` + `_apply_damage_stage`（每 stage 一次、modulate/显隐节点）；stage 内 `spawn_fx` 为 log-only no-op（见差距 B） |
| VF-PROFILE-07 投射体 actor/影子 | ◐ | 影子跟随 `ground_position` 已实现（`visual_projectile_projection_smoke` 在册）；影子视觉绘制为占位（代码注释 "visual TBD when actor scenes exist"，见差距 B） |

### Phase 3 VisualStageLayer（03-VisualStageLayer层级环境任务.md）

| 任务 | 状态 | 证据 |
|---|---|---|
| VF-LAYER-01 VisualLayerPolicy | ✓ | 11 层常量 + LAYER_BASE 数值与任务书建议**逐值一致** + ROW_STRIDE=100 |
| VF-LAYER-02 VisualStageLayerService | ✓ | `initialize / get_layer_host / apply_z_index / apply_visual_preset / cleanup`；battle_manager 已接线 |
| VF-LAYER-03 lane z_index | ✓ | `resolve_z_index(entity_kind, lane_id, layer, local_offset)`，lane_id<0 安全默认 |
| VF-LAYER-04 本体/影子分层 | ◐ | 坐标来源分离已实现并有验证；影子可见物占位（差距 B） |
| VF-LAYER-05 battlefield visual preset | ✓（v1 口径） | `apply_visual_preset` 读取 preset；`data/combat/environments/` 6 个环境资源；v1 只记录不建完整背景——符合任务书"v1 可先只读取并记录" |
| VF-LAYER-06 fog/weather/screen_fx 宿主 | ◐ | `_HOST_ORDER` 含全部宿主节点；fog/weather/screen_fx 为空壳宿主（v1 范围外，后置合理） |

### Phase 4 扩展槽（04-扩展槽与资源协议任务.md）

| 任务 | 状态 | 证据 |
|---|---|---|
| VF-SLOT-01..04 四 registry 接入 RegistryBase | ✓ | 四个 autoload 全部 `extends registry_base.gd`，kind/trust/扫描路径齐 |
| VF-SLOT-05 ALLOWED_REGISTER_KINDS | ✓ | `extension_pack_catalog.gd` 12 个 kind 含 4 视觉 kind |
| VF-SLOT-06 trust_level 规则 | ✓ | 全部 `data_only`；拒绝走 `record_protocol_issue` |
| VF-SLOT-07 guardrail 场景 | ✓ | `visual_slot_guardrail`（smoke+guardrail 双层）在册 |

### Phase 5 验证（05-验证与回归任务.md）

| 任务 | 状态 | 证据 |
|---|---|---|
| VF-TEST-01..07 | ✓ | `visual_registry_smoke / visual_cue_projectile_hit_smoke / visual_projectile_projection_smoke / visual_actor_profile_smoke / visual_slot_guardrail / visual_extension_pack_smoke` 全部在 `validation_scenarios.json`；2026-09-27 M5 收口时 public 225/225 全绿包含以上场景 |
| 超出任务书的验证 | ✓ | `visual_action_types_smoke`；local_private 层 8 个 reanim 场景（M5 交付） |

## 二、验收标准对照（00-总览与边界.md）

| 标准 | 判定 |
|---|---|
| 视觉层不改变规则结果 | ✓ 架构 try-safe（host/runner 全部不抛出到战斗主链）+ guardrail |
| 任一视觉子系统失败时战斗继续 | ✓ action 失败降级 no-op + 记录 |
| 无 cue/fx/profile 时 fallback 可运行 | ✓ actor_scene=null 降级链完整（`visual_actor_profile_smoke` 覆盖） |
| DebugService 记录 cue 匹配与 action request | ✓ `record_visual_event` 贯穿匹配/跳过/执行 |

## 三、真实剩余差距（按值得立项排序）

### 差距 A：状态 overlay 消费链缺失（协议字段无消费方）——建议立项

- 事实：`VisualProfileDef.status_visual_map` 字段存在，但**全仓无任何消费方**（唯一定义处即 def 本身）。02 任务书的"状态 overlay 合成"（`base_color -> hit_flash -> status_overlay -> special_overlay`）未实现：`VisualActorComponent` 只处理 hit flash 与 damage stages，冰冻/魅惑/睡眠等状态染色无从落地。
- 影响：状态效果的视觉表达当前只能靠 reanim actor 内建行为，data-only 声明的状态 overlay 无效。
- 立项建议：`design/visual-feedback` 后续执行任务之一——在 VisualActorComponent 增加 status overlay 管理器（订阅 `entity.status_applied / status_removed`，按 `status_visual_map` 合成 modulate/overlay），补 1 个 smoke + 1 个 guardrail。

### 差距 B：可见素材接线（占位等待素材）——不立项，随素材批次走

- 事实：内置 `core.*` FX 的 `fx_scene` 全部为 null（registry 只带 lifetime/layer 元数据），`spawn_fx` 实际降级 no-op+log；影子可见物 TBD；damage stage 的 `spawn_fx` no-op。
- 判定：这是**素材侧**差距而非协议侧——协议、降级、日志链全部就位，`openpvz_placeholder_assets` 包已有 `classic_placeholder_plant.tres` 先例。等真实美术资源批次（与 classic_original_assets 素材线合并处理），单独立项无意义。

### 差距 C：wiki 正文未同步视觉层事实——建议作为独立文档任务

- 事实：`wiki/02-runtime-protocol/` 无视觉反馈层正文页；唯一状态快照页（23-当前阶段与实现路线）与架构总览均不提 VisualCue/VisualProfile/StageLayer；wiki 提及视觉 registry 的只有 43/44/45（扩展 manifest 侧）。README 推荐阅读清单无视觉层入口。
- 影响：新人从 wiki 无法发现视觉层已存在；违反"正文只写已成立事实"的完整性（已成立却不写）。
- 立项建议：新增 `wiki/02-runtime-protocol/19-视觉反馈层.md`（或顺延编号）+ 更新 23 页快照与 index 阅读清单。文档健康检查的数字断言不含视觉层数字，无连带。

### 差距 D：fog/weather/screen_fx 空壳宿主——不立项

- v1 任务书明确"只读取并记录 preset"；空壳符合口径。待环境/天气设计草案（`plans/draft/` 已有）立项时一并消费。

## 四、对任务包本身的修订建议

1. README"状态：设计拆解，尚非实现事实"已过时——实现已发生，应改为"实现状态见 07 对照报告"。
2. 01/02/03/04/05 五篇任务书可标记"已被实现消费"（保留原文作设计依据，不删）。
3. 本包在实现完成后应整体归档至 `plans/archive/`（按归档惯例，待差距 A/C 收口后执行）。

## 五、后续执行顺序建议

1. **差距 C**（wiki 同步）——纯文档、无代码风险、让已成立事实可见；
2. **差距 A**（status overlay 消费链）——最后一个协议级缺口，含验证场景；
3. 差距 B/D 挂起等素材/环境批次；
4. 全部收口后本任务包归档。
