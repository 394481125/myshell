#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 变量配置
FRP_VERSION="0.54.0"
WORK_DIR="$HOME/.openclaw/workspace/frp"
SERVICE_FILE="/etc/systemd/system/frps.service"
MARKDOWN_FILE="$WORK_DIR/frp_setup_info.md"

# 默认配置参数 (可以根据需要修改)
BIND_PORT=7000
DASHBOARD_PORT=7500
DASHBOARD_USER="admin"
DASHBOARD_PWD=$(openssl rand -hex 4) # 随机生成4位密码
TOKEN=$(openssl rand -hex 8)         # 随机生成8位Token

echo -e "${BLUE}==============================================${NC}"
echo -e "${GREEN}    OpenClaw FRP 服务器一键部署脚本 v${FRP_VERSION}${NC}"
echo -e "${BLUE}==============================================${NC}"

# 1. 环境准备
echo -e "\n${YELLOW}[1/6] 正在准备工作目录...${NC}"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR" || exit
echo -e "目录已就绪: $WORK_DIR"

# 2. 下载并解压
echo -e "\n${YELLOW}[2/6] 正在从 GitHub 下载 FRP v${FRP_VERSION}...${NC}"
FILENAME="frp_${FRP_VERSION}_linux_amd64.tar.gz"
URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${FILENAME}"

wget -O "$FILENAME" "$URL"
if [ $? -ne 0 ]; then
    echo -e "${RED}下载失败，请检查网络连接或手动下载。${NC}"
    exit 1
fi

echo -e "正在解压文件..."
tar -xzf "$FILENAME" --strip-components=1
chmod +x frps
echo -e "${GREEN}解压完成！${NC}"

# 3. 创建配置文件 (TOML 格式)
echo -e "\n${YELLOW}[3/6] 正在生成配置文件 (frps.toml)...${NC}"
cat > frps.toml <<EOF
bindPort = ${BIND_PORT}

# Dashboard 配置
webServer.addr = "0.0.0.0"
webServer.port = ${DASHBOARD_PORT}
webServer.user = "${DASHBOARD_USER}"
webServer.password = "${DASHBOARD_PWD}"

# 身份验证
auth.method = "token"
auth.token = "${TOKEN}"
EOF
echo -e "配置文件已生成。"

# 4. 创建 Systemd 服务
echo -e "\n${YELLOW}[4/6] 正在配置 Systemd 服务...${NC}"
sudo cat > frps.service <<EOF
[Unit]
Description=FRP Server Service
After=network.target

[Service]
Type=simple
User=$(whoami)
Restart=on-failure
RestartSec=5s
ExecStart=${WORK_DIR}/frps -c ${WORK_DIR}/frps.toml

[Install]
WantedBy=multi-user.target
EOF

sudo cp frps.service /etc/systemd/system/
sudo systemctl daemon-reload
echo -e "服务配置完成。"

# 5. 启动服务
echo -e "\n${YELLOW}[5/6] 正在启动 FRP 服务...${NC}"
sudo systemctl enable frps
sudo systemctl restart frps

# 检查状态
if systemctl is-active --quiet frps; then
    echo -e "${GREEN}FRP 服务已成功启动并运行！${NC}"
else
    echo -e "${RED}服务启动失败，请检查日志: sudo journalctl -u frps${NC}"
fi

# 6. 获取公网 IP 并生成文档
PUBLIC_IP=$(curl -s ifconfig.me || curl -s info.io/ip)
[ -z "$PUBLIC_IP" ] && PUBLIC_IP="您的服务器IP"

# 生成 Markdown 内容
cat > "$MARKDOWN_FILE" <<EOF
# 🚀 FRP 服务器部署报告

## 🔧 服务器配置详情
- **FRP 版本**: v${FRP_VERSION}
- **服务器公网 IP**: \`${PUBLIC_IP}\`
- **FRP 服务端口**: \`${BIND_PORT}\` (用于客户端连接)
- **Token (认证密钥)**: \`${TOKEN}\`
- **控制台 (Dashboard)**: \`http://${PUBLIC_IP}:${DASHBOARD_PORT}\`
- **控制台账号**: \`${DASHBOARD_USER}\`
- **控制台密码**: \`${DASHBOARD_PWD}\`

## 📋 文件路径
- **工作目录**: \`${WORK_DIR}\`
- **配置文件**: \`${WORK_DIR}/frps.toml\`
- **服务文件**: \`/etc/systemd/system/frps.service\`

## 💻 客户端使用方法 (frpc.toml)
在您的内网机器上创建 \`frpc.toml\` 并填入以下内容：

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

## 🛠️ 管理命令
- **查看状态**: \`sudo systemctl status frps\`
- **重启服务**: \`sudo systemctl restart frps\`
- **查看日志**: \`sudo journalctl -u frps -f\`
EOF

# 输出结果到屏幕
echo -e "\n${BLUE}==============================================${NC}"
echo -e "${GREEN}              部署完成！${NC}"
echo -e "${BLUE}==============================================${NC}"
cat "$MARKDOWN_FILE"
echo -e "\n${BLUE}==============================================${NC}"
echo -e "上述信息已保存至: ${YELLOW}$MARKDOWN_FILE${NC}"
