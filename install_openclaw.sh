#!/bin/bash
#
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║   🦞 OpenClaw 全自动部署脚本 v1.3.0                                        ║
# ║   说明：支持自主选择平台 (微信/QQ/飞书/Telegram等)                          ║
# ║                                                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
#

set -e

# ================================ 颜色与基础检测 ================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# ================================ 1. 环境准备 ================================

install_env() {
    log_step "正在安装基础环境 (Node.js 22)..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y curl git jq
            curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
            sudo apt-get install -y nodejs
        elif command -v yum &> /dev/null; then
            sudo yum install -y curl git jq
            curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
            sudo yum install -y nodejs
        fi
    fi
    
    log_info "更新 NPM 并优化全局安装配置..."
    sudo npm install -g npm@latest --no-fund
}

# ================================ 2. 安装 OpenClaw ================================

install_pkg() {
    log_step "正在安装 OpenClaw 本体..."
    # 使用 --unsafe-perm 确保 root 用户下安装成功
    sudo npm install -g openclaw@latest --no-fund --unsafe-perm=true
}

# ================================ 3. 交互式配置流程 ================================

setup_openclaw() {
    echo -e "\n${CYAN}-------------------------------------------------------${NC}"
    log_step "即将开始新手引导"
    echo -e "${YELLOW}提示：在接下来的步骤中，请根据提示选择你需要的平台（如微信、飞书等）${NC}"
    echo -e "${CYAN}-------------------------------------------------------${NC}\n"
    
    # 执行新手引导，这里会询问：
    # 1. 语言偏好
    # 2. 要启用的插件 (在这里你可以勾选 飞书/微信/QQ 等)
    # 3. 模型配置 (OpenAI/Claude/Gemini 等)
    openclaw onboard --install-daemon

    echo -e "\n${CYAN}-------------------------------------------------------${NC}"
    log_step "即将开始平台登录 (Channels Login)"
    echo -e "${YELLOW}提示：请在列表中选择你刚才启用的平台进行扫码或 Token 登录${NC}"
    echo -e "${CYAN}-------------------------------------------------------${NC}\n"
    
    # 启动登录流程
    openclaw channels login

    # 询问用户网关端口
    echo -en "\n${YELLOW}请输入网关运行端口 [默认 18789]: ${NC}"
    read PORT
    PORT=${PORT:-18789}

    log_step "正在启动网关服务 (端口: $PORT)..."
    log_info "启动后，你可以通过该端口与 AI 进行交互。"
    
    # 最终启动网关
    openclaw gateway --port "$PORT"
}

# ================================ 执行 ================================

main() {
    clear
    echo -e "${CYAN}"
    echo "#######################################################"
    echo "#                                                     #"
    echo "#           🦞 OpenClaw 多平台一键部署                #"
    echo "#        (支持微信 / QQ / 飞书 / Telegram 等)         #"
    echo "#                                                     #"
    echo "#######################################################"
    echo -e "${NC}"

    install_env
    install_pkg
    setup_openclaw
}

main "$@"
