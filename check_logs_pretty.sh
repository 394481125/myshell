#!/bin/bash

# =================================================================
# Ubuntu 系统异常日志一键美化展示工具
# =================================================================

# 颜色与样式定义
export LANG=en_US.UTF-8
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 装饰性符号
CHECK="✅"
ERROR="❌"
WARN="⚠️"
INFO="ℹ️"
FIRE="🔥"

# 清理屏幕
clear

# 打印标题
print_header() {
    echo -e "${CYAN}${BOLD}=================================================================="
    echo -e "         🚀 UBUNTU 系统健康度与异常日志分析报告"
    echo -e "         生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "==================================================================${NC}"
}

# 1. 系统概览
section_system_info() {
    echo -e "\n${BLUE}${BOLD}[ 1. 系统概览 ]${NC}"
    uptime_info=$(uptime -p)
    kernel_ver=$(uname -r)
    echo -e " ${INFO}  运行时间: ${GREEN}$uptime_info${NC}"
    echo -e " ${INFO}  内核版本: $kernel_ver"
    echo -e " ${INFO}  当前用户: $(whoami)"
}

# 2. 意外重启分析 (Detect Unexpected Reboots)
section_reboot_analysis() {
    echo -e "\n${BLUE}${BOLD}[ 2. 意外重启分析 ]${NC}"
    # 查找最近10条重启/关机记录，分析是否存在没有正常shutdown的reboot
    echo -e "${YELLOW} 近期重启历史 (前5条):${NC}"
    last -x -n 10 | grep -E "reboot|shutdown" | head -n 5 | while read line; do
        if [[ $line == *"crash"* ]] || [[ $line == *"gone"* ]]; then
            echo -e " ${ERROR} ${RED}$line (疑似异常退出)${NC}"
        else
            echo -e " ${CHECK} $line"
        fi
    done
}

# 3. 内核崩溃与异常 (Kernel Issues / OOM)
section_kernel_errors() {
    echo -e "\n${BLUE}${BOLD}[ 3. 内核崩溃与严重异常 ]${NC}"
    
    # 检索 OOM Killer
    oom_logs=$(dmesg | grep -iE "out of memory|oom-killer" | tail -n 3)
    if [ -n "$oom_logs" ]; then
        echo -e " ${FIRE} ${RED}${BOLD}检测到内存溢出 (OOM Killer):${NC}"
        echo -e "${RED}$oom_logs${NC}"
    else
        echo -e " ${CHECK} 未发现近期 OOM 记录"
    fi

    # 检索 Kernel Panic / Segfault
    kernel_panic=$(journalctl -k -p 0..3 --since "3 days ago" --no-pager | tail -n 5)
    if [ -n "$kernel_panic" ]; then
        echo -e " ${WARN} ${YELLOW}近期内核错误 (Critical/Error):${NC}"
        echo -e "$kernel_panic"
    else
        echo -e " ${CHECK} 近3天内核运行平稳"
    fi
}

# 4. 服务状态与崩溃 (Service Status)
section_service_failures() {
    echo -e "\n${BLUE}${BOLD}[ 4. 系统服务健康度 ]${NC}"
    
    failed_units=$(systemctl --failed --no-legend)
    if [ -n "$failed_units" ]; then
        echo -e " ${ERROR} ${RED}当前失败的服务:${NC}"
        echo "$failed_units" | awk '{printf "   - \033[0;31m%-20s\033[0m %s\n", $1, $2}'
    else
        echo -e " ${CHECK} 所有核心服务运行正常"
    fi

    echo -e "\n${YELLOW} 近期服务启动失败/崩溃记录 (journalctl):${NC}"
    journalctl -p 3 -n 5 --no-pager | grep -iE "failed|crash|error" | head -n 5 | sed 's/^/   /'
}

# 5. Apport 崩溃报告 (Ubuntu Specific /var/crash)
section_crash_reports() {
    echo -e "\n${BLUE}${BOLD}[ 5. 应用程序崩溃报告 (/var/crash) ]${NC}"
    if [ -d /var/crash ] && [ "$(ls -A /var/crash)" ]; then
        echo -e " ${WARN} ${YELLOW}发现以下应用程序崩溃文件:${NC}"
        ls -lh /var/crash | grep ".crash" | awk '{print "   📦 " $9 " (" $5 ")"}'
    else
        echo -e " ${CHECK} /var/crash 目录为空，无近期应用崩溃报告"
    fi
}

# 6. 核心日志摘要 (Last 24h Errors)
section_recent_errors() {
    echo -e "\n${BLUE}${BOLD}[ 6. 过去24小时严重错误统计 ]${NC}"
    error_count=$(journalctl --since "24 hours ago" -p 3 | wc -l)
    
    if [ "$error_count" -gt 50 ]; then
        echo -e " ${FIRE} ${RED}警报: 过去24小时产生了 $error_count 条错误日志！${NC}"
    else
        echo -e " ${INFO} 过去24小时错误日志数量: ${CYAN}$error_count${NC}"
    fi
    
    echo -e "\n${PURPLE}最新3条错误详情:${NC}"
    journalctl -p 3 -n 3 --no-pager | sed 's/^/  /'
}

# 执行流程
print_header
section_system_info
section_reboot_analysis
section_kernel_errors
section_service_failures
section_crash_reports
section_recent_errors

echo -e "\n${CYAN}=================================================================="
echo -e " 分析完成。建议根据以上 ${RED}红色${CYAN} 部分排查具体原因。"
echo -e " 如需实时查看，请使用: journalctl -f"
echo -e "==================================================================${NC}\n"
