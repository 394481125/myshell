#!/bin/bash

# ==========================================
# changedetection.io 交互式远程管理脚本
# ==========================================

INSTALL_DIR="/opt/changedetection"
SCRIPT_PATH="/usr/local/bin/cdio"

# 颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误：请使用 root 用户或 sudo 执行此脚本！${NC}"
    exit 1
fi

# 自动将脚本注册到本地系统（首次远程运行时自动落地为本地命令 cdio）
install_self() {
    if [ ! -f "$SCRIPT_PATH" ] && [ -n "$0" ] && [ -f "$0" ]; then
        cp "$0" "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
    fi
}

# 检查 Docker Compose 命令兼容性
get_compose_cmd() {
    if docker compose version &> /dev/null; then
        echo "docker compose"
    elif command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        echo ""
    fi
}

# 1. 安装 / 部署
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

    echo -e "${CYAN}>>> [3/4] 生成 docker-compose.yml 配置文件...${NC}"
    cat << 'COMPOSE_EOF' > docker-compose.yml
version: '3.8'

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

    echo -e "${CYAN}>>> [4/4] 拉取镜像并启动容器...${NC}"
    COMPOSE_CMD=$(get_compose_cmd)
    $COMPOSE_CMD up -d

    SERVER_IP=$(curl -s --connect-timeout 3 https://api.ipify.org || hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}======================================================${NC}"
    echo -e "${GREEN}🎉 部署完成！${NC}"
    echo -e "${GREEN}🌐 访问地址: http://${SERVER_IP}:5000${NC}"
    echo -e "${GREEN}📁 数据目录: ${INSTALL_DIR}/changedetection-data${NC}"
    echo -e "${GREEN}💡 提示: 脚本已自动在本地生成快捷命令，后续输入 cdio 即可直接管理！${NC}"
    echo -e "${GREEN}======================================================${NC}"
}

# 2. 启动服务
start_app() {
    if [ ! -f "${INSTALL_DIR}/docker-compose.yml" ]; then
        echo -e "${RED}错误：尚未安装，请先选择「1. 安装 / 首次部署」。${NC}"
        return
    fi
    cd "${INSTALL_DIR}"
    COMPOSE_CMD=$(get_compose_cmd)
    $COMPOSE_CMD up -d
    echo -e "${GREEN}服务已成功启动！${NC}"
}

# 3. 停止服务
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

# 4. 重启服务
restart_app() {
    if [ ! -f "${INSTALL_DIR}/docker-compose.yml" ]; then
        echo -e "${RED}错误：未找到配置文件。${NC}"
        return
    fi
    cd "${INSTALL_DIR}"
    COMPOSE_CMD=$(get_compose_cmd)
    $COMPOSE_CMD restart
    echo -e "${GREEN}服务已重启完成！${NC}"
}

# 5. 查看实时日志
view_logs() {
    if [ ! -f "${INSTALL_DIR}/docker-compose.yml" ]; then
        echo -e "${RED}错误：未找到配置文件。${NC}"
        return
    fi
    cd "${INSTALL_DIR}"
    COMPOSE_CMD=$(get_compose_cmd)
    echo -e "${CYAN}提示：按 Ctrl + C 可退出日志查看${NC}"
    $COMPOSE_CMD logs -f
}

# 6. 一键更新升级
update_app() {
    if [ ! -f "${INSTALL_DIR}/docker-compose.yml" ]; then
        echo -e "${RED}错误：尚未安装，请先选择「1. 安装 / 首次部署」。${NC}"
        return
    fi
    cd "${INSTALL_DIR}"
    COMPOSE_CMD=$(get_compose_cmd)
    echo -e "${CYAN}正在检查并拉取最新镜像...${NC}"
    $COMPOSE_CMD pull
    echo -e "${CYAN}正在重新构建容器...${NC}"
    $COMPOSE_CMD up -d
    echo -e "${GREEN}更新完毕，目前已是最新版本！${NC}"
}

# 7. 卸载与清理
uninstall_app() {
    if [ ! -d "${INSTALL_DIR}" ]; then
        echo -e "${YELLOW}未发现安装目录。${NC}"
        return
    fi
    read -p "确定要停止并卸载 changedetection.io 吗？(y/N): " confirm < /dev/tty
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        cd "${INSTALL_DIR}"
        COMPOSE_CMD=$(get_compose_cmd)
        if [ -n "$COMPOSE_CMD" ] && [ -f "docker-compose.yml" ]; then
            $COMPOSE_CMD down
        fi
        
        read -p "是否同时删除所有持久化监控数据？(y/N): " del_data < /dev/tty
        if [[ "$del_data" =~ ^[yY]$ ]]; then
            rm -rf "${INSTALL_DIR}"
            echo -e "${GREEN}容器与数据已全部清除！${NC}"
        else
            rm -f "${INSTALL_DIR}/docker-compose.yml"
            echo -e "${GREEN}容器已销毁，数据保留在: ${INSTALL_DIR}/changedetection-data${NC}"
        fi
        rm -f "$SCRIPT_PATH"
    else
        echo "已取消卸载。"
    fi
}

# 执行本地快捷命令备份
install_self

# 主菜单交互循环
while true; do
    echo ""
    echo -e "${CYAN}==============================================${NC}"
    echo -e "${GREEN}   changedetection.io 交互式管理面板${NC}"
    echo -e "${CYAN}==============================================${NC}"
    echo " 1. 安装 / 首次部署 (含无头浏览器)"
    echo " 2. 启动服务"
    echo " 3. 停止服务"
    echo " 4. 重启服务"
    echo " 5. 查看实时日志"
    echo " 6. 一键更新到最新版本"
    echo " 7. 卸载与清理"
    echo " 0. 退出面板"
    echo -e "${CYAN}----------------------------------------------${NC}"
    read -p "请输入选项 [0-7]: " choice < /dev/tty

    case $choice in
        1) install_app ;;
        2) start_app ;;
        3) stop_app ;;
        4) restart_app ;;
        5) view_logs ;;
        6) update_app ;;
        7) uninstall_app ;;
        0) echo "已退出。"; exit 0 ;;
        *) echo -e "${RED}输入无效，请输入 0 到 7 之间的数字。${NC}" ;;
    esac

    echo ""
    read -n 1 -s -r -p "按任意键返回菜单..." < /dev/tty
    echo ""
done
