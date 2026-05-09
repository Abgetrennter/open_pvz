# 规则基础设施收口归档（2026-05）

> 状态：已完成归档
> 归档时间：2026-05-09

本目录保存实体活跃性、空间索引、高度过滤与 tick 预算监控第二轮收口相关的正式计划和早期草稿。

这些文档已经不再作为待实施计划使用。当前事实以 `wiki/` 正文、`plans/未来计划.md` 和运行时代码为准。

## 已完成内容

- 多维 liveness profile 与明确语义 API。
- `StateComponent` 统一状态转换入口。
- 旧 `combat_active` / `attack_blocked` / `blocks_attack` 运行时口径清理。
- `SpatialIndex` 核心、`BattleManager.spatial_query(params)` 和热路径迁移。
- `height_range` overlap 标准过滤。
- tick budget warning 观测事件。
- liveness、SpatialIndex、tick budget 专项验证场景。

## 验证记录

最近一次完整验证矩阵：

- 时间：2026-05-09
- 场景数：140
- 结果：140 passed / 0 failed

## 归档文件

- [实体活跃性与状态控制计划](./实体活跃性与状态控制计划.md)
- [空间索引与高度过滤计划](./空间索引与高度过滤计划.md)
- [仿真与时序层计划](./仿真与时序层计划.md)
- [实体活跃性系统设计草案](./实体活跃性系统设计草案.md)
- [空间索引与车道系统设计草案](./空间索引与车道系统设计草案.md)
- [空间与距离层设计草案](./空间与距离层设计草案.md)
- [仿真与时序层分析](./仿真与时序层分析.md)

## 后续观察项

- Projectile 对象池：等待真实性能压力或 profiling 结果。
- 碰撞层声明：等待同队复杂碰撞/免疫关系需求。
- BoardSlot modifier：等待坑洞、屋顶、水池等场地变形内容。
- 帧间插值：等待视觉表现层进入正式质量阶段。
