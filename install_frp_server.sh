#!/bin/bash

# ====================================================
# FRP 服务器一键部署脚本 (优化版)
# 适用版本: v0.52.0 - v0.54.0+ (TOML 格式)
# ====================================================

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 配置变量
FRP_VERSION="0.54.0"
WORK_DIR="$HOME/.myshell/workspace/frp"
SERVICE_NAME="frps"
BIND_PORT=7000
DASHBOARD_PORT=7500
DASHBOARD_USER="admin"
DASHBOARD_PWD=$(openssl rand -hex 4) # 随机生成4位密码
TOKEN=$(openssl rand -hex 8)         # 随机生成8位Token
MARKDOWN_FILE="$WORK_DIR/frp_setup_info.md"

echo -e "${BLUE}==============================================${NC}"
echo -e "${GREEN}    正在开始部署 FRP 服务器 v${FRP_VERSION}${NC}"
echo -e "${BLUE}==============================================${NC}"

# 1. 环境清理与准备
echo -e "\n${YELLOW}[1/7] 正在清理环境与准备目录...${NC}"
# 强制停止旧进程，防止端口占用
sudo systemctl stop $SERVICE_NAME >/dev/null 2>&1
sudo pkill -f frps >/dev/null 2>&1

mkdir -p "$WORK_DIR"
cd "$WORK_DIR" || exit
echo -e "工作目录: $WORK_DIR"

# 2. 下载与安装
echo -e "\n${YELLOW}[2/7] 正在下载 FRP 程序...${NC}"
FILENAME="frp_${FRP_VERSION}_linux_amd64.tar.gz"
URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${FILENAME}"

if [ ! -f "frps" ]; then
    wget -O "$FILENAME" "$URL"
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败，请检查网络连接！${NC}"
        exit 1
    fi
    tar -xzf "$FILENAME" --strip-components=1
    chmod +x frps
    echo -e "程序解压成功。"
else
    echo -e "frps 程序已存在，跳过下载。"
fi

# 3. 编写修复后的配置文件 (TOML 格式)
echo -e "\n${YELLOW}[3/7] 正在生成修复后的配置文件 (frps.toml)...${NC}"
# 注意：v0.54.0 使用 webServer 替代旧版本的 dashboard 配置
cat > frps.toml <<EOF
bindPort = ${BIND_PORT}

# 控制台配置 (Dashboard)
webServer.addr = "0.0.0.0"
webServer.port = ${DASHBOARD_PORT}
webServer.user = "${DASHBOARD_USER}"
webServer.password = "${DASHBOARD_PWD}"

# 身份验证机制
auth.method = "token"
auth.token = "${TOKEN}"

# 日志配置 (输出到标准输出，由 Systemd 接管)
log.to = "console"
log.level = "info"
EOF
echo -e "配置文件已修正为最新 TOML 格式。"

# 4. 配置 Systemd 服务
echo -e "\n${YELLOW}[4/7] 正在创建 Systemd 服务文件...${NC}"
sudo cat > /etc/systemd/system/frps.service <<EOF
[Unit]
Description=FRP Server Service
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=${WORK_DIR}
ExecStart=${WORK_DIR}/frps -c ${WORK_DIR}/frps.toml
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
echo -e "服务安装成功。"

# 5. 端口检查与启动
echo -e "\n${YELLOW}[5/7] 正在检查端口并启动服务...${NC}"
# 检查 7500 是否被其他程序占用
OCCUPIED=$(sudo netstat -tlnp | grep ":${DASHBOARD_PORT} ")
if [ ! -z "$OCCUPIED" ]; then
    echo -e "${RED}警告: 端口 ${DASHBOARD_PORT} 已被占用，正在尝试强制释放...${NC}"
    sudo fuser -k ${DASHBOARD_PORT}/tcp
fi

sudo systemctl enable frps
sudo systemctl start frps

# 6. 验证运行状态
echo -e "\n${YELLOW}[6/7] 正在验证服务状态...${NC}"
sleep 2
if systemctl is-active --quiet frps; then
    echo -e "${GREEN}FRP 服务启动成功！${NC}"
    # 本地 curl 验证 Dashboard
    RESPONSE=$(curl -I -s http://127.0.0.1:${DASHBOARD_PORT} | head -n 1)
    echo -e "Dashboard 响应: ${BLUE}$RESPONSE${NC} (401 为正常认证提示)"
else
    echo -e "${RED}启动失败，请运行 'sudo journalctl -u frps -f' 查看日志。${NC}"
fi

# 7. 生成文档并输出
PUBLIC_IP=$(curl -s ifconfig.me || echo "您的服务器IP")

cat > "$MARKDOWN_FILE" <<EOF
# 🚀 FRP 服务器部署报告

## 🛠️ 基本信息
- **部署状态**: 运行中 ✅
- **FRP 版本**: v${FRP_VERSION}
- **服务器 IP**: \`${PUBLIC_IP}\`

## 📡 核心配置 (已修正为 v0.54.0 语法)
- **FRP 绑定端口**: \`${BIND_PORT}\`
- **认证 Token**: \`${TOKEN}\`
- **Dashboard 地址**: \`http://${PUBLIC_IP}:${DASHBOARD_PORT}\`
- **Dashboard 账号**: \`${DASHBOARD_USER}\`
- **Dashboard 密码**: \`${DASHBOARD_PWD}\`

## 💻 客户端配置模板 (frpc.toml)
在内网机器上创建 \`frpc.toml\` 并填入：
\`\`\`toml
serverAddr = "${PUBLIC_IP}"
serverPort = ${BIND_PORT}
auth.token = "${TOKEN}"

[[proxies]]
name = "ssh-proxy"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = 6000
\`\`\`

## 📂 文件管理
- **工作目录**: \`${WORK_DIR}\`
- **配置文件**: \`${WORK_DIR}/frps.toml\`
- **查看状态**: \`sudo systemctl status frps\`
- **查看日志**: \`sudo journalctl -u frps -f\`
EOF

echo -e "\n${BLUE}==============================================${NC}"
echo -e "${GREEN}              🎉 部署成功！${NC}"
echo -e "${BLUE}==============================================${NC}"
echo -e "${YELLOW}Dashboard 密码: ${DASHBOARD_PWD}${NC}"
echo -e "${YELLOW}认证 Token: ${TOKEN}${NC}"
echo -e "${BLUE}==============================================${NC}"
echo -e "配置说明文档已保存至: ${MARKDOWN_FILE}"
