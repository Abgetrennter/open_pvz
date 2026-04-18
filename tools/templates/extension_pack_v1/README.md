# Extension Pack v1 Template

这个目录是第五阶段 `v1` 扩展包脚手架。

它不会被运行时扫描；使用时请把整个目录复制到：

```text
extensions/<your_pack_id>/
```

然后全局替换下面占位符：

- `__PACK_ID__`：扩展包 ID，例如 `my_first_pack`
- `__PLANT_ID__`：示例植物模板 ID，例如 `plant_my_first_shooter`
- `__BINDING_ID__`：示例触发绑定 ID，例如 `plant_attack_my_first_shooter`
- `__SCENARIO_ID__`：示例验证场景 ID，例如 `my_first_pack_smoke_validation`

最小接入步骤：

1. 修改 `extension.json`
2. 修改 `data/combat/entity_templates/plants/plant_template_stub.tres`
3. 修改 `data/combat/trigger_bindings/plant_attack_template_stub.tres`
4. 修改 `scenes/validation/template_pack_smoke_validation.tres`
5. 把验证场景加入 `tools/validation_scenarios.json`
6. 跑对应验证场景

推荐先只做 `resources` 类型扩展包；需要新增 effect 时再增加：

```text
data/combat/effects/
scripts/effects/
```
