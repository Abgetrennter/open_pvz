# Reanim 资源转换工具链规划

> 日期：2026-04-20
> 状态：规划阶段，待视觉表现层阶段 2 实施时启动
> 前置依赖：视觉表现层设计（见 `视觉表现层设计讨论.md`）阶段 0-1 完成后
> 相关 vendor：`vendor/r2ga/`（R2Ga 参考工具）、`vendor/de-pvz/`（原版反编译）

---

## 1. 目标

构建一条从 PVZ 原版 `.reanim` 动画资源到 Open PVZ 可消费的 Godot 动画资源的离线转换管道，作为视觉表现层的内容来源之一。

---

## 2. 已完成的分析

### 2.1 R2Ga 参考工具分析

**仓库位置：** `vendor/r2ga/`（GPL v3，作者 HYTomZ，v3.1）

**架构：** C 核心转换器（Visual Studio 2022）+ Godot EditorPlugin（GDScript）

**数据模型 — PVZ 属性到 Godot Track 的映射：**

| PVZ 原始属性 | Godot Track | 属性路径 |
|---|---|---|
| `f` (visibility) | visibility | `TrackName:visible` |
| `x/y` (position) | position | `TrackName:position` |
| `kx/ky` (rotation) | rotation + skew | `TrackName:rotation` + `:skew` |
| `sx/sy` (scale) | scale | `TrackName:scale` |
| `i` (image/texture) | texture | `TrackName:texture` |
| `a` (alpha) | self_modulate | `TrackName:self_modulate` |
| `bm` (blend mode) | material | `TrackName:material` |

**R2Ga 的主要问题：**

| 问题 | 位置 | 影响 |
|---|---|---|
| UID 全部硬编码为占位符 `fuck_uid_114514_1919810` | FileIO.c:94 | Godot 4.x UID 冲突，无法正确导入 |
| Track 编号用固定倍数偏移（每部件 ×7 或 ×8） | main.c:93-103 | 多部件动画轨道错位 |
| 50MB 全量读入 + 全局变量状态机 | main.c:898 | 大文件风险，递归解析状态泄漏 |
| `kx/ky → rotation+skew` 拆分逻辑在角度 >360 时不正确 | main.c:355-418 | 旋转动画异常 |
| Shader 引用硬编码为 `res://normal.gdshader`、`res://add.gdshader` | FileIO.c:174-175 | 项目中不存在这些文件 |
| 仅 Windows 平台 | 预编译 EXE | 无法跨平台使用 |

### 2.2 原版 Reanim 系统分析

**源码位置：** `vendor/de-pvz/Sexy.TodLib/Reanimator.h`、`Reanimator.cpp`

**核心数据结构：**

```
ReanimatorDefinition（一个 .reanim 文件）
├── mFPS: float（帧率，通常 12）
├── mTracks[]: ReanimatorTrack[]
│   ├── mName: const char*（Track 名称）
│   ├── mTransforms[]: ReanimatorTransform[]（每帧变换数据）
│   │   ├── mTransX, mTransY（位移）
│   │   ├── mSkewX, mSkewY（倾斜/剪切）
│   │   ├── mScaleX, mScaleY（缩放）
│   │   ├── mFrame（图像帧索引，-1=不可见）
│   │   ├── mAlpha（透明度）
│   │   ├── mImage（图像指针）
│   │   └── mText（文本/挂载信息）
│   └── mTransformCount: int
└── mReanimAtlas: ReanimAtlas*（纹理图集）
```

**关键发现 1：没有点号层级**

原版 `.reanim` 的 Track 名称是扁平的（如 `Blover_head`、`CherryBomb_leftstem`），不存在 `body.head` 形式的父子层级。R2Ga 中 `.` 替换为 `_` 的代码（main.c:115-116）实际上几乎不触发——原版部件名本身就用下划线。**之前关于"R2Ga 展平丢失层级"的判断是错误的。**

原版渲染时所有部件 Track 独立绘制，按 Track 顺序叠合，无父子变换继承。

**关键发现 2：跨文件挂载通过 `attacher__` 机制**

原版的层级组装是跨文件的，通过 `attacher__` 命名约定实现：

```
格式: attacher__{REANIM_NAME}__{TRACK_NAME}[TAG1][TAG2]
示例: attacher__Zombie_football__anim_walk
      attacher__Zombie_charred[once]
```

解析逻辑在 `Reanimation::ParseAttacherTrack()`（Reanimator.cpp:1271）中：
- 运行时动态加载另一个 `.reanim` 文件
- 挂到当前 Track 的变换位置
- Tag 控制播放行为：`[hold]` 播放后保持、`[once]` 播放后消失、`[数字]` 播放速率

**关键发现 3：帧数据继承机制**

原版使用 `DEFAULT_FIELD_PLACEHOLDER = -10000.0f` 标记未设置的字段，加载时通过 `ReanimationFillInMissingData()` 从前一帧继承。逻辑（Reanimator.cpp:179-184）：

```cpp
void ReanimationFillInMissingData(float& thePrev, float& theValue) {
    if (theValue == DEFAULT_FIELD_PLACEHOLDER)
        theValue = thePrev;  // 当前帧未设置，继承前一帧
    else
        thePrev = theValue;  // 当前帧有值，更新"前一帧"引用
}
```

默认值：位移 0、缩放 1、倾斜 0、Alpha 1、帧索引 0。

**关键发现 4：图像路径映射**

图像加载路径映射（Definition.cpp:140）：

```cpp
{"IMAGE_", ""},              // 根目录
{"IMAGE_", "particles\\"},   // 粒子效果
{"IMAGE_REANIM_", "reanim\\"},  // reanim/ 目录
{"IMAGE_REANIM_", "images\\"}   // images/ 目录
```

`.reanim` 中的 `IMAGE_REANIM_PEASHOOTER_BACKLEAF_LEFTTIP` → 实际文件 `reanim/Peashooter_backleaf_lefttip.png`。

**关键发现 5：矩阵构建方式**

原版的变换矩阵构建（Reanimator.cpp:575）：

```cpp
void Reanimation::MatrixFromTransform(const ReanimatorTransform& t, SexyMatrix3& m) {
    float skewX = -DEG_TO_RAD(t.mSkewX);
    float skewY = -DEG_TO_RAD(t.mSkewY);
    m.m00 = cos(skewX) * t.mScaleX;
    m.m10 = -sin(skewX) * t.mScaleX;
    m.m01 = sin(skewY) * t.mScaleY;
    m.m11 = cos(skewY) * t.mScaleY;
    m.m02 = t.mTransX;
    m.m12 = t.mTransY;
}
```

这意味着 Godot 的 `rotation` + `skew` 需要从这个矩阵反推，不能简单地把 `kx` 当 `rotation`、`ky-kx` 当 `skew`。

### 2.3 资源解包现状

| 路径 | 内容 | 状态 |
|---|---|---|
| `DebugVS2005/reanim/` | 146 个 `.reanim` XML | 已解包，可直接使用 |
| `DebugVS2005/compiled/` | 253 个 `.compiled` 二进制 | 跳过，有 XML 即可 |
| `DebugVS2005/images/` | UI 图片（图鉴、菜单等） | 已解包，不含角色精灵 |
| `DebugVS2005/main.pak` | ~24MB 主资源包 | **未解包，包含全部角色精灵图** |
| 根目录 `images/` | 字体纹理等 | 已解包，与动画无关 |

**结论：需要先解包 `main.pak`**，否则转换工具没有纹理可引用。`main.pak` 是 PakCollection 格式（文件名 + 偏移 + 大小索引表 + 原始数据），可使用社区工具（PvZTools、PopCapPak）解包，或根据 `PakInterface.h` 自行编写解包器。

---

## 3. 决策记录

### 3.1 不 Fork R2Ga

**理由：**

1. **许可证约束** — R2Ga 是 GPL v3，fork 并修改会引入 GPL 传染性
2. **ROI 极低** — 需要改的只有 UID 和少数 bug，但要维护整个 C 构建链
3. **架构不匹配** — R2Ga 输出扁平 TSCN + AnimationPlayer，Open PVZ 需要 VisualProfile + AnimDriver 组件体系
4. **CLAUDE.md 约束** — vendor/ 目录为参考实现，不直接修改或依赖

### 3.2 用 GDScript 重写新工具

**理由：**

1. **逻辑简单** — 原版 `ReanimationLoadDefinition` 核心逻辑仅 40 行（XML 解析 + FillInMissingData）
2. **原生 Godot 输出** — 直接创建 Animation 资源，无需拼接文本文件
3. **无需构建链** — 作为 `@tool` 脚本在编辑器中运行
4. **可维护** — GDScript 与项目其他代码统一，团队能力覆盖

### 3.3 工具定位为离线预处理

与项目设计文档一致："原版 reanim 资源迁移应视为离线工作流，不应成为当前运行时前置依赖"。新工具的产出是 Godot 原生可消费的资源文件，运行时不感知 reanim 格式。

---

## 4. 工具架构设计

### 4.1 文件位置

```
tools/
└── import_reanim.gd    ← @tool 脚本，编辑器工具菜单调用
```

### 4.2 资源管道

```
main.pak ──(解包)──> 角色 PNG 精灵图
                         │
146 个 .reanim XML ──────┤
                         ▼
              tools/import_reanim.gd
                   │
                   ├── 解析 XML（XMLParser）
                   ├── FillInMissingData 帧继承
                   ├── kx/ky → rotation + skew 正确转换
                   ├── anim_* 动画层帧范围识别
                   ├── attacher__ 挂载点元数据提取
                   ├── IMAGE_REANIM_* → 纹理引用映射
                   │
                   ▼ 输出
              Godot 原生资源：
              ├── data/combat/visual_profiles/plants/Peashooter/
              │   ├── Peashooter.tscn        ← Node2D + Sprite2D 子节点
              │   ├── Peashooter_idle.tres    ← Animation 资源
              │   ├── Peashooter_attack.tres  ← Animation 资源
              │   └── Peashooter.vprofile.tres ← VisualProfile（未来对接）
              └── data/combat/visual_profiles/zombies/...
```

### 4.3 核心模块划分

| 模块 | 职责 | 复杂度 |
|---|---|---|
| XML 解析器 | 读取 .reanim XML → 内部数据结构 | 低 |
| 帧继承处理器 | 实现 FillInMissingData 逻辑 | 低 |
| 变换转换器 | kx/ky/sx/sy → Godot rotation/skew/scale | 中 |
| 动画层识别器 | 从 anim_* track 提取帧范围，拆分独立动画 | 中 |
| 挂载点提取器 | 识别 attacher__ track，输出元数据 | 低 |
| 资源输出器 | 生成 Godot Animation/.tscn 资源 | 中 |
| VisualProfile 生成器 | 输出 VisualProfile .tres（对接设计讨论文档） | 中 |

### 4.4 kx/ky 变换的正确转换方案

原版矩阵：
```
M = [ cos(-kx°)*sx  sin(-ky°)*sy  tx  ]
    [-sin(-kx°)*sx  cos(-ky°)*sy  ty  ]
```

Godot Node2D 变换：
```
M = [ cos(rot)*sx  -sin(rot+skew)*sy  0  ]
    [ sin(rot)*sx   cos(rot+skew)*sy  0  ]
```

需要从原版 kx/ky/sx/sy 求解 Godot rot/skew/sx/sy，这不是简单的 `rot=kx, skew=ky-kx`（R2Ga 的做法有 bug）。正确方案是解方程组或直接用矩阵元素对应关系推导。

---

## 5. 实施前置条件

| 序号 | 条件 | 当前状态 |
|------|------|---------|
| 1 | `main.pak` 解包，获得角色精灵 PNG | 未完成 |
| 2 | 视觉表现层阶段 0 完成（VisualProfile 等资源类定义） | 未开始 |
| 3 | 视觉表现层阶段 1 完成（VisualComponent 骨架 + NullAnimDriver） | 未开始 |
| 4 | FramesAnimDriver 或 AnimationPlayerDriver 实现 | 未开始 |

---

## 6. 实施阶段

| 阶段 | 内容 | 预估工作量 | 产出 |
|------|------|-----------|------|
| **P0** | 解包 `main.pak`，获得精灵图资源 | 0.5 天 | `assets/reanim_images/` 目录 |
| **P1** | `import_reanim.gd` 核心解析器：XML 解析 + FillInMissingData + 基础 Track 输出 | 1-2 天 | 可转换单动画 .reanim → Godot Animation |
| **P2** | 变换转换器：正确的 kx/ky → rotation + skew | 0.5 天 | 旋转/倾斜动画正确播放 |
| **P3** | 动画层拆分：anim_* 帧范围识别 → 独立 Animation 资源 | 0.5 天 | 一个 .reanim 产出多个动画文件 |
| **P4** | attacher__ 挂载点元数据提取 + 跨文件组装 | 1 天 | 支持僵尸等复杂角色的部件组合 |
| **P5** | VisualProfile 自动生成（对接视觉表现层设计） | 1 天 | 转换产物可直接被 VisualComponent 消费 |

---

## 7. 验证标准

- [ ] 豌豆射手 Idle 动画在 Godot 中正确播放，视觉与原版一致
- [ ] 向日葵产阳光动画帧范围正确拆分
- [ ] 僵尸行走动画的部件旋转/倾斜表现正确
- [ ] attacher__ 挂载的僵尸（如橄榄球僵尸）部件正确组装
- [ ] 生成的 VisualProfile 可被 VisualComponent 加载并驱动显示
- [ ] 至少新增 1 个验证场景覆盖转换产物的正确性

---

## 8. 参考资料

- R2Ga 源码：`vendor/r2ga/`（GPL v3）
- 原版 Reanim 系统：`vendor/de-pvz/Sexy.TodLib/Reanimator.h`、`Reanimator.cpp`
- 原版挂载系统：`vendor/de-pvz/Sexy.TodLib/Attachment.h`、`Attachment.cpp`
- 原版 XML 解析：`vendor/de-pvz/Sexy.TodLib/Definition.h`、`Definition.cpp`
- 原版 PAK 格式：`vendor/de-pvz/PakLib/PakInterface.h`
- 视觉表现层设计：`plans/视觉表现层设计讨论.md`
- 参考项目对比：`wiki/04-roadmap-reference/42-参考项目综合对比分析.md`
