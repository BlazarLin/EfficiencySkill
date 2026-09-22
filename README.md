# EfficiencySkill

团队共享的 Codex Skills 仓库。

## 当前技能

| 技能 | 用途 |
| --- | --- |
| `vt-algorithm-concept-explainer` | 解释图像算法、数学概念、OpenCV/HALCON 函数与工业视觉工程要点。 |
| `vt-project-activity-analysis` | 分析 C/C++、Python Git 工程及子工程的贡献度、分支活跃度与构建产物。 |
| `vt-check-before-release` | 发布前审查当前分支从 Tag 到 HEAD 的变更，给出复测建议、验收标准和发布红线。 |

## 安装

新电脑先安装 Node.js https://nodejs.org/en/download/current
确保以下命令能运行：

```powershell
npx --version
```

安装单个skill
```powershell
npx skills add Project/EfficiencySkill -g  --skill vt-check-before-release -y
```

列出有哪些skill可以安装
```powershell
npx skills add Project/EfficiencySkill --list
```

安装全部 skill：

```powershell
npx skills@latest add Project/EfficiencySkill -g -a --skill "*" -y
```

查询已安装 skill：

```powershell
npx skills@latest list -g -a
```

将当前仓库的skill安装到系统中
```powershell
npx skills@latest add . -g -a --skill "*" --copy -y
```

将当前仓库的skill更新到服务器中
```powershell
./Publish-EfficiencySkill.cmd
```

内网仓库地址： \\192.168.205.91\f\Project\EfficiencySkill

## 仓库约定

- 每个技能独立放在 `skills/<skill-name>/`，并包含 `SKILL.md`。
- `SKILL.md` 的 YAML frontmatter 必须包含唯一的 `name` 和清晰的 `description`。
- 需要脚本、参考资料或资产时，将其放在该技能自己的子目录中。
- 合并前至少执行一次 `npx skills@latest add . --list`，确认技能可被发现。
