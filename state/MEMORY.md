# RandomRooms —— 开发记忆入口

> 2026-09-20：用户明确要求部署，v11.1已正式替换release并通过独立原版入口检查。对应原版的房间尺度、城市编排与四类扩张验证完成，无待答设计题。

## 1. 模组是什么

- 为Remains 1.02从零生成建筑空间，按用途安排原版家具与通用探索内容，不复制原版整房或地形片段。
- 工厂、废弃避难厩、下水道、城市废墟分别控制空间、材料、门窗、敌群和设施；一次探索固定场景，向右、向下无限扩张。
- 运行入口固定release/RandomRoomsMod.swf，类RandomRoomsMod，public static init(main)。仓库在本模组目录，分支main。

## 2. 用户决定与边界

- 土地=整次旅行地图；合成房=48×25格；房间=内部功能空间。采用C从零生成，不能改成有限5×5加F4。
- 取消统一三段式、中央井和穿房路线。普通上下连接错开、少量特殊井；较强探索、回环为主、少量有内容的尽头。
- 上下左右任一实际开放入口都能进入与返回，不要求每房四面全开，不指定首入口，不随进入方向重排。
- 保留原版门、活板门、玻璃；四类场景整次探索保持，扩张和F4不换。F1四类入口加随机，F2回城，F4深入，F5展示馆。
- 下水道真实污水，必经干路，涉水可选。通用敌群/机关/奖励/服务可刷新；剧情NPC、任务装置、首领另行设计。
- Q1按原版生态和空间用途分离，允许合理共用。Q2已答“1”：城市按整张地图组织连续建筑、街巷、屋顶，不再每个合成房都塞室内外。
- 最新要求：开发房偏大空荡，应增加内部房间，参考对应原版场景，不能四类统一切成小格。
- 只改本模组。根/DLC SWF、真实存档、其他模组不改。测试用唯一pferr-style-*应用、newGame(-1)、隐藏ADL，不用Ghost、不干扰用户实例。
- 评审页自动打开曾被Browser URL策略拒绝；不换浏览器、代理或服务器绕过，提供本地文件链接即可。
- 版本替换须重启、回城后新开土地。已载入地图不会自动更新。已决定事项不重复询问。

## 3. 当前状态

- 正式release：v11.1，46044 B，SHA256 16F3D2BD63D19660E039F5F44B4792FD85F3E2119A59F058F8290F5746346C7F；对应build/RandomRooms-v11.1-candidate.swf。日志[RR:v11.1]。
- 完整核心验证候选build/RandomRooms-v11-dev-13.swf，46043 B，SHA256 959A4C3ECD314B988FCECD20CA1DD6C4E78E098F34A7DA7CF2FC6704B0704533；日志[RR:v11-dev]，XML space-v11/revision11.1。
- 原版调查192间外置房、12间实景。RREcology按1.02实际难度选择同房生态，RRGrowth恢复被Land改写的tipEnemy；材料、家具和设施按场景与用途配置。
- 本轮缩小普通功能房、增加附室，保留作业厅/公共厅/水渠等大空间；小家具组合适配窄房，背景装饰失败不再连带取消实体家具。
- 城市按坐标稳定生成2–4列建筑组及街巷，顶部屋顶，下方住宅/办公/商业/坍塌空间；相邻两行用途延续，扩张保持街巷位置；取消城市随机镜像。
- 同组种子每类32间：内部规划空间平均数工厂4.22→9.81、避难厩5.88→11.06、下水道3.88→7.81、城市5.97→10.75。包括走廊/大厅，不能冒充原版作者房间数。
- 批量128单房+64城市房结构/材料通过，128单房生态通过；16房型均出现；城市112对邻接及请求顺序独立性通过。冻结batch-density-dev13.zip。
- 原版渲染16房型、32图冻结design/assets/v11-density-dev12；这16间与dev13 XML逐项语义一致。新页design/generator-v11-density-review.html含对应原版对照和64格城市用途图。
- dev13四类独立完整扩张均4/4：工厂5717帧/193个旧对象、避难厩6302/189、下水道6120/165、城市5299/190；5×5→8×8、原XML/mirror不变、空箱不补；下水道wetFrames=0。结果对应固定种子，不是穷尽证明。
- 最新dev13原版内容检查100房807个对象、4/4通过；生态100/100一致，创建、成功交互、实际碰撞触发通过。不是逐物体步行、技能成功率或战斗平衡证明。历史dev4/dev7/dev8与独立深池结果另存，不冒充当前验证。

## 4. 正在进行

- 实现和验证已完成，用户授权后的v11.1部署完成；相对dev13只修改两处日志版本字符串。正式SWF独立冒烟2/2通过（F5避难厩12房、F1工厂25房，issues=0），证据release-v11.1-smoke。
- 开发验证失败多处涉及驾驶器（过早离梯、坡向、梁面、家具顶面），失败XML/图/日志独立冻结；只有真实完整通过才更新结果。
- 原样单房复查最终通过：工厂18/18目标、4941帧，下水道13/13、1609帧且wetFrames=0。证据plant-interior-dev13、sewer-interior-dev13。早期失败另存；独立封边样本证明内部空间/楼梯平台访问，不当作跨房或每段指定楼梯的独占路径证明。
- 最新结果和证据入口：knowledge/experiments/generator-v11-density-validation-2026-09-20.md。

## 5. 已知问题与机制

- 自然度尚未等同原版：部分狭长空间、空墙、城市屋顶顶边框可继续打磨；下水道大池保留，几何空格率仍高于原版。
- RRTraversal只是地形图，不是完整物理；实际行走须处理单向梁、家具、门的视线和计时。
- 行动要有到交互中心的isLine视线并持续按住；下键加双击下会先抓邻梯，低门旁落梁只用双击下。梯子中段无接收平台时不能提前跳出。
- 斜梯需上键；公开tile.diagon/getMaxY可读，UnitPlayer.diagon为internal。斜梯下方实体地面是独立行走层，不能把地面格心替换成斜面高度；保留入梯节点、在斜面上沿当前路径走，避免中途重选下方平地。原版跳跃高度依赖按住数帧，一帧脉冲不足以越过普通箱子。固体平台边缘有时须正常跳跃。
- setDoor/setNoObj会省略rem对象：左右入口向内6格、上下3行。人口和家具预留遵守规则。黏液地雷用slime tr=10，不是cid，不读取internal aiState。
- 必经干桥下一格的脚点可能触水；真实干路图排除水面上一格。水下池底stay可能false，不可强求干地站立。
- 未穷尽随机种子、长期扩张、联机、真实旧档死亡恢复、六模组集成、逐敌人战斗、伤害与购买平衡。

## 6. 下一步与回滚

- v11.1已通过发布门禁并部署；用户需完全退出重启，回城后F1进入新地图。后续按实景反馈打磨空墙/狭长空间/城市屋顶边框。
- 根pfe.swf已观测为9A81430D775209E37E8E7FD54414057995E0680671445F38797623865B5A699A（15078864 B），与上一阶段5300EC…指纹不同。本轮未写根文件；当前已通过实测的manifest均为新指纹，测试副本相同。原因未推定，不覆盖外部变化。
- 既有v9回滚包build/release-backups/RandomRoomsMod_before_v10_20260920.swf，37785 B，SHA256 7DC5DB91D6FCE0802EEE73BD3312C6724FB0BCF16A2B48246D00554BEFD8BC4E。v11.1回滚用build/release-backups/RandomRoomsMod_before_v11_1_20260920.swf（v10，41027 B，SHA256 7AC89A73D6A09C0922FD0C7F1FFE7C2C2A836EE635393BF5D32FCC503463058C）；退出游戏后复制回release并核对哈希，重启后进入新地图。
- 正式产物和运行目录不进Git；本次新增冻结证据须保持Git字节哈希，部署记录见当前验证报告末节。

## 7. 深入阅读与复现

- 设计来源design/native-scene-audit-2026-09-20.md；decisions/DEC-0005-architectural-generation.md、DEC-0006-scene-identity.md。旧调查页已链接最新密度对照。
- 当前实证knowledge/experiments/generator-v11-density-validation-2026-09-20.md与generator-v11-evidence/；正式v10结果另见v10报告。
- 构建build/build-v7.ps1 -OutputName RandomRooms-v11.1-next.swf只写build；dev13与v11.1-candidate已冻结，不覆盖。旧build-m0.sh直写release，勿用于验证。
- 批量build/style-review/harness/run-baseline.ps1支持-SamplesPerBiome 32 -PopulationDepth 3 -MapSize 8 -MapScene mane；verify_architecture/scenes/population/city_map分别检查。
- 实机build/style-review/game-harness/run-game-captures.ps1 -DevelopmentSwf build/RandomRooms-v11-dev-13.swf -NavigationProbe -GrowthProbe -Scene plant；-SessionDirectory visual-app隔离另一轮。内容-PopulationProbe -AllScenes，冒烟-SmokeOnly。
- freeze_captures.py仅完整且哈希匹配才冻结；失败用freeze_failed_run.py按manifest时间窗口留证，不混入旧captures。AIR独立存储走隔离测试审批，不能借真实存储绕行。
