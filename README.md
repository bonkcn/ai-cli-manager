# AI CLI 管理脚本

用于在新的 VPS 环境中一键安装、配置和卸载 Claude Code 与 Codex。

自用脚本，谨慎使用。

## 功能
- 安装 Claude Code
- 安装 Codex
- 更换 Claude Code 提供商
- 更换 Codex 提供商
- 卸载 Claude Code
- 卸载 Codex
- 一键安装全部

## 自动安装说明
- 脚本会优先复用系统现有的 Node.js / npm
- 若未安装 Node.js，会自动尝试 `apt-get`、`dnf`、`yum`、`apk`、`pacman`、`zypper`
- 如果系统没有上述包管理器，或仓库安装失败，会自动回退到 Node.js 官方二进制包安装
- 全局 CLI 安装会自动使用 `sudo`，适合普通用户在新 VPS 上直接执行

## 使用

```bash
bash ai_cli_manager.sh
```

## 一键执行

```bash
curl -fsSL https://raw.githubusercontent.com/bonkcn/ai-cli-manager/main/ai_cli_manager.sh | bash
```

```bash
curl -fsSL -o ai_cli_manager.sh https://raw.githubusercontent.com/bonkcn/ai-cli-manager/main/ai_cli_manager.sh && bash ai_cli_manager.sh
```
