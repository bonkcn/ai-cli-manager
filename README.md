# AI CLI 管理脚本

用于在新的 VPS 环境中一键安装、配置和卸载 Claude Code 与 Codex。

自用脚本，谨慎使用。

## 功能
- 菜单顺序固定为：
  - `1. 安装 Claude Code`
  - `2. 更换 Claude Code 提供商`
  - `3. 卸载 Claude Code`
  - `4. 安装 Codex`
  - `5. 更换 Codex 提供商`
  - `6. 卸载 Codex`
  - `7. 一键安装全部`
- 自动安装 Claude Code
- 自动安装 Codex
- 自动安装和配置 Node.js / npm
- Claude Code 提供商配置自动写入 `~/.bashrc`
- 更换 Claude Code 提供商时会先清理旧的 `ANTHROPIC_*` 再覆盖
- Claude Code 首次配置后会自动重新加载 `~/.bashrc`
- Codex 提供商配置自动写入 `~/.codex/auth.json`、`~/.codex/config.toml` 和 `~/.bashrc`

## 自动安装说明
- 脚本会优先复用系统现有的 Node.js / npm
- 若未安装 Node.js，会自动尝试 `apt-get`、`dnf`、`yum`、`apk`、`pacman`、`zypper`
- 如果系统没有上述包管理器，或仓库安装失败，会自动回退到 Node.js 官方二进制包安装
- 全局 CLI 安装会自动使用 `sudo`，适合普通用户在新 VPS 上直接执行

## 运行

已下载到本机后：

```bash
bash ai_cli_manager.sh
```

如果你保存到了 `/root/ai_cli_manager.sh`：

```bash
bash /root/ai_cli_manager.sh
```

## 在线执行

```bash
curl -fsSL https://raw.githubusercontent.com/bonkcn/ai-cli-manager/main/ai_cli_manager.sh | bash
```

下载后再执行：

```bash
curl -fsSL -o ai_cli_manager.sh https://raw.githubusercontent.com/bonkcn/ai-cli-manager/main/ai_cli_manager.sh && bash ai_cli_manager.sh
```

## 强制更新最新版脚本

测试服务器怀疑命中旧缓存时，直接这样更新：

```bash
curl -H 'Cache-Control: no-cache' -fsSL -o /root/ai_cli_manager.sh "https://raw.githubusercontent.com/bonkcn/ai-cli-manager/main/ai_cli_manager.sh?ts=$(date +%s)" && bash /root/ai_cli_manager.sh
```

## 配置行为说明

### Claude Code

- 更换或首次配置时会写入：
  - `export ANTHROPIC_AUTH_TOKEN=...`
  - `export ANTHROPIC_BASE_URL=...`
- 写入目标文件：`~/.bashrc`
- 如果检测到旧的 `ANTHROPIC_AUTH_TOKEN` / `ANTHROPIC_BASE_URL`，会先删除再写入
- 写入后脚本会自动尝试重新加载 `~/.bashrc`

### Codex

- API Key 会写入 `~/.codex/auth.json`
- base URL 和默认模型会写入 `~/.codex/config.toml`
- 同时会写入 `~/.bashrc`：
  - `export OPENAI_BASE_URL=...`
  - `export OPENAI_API_KEY=...`
