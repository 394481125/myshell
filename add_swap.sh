#!/bin/bash
# =================================================================
# Ubuntu 系统 Swap (交换空间) 交互式配置与增加脚本 (智能清理版)
# =================================================================

C_TITLE='\033[1;36m' 
C_SUB='\033[1;34m'   
C_HL='\033[1;33m'    
C_ERR='\033[1;31m'   
C_SUCC='\033[1;32m'  
C_END='\033[0m'      
SEP="────────────────────────────────────────────────────────────────"

function print_header() {
    clear
    echo -e "\n${C_TITLE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${C_END}"
    echo -e "${C_TITLE}┃                   UBUNTU 系统 SWAP 交换空间管理工具                 ┃${C_END}"
    echo -e "${C_TITLE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${C_END}"
    echo -e "执行时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

function check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "\n${C_ERR}✖ 错误: 请使用 sudo 或 root 权限运行此脚本。${C_END}"
        exit 1
    fi
}

function show_current_swap() {
    echo -e "\n${C_SUB}▶ [1/5] 当前 Swap 空间及内存状态${C_END}"
    local swap_info=$(swapon --show)
    if [ -z "$swap_info" ]; then
        echo -e "  ${C_ERR}当前系统未启用任何 Swap 交换空间。${C_END}"
    else
        echo -e "  ${C_HL}已启用的 Swap 文件/分区:${C_END}"
        swapon --show | sed 's/^/    /'
    fi
    echo -e "\n  ${C_HL}系统内存概览:${C_END}"
    free -h | sed 's/^/    /'
}

function handle_existing_swap() {
    echo -e "\n${C_SUB}▶ [2/5] 处理现有 Swap 空间${C_END}"
    local swap_count=$(swapon --show --noheadings | wc -l)
    
    if [ "$swap_count" -eq 0 ]; then
        echo -e "  ${C_SUCC}当前无 Swap，跳过清理步骤。${C_END}"
        return
    fi

    echo -e "  检测到系统当前已有启用的 Swap 空间。"
    echo -e "  请选择操作："
    echo -e "  ${C_HL}[1] 保留现有 Swap，直接追加创建新的 Swap 空间 (默认)${C_END}"
    echo -e "  ${C_ERR}[2] 卸载并删除所有现有 Swap，然后重新创建${C_END}"
    read -p "  ➤ 请输入选项 [1/2]: " SWAP_CHOICE </dev/tty
    SWAP_CHOICE=${SWAP_CHOICE:-1}

    if [ "$SWAP_CHOICE" == "2" ]; then
        echo -e "  ${C_ERR}警告: 正在卸载并清理现有 Swap...${C_END}"
        cp /etc/fstab /etc/fstab.bak_swap_clean
        
        swapon --show=NAME,TYPE --noheadings | while read -r s_name s_type; do
            echo -e "    - 正在停用: $s_name ..."
            # 停用swap时增加保护机制，防止OOM死机
            swapoff "$s_name" || { echo -e "      ${C_ERR}✖ 停用失败！可能是系统内存不足以承载 Swap 中正在使用的数据，请重启系统释放内存后再试。${C_END}"; exit 1; }
            
            if [ "$s_type" == "file" ]; then
                echo -e "    - 正在删除文件: $s_name"
                rm -f "$s_name"
            else
                echo -e "    - $s_name 是磁盘分区(partition)，为保证数据安全，已跳过文件删除。"
            fi
            
            # 从 fstab 中删除对应的自启动挂载行
            sed -i "\|^$s_name|d" /etc/fstab
        done
        echo -e "  ${C_SUCC}✔ 现有 Swap 已全部清理完毕，/etc/fstab 已更新。${C_END}"
    else
        echo -e "  ${C_SUCC}✔ 选择保留现有 Swap，准备追加空间。${C_END}"
    fi
}

function interactive_config() {
    echo -e "\n${C_SUB}▶ [3/5] 配置新的 Swap 文件${C_END}"
    echo -e "  请输入你要存放 Swap 文件的【目录路径】 (直接回车默认使用根目录: ${C_HL}/${C_END})"
    read -p "  ➤ 目录路径: " SWAP_DIR </dev/tty
    SWAP_DIR=${SWAP_DIR:-/} 

    if [ ! -d "$SWAP_DIR" ]; then
        echo -e "  ${C_HL}目录 $SWAP_DIR 不存在，正在尝试创建...${C_END}"
        mkdir -p "$SWAP_DIR" || { echo -e "  ${C_ERR}✖ 创建失败。${C_END}"; exit 1; }
    fi

    local avail_space_mb=$(df -m "$SWAP_DIR" | awk 'NR==2 {print $4}')
    local avail_space_gb=$(echo "scale=2; $avail_space_mb / 1024" | bc)
    echo -e "  当前目录 [${C_SUCC}$SWAP_DIR${C_END}] 所在磁盘可用空间为: ${C_HL}${avail_space_gb} GB${C_END}"

    echo -e "\n  请输入需要增加的 Swap 大小（单位: GB，仅输入整数） (直接回车默认为: ${C_HL}4${C_END})"
    read -p "  ➤ 增加大小(GB): " SWAP_SIZE_GB </dev/tty
    SWAP_SIZE_GB=${SWAP_SIZE_GB:-4}

    if ! [[ "$SWAP_SIZE_GB" =~ ^[0-9]+$ ]]; then
        echo -e "  ${C_ERR}✖ 错误: 只能输入整数数字。${C_END}"
        exit 1
    fi

    local required_mb=$((SWAP_SIZE_GB * 1024))
    if [ "$required_mb" -ge $((avail_space_mb - 1024)) ]; then
        echo -e "  ${C_ERR}✖ 错误: 磁盘空间不足！所需 ${SWAP_SIZE_GB}GB，当前可用 ${avail_space_gb}GB (需预留1GB防崩溃)。${C_END}"
        exit 1
    fi

    SWAP_DIR=${SWAP_DIR%/}
    if [ -z "$SWAP_DIR" ]; then SWAP_DIR=""; fi
    SWAP_FILE="${SWAP_DIR}/swapfile_$(date +%s)"
    
    echo -e "\n  ${C_SUCC}✔ 准备在 [${SWAP_FILE}] 创建 ${SWAP_SIZE_GB}GB 的 Swap 空间。${C_END}"
    read -p "  按 [Enter] 键开始执行，或按 [Ctrl+C] 取消..." </dev/tty
}

function execute_swap() {
    echo -e "\n${C_SUB}▶ [4/5] 正在创建并激活 Swap 空间...${C_END}"
    echo -e "  [1/4] 正在分配磁盘空间 (${SWAP_SIZE_GB}GB)... ${C_HL}请耐心等待。${C_END}"
    dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$((SWAP_SIZE_GB * 1024)) status=progress || exit 1
    echo -e "  [2/4] 设置安全权限 (600)..."
    chmod 600 "$SWAP_FILE"
    echo -e "  [3/4] 格式化为 Swap..."
    mkswap "$SWAP_FILE" >/dev/null 2>&1
    echo -e "  [4/4] 激活 Swap..."
    swapon "$SWAP_FILE" || exit 1
    echo -e "  ${C_SUCC}✔ 成功！${C_END}"
}

function setup_fstab() {
    echo -e "\n${C_SUB}▶ [5/5] 配置开机自动挂载${C_END}"
    if ! grep -q "$SWAP_FILE" /etc/fstab; then
        cp /etc/fstab /etc/fstab.bak
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
        echo -e "  ${C_SUCC}✔ 开机挂载配置完成。${C_END}"
    fi
}

check_root
print_header
show_current_swap
handle_existing_swap
interactive_config
execute_swap
setup_fstab

echo -e "\n${C_TITLE}${SEP}${C_END}"
echo -e "操作完成！最新的 Swap 状态："
swapon --show | sed 's/^/  /'
echo -e "${C_TITLE}${SEP}${C_END}\n"
