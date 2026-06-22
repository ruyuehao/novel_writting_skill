# 网文写作技巧指南

网文写作辅助工具，专注于仙侠、玄幻品类，提供 12 个写作维度的技巧参考、4 个写作工作流、6 份检查清单，通过 MCP 服务器按需精确检索。本 skill 在 **opencode 框架** 和 **任意 AI 平台**（复制 SYSTEM_PROMPT.md 到 system prompt）中均可使用。使用时记得把mcp解压

## 目录结构

```
novel-writing/
├── SKILL.md                        # Skill 主入口（opencode 框架）
├── SYSTEM_PROMPT.md                # 通用入口（任意 AI 平台）
├── validate.ps1                    # 结构校验脚本
├── README.md                       # 本文档
├── mcp-server/                     # MCP 参考检索服务器
│   ├── package.json
│   ├── index.js                    # MCP 服务器入口
│   ├── build-index.js              # 索引构建脚本
│   └── ref-index.json              # 预构建索引（提交到仓库）
├── references/                     # 12 个写作维度的参考文件
│   ├── 01-scene-atmosphere.md
│   ├── 02-action-description.md
│   ├── 03-detail-description.md
│   ├── 04-emotion-expression.md
│   ├── 05-sentence-dialogue.md
│   ├── 06-character-creation.md
│   ├── 07-plot-pacing.md
│   ├── 08-immersion.md
│   ├── 09-battle-scenes.md
│   ├── 10-psychological-description.md
│   ├── 11-story-architecture.md
│   └── 12-hooks-opening.md
├── assets/templates/               # 写作模板
│   ├── rewrite-before-after-template.md
│   ├── writing-diagnosis-template.md
│   └── writing-exercise-template.md
└── agents/                         # 多模型适配配置
    ├── claude.yaml
    ├── deepseek.yaml
    └── openai.yaml
```

## 前置条件

- Node.js >= 18

## 安装

```bash
cd novel-writing/mcp-server
npm install
```

首次安装或修改 `references/` 或 `SKILL.md` 后需重建索引：

```bash
npm run build
```

如果只想校验 skill 结构完整性（不启动 MCP 服务器）：

```powershell
# PowerShell
.\validate.ps1
```

## MCP 服务器注册

### 方式一：一键注册（推荐）

在 skill 根目录运行注册脚本，自动检测路径并写入 `opencode.json`：

```powershell
.\register-mcp.ps1
```

该脚本会向上搜索最多 6 层目录查找 `opencode.json`，找到后自动写入 MCP 服务器配置。如果不想写入文件、只想查看配置 JSON：

```powershell
.\register-mcp.ps1 -PrintOnly
```

### 方式二：手动配置

将以下配置加入 `opencode.json` 的 `mcpServers` 字段（无需 `cwd`，`command` 使用包装器自动定位目录）：

```json
{
  "mcpServers": {
    "novel-writing": {
      "command": "cmd",
      "args": ["/c", "<skill-绝对路径>/mcp-server/start-mcp.cmd"]
    }
  }
}
```

将 `<skill-绝对路径>` 替换为 skill 所在目录的实际路径，或用 `register-mcp.ps1 -PrintOnly` 自动生成。

## 通用使用方式（任意 AI 平台）

将 `SYSTEM_PROMPT.md` 的内容完整复制到 AI 的 system prompt（系统提示词）中即可使用。无需 opencode 框架，Claude.ai、ChatGPT、DeepSeek Chat、Cursor 等平台均可。

包含：
- 角色定义与激活关键词
- 4 个完整工作流
- 12 个写作维度的参考索引
- 6 份检查清单
- 执行规范与写作示例

如果 AI 平台支持 MCP 协议，可按下方说明连接 MCP 服务器实现精确技巧检索；不支持的平台可直接阅读 `references/` 目录下的参考文件。

## 使用方式（opencode）

### 方式一：通过工具调用（推荐）

当 LLM 加载本 skill 后，通过 MCP 工具 `get_technique` 按写作维度获取技巧参考：

```json
// 获取情绪表达技巧（附带检查清单）
{
  "domain": "emotion",
  "workflow": 1
}

// 获取战斗描写技巧（不含检查清单）
{
  "domain": "battle"
}
```

### 方式二：直接阅读参考文件

每个写作维度对应一个 `references/` 文件，可直接打开阅读：

| 维度 | 文件 | 关键词 |
|------|------|--------|
| scene | `01-scene-atmosphere.md` | 场景氛围、五感法、揉入动作法 |
| action | `02-action-description.md` | 动作拆解、次级动作、停顿节点 |
| detail | `03-detail-description.md` | 专属特征、小障碍、情绪意象 |
| emotion | `04-emotion-expression.md` | 动作演绎、面部分解、生理反应 |
| dialogue | `05-sentence-dialogue.md` | 断句、潜台词、对白互动感 |
| character | `06-character-creation.md` | 成长弧线、配角功能、反派动机 |
| pace | `07-plot-pacing.md` | 节奏控制、场景转换、铺垫余波 |
| immersion | `08-immersion.md` | 代入感六支柱、认知共鸣 |
| battle | `09-battle-scenes.md` | 三段式战斗、层次感、环境互动 |
| psychology | `10-psychological-description.md` | 内心独白、冲突、意识流 |
| plot | `11-story-architecture.md` | 三级大纲、爽点体系、伏笔回收 |
| hooks | `12-hooks-opening.md` | 黄金三章、章首/章末钩子 |

## 写作工作流

SKILL.md 定义了 4 个写作工作流，根据当前场景自动匹配：

| 工作流 | 适用场景 |
|--------|---------|
| 同步写作 | 从零开始写一个新段落 |
| 多维润色 | 已有段落综合改稿 |
| 定向优化 | 某个写作维度特别弱 |
| 卡文诊断 | 不知道怎么写下去 |

每个工作流程中标注了应使用的 `domain` 参数，调用 `get_technique` 获取对应技巧参考。

## 域间交叉引用

同一技术小节可能映射到多个写作维度。例如 `情绪匹配意象法` 同时属于 `scene`、`emotion`、`detail` 三个 domain，在任一个维度下调用都会返回该小节。

| 维度 | 小节数 | 跨域引用 |
|------|--------|---------|
| scene | 8 | 引用 emotion, immersion, detail |
| emotion | 9 | 引用 scene, action, battle, psychology |
| action | 7 | 引用 emotion, character, battle |
| dialogue | 3 | 引用 pace |
| character | 11 | 引用 detail, psychology, plot |
| detail | 5 | 引用 scene, emotion, pace |
| pace | 9 | 引用 scene, character, plot |
| immersion | 5 | 引用 scene, emotion, plot |
| battle | 6 | 引用 action, psychology |
| psychology | 5 | 引用 emotion, character |
| plot | 14 | 引用 pace, immersion, hooks |
| hooks | 7 | 引用 plot |

## 检查清单

本 skill 提供 6 份检查清单，调用 `get_technique` 时传 `workflow` 参数可附带：

- **场景画面检查清单** — 评估场景描写的画面感与功能性
- **情绪表达检查清单** — 检查是否以"演"代"说"
- **动作对白检查清单** — 评估动作拆解和对白互动
- **人物塑造检查清单** — 检查角色立体度和成长弧线
- **代入感检查清单** — 评估读者共鸣和沉浸感
- **节奏与段落检查清单** — 检查节奏控制与段落变换

## 常见问题

### ref-index.json 不存在或过期

运行 `npm run build` 重新构建索引。

### 修改了 references/ 后需要做什么

修改参考文件内容后重新运行 `npm run build` 更新索引。

### 新增或修改 `references/` 中的标题

当你在 `references/` 的某个 `.md` 文件中添加新的 `##` 标题时，需要同步更新以下文件：

1. **`mcp-server/build-index.js` 的 `SECTION_MAP`** — 添加新条目，指定 `file`、`heading`、`domains`
2. **`mcp-server/build-index.js` 的 `CHECKLIST_MAP`** — 如果使用了新的 domain 名称，需要将其映射到检查清单
3. **`SKILL.md` / `SYSTEM_PROMPT.md`** — 如需新增检查清单，同步更新两处
4. **`README.md` 的"域间交叉引用"表** — 更新维度的"小节数"和"跨域引用"
5. **`agents/*.yaml` 的 `activation_keywords`** — 将新的关键词加入各 agent 配置，确保 LLM 能正确激活
6. **`SYSTEM_PROMPT.md`** — 更新激活关键词列表和 Reference Index 表

修改后运行 `npm run build` 重建索引，观察控制台是否有 `[WARN]` 输出（如果 `SECTION_MAP` 未完全覆盖新增标题会警告）。
运行 `npm test` 确认全部测试通过。

### 想增加新的写作维度

1. 添加新的 `references/xx-xxx.md` 文件，使用 `##` 标题划分各个技术小节
2. 在 `mcp-server/build-index.js` 的 `SECTION_MAP` 数组中为每个 `##` 标题添加条目
3. 如果新维度需要关联已有或新增检查清单，更新 `CHECKLIST_MAP`
4. 将新维度的 domain 名加入 `mcp-server/index.js` 的 `VALID_DOMAINS` 数组（如果 server 做了校验）
5. 更新 `README.md` 的"使用方式"维表、"域间交叉引用"表、"写作工作流"表
6. 更新 `agents/*.yaml` 的 `activation_keywords`，增加新维度的相关关键词
7. 更新 `SYSTEM_PROMPT.md` 的激活关键词列表和 Reference Index 表
8. 运行 `npm run build && npm test` 验证索引构建和测试
