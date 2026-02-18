#!/bin/bash

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# --- 进度条函数 ---
# 参数: $1=百分比, $2=长度
draw_bar() {
    local perc=$1
    local size=$2
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

# --- 数据采集 ---

# 系统信息
HOSTNAME=$(hostname)
OS=$(grep -w "PRETTY_NAME" /etc/os-release | cut -d '"' -f 2)
KERNEL=$(uname -r)
UPTIME=$(uptime -p | sed 's/up //')

# CPU信息
CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -n 1 | cut -d ':' -f 2 | xargs)
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

# 内存信息 (MB)
MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
MEM_USED=$(free -m | awk '/Mem:/ {print $3}')
MEM_PERC=$(( MEM_USED * 100 / MEM_TOTAL ))

# 磁盘信息 (根目录)
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_PERC=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')

# 网络信息
IP_LOCAL=$(hostname -I | awk '{print $1}')
IP_PUBLIC=$(curl -s https://api64.ipify.org || echo "Timeout")
# 流量统计 (以 eth0 为例，如果找不到则取第一个非环回接口)
IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5}')
if [ -z "$IFACE" ]; then IFACE="eth0"; fi
RX_BYTES=$(cat /proc/net/dev | grep "$IFACE" | awk '{print $2}')
TX_BYTES=$(cat /proc/net/dev | grep "$IFACE" | awk '{print $10}')
# 转换为 GB
RX_GB=$(echo "scale=2; $RX_BYTES/1024/1024/1024" | bc)
TX_GB=$(echo "scale=2; $TX_BYTES/1024/1024/1024" | bc)

# --- 打印看板 ---

clear
echo -e "${CYAN}${BOLD}========================================================================${NC}"
echo -e "${WHITE}${BOLD}                     🖥️  系统运行状态监控 (MyShell)                     ${NC}"
echo -e "${CYAN}${BOLD}========================================================================${NC}"

# 基础信息
echo -e "${BLUE}[基础信息]${NC}"
printf "  %-12s : %s\n" "主机名" "$HOSTNAME"
printf "  %-12s : %s\n" "发行版本" "$OS"
printf "  %-12s : %s\n" "内核版本" "$KERNEL"
printf "  %-12s : %s\n" "运行时间" "$UPTIME"
echo ""

# CPU 状态
echo -e "${YELLOW}[CPU 状态]${NC}"
printf "  %-12s : %s\n" "型号" "$CPU_MODEL"
printf "  %-12s : " "使用率"
if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then color=$RED; else color=$GREEN; fi
echo -ne "${color}"
draw_bar ${CPU_USAGE%.*} 30
echo -e "${NC}"

# 内存状态
echo -e "${PURPLE}[内存状态]${NC}"
printf "  %-12s : %s / %s MB\n" "使用情况" "$MEM_USED" "$MEM_TOTAL"
printf "  %-12s : " "占用率"
if [ $MEM_PERC -gt 80 ]; then color=$RED; else color=$GREEN; fi
echo -ne "${color}"
draw_bar $MEM_PERC 30
echo -e "${NC}"

# 磁盘状态
echo -e "${CYAN}[磁盘状态 (根目录)]${NC}"
printf "  %-12s : %s / %s\n" "使用情况" "$DISK_USED" "$DISK_TOTAL"
printf "  %-12s : " "占用率"
if [ $DISK_PERC -gt 85 ]; then color=$RED; else color=$GREEN; fi
echo -ne "${color}"
draw_bar $DISK_PERC 30
echo -e "${NC}"

# 网络状态
echo -e "${GREEN}[网络信息]${NC}"
printf "  %-12s : %s\n" "内网 IP" "$IP_LOCAL"
printf "  %-12s : %s\n" "公网 IP" "$IP_PUBLIC"
printf "  %-12s : ⬇️  %s GB / ⬆️  %s GB\n" "总流量 ($IFACE)" "$RX_GB" "$TX_GB"

echo -e "${CYAN}${BOLD}========================================================================${NC}"
