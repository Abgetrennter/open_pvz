# WaveRunner 规则化组波归档

- 日期：2026-05-21
- 状态：已归档
- 对应正式 Wiki：[波次与组波系统](../../../wiki/02-runtime-protocol/18-波次与组波系统.md)

---

## 归档内容

- [僵尸波次管理器 WaveRunner 设计草案](僵尸波次管理器WaveRunner设计草案.md)

该草案记录了 WaveRunner 从“显式波次执行器”扩展到“显式波次 + 规则化 recipe 编译 + 受控注入”的设计讨论。当前已完成 Phase 0-4 最小切片，正式事实已同步到 Wiki，不再以 draft 作为当前实现依据。

---

## 已落地范围

| Phase | 状态 | 说明 |
| --- | --- | --- |
| Phase 0 | 已完成 | 固定 WaveRunner 执行器边界，显式 `WaveDef[]` 与 `wave_recipe` 共存 |
| Phase 1 | 已完成 | 新增 `WaveRecipeDef`、`WavePoolDef`、`WavePoolEntryDef`、`WaveComposer` |
| Phase 2 | 已完成 | 新增 `WaveAdvancePolicyDef`，支持时间 + 血量阈值推进和 huge wave warning |
| Phase 3 | 已完成 | recipe 预过滤 `spawn.medium.*`，运行时仍由 `BattleSpawnResolver` 最终裁判 |
| Phase 4 | 已完成 | 新增受控 `WaveInjectionRuleDef`，不开放任意 WaveRunner 脚本 |

---

## 当前事实入口

- 运行时协议：[wiki/02-runtime-protocol/18-波次与组波系统.md](../../../wiki/02-runtime-protocol/18-波次与组波系统.md)
- 状态快照：[wiki/01-overview/23-当前阶段与实现路线.md](../../../wiki/01-overview/23-当前阶段与实现路线.md)
- 验证清单：[wiki/03-content-validation/15-验证清单.md](../../../wiki/03-content-validation/15-验证清单.md)
- 验证矩阵：[wiki/03-content-validation/32-验证矩阵.md](../../../wiki/03-content-validation/32-验证矩阵.md)

---

## 验证证据

上一轮完整验证：

```powershell
pwsh "tools/run_all_validations.ps1" -GodotExe "E:/SDK/Godot/Godot_v4.6.1-stable_win64_console.exe" -MaxParallel 4
```

结果：

- `218 passed / 0 failed`
- 批次目录：`artifacts/validation/batch_20260521_211642`

新增或相关场景已接入 `tools/validation_scenarios.json` 与 `tools/formal_content_validation_map.json` 的 `wave_and_level_structure_v1`。
