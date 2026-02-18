#!/bin/bash

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
    # 确保 perc 是纯数字且不为空，如果为空则设为 0
    perc=$(echo "$perc" | tr -d '[:space:]')
    : "${perc:=0}"
    
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

# --- 数据采集 (使用 /proc 直读，不依赖命令输出格式) ---

# 1. 内存信息 - 直接读取 /proc/meminfo (单位: KB)
# 这种方法不收语言环境(中文/英文)影响
mem_total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
mem_avail_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
# 如果没有 MemAvailable (旧版本内核)，则使用 MemFree + Buffers + Cached
if [ -z "$mem_avail_kb" ]; then
    mem_free=$(grep MemFree /proc/meminfo | awk '{print $2}')
    mem_buf=$(grep Buffers /proc/meminfo | awk '{print $2}')
    mem_cach=$(grep ^Cached /proc/meminfo | awk '{print $2}')
    mem_avail_kb=$((mem_free + mem_buf + mem_cach))
fi

MEM_TOTAL=$(( mem_total_kb / 1024 ))
MEM_AVAIL=$(( mem_avail_kb / 1024 ))
MEM_USED=$(( MEM_TOTAL - MEM_AVAIL ))
# 防止除以零
if [ "$MEM_TOTAL" -gt 0 ]; then
    MEM_PERC=$(( MEM_USED * 100 / MEM_TOTAL ))
else
    MEM_PERC=0
fi

# 2. CPU 使用率 - 使用 /proc/loadavg (取 1 分钟平均负载)
# 或者通过读取 /proc/stat 计算（更准确但代码长），这里取 top 简易兼容版
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' | cut -d. -f1)
: "${CPU_USAGE:=0}"

# 3. 磁盘信息
DISK_INFO=$(df -h / | awk 'NR==2 {print $2,$3,$5}')
DISK_TOTAL=$(echo $DISK_INFO | awk '{print $1}')
DISK_USED=$(echo $DISK_INFO | awk '{print $2}')
DISK_PERC=$(echo $DISK_INFO | awk '{print $3}' | tr -d '%')
: "${DISK_PERC:=0}"

# 4. 基础信息
HOSTNAME=$(hostname)
OS=$(grep -w "PRETTY_NAME" /etc/os-release | cut -d '"' -f 2)
[ -z "$OS" ] && OS=$(uname -sr)
UPTIME=$(uptime -p | sed 's/up //')

# 5. 网络信息
IP_LOCAL=$(hostname -I | awk '{print $1}')
IP_PUBLIC=$(curl -s --connect-timeout 2 https://api64.i
