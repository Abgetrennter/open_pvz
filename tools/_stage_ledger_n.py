import io

# zombie ledger: batch N header note + Z-16/Z-17/Z-22/Z-23/Z-30 rows
p = 'plans/original-zombie-protocol-gaps.md'
s = io.open(p, encoding='utf-8').read()

anchor = '附注：Snorkel 出水后步行用默认区间（原版 PickRandomSpeed 无 SNORKEL_WALKING 特判）；Dolphin 入水/骑乘动画相未表达（位置/速度语义已补）；池 edge 700/720 区间简化为单线 700。'
addition = anchor + '''>
>
> 更新（2026-10-01，Batch N）：Z-16（hop_cycle 新增 `hop_height_sequence` [40,40,90,170] 循环序列，apex 高度按 sqrt(2|g|h) 折算起跳速度）、Z-17（Pogo 挂 pogo_stick 20 血 metal attachment 层；hop_cycle 中空遇 vault_blocker 走 `blocked_landing_movement` 并以 spillover=false 的 9999 剥层（Magnet 吸金属 20 伤同样打穿该层）→ `health.layer_destroyed` 状态机 bouncing→walking 0.23–0.32，对应原版 PogoBreak）、Z-22（explode 新增 `radius_slots_plant`/`radius_slots_zombie` 双半径 + `blast_team_mode: allies` 第二遍扫己方（对应 KillAllZombiesInRadius 115 / KillAllPlantsInRadius 90，自爆者排除），Jack payload 双键落位 0.9375/1.197917）、Z-23（Bungee 重做完整流程：diving 1.9s→grabbing 3s（原版 300 ticks）→proximity 30px 检测驱动 steal（context_target 9999 + overhead/bungee 标签保留伞叶拦截）或 require_no_target 离场 consume；新增 hover bite 控制器 suppress flying（悬停不啃））、Z-30（核证修正：原版小鬼落点恒为 mPosX−133（现状已对），真正缺的是投掷条件门 `aThrowingDistance > 40` 即 mPosX>400——when_damaged 新增 `min_owner_x` 条件，巨人抛掷触发挂 400）。连带引擎修复：board_state 监听 entity.died|entity.consumed 即时释放 slot 角色（原依赖 queue_free 懒清理）；Doom-shroom 补自灭 payload（原版爆后 Die()，此前爆炸后存活占格）。探针 `zombie_original_batch_n_interactions`（双半径几何/跳高序列/Tall-nut 断簧/偷取链/抛掷门）+ 场景 `plant_original_doomshroom_crater_validation` 恢复补种拒绝断言。附注：pogo 断簧后实体 metal 标签保留（Magnet 对步行体继续 20 伤/5s 的轻微近似）；bungee dive/grab 动画相未表达（时序语义已补）；Jack 双半径的爆炸自伤排除（原版 DieNoLoot 自灭语义已由 consume 承载）。'''
assert anchor in s
s = s.replace(anchor, addition)

s = s.replace('''| Z-16 | Pogo 弹跳高度序列 | 部分覆盖 | Pogo | 原版三段递增高跳（普通 40 → FORWARD_2 90 → FORWARD_7 170，`Zombie.cpp:1372-1414`）；当前 `hop_cycle` 单一 jump_velocity |''', '''| Z-16 | Pogo 弹跳高度序列 | 已覆盖（2026-10-01） | Pogo | hop_cycle 新增 `hop_height_sequence`（[40,40,90,170] 循环，对应原版普通 40/FORWARD_2 90/FORWARD_7 170 的三段递增近似），apex→起跳速度 sqrt(2|g|h)；探针 `zombie_original_batch_n_interactions`（断言 170px apex 达成）。附注：原版 HIGH_BOUNCE_1..6 的 50–150 中间档归并为单 170 档 |''')

s = s.replace('''| Z-17 | Pogo 弹簧破坏后步行 | 未覆盖 | Pogo | 原版 Tall-nut 碰撞或 Magnet 吸簧触发 `PogoBreak` 转步行（`Zombie.cpp:1332-1360`、`:1416-1425`）；依赖 G-19 与 Z-19 |''', '''| Z-17 | Pogo 弹簧破坏后步行 | 已覆盖（2026-10-01） | Pogo | pogo_stick 20 血 metal attachment 层（Magnet 20 伤一击剥簧）；hop_cycle 中空遇 vault_blocker（Tall-nut）以 spillover=false 9999 剥层并落 `blocked_landing_movement`；`health.layer_destroyed` 状态机 bouncing→walking（0.23–0.32，对应 PickRandomSpeed 默认档）；探针 batch_n_interactions（Tall-nut 断簧→步行）。附注：断簧后实体 metal 标签保留，Magnet 对步行体继续 20 伤/5s 为已知近似 |''')

s = s.replace('''| Z-22 | Jack 爆炸半径分目标 | 部分覆盖（单半径已校准 2026-09-28） | Jack-in-the-Box | 原版僵尸半径 115 / 植物半径 90（`Zombie.h:25-26`）；explode effect 协议（`allow_extra_params=false`）只支持单 `radius_slots`，已按植物面 90px≈0.94 校准；分目标双半径需 effect 协议扩展，维持部分覆盖 |''', '''| Z-22 | Jack 爆炸半径分目标 | 已覆盖（2026-10-01） | Jack-in-the-Box | explode 新增 `radius_slots_plant`/`radius_slots_zombie`：敌侧按植物半径 0.9375（90px）解析，`blast_team_mode: allies` 第二遍按僵尸半径 1.197917（115px）扫己方（对应 KillAllZombiesInRadius/KillAllPlantsInRadius 双调用，爆炸者自排除）；Jack payload 双键落位；探针 batch_n_interactions（80px 植物中/105px 僵尸中/130px 植物不中） |''')

s = s.replace('''| Z-23 | Bungee 完整偷取流程 | 部分覆盖 | Bungee | 原版：整列随机选格 → 俯冲（下落 8/tick）→ 底部停 300 ticks 抓植物 → 举起飞走（`Zombie.cpp:230-247`、`:1220-1264`）；当前 on_spawned 落地伤害 + consume_self 近似，无目标选择与飞走阶段 |''', '''| Z-23 | Bungee 完整偷取流程 | 已覆盖（2026-10-01） | Bungee | 重做：diving 1.9s（原版俯冲时长近似）→ grabbing 3s（原 300 ticks 抓取窗）→ proximity 30px 检测（required_state grabbing 门控）：有植物→context_target 9999 偷取（attack_tags overhead/bungee 保留伞叶拦截语义）+ consume 离场；空位→require_no_target 离场；新增 hover bite 控制器（suppress flying，悬停不啃）；探针 batch_n_interactions（俯冲→抓取→偷走→离场全链）。附注：整列随机选格由 wave 层 x_position 承载（场景内由 spawn 决定）；俯冲/举起飞走动画相未表达 |''')

s = s.replace('''| Z-30 | Gargantuar 投掷条件与距离 | 部分覆盖 | Gargantuar, Redeye | 原版条件 `mHasObject && HP<50% && mPosX-360 > 40`（`:2208-2213`），投掷距离 `mPosX-360 - Rand(0,100)`、屋顶减 180（`:2133-2155`）；当前 `when_damaged` HP 阈值触发已近似，距离公式缺 |''', '''| Z-30 | Gargantuar 投掷条件与距离 | 已覆盖（2026-10-01，核证修正） | Gargantuar, Redeye | 核证修正：原版投掷距离变量只用于条件门与随机化，小鬼落点恒为 `mPosX - 133`（`:2161`）——现有 x_offset -133 落点本已正确；真正缺的是条件门 `aThrowingDistance > 40`（即 mPosX > 400，近屋不抛只砸）。when_damaged 新增 `min_owner_x` 条件，Gargantuar/Redeye 抛掷触发挂 400；探针 batch_n_interactions（350px 处打穿血线不出小鬼）。附注：屋顶 -180/-140 门（StageHasRoof 分支）与抛掷飞行弧（PHASE_IMP_GETTING_THROWN velX 3）未表达 |''')

io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('zombie ledger ok')

# plant ledger: doom self-death note on G-29
p2 = 'plans/original-plant-protocol-gaps.md'
s2 = io.open(p2, encoding='utf-8').read()
old = '''| G-29 | 坑洞/crater | 已覆盖（2026-10-01，与僵尸侧 Z-11/Z-14 联动） | Doom-shroom | explode 新增 `crater_at_source_slot` + `crater_duration_ticks` 18000（原版 AddACrater->mGridItemCounter=18000）：爆后于源格生成 archetype_crater GridItem（occupies_blocker_role 阻挡补种，占格语义由 grid_item_crater_validation 覆盖）；battle_grid_item_state 新增 `schedule_expiry` game.tick 寿命通道（到期 remove+grid_item.removed reason expired）；场景 `plant_original_doomshroom_crater_validation`（夜环境唤醒→爆炸→坑洞落格）。附注：同格补种在尸体淡出完成前会先命中 placement_role_occupied（尸体占格为既有引擎缺口，非坑洞语义） |'''
new = '''| G-29 | 坑洞/crater | 已覆盖（2026-10-01，与僵尸侧 Z-11/Z-14 联动；Batch N 补全） | Doom-shroom | explode 新增 `crater_at_source_slot` + `crater_duration_ticks` 18000（原版 AddACrater->mGridItemCounter=18000）：爆后于源格生成 archetype_crater GridItem（occupies_blocker_role 阻挡补种，占格语义由 grid_item_crater_validation 覆盖）；battle_grid_item_state 新增 `schedule_expiry` game.tick 寿命通道（到期 remove+grid_item.removed reason expired）；Batch N 连带：Doom-shroom 补 consume_self payload（原版爆后 Die()，此前爆炸后存活占 primary 致同格永远 placement_role_occupied）、board_state 监听 entity.died|consumed 即时释放 slot 角色；场景 `plant_original_doomshroom_crater_validation` 恢复补种断言（1.5s 复种 → required_empty_role_occupied，证明尸体即时释放且拒绝来自坑洞 blocker） |'''
assert old in s2, 'g29 row'
s2 = s2.replace(old, new)
io.open(p2, 'w', encoding='utf-8', newline='\n').write(s2)
print('plant ledger ok')
