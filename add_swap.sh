#!/bin/bash
# =================================================================
# Ubuntu 系统 Swap (交换空间) 交互式配置与增加脚本
# =================================================================

# 颜色定义
C_TITLE='\033[1;36m'  # 青色加粗 (标题)
C_SUB='\033[1;34m'    # 蓝色加粗 (副标题)
C_HL='\033[1;33m'     # 黄色加粗 (高亮)
C_ERR='\033[1;31m'    # 红色加粗 (报警/错误)
C_SUCC='\033[1;32m'   # 绿色加粗 (正常)
C_END='\033[0m'       # 重置颜色

# 字符定义
SEP="────────────────────────────────────────────────────────────────"

# 打印美化标题
function print_header() {
    clear
    echo -e "\n${C_TITLE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${C_END}"
    echo -e "${C_TITLE}┃                   UBUNTU 系统 SWAP 交换空间管理工具                 ┃${C_END}"
    echo -e "${C_TITLE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${C_END}"
    echo -e "执行时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 检查 Root 权限
function check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "\n${C_ERR}✖ 错误: Swap 操作涉及系统底层配置，请使用 sudo 或 root 权限运行此脚本。${C_END}"
        echo -e "示例: ${C_HL}sudo bash $0${C_END}\n"
        exit 1
    fi
}

# 1. 检查现有 Swap 信息
function show_current_swap() {
    echo -e "\n${C_SUB}▶ [1/4] 当前 Swap 空间及内存状态${C_END}"
    
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

# 2. 交互式配置 (路径与大小)
function interactive_config() {
    echo -e "\n${C_SUB}▶ [2/4] 配置新的 Swap 文件${C_END}"

    # 询问文件夹路径
    echo -e "  请输入你要存放 Swap 文件的【目录路径】"
    echo -e "  (直接回车默认使用根目录: ${C_HL}/${C_END})"
    read -p "  ➤ 目录路径: " SWAP_DIR
    SWAP_DIR=${SWAP_DIR:-/} # 默认值为 /

    # 检查目录是否存在
    if [ ! -d "$SWAP_DIR" ]; then
        echo -e "  ${C_HL}目录 $SWAP_DIR 不存在，正在尝试创建...${C_END}"
        mkdir -p "$SWAP_DIR" || { echo -e "  ${C_ERR}✖ 创建目录失败，请检查路径或权限。${C_END}"; exit 1; }
    fi

    # 获取该目录所在磁盘的剩余空间 (单位: MB)
    local avail_space_mb=$(df -m "$SWAP_DIR" | awk 'NR==2 {print $4}')
    local avail_space_gb=$(echo "scale=2; $avail_space_mb / 1024" | bc)
    
    echo -e "  当前目录 [${C_SUCC}$SWAP_DIR${C_END}] 所在磁盘可用空间为: ${C_HL}${avail_space_gb} GB${C_END}"

    # 询问大小
    echo -e "\n  请输入需要增加的 Swap 大小（单位: GB，仅输入整数）"
    echo -e "  (直接回车默认为: ${C_HL}4${C_END})"
    read -p "  ➤ 增加大小(GB): " SWAP_SIZE_GB
    SWAP_SIZE_GB=${SWAP_SIZE_GB:-4}

    # 校验输入是否为数字
    if ! [[ "$SWAP_SIZE_GB" =~ ^[0-9]+$ ]]; then
        echo -e "  ${C_ERR}✖ 错误: 只能输入整数数字。${C_END}"
        exit 1
    fi

    # 校验磁盘空间是否足够 (预留至少 1GB 剩余空间以防系统崩溃)
    local required_mb=$((SWAP_SIZE_GB * 1024))
    if [ "$required_mb" -ge $((avail_space_mb - 1024)) ]; then
        echo -e "  ${C_ERR}✖ 错误: 磁盘空间不足！所需 ${SWAP_SIZE_GB}GB，当前可用 ${avail_space_gb}GB (需预留1GB系统空间)。${C_END}"
        exit 1
    fi

    # 确定最终文件路径
    # 移除目录路径末尾的斜杠以防出现 //swapfile
    SWAP_DIR=${SWAP_DIR%/}
    if [ -z "$SWAP_DIR" ]; then SWAP_DIR=""; fi
    SWAP_FILE="${SWAP_DIR}/swapfile_$(date +%s)"
    
    echo -e "\n  ${C_SUCC}✔ 检查通过。准备在 [${SWAP_FILE}] 创建 ${SWAP_SIZE_GB}GB 的 Swap 空间。${C_END}"
    
    read -p "  按 [Enter] 键开始执行，或按 [Ctrl+C] 取消..."
}

# 3. 执行创建 Swap
function execute_swap() {
    echo -e "\n${C_SUB}▶ [3/4] 正在创建并激活 Swap 空间...${C_END}"
    
    echo -e "  [1/4] 正在分配磁盘空间 (大小: ${SWAP_SIZE_GB}GB)... ${C_HL}这可能需要几分钟，请耐心等待。${C_END}"
    # 使用 dd 替代 fallocate，因为 fallocate 在 BTRFS/ZFS 等文件系统上可能会导致 Swap 损坏
    dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$((SWAP_SIZE_GB * 1024)) status=progress || { echo -e "  ${C_ERR}✖ 空间分配失败。${C_END}"; exit 1; }

    echo -e "  [2/4] 设置安全权限 (600)..."
    chmod 600 "$SWAP_FILE"

    echo -e "  [3/4] 格式化为 Swap 文件系统..."
    mkswap "$SWAP_FILE" >/dev/null 2>&1

    echo -e "  [4/4] 激活 Swap 空间..."
    swapon "$SWAP_FILE" || { echo -e "  ${C_ERR}✖ 激活失败。${C_END}"; exit 1; }
    
    echo -e "  ${C_SUCC}✔ Swap 空间已成功创建并激活！${C_END}"
}

# 4. 写入开机自启
function setup_fstab() {
    echo -e "\n${C_SUB}▶ [4/4] 配置开机自动挂载${C_END}"
    
    if grep -q "$SWAP_FILE" /etc/fstab; then
        echo -e "  ${C_SUCC}✔ 该文件已存在于 /etc/fstab 中。${C_END}"
    else
        echo -e "  正在备份 /etc/fstab 到 /etc/fstab.bak..."
        cp /etc/fstab /etc/fstab.bak
        
        echo -e "  写入挂载信息..."
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
        echo -e "  ${C_SUCC}✔ 开机自动挂载配置完成。${C_END}"
    fi
}

# =================================================================
# 主程序执行流
# =================================================================

check_root
print_header
show_current_swap
interactive_config
execute_swap
setup_fstab

echo -e "\n${C_TITLE}${SEP}${C_END}"
echo -e "操作完成！以下是系统最新的 Swap 状态："
swapon --show | sed 's/^/  /'
echo -e "\n如果将来需要删除此 Swap，请依次执行:"
echo -e "1. ${C_HL}sudo swapoff ${SWAP_FILE}${C_END}"
echo -e "2. ${C_HL}sudo rm ${SWAP_FILE}${C_END}"
echo -e "3. 打开 ${C_HL}/etc/fstab${C_END} 删除对应的那一行。"
echo -e "${C_TITLE}${SEP}${C_END}\n"
