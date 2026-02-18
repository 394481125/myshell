#!/bin/bash

# --- 检查依赖 ---
if ! command -v bc &> /dev/null; then
    # 如果没装 bc，尝试安装 (仅限 Debian/Ubuntu)
    if command -v apt &> /dev/null; then
        sudo apt-get install -y bc > /dev/null 2>&1
    fi
fi

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' 
BOLD='\033[1m'

# --- 进度条函数 ---
draw_bar() {
    local perc=$1
    local size=$2
    # 确保 perc 是数字且不为空
    if [[ -z "$perc" ]]; then perc=0; fi
    local inc=$(( perc * size / 100 ))
    local out="["
    for ((i=0; i<size; i++)); do
        if [ $i -lt $inc ]; then
            out="${out}#"
        else
            out="${out}-"
        fi
    done
    out="${out}] ${perc}%"
    echo -e "$out"
}

# --- 数据采集 (增强兼容性) ---

# 系统信息
HOSTNAME=$(hostname)
OS=$(grep -w "PRETTY_NAME" /etc/os-release | cut -d '"' -f 2)
[ -z "$OS" ] && OS=$(uname -s)
KERNEL=$(uname -r)
UPTIME=$(uptime -p | sed 's/up //')

# CPU信息 (改用更稳健的 top 抓取方式)
CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -n 1 | cut -d ':' -f 2 | xargs)
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' | cut -d. -f1)
[ -z "$CPU_USAGE" ] && CPU_USAGE=0

# 内存信息 (改用 NR==2 提取第二行，不匹配字符串)
MEM_INFO=$(free -m | awk 'NR==2 {print $2,$3}')
MEM_TOTAL=$(echo $MEM_INFO | awk '{print $1}')
MEM_USED=$(echo $MEM_INFO | awk '{print $2}')
if [[ -n "$MEM_TOTAL" && "$MEM_TOTAL" -gt 0 ]]; then
    MEM_PERC=$(( MEM_USED * 100 / MEM_TOTAL ))
else
    MEM_PERC=0
fi

# 磁盘信息 (根目录)
DISK_INFO=$(df -h / | awk 'NR==2 {print $2,$3,$5}')
DISK_TOTAL=$(echo $DISK_INFO | awk '{print $1}')
DISK_USED=$(echo $DISK_INFO | awk '{print $2}')
DISK_PERC=$(echo $DISK_INFO | awk '{print $3}' | sed 's/%//')
[ -z "$DISK_PERC" ] && DISK_PERC=0

# 网络信息
IP_LOCAL=$(hostname -I | awk '{print $1}')
IP_PUBLIC=$(curl -s --connect-timeout 2 https://api64.ipify.org || echo "N/A")
IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5}')
if [ -z "$IFACE" ]; then IFACE=$(ls /sys/class/net | grep -E "eth|enp|eno|wlan" | head -1); fi

# 流量统计
if [ -n "$IFACE" ]; then
    RX_BYTES=$(cat /proc/net/dev | grep "$IFACE" | awk '{print $2}')
    TX_BYTES=$(cat /proc/net/dev | grep "$IFACE" | awk '{print $10}')
    RX_GB=$(awk "BEGIN {printf \"%.2f\", $RX_BYTES/1024/1024/1024}")
    TX_GB=$(awk "BEGIN {printf \"%.2f\", $TX_BYTES/1024/1024/1024}")
else
    RX_GB="0.00"; TX_GB="0.00"
fi

# --- 打印看板 ---
clear
echo -e "${CYAN}${BOLD}========================================================================${NC}"
echo -e "${WHITE}${BOLD}                     🖥️  系统运行状态监控 (MyShell)                     ${NC}"
echo -e "${CYAN}${BOLD}========================================================================${NC}"

echo -e "${BLUE}[基础信息]${NC}"
printf "  %-12s : %s\n" "主机名" "$HOSTNAME"
printf "  %-12s : %s\n" "发行版本" "$OS"
printf "  %-12s : %s\n" "内核版本" "$KERNEL"
printf "  %-12s : %s\n" "运行时间" "$UPTIME"
echo ""

echo -e "${YELLOW}[CPU 状态]${NC}"
printf "  %-12s : %s\n" "型号" "$CPU_MODEL"
printf "  %-12s : " "使用率"
[ "$CPU_USAGE" -gt 80 ] && color=$RED || color=$GREEN
echo -ne "${color}"
draw_bar $CPU_USAGE 30
echo -e "${NC}"

echo -e "${PURPLE}[内存状态]${NC}"
printf "  %-12s : %s / %s MB\n" "使用情况" "$MEM_USED" "$MEM_TOTAL"
printf "  %-12s : " "占用率"
[ "$MEM_PERC" -gt 80 ] && color=$RED || color=$GREEN
echo -ne "${color}"
draw_bar $MEM_PERC 30
echo -e "${NC}"

echo -e "${CYAN}[磁盘状态]${NC}"
printf "  %-12s : %s / %s\n" "使用情况" "$DISK_USED" "$DISK_TOTAL"
printf "  %-12s : " "占用率"
[ "$DISK_PERC" -gt 85 ] && color=$RED || color=$GREEN
echo -ne "${color}"
draw_bar $DISK_PERC 30
echo -e "${NC}"

echo -e "${GREEN}[网络信息]${NC}"
printf "  %-12s : %s\n" "内网 IP" "$IP_LOCAL"
printf "  %-12s : %s\n" "公网 IP" "$IP_PUBLIC"
printf "  %-12s : ⬇️  %s GB / ⬆️  %s GB\n" "总流量 ($IFACE)" "$RX_GB" "$TX_GB"

echo -e "${CYAN}${BOLD}========================================================================${NC}"
