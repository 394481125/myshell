#!/bin/bash

# ==========================================
# changedetection.io 交互式远程全功能管理脚本
# ==========================================

INSTALL_DIR="/opt/changedetection"
SCRIPT_PATH="/usr/local/bin/cdio"

# 终端颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误：请使用 root 用户或 sudo 执行此脚本！${NC}"
    exit 1
fi

# 自动生成本地快捷指令 cdio
install_self() {
    if [ ! -f "$SCRIPT_PATH" ] && [ -n "$0" ] && [ -f "$0" ]; then
        cp "$0" "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
    fi
}

# 兼容 Docker Compose 命令
get_compose_cmd() {
    if docker compose version &> /dev/null; then
        echo "docker compose"
    elif command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        echo ""
    fi
}

# 一键配置国内 Docker 镜像加速
set_docker_mirror() {
    echo -e "${CYAN}>>> 正在为 Docker 配置国内加速源...${NC}"
    mkdir -p /etc/docker
    cat << 'EOF' > /etc/docker/daemon.json
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.1panel.live",
    "https://hub.rat.dev",
    "https://docker.chenby.cn"
  ]
}
EOF
    systemctl daemon-reload
    systemctl restart docker
    echo -e "${GREEN}✔ 镜像加速源配置完成并已重启 Docker！${NC}"
}

# 1. 安装 / 部署服务
install_app() {
    echo -e "${CYAN}>>> [1/4] 检查 Docker 环境...${NC}"
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}未检测到 Docker，正在自动安装...${NC}"
        curl -fsSL https://get.docker.com | sh
        systemctl enable --now docker || true
    else
        echo -e "${GREEN}Docker 环境正常。${NC}"
    fi

    echo -e "${CYAN}>>> [2/4] 初始化配置目录: ${INSTALL_DIR}${NC}"
    mkdir -p "${INSTALL_DIR}"
    cd "${INSTALL_DIR}"

    echo -e "${CYAN}>>> [3/4] 写入 docker-compose.yml 配置文件...${NC}"
    cat << 'COMPOSE_EOF' > docker-compose.yml
services:
  changedetection:
    image: ghcr.io/dgtlmoon/changedetection.io
    container_name: changedetection
    hostname: changedetection
    volumes:
      - ./changedetection-data:/datastore
    environment:
      - PORT=5000
      - PUID=1000
      - PGID=1000
      - PLAYWRIGHT_DRIVER_URL=ws://sockpuppetbrowser:3000
    ports:
      - "5000:5000"
    restart: unless-stopped
    depends_on:
      sockpuppetbrowser:
        condition: service_started

  sockpuppetbrowser:
    image: dgtlmoon/sockpuppetbrowser:latest
    container_name: sockpuppetbrowser
    hostname: sockpuppetbrowser
    restart: unless-stopped
    environment:
      - SCREEN_WIDTH=1920
      - SCREEN_HEIGHT=1024
      - SCREEN_DEPTH=16
      - MAX_CONCURRENT_CHROME_PROCESSES=10
COMPOSE_EOF

    echo -e "${CYAN}>>> [4/4] 正在拉取镜像并启动容器（请耐心等待）...${NC}"
    COMPOSE_CMD=$(get_compose_cmd)
    
    # 启动容器并捕获执行结果
    if $COMPOSE_CMD up -d; then
        # 再次检查容器实际运行状态
        sleep 2
        RUNNING_COUNT=$(docker ps --filter "name=changedetection" --filter "name=sockpuppetbrowser" -q | wc -l)
        if [ "$RUNNING_COUNT" -ge 2 ]; then
            SERVER_IP=$(curl -s --connect-timeout 3 https://api.ipify.org || hostname -I | awk '{print $1}')
            echo ""
            echo -e "${GREEN}======================================================${NC}"
            echo -e "${GREEN}🎉 changedetection.io 部署并启动成功！${NC}"
            echo -e "${GREEN}🌐 访问地址: http://${SERVER_IP}:5000${NC}"
            echo -e "${GREEN}📁 数据目录: ${INSTALL_DIR}/changedetection-data${NC}"
            echo -e "${GREEN}💡 提示: 之后输入 cdio 即可快速调出此管理面板。${NC}"
            echo -e "${GREEN}======================================================${NC}"
            return
        fi
    fi

    # 如果启动失败，给出清晰排查建议
    echo ""
    echo -e "${RED}======================================================${NC}"
    echo -e "${RED}❌ 启动失败！通常是由于国内网络拉取 Docker 镜像超时。${NC}"
    echo -e "${YELLOW}建议解决方案：${NC}"
    echo -e " 1. 返回菜单选择「2. 配置 Docker 国内镜像加速源」后重试；"
    echo -e " 2. 若服务器有代理，请配置 Docker HTTP 代理后重试。"
    echo -e "${RED}======================================================${NC}"
}

# 启动服务
start_app() {
    if [ ! -f "${INSTALL_DIR}/docker-compose.yml" ]; then
        echo -e "${RED}错误：尚未安装，请先选择「1. 安装 / 首次部署」。${NC}"
        return
    fi
    cd "${INSTALL_DIR}"
    COMPOSE_CMD=$(get_compose_cmd)
    $COMPOSE_CMD up -d
    echo -e "${GREEN}启动指令已发送，可选择「查看运行状态」确认是否正常。${NC}"
}

# 停止服务
stop_app() {
    if [ ! -f "${INSTALL_DIR}/docker-compose.yml" ]; then
        echo -e "${RED}错误：未找到配置文件。${NC}"
        return
    fi
    cd "${INSTALL_DIR}"
    COMPOSE_CMD=$(get_compose_cmd)
    $COMPOSE_CMD down
    echo -e "${YELLOW}服务已停止。${NC}"
}

# 重启服务
restart_app() {
    if [ ! -f "${INSTALL_DIR}/docker-compose.yml" ]; then
        echo -e "${RED}错误：未找到配置文件。${NC}"
        return
    fi
    cd "${INSTALL_DIR}"
    COMPOSE_CMD=$(get_compose_cmd)
    $COMPOSE_CMD restart
    echo -e "${GREEN}服务已重启！${NC}"
}

# 查看实时日志
view_logs() {
    if [ ! -f "${INSTALL_DIR}/docker-compose.yml" ]; then
        echo -e "${RED}错误：未找到配置文件。${NC}"
        return
    fi
    cd "${INSTALL_DIR}"
    COMPOSE_CMD=$(get_compose_cmd)
    echo -e "${CYAN}提示：按 Ctrl + C 可退出日志查看模式${NC}"
    $COMPOSE_CMD logs -f
}

# 查看容器状态
status_app() {
    echo -e "${CYAN}>>> 当前 changedetection 容器状态：${NC}"
    docker ps -a --filter "name=changedetection" --filter "name=sockpuppetbrowser" \
      --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# 一键更新
update_app() {
    if [ ! -f "${INSTALL_DIR}/docker-compose.yml" ]; then
        echo -e "${RED}错误：尚未安装，请先选择「1. 安装 / 首次部署」。${NC}"
        return
    fi
    cd "${INSTALL_DIR}"
    COMPOSE_CMD=$(get_compose_cmd)
    echo -e "${CYAN}正在拉取最新镜像...${NC}"
    if $COMPOSE_CMD pull; then
        $COMPOSE_CMD up -d
        echo -e "${GREEN}更新成功！已升级至最新镜像并运行。${NC}"
    else
        echo -e "${RED}更新失败，镜像拉取超时，请检查网络或加速源。${NC}"
    fi
}

# 卸载清理（仅删除本机 changedetection 容器与指定目录）
uninstall_app() {
    if [ ! -d "${INSTALL_DIR}" ]; then
        echo -e "${YELLOW}未发现安装目录。${NC}"
        return
    fi
    read -p "确定要卸载 changedetection 吗？(y/N): " confirm < /dev/tty
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        cd "${INSTALL_DIR}"
        COMPOSE_CMD=$(get_compose_cmd)
        if [ -n "$COMPOSE_CMD" ] && [ -f "docker-compose.yml" ]; then
            $COMPOSE_CMD down
        fi
        
        read -p "是否彻底删除监控历史数据目录 (changedetection-data)？(y/N): " del_data < /dev/tty
        if [[ "$del_data" =~ ^[yY]$ ]]; then
            rm -rf "${INSTALL_DIR}"
            echo -e "${GREEN}容器与数据已彻底清理！${NC}"
        else
            rm -f "${INSTALL_DIR}/docker-compose.yml"
            echo -e "${GREEN}容器已删除，监控历史数据依然保留在: ${INSTALL_DIR}/changedetection-data${NC}"
        fi
        rm -f "$SCRIPT_PATH"
    else
        echo "已取消卸载。"
    fi
}

# 自动注册系统快捷命令
install_self

# 主菜单交互循环
while true; do
    echo ""
    echo -e "${CYAN}==============================================${NC}"
    echo -e "${GREEN}   changedetection.io 容器管理面板${NC}"
    echo -e "${CYAN}==============================================${NC}"
    echo " 1. 安装 / 首次部署 (含无头浏览器)"
    echo " 2. 配置 Docker 国内镜像加速源 (解决拉取超时)"
    echo " 3. 启动服务"
    echo " 4. 停止服务"
    echo " 5. 重启服务"
    echo " 6. 查看实时日志"
    echo " 7. 查看容器运行状态"
    echo " 8. 一键更新到最新版本"
    echo " 9. 卸载与清理"
    echo " 0. 退出面板"
    echo -e "${CYAN}----------------------------------------------${NC}"
    read -p "请输入选项 [0-9]: " choice < /dev/tty

    case $choice in
        1) install_app ;;
        2) set_docker_mirror ;;
        3) start_app ;;
        4) stop_app ;;
        5) restart_app ;;
        6) view_logs ;;
        7) status_app ;;
        8) update_app ;;
        9) uninstall_app ;;
        0) echo "已退出。"; exit 0 ;;
        *) echo -e "${RED}输入无效，请输入 0 到 9 之间的数字。${NC}" ;;
    esac

    echo ""
    read -n 1 -s -r -p "按任意键返回主菜单..." < /dev/tty
    echo ""
done
