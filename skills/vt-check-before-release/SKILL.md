---
name: vt-check-before-release
description: 版本发布前对 git 变更做代码级审查，输出含整体复测重点、发布阻止红线和风险提示的精简 PDF 审查报告。逐个审查关键提交的实际代码 diff，不只是归纳 commit message；适用于含子模块的多仓库项目。
---

# VT 发布前代码审查

版本发布前，对从「上一个 tag」到「当前 HEAD」的代码变更做代码级审查，产出可直接发给测试人员的精简 PDF 审查报告，重点是整体复测重点、发布阻止红线和风险提示。

## 适用场景

- 新版本发布前，梳理变更、定位风险、给出可执行的复测清单
- 含子模块的多仓库项目（主项目 + git submodule）

## 对比基准

- **默认**：每个仓库（主项目 + 各子模块）各自从「最近一个 tag」到 HEAD
- 子模块用**子模块自己的最近 tag**，不是主项目引用的子模块 commit
- 用户特殊说明时（如「近 N 个 tag」），按指定范围
- 基准一旦确定，全文统一，不中途变更

## 强制范围确认（不得跳过）

在开始任何变更统计、`git log`、`git diff`、`git show`、代码审查或报告生成前，必须先完成以下确认闸门：

1. 只查询当前 `HEAD` 可达的 tag；其他分支上的 tag 不参与候选：

   ```bash
   git tag --merged HEAD --sort=-creatordate | head -3
   ```

   子模块同样在各自仓库执行 `git tag --merged HEAD --sort=-creatordate | head -3`。

2. 列出最近 3 个候选 tag、当前 HEAD 短 SHA，以及默认选中的最新 tag；向用户明确展示：

   ```text
   候选 tag：<tag1>、<tag2>、<tag3>
   检查范围为 <tag1> -> HEAD（<head-short-sha>），若无异议则继续分析；
   ```

3. **必须等待用户明确回复确认**（例如“确认”“继续”或指定候选 tag）。未确认前只能读取 tag、HEAD、子模块路径等范围元数据；不得读取变更统计、commit、diff，也不得生成审查报告。

4. 用户改选 tag 或范围时，重新展示新的 `<tag> -> HEAD` 范围并再次等待确认；不能把沉默、未回复或“看一下”当作确认。

5. 当前 HEAD 没有可达 tag 时，先要求用户提供明确时间范围（例如“近 30 天”或起止日期）；得到范围后展示 `<起点> -> HEAD` 并按同样规则等待确认。

## 工作流

### 1. 摸清仓库结构

```
git tag --sort=-creatordate | head        # 主项目最近 tag
git submodule status && cat .gitmodules   # 子模块
git -C <子模块> tag --sort=-creatordate | head   # 子模块最近 tag
```

记录：主项目路径、各子模块路径、各仓库 HEAD、基准 tag、tag 创建时间。

### 2. 展示范围并等待确认

按“强制范围确认”章节执行。用户确认前在此停止，不能进入后续步骤。

### 3. 收集变更统计

每个仓库：
```
git diff --shortstat <tag>..HEAD                                   # commits/files/lines
git log <tag>..HEAD --pretty=format:"%h | %an | %ad | %s" --date=short
git diff --name-status <tag>..HEAD
```

### 4. 代码审查（核心 — 不是只归纳 commit message）

对关键提交（大改动、feature、fix）**逐个审查实际 diff**：

- **先概览 hunk 头**：`git show <commit> | grep -E "^diff --git|^@@"`，了解改了哪些函数
- **再深看新增行**：`git show <commit> -- <file> | grep -E "^\+" | grep -v "^+++"`，聚焦：
  - 新增/修改的函数调用 → 触达哪些旧模块
  - 接口签名变化
  - include 变化
  - 关键逻辑分支与行为变更
- **影响旧模块从代码分析得出**，不是只看 fileChange。fileChange 只告诉你改了哪个文件，代码 diff 才告诉你触达了哪些旧接口
- **commit message 只作线索，以代码为准**：message 写 feature 但实际是修 bug 的，按 bug 归类；message 没写的改动，从 diff 里挖出来

### 5. 提取全局发布信息

不再按“新功能与功能完善”“Bug 修复”分类。代码审查结果只用于提炼发布阻止红线、整体复测重点和风险提示，不为每个模块单独写影响分析或复测建议。

### 6. 整体复测重点

只有同一个功能或同一条完整功能链路的复测才允许合并。不同功能即使共用接口、数据或风险类型，也必须分别列出复测内容。

新功能如果调用、修改或改变了旧功能路径，在该新功能的复测项中把所有关联旧功能一并列出；每个关联功能都要写清楚复测场景和通过标准。不限制条目数量，但同一功能的重复场景必须合并。

### 7. 发布阻止红线

分三档，明确判断：
- 🔴 **必须通过才能发版**（任一不过就不发）：列出红线项 + 理由
- 🟡 **可带条件发版**：记录已知限制和放行条件（如协议没补齐先不开、超限可回退旧版）
- 🟢 **不影响发版**：辅助问题发版后迭代

### 8. 风险提示

按需列出：二进制库无源码、协议未补齐、接口签名变更兼容性、模型体积/性能影响、回归面提示（大改后哪些未变更模块也建议回归）等。

## 报告内容与取舍（强制）

本报告给项目负责人、开发和测试人员阅读，不是代码审计底稿。简洁优先，但不设页数、风险项或复测项数量上限。

- **每个主项目或子模块只保留基本信息与变更规模**：
  - 变更规模：commit 数、文件数、新增/删除行数。
  - 基准：`<Tag> -> HEAD <短 SHA>`，并标出 Tag 日期。
  - 时间区间：首个变更提交日期～最新变更提交日期。
  - 贡献者：按实际提交记录去重列出。

  ```text
  ## 子模块 <模块名>
  ### 基本信息
  > 变更规模：<commit 数> commits | <文件数> files | +<新增行> / -<删除行>
  - 基准：<Tag> -> HEAD <短 SHA>（<Tag 日期>）
  - 时间区间：<开始日期> ～ <结束日期>
  - 贡献者：<姓名1>、<姓名2>
  ```
- 不输出“新功能与功能完善”“Bug 修复”“影响模块与复测建议”等模块；不列文件清单、逐 commit 记录、完整 diff 或实现过程。
- 各模块信息后，报告只保留三个全局章节：**发布阻止红线**、**整体复测重点**、**风险提示**。
- 发布阻止红线、整体复测重点和风险提示不限制条目数量。整体复测重点只允许合并同一个功能或同一条完整功能链路；不同功能必须单独列项。新功能影响旧功能时，在该项内列全关联旧功能的复测内容。没有发布阻止项时明确写“无发布阻止项”。
- 二进制库且无源码时，仅在影响发版时标注“未做源码验证”。Markdown 只能作为生成 PDF 的临时输入；最终只保留 PDF。

## 输出

### PDF 文档

- **文件名**：`YYMMDD_<主项目名>_发布前审查.pdf`（日期用当前本地日期，两位年月日，如 260721）
- 保存到主项目根目录
- 结构：各仓库（基本信息 + 变更规模醒目块）→ 发布阻止红线 → 整体复测重点 → 风险提示

### PDF 生成

环境依赖：Python 3 + Chrome 或 Edge。脚本会自动安装缺失的 `markdown-it-py` 和 `pypdf`；Chrome/Edge 未安装时会提示用户安装。

**直接调用技能自带脚本**（不要手写临时脚本，省约 3000 token）：

```bash
python "<技能目录>/scripts/gen_review_pdf.py" "<md路径>" [pdf路径]
```

`scripts/gen_review_pdf.py` 一条命令完成：自动安装缺失 Python 依赖 -> Markdown -> HTML（GFM + 美观 CSS）-> Chrome headless PDF -> pypdf 验证页数/中文 -> 替换正式 PDF（处理阅读器占用）-> 清理临时文件。pdf 路径省略时自动取 md 同名 .pdf。PDF 成功后删除临时 Markdown；依赖安装、浏览器检测、转换、验证或替换失败时保留 Markdown 并提示用户路径。

脚本内嵌 CSS 要点：A4 纸张、微软雅黑中文字体、表格斑马纹 + 深色表头、代码浅灰底、blockquote 左边框浅蓝背景、`page-break-after: avoid` 避让标题孤行、`thead { display: table-header-group }` 跨页重复表头。

**环境检查（合并一条命令，不要分次跑）**：

```bash
python --version; python -c "import markdown_it,pypdf; print('md-it',markdown_it.__version__,'pypdf',pypdf.__version__)"; ls "/c/Program Files/Google/Chrome/Application/chrome.exe" 2>/dev/null && echo "Chrome OK" || (ls "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" 2>/dev/null && echo "Edge OK")
```

> ⚠️ 若需自定义 CSS 而手写脚本：markdown-it-py 3.0 用 `MarkdownIt("default", options_update={"html": True})` + `enable(["table"])`，**不支持 `preset=` 关键字参数**（会报 TypeError）；CSS 含花括号，HTML 拼接用字符串 `+`，不要用 f-string。

## 语言风格（重要 — 去 AI 味）

工程口语，像内部技术文档，不要官方腔。避免 / 改用：

| 避免（AI 官腔） | 改用（工程口语） |
|---|---|
| 劣化 | 降低 / 变差 |
| 无崩溃/卡死 | 不崩溃不卡死 |
| 无持续增长 | 不持续涨 |
| 无错位撕裂 | 不错位不撕裂 |
| 无残留引用 | 没残留引用 |
| 经产品确认 | 和产品确认过 |
| 需与XX确认 | 要和XX确认 |
| 需向XX索取 | 找XX要 |
| 可承受 / 在可接受范围 | 扛得住 / 能接受 |
| 可达性 | 能发出去 |
| 回归基线 | 和 \<tag\> 对比 |
| 建议XX | 要XX / 得XX |
| 确保 | 去掉 |
| 任一未过即阻塞 | 任意一项不过就不发 |
| 可带条件发布 | 可以带条件发版 |
| 不阻塞 | 不影响发版 |
| 导致检测缺失 | 会漏检 |
| 导致现场争议 | 现场会扯皮 |

## 格式要求

- **不记录测试人员不关心的内容**：涉及文件列、改了哪个 cpp — 这些对测试无用
- **变更规模醒目**：用 `> 📊 **变更规模：...**` 引用块显示，不与汇总表重复
- **表格列宽均衡**：某列内容过长导致列宽失衡时，改用分条格式
- **信息不冗余**：同一数据只在一处详列
- **文件路径用反引号纯文本**，不用 markdown 链接（报告要发给人看，不需要可点击链接）
- **功能说明压缩到 1 行**，细节放代码 diff 里看，不堆进报告

## 客观原则

- **二进制库（dll/lib/pdb）无源码**的功能点，标注「基于 commit message，未源码验证」，不把 message 当已验证事实
- **数据以 `git diff --shortstat` 实际查询为准**，不臆测；用户给的参考数据若与实际不符，以实际为准并说明差异
- **行为变更归类一致**：同一行为不能既算新功能又算变更功能
- **发现的工程问题**（如子模块配置异常、`.gitmodules` 缺映射）如实提示，由用户决定是否记录进报告
- **不要一味顺着用户**：若用户思路有风险或误区，直接指出并给理由

## 省 token 举措（预置，运行时直接复用）

以下举措已实测有效，运行时直接套用，不要重新探索：

1. **PDF 生成调用固化脚本**：`python <技能目录>/scripts/gen_review_pdf.py <md路径>` 一条命令完成，不手写临时脚本。省约 3000 token（CSS + 脚本逻辑不入上下文）。

2. **范围元数据查询并行**：tag 列表、HEAD SHA、子模块状态、当前分支 4 个查询合并成一次响应（多个 Bash 并行），不逐个执行。

3. **环境检查合并一条 Bash**：Python 版本 + markdown-it-py + pypdf + Chrome 路径检查合并成一次调用（见 PDF 生成章节）。

4. **diff 审查 hunk 头 + 关键词 grep**（核心省 token 手法）：
   - 概览：`git show <commit> | grep -E "^diff --git|^@@"` 看改了哪些函数
   - 深看：`git show <commit> -- <file> | grep -E "^\+" | grep -v "^+++" | grep -iE "join|stop|wait|thread|delete|mutex|lock|nullptr|disconnect"` 只看新增行的关键词
   - 大 diff（>200 行）绝不全量 dump

5. **多提交 stat 并行**：`git show <commit> --stat` 多个提交并行查规模，不逐个全量 diff。

6. **二进制一次性过滤**：`git diff --name-only <tag>..HEAD | grep -iE "\.(dll|lib|pdb|exe|trt|onnx|engine)$"` 一次列全部二进制，不逐个文件判断。

7. **commit 按主题归类**：不逐个审查所有提交，按主题分组（如"多相机合图""判定工具"），只对关键提交深看 diff，其余归类一笔带过。

8. **报告一次成型 Write**：用 Write 一次写完整个报告，不多次 Edit 拼接。

9. **强制范围确认前置**：用户确认范围后再做实质工作，避免方向错误后返工（最大省 token 项，一次错误方向浪费上万 token）。

其他：报告精炼，复测建议是重点，其他部分从简。
