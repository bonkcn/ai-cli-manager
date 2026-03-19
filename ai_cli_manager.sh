#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
MANAGER_DIR="${HOME}/.ai-cli-manager"
BACKUP_DIR="${MANAGER_DIR}/backups"
CLAUDE_BASHRC_START="# >>> AI_CLI_MANAGER_CLAUDE >>>"
CLAUDE_BASHRC_END="# <<< AI_CLI_MANAGER_CLAUDE <<<"
CODEX_BASHRC_START="# >>> AI_CLI_MANAGER_CODEX >>>"
CODEX_BASHRC_END="# <<< AI_CLI_MANAGER_CODEX <<<"
CODEX_CONFIG_START="# >>> AI_CLI_MANAGER_CODEX_PROVIDER >>>"
CODEX_CONFIG_END="# <<< AI_CLI_MANAGER_CODEX_PROVIDER <<<"

mkdir -p "$MANAGER_DIR" "$BACKUP_DIR"

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
elif command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  echo "此脚本在安装软件时需要 root 权限。"
  exit 1
fi

log() {
  printf '%s\n' "$*"
}

success() {
  printf '[OK] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*"
}

error() {
  printf '[ERR] %s\n' "$*" >&2
}

pause() {
  printf '\n按回车继续...'
  read -r _
}

backup_file() {
  local file="$1"
  if [ -f "$file" ]; then
    local base ts
    base="$(basename "$file")"
    ts="$(date +%Y%m%d-%H%M%S)"
    cp "$file" "${BACKUP_DIR}/${base}.${ts}.bak"
  fi
}

ensure_parent_dir() {
  local file="$1"
  mkdir -p "$(dirname "$file")"
}

strip_block() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"
  [ -f "$file" ] || return 0

  awk -v start="$start_marker" -v end="$end_marker" '
    $0 == start { skip = 1; next }
    $0 == end { skip = 0; next }
    !skip { print }
  ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

append_block() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"
  local block="$4"

  ensure_parent_dir "$file"
  touch "$file"
  strip_block "$file" "$start_marker" "$end_marker"

  if [ -s "$file" ] && [ -n "$(tail -c 1 "$file" 2>/dev/null)" ]; then
    printf '\n' >> "$file"
  fi

  {
    printf '%s\n' "$start_marker"
    printf '%s\n' "$block"
    printf '%s\n' "$end_marker"
  } >> "$file"
}

prompt_required() {
  local label="$1"
  local value=""
  while [ -z "$value" ]; do
    printf '%s: ' "$label"
    read -r value
    if [ -z "$value" ]; then
      warn "$label 不能为空。"
    fi
  done
  printf '%s' "$value"
}

prompt_default() {
  local label="$1"
  local default_value="$2"
  local value=""
  printf '%s [%s]: ' "$label" "$default_value"
  read -r value
  if [ -z "$value" ]; then
    value="$default_value"
  fi
  printf '%s' "$value"
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

ensure_node() {
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    success "Node.js 已可用: $(node -v), npm $(npm -v)"
    return 0
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    error "当前缺少 Node.js，且系统没有 apt-get。请先手动安装 Node.js。"
    return 1
  fi

  log "正在安装 Node.js 22 ..."
  $SUDO apt-get update
  $SUDO apt-get install -y ca-certificates curl gnupg
  curl -fsSL https://deb.nodesource.com/setup_22.x | $SUDO bash -
  $SUDO apt-get install -y nodejs

  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    success "Node.js 安装完成: $(node -v), npm $(npm -v)"
    return 0
  fi

  error "Node.js 安装未成功完成。"
  return 1
}

install_claude_code() {
  ensure_node || return 1
  log "正在安装 Claude Code ..."
  npm install -g @anthropic-ai/claude-code
  if command -v claude >/dev/null 2>&1; then
    success "Claude Code 安装完成: $(claude --version 2>/dev/null || echo "版本检测失败")"
  else
    error "Claude Code 安装完成，但 PATH 中未找到 'claude' 命令。"
    return 1
  fi
}

install_codex() {
  ensure_node || return 1
  log "正在安装 Codex ..."
  npm install -g @openai/codex
  if command -v codex >/dev/null 2>&1; then
    success "Codex 安装完成: $(codex --version 2>/dev/null || echo "版本检测失败")"
  else
    error "Codex 安装完成，但 PATH 中未找到 'codex' 命令。"
    return 1
  fi
}

install_all() {
  install_claude_code || return 1
  install_codex || return 1

  log ""
  log "开始配置 Claude Code 提供商"
  configure_claude_provider || return 1

  log ""
  log "开始配置 Codex 提供商"
  configure_codex_provider || return 1

  success "全部组件已安装并完成配置。"
}

configure_claude_provider() {
  local base_url api_key block
  base_url="$(prompt_required "请输入 Claude 提供商 base URL")"
  api_key="$(prompt_required "请输入 Claude 提供商 API Key")"

  backup_file "${HOME}/.bashrc"
  block=$(cat <<EOF
export ANTHROPIC_BASE_URL="$(printf '%s' "$base_url")"
export ANTHROPIC_AUTH_TOKEN="$(printf '%s' "$api_key")"
EOF
)
  append_block "${HOME}/.bashrc" "$CLAUDE_BASHRC_START" "$CLAUDE_BASHRC_END" "$block"
  success "Claude 提供商配置已写入 ${HOME}/.bashrc"
  log "请执行: source ~/.bashrc"
}

configure_codex_provider() {
  local base_url api_key model auth_file config_file block api_key_json
  base_url="$(prompt_required "请输入 Codex 提供商 base URL")"
  api_key="$(prompt_required "请输入 Codex 提供商 API Key")"
  model="$(prompt_default "请输入 Codex 默认模型" "gpt-5.4")"

  auth_file="${HOME}/.codex/auth.json"
  config_file="${HOME}/.codex/config.toml"

  ensure_parent_dir "$auth_file"
  ensure_parent_dir "$config_file"
  backup_file "$auth_file"
  backup_file "$config_file"

  api_key_json="$(json_escape "$api_key")"
  cat > "$auth_file" <<EOF
{
  "OPENAI_API_KEY": "$api_key_json"
}
EOF

  block=$(cat <<EOF
model_provider = "ai_cli_manager_custom"
model = "$(printf '%s' "$model")"
model_reasoning_effort = "medium"

[model_providers.ai_cli_manager_custom]
name = "ai_cli_manager_custom"
wire_api = "responses"
requires_openai_auth = true
base_url = "$(printf '%s' "$base_url")"
EOF
)
  append_block "$config_file" "$CODEX_CONFIG_START" "$CODEX_CONFIG_END" "$block"

  backup_file "${HOME}/.bashrc"
  block=$(cat <<EOF
export OPENAI_BASE_URL="$(printf '%s' "$base_url")"
export OPENAI_API_KEY="$(printf '%s' "$api_key")"
EOF
)
  append_block "${HOME}/.bashrc" "$CODEX_BASHRC_START" "$CODEX_BASHRC_END" "$block"

  success "Codex 提供商配置已写入 ${HOME}/.codex/auth.json 和 ${HOME}/.codex/config.toml"
  log "请执行: source ~/.bashrc"
}

uninstall_claude_code() {
  if command -v npm >/dev/null 2>&1; then
    log "正在卸载 Claude Code ..."
    npm uninstall -g @anthropic-ai/claude-code || warn "npm uninstall 返回了非 0 状态码。"
  else
    warn "未找到 npm，跳过包卸载。"
  fi

  backup_file "${HOME}/.bashrc"
  strip_block "${HOME}/.bashrc" "$CLAUDE_BASHRC_START" "$CLAUDE_BASHRC_END"
  success "Claude Code 卸载已执行，并从 ${HOME}/.bashrc 中移除了受控 Claude 配置"
}

uninstall_codex() {
  if command -v npm >/dev/null 2>&1; then
    log "正在卸载 Codex ..."
    npm uninstall -g @openai/codex || warn "npm uninstall 返回了非 0 状态码。"
  else
    warn "未找到 npm，跳过包卸载。"
  fi

  backup_file "${HOME}/.bashrc"
  strip_block "${HOME}/.bashrc" "$CODEX_BASHRC_START" "$CODEX_BASHRC_END"

  backup_file "${HOME}/.codex/config.toml"
  strip_block "${HOME}/.codex/config.toml" "$CODEX_CONFIG_START" "$CODEX_CONFIG_END"

  if [ -f "${HOME}/.codex/auth.json" ]; then
    backup_file "${HOME}/.codex/auth.json"
    rm -f "${HOME}/.codex/auth.json"
  fi

  success "Codex 卸载已执行，并移除了受控 Codex 配置"
}

print_status() {
  log ""
  log "当前状态"
  log "--------"

  if command -v claude >/dev/null 2>&1; then
    log "Claude Code: 已安装 ($(claude --version 2>/dev/null || echo "版本未知"))"
  else
    log "Claude Code: 未安装"
  fi

  if command -v codex >/dev/null 2>&1; then
    log "Codex: 已安装 ($(codex --version 2>/dev/null || echo "版本未知"))"
  else
    log "Codex: 未安装"
  fi

  if grep -q "$CLAUDE_BASHRC_START" "${HOME}/.bashrc" 2>/dev/null; then
    log "Claude 提供商: 已存在受控 ~/.bashrc 配置块"
  else
    log "Claude 提供商: 未发现受控 ~/.bashrc 配置块"
  fi

  if grep -q "$CODEX_CONFIG_START" "${HOME}/.codex/config.toml" 2>/dev/null; then
    log "Codex 提供商: 已存在受控 ~/.codex/config.toml 配置块"
  else
    log "Codex 提供商: 未发现受控 ~/.codex/config.toml 配置块"
  fi
}

show_menu() {
  clear
  log "AI CLI 管理脚本"
  log "================"
  print_status
  log ""
  log "1. 安装 Claude Code"
  log "2. 安装 Codex"
  log "3. 更换 Claude Code 提供商"
  log "4. 更换 Codex 提供商"
  log "5. 卸载 Claude Code"
  log "6. 卸载 Codex"
  log "7. 一键安装全部"
  log "0. 退出"
  log ""
}

main_loop() {
  local choice=""
  while true; do
    show_menu
    printf '请选择功能编号: '
    read -r choice
    case "$choice" in
      1)
        install_claude_code
        pause
        ;;
      2)
        install_codex
        pause
        ;;
      3)
        configure_claude_provider
        pause
        ;;
      4)
        configure_codex_provider
        pause
        ;;
      5)
        uninstall_claude_code
        pause
        ;;
      6)
        uninstall_codex
        pause
        ;;
      7)
        install_all
        pause
        ;;
      0)
        exit 0
        ;;
      *)
        warn "无效选项: $choice"
        pause
        ;;
    esac
  done
}

main_loop
