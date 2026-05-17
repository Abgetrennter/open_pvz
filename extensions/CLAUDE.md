# extensions/ — 扩展包目录

Open PVZ 扩展体系实验场：7 个包（1 内容 + 6 守卫/探测），通过 `ExtensionPackCatalog` 加载。

## EXTENSION PACK INVENTORY

| pack_dir | pack_id | enabled | trust_level | registered_slots | category | files |
|----------|---------|---------|-------------|------------------|----------|-------|
| minimal_chaos_pack | minimal_chaos_pack | yes | data_only | resources | smoke | 6 |
| my_pack | my_pack | no | trusted_runtime | resources, projectile_movement, mechanic_compilers | demo | 10 |
| phase5_guardrail_pack | phase5_guardrail_pack | no | trusted_runtime | effects | guardrail | 7 |
| registry_probe_pack | registry_probe_pack | no | trusted_runtime | resources, effects, triggers, detections, controllers | probe | 14 |
| registry_strategy_guardrail_pack | registry_strategy_guardrail_pack | no | trusted_runtime | triggers, detections, controllers | guardrail | 7 |
| runtime_trust_guardrail_pack | runtime_trust_guardrail_pack | no | data_only | projectile_movement | guardrail | 1 |
| slot_guardrail_pack | slot_guardrail_pack | no | trusted_runtime | resources, projectile_movement, mechanic_compilers | guardrail | 15 |

## extension.json SCHEMA

每个包根目录必需 `extension.json`（JSON 清单，与主仓 .tres Resource 体系不同）：

```
{
  pack_id: string,                          // 唯一包标识
  display_name?: string,                    // 可选展示名
  version?: string,                         // 可选版本号
  trust_level: "data_only" | "trusted_runtime",
  enabled_by_default: bool,
  register: string[],                       // 声明使用的 slot
  capabilities?: string[],                  // 声明运行时能力
  activation_scenario_ids?: string[],       // 按验证场景 ID 激活
  activation_cli_flags?: string[]           // 按 CLI 标志激活
}
```

## SLOT COVERAGE

| slot | 使用包数 | 包列表 |
|------|---------|--------|
| resources | 4 | minimal_chaos, my_pack, registry_probe, slot_guardrail |
| effects | 2 | phase5_guardrail, registry_probe |
| projectile_movement | 3 | my_pack, runtime_trust_guardrail, slot_guardrail |
| mechanic_compilers | 2 | my_pack, slot_guardrail |
| triggers | 2 | registry_probe, registry_strategy_guardrail |
| detections | 2 | registry_probe, registry_strategy_guardrail |
| controllers | 2 | registry_probe, registry_strategy_guardrail |

## ACTIVATION RULES

`ExtensionPackCatalog.list_enabled_packs(kind)` 扫描各包 `extension.json`，判定激活：

- **默认激活**：`enabled_by_default = true`（minimal_chaos_pack、phase5_chaos_pack）
- **场景激活**：当前验证场景 ID 匹配 `activation_scenario_ids[]` 时激活
- **CLI 激活**：启动参数匹配 `activation_cli_flags[]` 时激活（如 `--include-guardrail-extension-packs`）
- 三路取并集；未激活包的资源不参与扫描和注册

## GUARDRAIL CATEGORIES

4 个守卫/探测包覆盖全部拒绝路径，仅在对应验证场景运行时激活：

- **slot_guardrail_pack**：core.* 覆盖拒绝、重复 id 拒绝、未知 family 拒绝
- **phase5_guardrail_pack**：effect strategy 签名/参数非法拒绝
- **registry_strategy_guardrail_pack**：trigger/detection/controller strategy script 非法拒绝
- **runtime_trust_guardrail_pack**：code slot 要求 trusted_runtime 但包仅 data_only 时拒绝

所有拒绝统一记录为 `protocol.issue` 事件，验证场景断言拒绝发生。
