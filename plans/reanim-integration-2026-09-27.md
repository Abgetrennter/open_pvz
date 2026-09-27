# Reanim 分支集成验收（2026-09-27）

- 状态：自动化集成验收完成；GUI 校准和性能基线属于独立 M5 工作。
- 合并来源：`feature/private-assets@1526f97`；目标基线 `master@1621325`。
- 环境：Godot 4.6.1 stable，PowerShell 7，独立引擎 worktree + paired_write 素材 worktree。

## 发现与修复

1. 只有 `plans/README.md` 冲突：保留当前索引结构，恢复分支的计划入口；不恢复旧 vendor/gitlink。分支带入的 `.zcode` 计划移入 `plans/archive/agent-notes/reanim-full-migration-session.md`。
2. 分支文档称 48 株完成，但素材基线实际只有 18 条 manifest/native 产物，且 asset_index 还引用已退役 `actors/`。按现有转换管线补齐 30 株并重建索引；原 18 条 manifest 语义未改。
3. `run_reanim_migrate_one.ps1` 调用了未定义的 `Invoke-Godot`，改为显式进程调用并检查退出码。Stage B 失败立即终止，不以磁盘旧报告判成功；负例确认 exit 9 + 旧 ok=true 报告仍被拒绝。
4. 批量脚本缺失首批四株配置，补 cherrybomb/coffeebean/gravebuster/hypnoshroom。root_offset 来自现有 AABB 种子工具，分别为 [-42.6,-69.5]、[-40.5,-121.2]、[-40.7,-34.0]、[-39.4,-78.5]；都是待目测候选，不是已校准结论。
5. 素材原始 audio 被 Godot 编辑器自动导入时在 pause.ogg 处原生崩溃。原始输入本不属于运行时导入层，素材仓为 sources 加入 `.gdignore`；转换器和 ReanimPlayer 继续通过原始文件接口读图，生成场景保留自身资源。重新导入成功，原始音频未删除/改写。本次不宣称修复 Godot 音频解码器。
6. 私有 manifest 校验增加正式 archetype 绑定完整性和 native def 校验。原始 18 条目素材包被明确拒绝，重建的 48 条目通过。

## 验收结果

| 验证 | 结果 |
|---|---|
| 无私有素材挂载：全部公开层 | 225/225 PASSED，batch_20260927_121539 |
| 配对素材挂载：local_private | 10/10 PASSED，batch_20260927_122136 |
| manifest / index / archetype / native def | 48 profiles valid |
| 48 株展示场景，900 帧、固定 60 FPS、headless | exit 0；expected=48 loaded=48 missing=[]，无 ERROR 日志 |
| 生成失败 + 旧成功报告负例 | 拒绝，未误报成功 |

公开回归与私有回归合计 235 个场景，计数以 manifest 为准。展示场景只证明加载与运行链，不证明 GUI 视觉质量。

## 复现

先完成独立工作树的 Godot 导入，再从引擎工作树运行：

```powershell
# 不挂载 local_extensions 时跑公开层
pwsh tools/run_all_validations.ps1 -GodotExe <godot-console> -MaxParallel 8
# 挂载匹配的素材版本后
pwsh tools/run_all_validations.ps1 -GodotExe <godot-console> -Layers local_private -MaxParallel 2
& <godot-console> --headless --path . --script res://tools/check_private_classic_visual_manifest.gd -- --include-classic-original-assets
& <godot-console> --headless --path . res://scenes/validation/visual_reanim_native_actual_demo.tscn --fixed-fps 60 --quit-after 900 -- --include-classic-original-assets --integration-report
```

重新生成只在 paired_write 素材槽中执行：`run_reanim_migrate_batch.ps1 -Batch all`，随后调用 `reanim_rebuild_asset_index.gd --manifest <private-manifest>`；不要对共享主素材挂载写入。

## 剩余边界

M5 仍需逐株 GUI 检查 root_offset、遮挡、动作观感及节点/帧耗时/内存采样，验收后再归档迁移计划。本次不把 headless 或 profile 数量等同于原版视觉一致性。完整双仓 revision 与日志摘要由工作区 `docs/baselines/` 的本次集成证据记录保存。
