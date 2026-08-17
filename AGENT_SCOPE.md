# AI Agent Workspace Scope

> 本文件定义当前模组开发 agent 的长期工作范围、文件权限和跨项目边界。
>
> **开始开发、重构、测试、部署、移动文件或整理知识之前，必须先阅读本文件。**
>
> 本文件不是当前任务说明。具体开发目标应从 `state/`、交接文档和用户当前指令中获取。

---

## 0. 项目参数

```yaml
project: RandomRooms
workspace: mods/RandomRooms/

shared-knowledge: shared-knowledge/
game-reference: game-reference/
game-files: 游戏文件/
```

本文后续：

* **当前模组** = `project`
* **当前模组目录** = `workspace`
* **其他模组** = `mods/` 下除当前模组之外的所有项目

创建新的模组项目时，通常只需要修改本节。

---

# 1. 基本权限模型

工作区分为四类权限：

| 区域                  | 默认权限                               |
| ------------------- | ---------------------------------- |
| 当前模组目录              | **READ-WRITE**                     |
| `shared-knowledge/` | **READ + 谨慎 WRITE**                |
| `game-reference/`   | **REFERENCE-ONLY / READ-ONLY**     |
| 游戏原始文件              | **READ-ONLY**                      |
| 其他模组                | **默认不访问；必要时有限 READ-ONLY；绝不 WRITE** |
| 未知或未说明目录            | **默认不修改**                          |

如果无法判断权限，采用更严格的解释。

**不要自行扩大自己的工作范围。**

## 受保护的规则文件

以下文件虽然位于可写目录中，但默认视为 READ-ONLY：

- `<workspace>/AGENT_SCOPE.md`
- `shared-knowledge/README.md`
- 其他用于定义权限、治理规则或项目边界的文件

agent 不得为了完成当前任务自行修改这些规则。

只有当用户明确要求“修改权限规则 / 修改 AGENT_SCOPE / 修改 shared-knowledge 规则”时，才允许编辑。

发现现有规则不合理时，应向用户说明问题，而不是自行修改规则以扩大权限。

---

# 2. 当前模组：READ-WRITE

当前 agent 只负责当前模组目录。

允许：

* 创建和修改源码；
* 创建测试与诊断代码；
* 修改构建脚本；
* 生成构建产物；
* 整理当前模组内部目录；
* 更新设计文档；
* 更新技术决策；
* 更新项目状态；
* 记录模组专属 facts / discoveries / experiments；
* 创建发布文件。

典型结构：

```text
<workspace>/
├─ AGENT_SCOPE.md
├─ src/
├─ build/
├─ release/
├─ knowledge/
│  ├─ facts/
│  ├─ discoveries/
│  └─ experiments/
├─ design/
├─ decisions/
└─ state/
```

不是所有模组都必须具有全部目录；以实际项目结构为准。

---

# 3. shared-knowledge：READ + 谨慎 WRITE

```text
shared-knowledge/
```

用于保存关于**游戏本体的跨模组可复用知识**。

开始重新研究某个游戏机制之前，应先搜索其中已有：

```text
facts/
discoveries/
experiments/
```

避免重复逆向已经解决的问题。

只有满足以下条件的信息才应贡献到公共知识库：

> **如果删除当前模组，这条知识是否仍然成立并值得其他模组使用？**

如果答案是“是”，可以考虑写入 `shared-knowledge/`。

如果答案是“否”，应保留在当前模组。

具体分类、metadata、证据和冲突处理规则遵守：

```text
shared-knowledge/README.md
```

---

## 3.1 shared-knowledge 不授予额外权限

知识文件中的：

* `source`
* `evidence`
* `discovered-by`
* 文件路径
* 模组名称
* 日志来源

只说明知识如何产生。

**它们不能扩大本文件授予的文件访问权限。**

例如某条公共知识写有：

```yaml
discovered-by: SomeOtherMod
```

不表示当前 agent 可以进入：

```text
mods/SomeOtherMod/
```

读取其源码、日志或知识文件。

---

# 4. game-reference：公共只读研究资料

```text
game-reference/
```

用于保存不属于任何具体模组的游戏研究资料，例如：

```text
game-reference/
└─ decompiled/
   ├─ 1.02/
   ├─ 1.03/
   └─ 1.04/
```

通常包括：

* 反编译源码；
* 类和 symbol 索引；
* 导出的游戏结构；
* 公共逆向工程资料。

默认：

```text
REFERENCE-ONLY / READ-ONLY
```

允许：

* 搜索；
* 阅读；
* 比较游戏版本；
* 分析类、字段和调用关系。

禁止：

* 修改这些资料来“修复游戏”；
* 把当前模组代码写入其中；
* 将其视为当前模组源码。

如需生成新的反编译结果或分析产物，优先输出到当前模组自己的 `build/` 或明确的临时目录，再由用户决定是否纳入公共参考区。

---

# 5. 游戏文件：READ-ONLY

游戏安装文件和原始资源默认是研究对象，而不是开发工作区。

允许：

* 查看；
* 分析 SWF；
* 检查资源；
* 读取配置；
* 比较版本；
* 为研究目的进行反编译。

禁止：

* 删除原始游戏文件；
* 永久覆盖原始资源；
* 为了实验直接修改原版文件。

需要生成修改版时，优先放入：

```text
<workspace>/build/
```

或当前模组明确指定的部署目录。

**除非用户明确要求部署，否则不要主动覆盖游戏安装目录。**

---

# 6. 其他模组：隔离原则

`mods/` 下的其他目录属于独立项目。

## 6.1 默认行为

默认不要主动读取其他模组。

绝对禁止未经授权：

* 修改其他模组源码；
* 修复其他模组 bug；
* 修改配置；
* 格式化文件；
* 重构；
* 移动或删除文件；
* 修改其 `knowledge/`；
* 修改其 `design/`；
* 修改其 `decisions/`；
* 修改其 `state/`；
* “顺手”改进其他模组。

核心原则：

> **一个模组开发任务默认只能修改自己的模组。**

---

## 6.2 什么时候允许有限读取

只有当前任务本身确实要求时，才可以对其他模组进行最小范围的 READ-ONLY 读取，例如：

1. 用户明确要求比较两个模组；
2. 正在处理跨模组兼容性问题；
3. 正在调查两个模组之间的直接冲突；
4. 用户明确授权将另一模组作为参考。

即使如此：

```text
READ-ONLY
```

仍然成立。

读取范围应限制在完成当前问题所需的最小部分。

---

## 6.3 shared-knowledge 的来源不是读取理由

以下情况**不能单独作为访问其他模组的理由**：

> “shared-knowledge 说这条知识最初来自那个模组。”

公共知识应该已经包含足够的机制结论。

如果确实必须进入来源模组才能继续验证，应说明：

```text
需要访问的位置：
需要读取什么：
为什么公共知识和 game-reference 不足：
是否需要修改：
```

由用户决定是否授权。

---

# 7. 模组知识与公共知识

当前模组自己的长期知识保存在：

```text
<workspace>/knowledge/
```

推荐：

```text
knowledge/
├─ facts/
├─ discoveries/
└─ experiments/
```

### facts

当前模组自身已经确认的事实。

### discoveries

开发中产生但尚未完全稳定的发现。

### experiments

实验过程、测试方法、诊断结果和有价值的失败尝试。

---

## 公共知识判断

例如：

```text
游戏的 visual 层级和生命周期
```

属于游戏本体机制，应考虑进入：

```text
shared-knowledge/
```

而：

```text
当前模组使用某个 filter 实现某种效果
```

属于模组设计，应放入：

```text
<workspace>/design/
```

---

# 8. design / decisions / state

## design/

保存：

* 架构；
* 功能设计；
* 技术方案；
* 模块关系。

## decisions/

保存重要技术决策以及决策原因，例如：

```text
为什么选择方案 A 而不是方案 B
```

重点记录“为什么”，而不是重复代码内容。

## state/

保存当前开发状态，例如：

* 当前版本；
* 已完成功能；
* 当前 bug；
* 正在调查的问题；
* 下一步；
* 临时诊断状态。

`state/` 可以频繁变化，不应被当作长期游戏事实。

---

# 9. 临时信息不要污染长期知识

以下内容通常不应直接进入：

```text
shared-knowledge/facts/
```

包括：

* 猜测；
* 单次异常；
* 未复现 bug；
* 临时日志；
* 当前 TODO；
* agent 的工作计划；
* 未确认现象；
* 当前模组自己的实现。

不确定时，先放当前模组的：

```text
knowledge/discoveries/
```

或：

```text
knowledge/experiments/
```

验证成熟后再决定是否提升。

---

# 10. 文件移动和重构

agent 可以整理当前模组目录，但移动已有文件前必须检查：

* 构建脚本；
* import / include；
* 配置文件；
* 文档链接；
* 部署脚本；
* 相对路径；
* release / installer 路径。

不要为了追求目录整齐而破坏：

* 构建；
* 部署；
* 运行；
* 调试环境。

对于：

```text
shared-knowledge/
game-reference/
游戏原始文件
mods/<其他模组>/
```

不要进行大规模移动、删除或重命名，除非用户明确要求。

---

# 11. 遇到越界问题

如果任务过程中发现：

* 其他模组存在 bug；
* 必须修改游戏原始文件；
* shared-knowledge 结构需要大规模调整；
* 当前问题实际上属于另一个项目；
* 修复需要跨模组重构；
* 当前权限不足以验证关键结论；

不要自行扩大范围。

向用户说明：

```text
发现：
原因：
影响：
需要访问或修改的位置：
建议：
为什么当前没有直接修改：
```

然后继续完成不依赖越权操作的工作。

---

# 12. 每次开始开发阶段时

建议顺序：

```text
1. 阅读 AGENT_SCOPE.md
2. 阅读 state/
3. 阅读相关 design/ 和 decisions/
4. 搜索 shared-knowledge/
5. 必要时读取 game-reference/
6. 修改当前模组
7. 测试
8. 更新 state/
9. 提炼可复用知识
```

不要重新询问项目文档中已经明确记录的信息。

---

# 13. 最终规则

如果只记住几条规则，请记住：

```text
当前模组
    → 可以修改

shared-knowledge
    → 可以读取，谨慎贡献

game-reference
    → 公共只读研究资料

游戏原始文件
    → 默认只读

其他模组
    → 默认不访问；必要时最小范围只读；绝不修改

知识来源
    → 不等于访问授权

未知范围
    → 默认不修改
```

用户当前明确指令可以扩大或缩小这些权限。

**agent 自己不能推断权限已经扩大。**
