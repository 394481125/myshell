#!/bin/bash

# =================================================================
# Ubuntu 系统 CPU & GPU 一键健康报告与可视化展示脚本
# =================================================================

# 颜色定义
C_TITLE='\033[1;36m'   # 青色加粗 (标题)
C_SUB='\033[1;34m'     # 蓝色加粗 (副标题)
C_HL='\033[1;33m'      # 黄色加粗 (高亮)
C_ERR='\033[1;31m'     # 红色加粗 (报警/错误)
C_SUCC='\033[1;32m'    # 绿色加粗 (正常)
C_END='\033[0m'        # 重置颜色

# 字符定义
BAR_CHAR="■"
SEP="────────────────────────────────────────────────────────────────"

# 打印美化标题
function print_header() {
    echo -e "\n${C_TITLE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${C_END}"
    echo -e "${C_TITLE}┃                UBUNTU 系统 CPU & GPU 深度诊断报告                ┃${C_END}"
    echo -e "${C_TITLE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${C_END}"
    echo -e "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 绘制简易进度条
function draw_bar() {
    local percent=$1
    local width=20
    local filled=$(($percent * $width / 100))
    local empty=$(($width - $filled))
    local color=$C_SUCC
    if [ $percent -gt 70 ]; then color=$C_HL; fi
    if [ $percent -gt 90 ]; then color=$C_ERR; fi
    
    printf "["
    printf "${color}"
    for ((i=0; i<$filled; i++)); do printf "$BAR_CHAR"; done
    printf "${C_END}"
    for ((i=0; i<$empty; i++)); do printf " "; done
    printf "] %d%%" "$percent"
}

# 1. 基础信息
function get_base_info() {
    echo -e "\n${C_SUB}▶ [1/5] 系统基础信息${C_END}"
    echo "  主机名:   $(hostname)"
    echo "  内核版本: $(uname -r)"
    echo "  系统版本: $(lsb_release -ds)"
    echo "  运行时间: $(uptime -p)"
}

# 2. CPU 信息
function get_cpu_info() {
    echo -e "\n${C_SUB}▶ [2/5] CPU 状态监控${C_END}"
    local cpu_model=$(lscpu | grep "Model name" | cut -d':' -f2 | sed 's/^[ \t]*//')
    local cpu_cores=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
    local cpu_load=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    local cpu_temp=$(sensors 2>/dev/null | grep -E "Package|Core 0" | awk '{print $4}' | head -n 1)
    
    echo "  处理器:   $cpu_model ($cpu_cores 核心)"
    echo -n "  当前占用: "
    draw_bar ${cpu_load%.*}
    echo -e " (Load Avg: $(awk '{print $1", "$2", "$3}' /proc/loadavg))"
    echo "  实时频率: $(grep "cpu MHz" /proc/cpuinfo | head -n 1 | awk '{print $4}') MHz"
    [ -n "$cpu_temp" ] && echo "  核心温度: ${C_HL}$cpu_temp${C_END}"
}

# 3. GPU 信息 (NVIDIA 专用)
function get_gpu_info() {
    echo -e "\n${C_SUB}▶ [3/5] GPU 状态监控 (NVIDIA)${C_END}"
    
    if ! command -v nvidia-smi &> /dev/null; then
        echo -e "  ${C_ERR}未检测到 NVIDIA 驱动或 GPU 设备。${C_END}"
        return
    fi

    # 获取GPU基本信息
    nvidia-smi --query-gpu=name,driver_version,memory.total,memory.used,memory.free,utilization.gpu,temperature.gpu,power.draw --format=csv,noheader,nounits | while IFS=', ' read -r name driver mem_total mem_used mem_free util temp power; do
        echo "  设备名称: $name (驱动: $driver)"
        echo -n "  GPU 负载: "
        draw_bar $util
        echo -e " | 功耗: ${C_HL}${power}W${C_END}"
        
        local mem_pct=$(( 100 * mem_used / mem_total ))
        echo -n "  显存占用: "
        draw_bar $mem_pct
        echo -e " | ${mem_used}MB / ${mem_total}MB"
        echo "  核心温度: ${C_HL}${temp}°C${C_END}"
    done

    # 显存进程列表
    echo -e "\n  ${C_HL}显存占用进程排行:${C_END}"
    local gpu_proc=$(nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader)
    if [ -z "$gpu_proc" ]; then
        echo "    [无活跃计算进程]"
    else
        echo "    PID      进程名             显存占用"
        echo "    ------------------------------------"
        echo "$gpu_proc" | awk -F', ' '{printf "    %-8s %-18s %-10s\n", $1, $2, $3}'
    fi
}

# 4. 系统负载与进程
function get_top_processes() {
    echo -e "\n${C_SUB}▶ [4/5] 进程资源占用 (Top 5)${C_END}"
    echo -e "  ${C_HL}CPU 占用最高:${C_END}"
    ps -eo pid,ppid,cmd,%cpu --sort=-%cpu | head -n 6 | sed 's/^/    /'
    echo -e "  ${C_HL}内存占用最高:${C_END}"
    ps -eo pid,ppid,cmd,%mem --sort=-%mem | head -n 6 | sed 's/^/    /'
}

# 5. 故障诊断日志
function get_fault_logs() {
    echo -e "\n${C_SUB}▶ [5/5] 关键故障信息日志 (近期)${C_END}"
    
    echo -e "  ${C_HL}[dmesg 硬件错误监控]:${C_END}"
    local hw_errors=$(sudo dmesg | grep -iE "Xid|NVRM|thermal|throttling|segfault|error" | tail -n 5)
    if [ -z "$hw_errors" ]; then
        echo -e "    ${C_SUCC}✔ 未发现明显硬件异常日志${C_END}"
    else
        echo "$hw_errors" | sed 's/^/    /'
    fi

    echo -e "\n  ${C_HL}[Journalctl GPU/Driver 报错]:${C_END}"
    local journal_errors=$(journalctl -k --grep="nvidia|gpu|nvrm" -n 5 --no-pager 2>/dev/null)
    if [ -z "$journal_errors" ]; then
         echo -e "    ${C_SUCC}✔ 近期驱动运行平稳${C_END}"
    else
        echo "$journal_errors" | grep -v "^--" | tail -n 5 | sed 's/^/    /'
    fi
}

# 执行收集过程
print_header
get_base_info
get_cpu_info
get_gpu_info
get_top_processes
get_fault_logs

echo -e "\n${C_TITLE}${SEP}${C_END}"
echo -e "报告生成完毕。如果是为了持续监控，建议安装: ${C_HL}nvtop${C_END} 或 ${C_HL}btm${C_END}。"
echo -e "${C_TITLE}${SEP}${C_END}\n"
