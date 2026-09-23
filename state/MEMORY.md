# RandomRooms —— 开发记忆入口

> 2026-09-23：按用户“开始实施，先在HTML看效果”完成v12随机矩形分区原型与交互对照，512组静态验证、8组新旧原版实景。尚未接入正式F1/扩张，未部署；正式版仍为2026-09-20的v11.1。

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
- 尺度要求：开发房偏大空荡，应增加内部房间，参考对应原版场景，不能四类统一切成小格。
- 2026-09-23分区规划Q1：本轮保持矩形，先丰富数量、尺寸和位置；Q2：允许同场景各合成房明显偏重不同用途，并保留合理配套。随后明确要求开始实施、先在HTML里看效果；本轮先交付真实算法原型和预览，不部署。
- 只改本模组。根/DLC SWF、真实存档、其他模组不改。测试用唯一pferr-style-*应用、newGame(-1)、隐藏ADL，不用Ghost、不干扰用户实例。
- 评审页自动打开曾被Browser URL策略拒绝；不换浏览器、代理或服务器绕过，提供本地文件链接即可。
- 版本替换须重启、回城后新开土地。已载入地图不会自动更新。已决定事项不重复询问。

## 3. 当前状态

- v12原型入口design/partition-preview-v12/index.html：四场景16用途×4边口×8种子；新旧并排、用途/地形/物体三层、分区详情、连续样本和8组原版实景。最终浏览器512条件/8图组、1440/390宽度检查通过，0脚本错误。
- RRSpaceRules先抽用途和尺寸要求，RRPartitionPlan做受约束矩形切分/交错分区/局部重排，connectVolumes按用途联系加权；保留原版地形/内容消费者。仅context.partition="rules"且明确seed时启用，普通F1仍走旧链。
- 开发SWF build/RandomRooms-v12-prototype-1.swf，50589 B，SHA256 299FAD4DA952840C0BB53207335062C573C99A38E478549AE0602D02AF9749A4。不可直接当作已接入的新正式版部署。

- 正式release：v11.1，46044 B，SHA256 16F3D2BD63D19660E039F5F44B4792FD85F3E2119A59F058F8290F5746346C7F；对应build/RandomRooms-v11.1-candidate.swf。日志[RR:v11.1]。
- 完整核心验证候选build/RandomRooms-v11-dev-13.swf，46043 B，SHA256 959A4C3ECD314B988FCECD20CA1DD6C4E78E098F34A7DA7CF2FC6704B0704533；日志[RR:v11-dev]，XML space-v11/revision11.1。
- 原版调查192间外置房、12间实景。RREcology按1.02实际难度选择同房生态，RRGrowth恢复被Land改写的tipEnemy；材料、家具和设施按场景与用途配置。
- v11.1已缩小普通功能房、增加附室，保留作业厅/公共厅/水渠等大空间；小家具组合适配窄房，背景装饰失败不再连带取消实体家具。
- 城市按坐标稳定生成2–4列建筑组及街巷，顶部屋顶，下方住宅/办公/商业/坍塌空间；相邻两行用途延续，扩张保持街巷位置；取消城市随机镜像。
- v11.1同组种子每类32间：内部规划空间平均数工厂4.22→9.81、避难厩5.88→11.06、下水道3.88→7.81、城市5.97→10.75。包括走廊/大厅，不能冒充原版作者房间数。
- 批量128单房+64城市房结构/材料通过，128单房生态通过；16房型均出现；城市112对邻接及请求顺序独立性通过。冻结batch-density-dev13.zip。
- 原版渲染16房型、32图冻结design/assets/v11-density-dev12；这16间与dev13 XML逐项语义一致。新页design/generator-v11-density-review.html含对应原版对照和64格城市用途图。
- dev13四类独立完整扩张均4/4：工厂5717帧/193个旧对象、避难厩6302/189、下水道6120/165、城市5299/190；5×5→8×8、原XML/mirror不变、空箱不补；下水道wetFrames=0。结果对应固定种子，不是穷尽证明。
- 最新dev13原版内容检查100房807个对象、4/4通过；生态100/100一致，创建、成功交互、实际碰撞触发通过。不是逐物体步行、技能成功率或战斗平衡证明。历史dev4/dev7/dev8与独立深池结果另存，不冒充当前验证。

## 4. 正在进行

- 当前里程碑为随机矩形分区HTML原型。partition-dev3新512/512、旧494/512，16组种子重放一致；结构/素材/生态各512通过，4947矩形不重叠/不越界，494对新旧边口相同。8个用途首个成功配对由原版渲染16房32图，捕获输入与导出语义一致。
- 本批新房46间没有贯穿分隔线；连接图多样性提高，但大多数仍有长分隔、局部空墙。4947空间中3002至少有一组用途家具，剩余空间仍可能有其他内容；不能声称家具净空需求已完成。旧版18个失败和dev2新10个失败已冻结，未换种子掩盖。
- 最新完整记录design/partition-preview-v12/validation.md；源码/批次、失败、图片与manifest冻结在同目录。原型已交付可审查；下一步完善家具适配，再接游戏地图与真实通行。
- 上一阶段v11.1实现、验证与用户授权后的部署已完成；相对dev13只修改两处日志版本字符串。正式SWF独立冒烟2/2通过（F5避难厩12房、F1工厂25房，issues=0），证据release-v11.1-smoke。
- 开发验证失败多处涉及驾驶器（过早离梯、坡向、梁面、家具顶面），失败XML/图/日志独立冻结；只有真实完整通过才更新结果。
- 原样单房复查最终通过：工厂18/18目标、4941帧，下水道13/13、1609帧且wetFrames=0。证据plant-interior-dev13、sewer-interior-dev13。早期失败另存；独立封边样本证明内部空间/楼梯平台访问，不当作跨房或每段指定楼梯的独占路径证明。
- 上一正式阶段完整证据：knowledge/experiments/generator-v11-density-validation-2026-09-20.md。

## 5. 已知问题与机制

- 正式v11.1走seedScene→refineSpaces，旧partition/profile.min/max/bias不是有效布局入口。v12原型则走RRSpaceRules→RRPartitionPlan；sceneForm在新链中表示用途组合家族而非固定坐标。archetype除connector特例外不直接选择主体。
- 配置遗留：RRMenu仍显示v10.0；enabled存储/显示但未接入当前合成链；修改种子只保存，synth序列在初始化创建，需要重启。本轮未处理这些配置遗留。
- 正式版房内仍用共享推进的synth随机序列。v12原型固定边口/用途/种子/内容时按阶段独立复现；没有接入地图坐标种子，省略边口仍从外部rnd抽口，不宣称整个地图已顺序独立。原型单房中位约94–147ms、最慢2232ms，搜索慢尾待优化。普通长梯错开失败仍可能回退直梯。
- 自然度尚未等同原版：部分狭长空间、空墙、城市屋顶顶边框可继续打磨；下水道大池保留，几何空格率仍高于原版。
- RRTraversal只是地形图，不是完整物理；实际行走须处理单向梁、家具、门的视线和计时。
- 行动要有到交互中心的isLine视线并持续按住；下键加双击下会先抓邻梯，低门旁落梁只用双击下。梯子中段无接收平台时不能提前跳出。
- 斜梯需上键；公开tile.diagon/getMaxY可读，UnitPlayer.diagon为internal。斜梯下方实体地面是独立行走层，不能把地面格心替换成斜面高度；保留入梯节点、在斜面上沿当前路径走，避免中途重选下方平地。原版跳跃高度依赖按住数帧，一帧脉冲不足以越过普通箱子。固体平台边缘有时须正常跳跃。
- setDoor/setNoObj会省略rem对象：左右入口向内6格、上下3行。人口和家具预留遵守规则。黏液地雷用slime tr=10，不是cid，不读取internal aiState。
- 必经干桥下一格的脚点可能触水；真实干路图排除水面上一格。水下池底stay可能false，不可强求干地站立。
- 未穷尽随机种子、长期扩张、联机、真实旧档死亡恢复、六模组集成、逐敌人战斗、伤害与购买平衡。

## 6. 下一步与回滚

- 依据HTML实景反馈完善家具落位和用途辨识，继续减少机械分层/空墙；优化搜索慢尾及分布偏向。再接F1/右下扩张的房间种子，做实际各入口往返、污水干路、城市连续性和旧对象状态测试。原型静态检查与截图不能替代这些验证；部署另走门禁。
- v11.1已通过发布门禁并部署；用户需完全退出重启，回城后F1进入新地图。后续按实景反馈打磨空墙/狭长空间/城市屋顶边框。
- 当前根pfe.swf为B78244657ED407D03808C90E97325509DB35F802122835F58933FFF8003305AC，ModLoader v2读取mods/loader-manifest.txt；共享事实库已记录此更新。本轮未写根文件或正式清单。截图驾驶器已生成仅测试入口的隔离清单，并按哈希更新宿主副本、拒绝旧日志。v11历史9A814…验证不冒充此宿主的完整功能回归。
- 既有v9回滚包build/release-backups/RandomRoomsMod_before_v10_20260920.swf，37785 B，SHA256 7DC5DB91D6FCE0802EEE73BD3312C6724FB0BCF16A2B48246D00554BEFD8BC4E。v11.1回滚用build/release-backups/RandomRoomsMod_before_v11_1_20260920.swf（v10，41027 B，SHA256 7AC89A73D6A09C0922FD0C7F1FFE7C2C2A836EE635393BF5D32FCC503463058C）；退出游戏后复制回release并核对哈希，重启后进入新地图。
- 正式产物和运行目录不进Git；本次新增冻结证据须保持Git字节哈希，部署记录见当前验证报告末节。

## 7. 深入阅读与复现

- 当前预览design/partition-preview-v12/index.html；验证/局限validation.md；证据evidence/partition-dev3.zip包含生成时源码、开发SWF和完整XML，dev2失败另存。规划design/rule-based-partitions-plan-2026-09-23.md已注明实施进度；此前路线见design/structure-diversity-brainstorm-2026-09-12.md。
- 原型批次build/style-review/harness/run-partitions.ps1 -Output <新批次名> -Samples 8；生成页面build_partition_preview.py --stem <批次名>；check_partition_preview.cjs做实际Chrome交互检查。freeze_partition_preview.py只冻结已验dev3且拒绝覆盖已有包，不用于任意新批次。
- 用户向算法学习：design/generator-explained-v11.1/guide.html（16样本四图层、尺寸实验、有效/遗留参数），flow.html（Archify流程图），source-map.md（源码行号与范围）；文档交互检查不冒充游戏回归。
- 设计来源design/native-scene-audit-2026-09-20.md；decisions/DEC-0005-architectural-generation.md、DEC-0006-scene-identity.md。旧调查页已链接最新密度对照。
- 当前实证knowledge/experiments/generator-v11-density-validation-2026-09-20.md与generator-v11-evidence/；正式v10结果另见v10报告。
- 构建build/build-v7.ps1 -OutputName RandomRooms-v11.1-next.swf只写build；dev13与v11.1-candidate已冻结，不覆盖。旧build-m0.sh直写release，勿用于验证。
- 批量build/style-review/harness/run-baseline.ps1支持-SamplesPerBiome 32 -PopulationDepth 3 -MapSize 8 -MapScene mane；verify_architecture/scenes/population/city_map分别检查。
- 实机build/style-review/game-harness/run-game-captures.ps1 -DevelopmentSwf build/RandomRooms-v11-dev-13.swf -NavigationProbe -GrowthProbe -Scene plant；-SessionDirectory visual-app隔离另一轮。内容-PopulationProbe -AllScenes，冒烟-SmokeOnly。
- freeze_captures.py仅完整且哈希匹配才冻结；失败用freeze_failed_run.py按manifest时间窗口留证，不混入旧captures。AIR独立存储走隔离测试审批，不能借真实存储绕行。
