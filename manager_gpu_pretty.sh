#!/bin/bash

# =================================================================
# GPU 深度管理工具 (科研专用版)
# 适用场景：Ubuntu + NVIDIA Driver + 深度学习开发
# =================================================================

# 颜色定义
G='\033[0;32m' # Green
R='\033[0;31m' # Red
Y='\033[1;33m' # Yellow
B='\033[0;34m' # Blue
C='\033[0;36m' # Cyan
NC='\033[0m'    # No Color

# 检查 nvidia-smi 是否可用
if ! command -v nvidia-smi &> /dev/null; then
    echo -e "${R}错误: 未检测到 NVIDIA 驱动，请检查环境！${NC}"
    exit 1
fi

# 1. 实时监控 (高亮变化)
function watch_gpu() {
    echo -e "${G}正在启动实时监控 (每0.5秒更新，高亮变化部分)...${NC}"
    echo -e "${Y}提示: 按 Ctrl+C 退出监控返回菜单${NC}"
    sleep 2
    watch -d -n 0.5 nvidia-smi
}

# 2. 详细列出占用 GPU 的用户和进程 (追溯神器)
function list_gpu_procs() {
    echo -e "${B}========== 当前 GPU 进程详细清单 ==========${NC}"
    # 使用 fuser 查找真实占用，防止 nvidia-smi 漏报
    for i in $(ls /dev/nvidia[0-9]* | cut -d'a' -f2); do
        echo -e "${C}GPU $i 占用情况:${NC}"
        fuser -v /dev/nvidia$i 2>/dev/null
        echo "--------------------------------------------"
    done
}

# 3. 按显卡编号一键清理 (防止误杀室友的实验)
function kill_gpu_specific() {
    nvidia-smi --format=csv,noheader --query-gpu=index,name
    read -p "请输入要清空的 GPU 编号 (例如: 0): " gpu_id
    if [[ -z "$gpu_id" ]]; then return; fi
    
    echo -e "${Y}正在检索 GPU $gpu_id 的进程...${NC}"
    pids=$(fuser /dev/nvidia$gpu_id 2>/dev/null)
    
    if [ -z "$pids" ]; then
        echo -e "${G}GPU $gpu_id 已经是空的，无需清理。${NC}"
    else
        echo -e "${R}找到以下进程: $pids${NC}"
        read -p "确定要强制杀掉这些进程吗? (y/n): " confirm
        if [[ "$confirm" == "y" ]]; then
            fuser -ki /dev/nvidia$gpu_id
            echo -e "${G}清理完成。${NC}"
        fi
    fi
}

# 4. 紧急全卡清空 (慎用：清空所有显卡)
function kill_gpu_all() {
    echo -e "${R}！！！危险操作：即将杀掉所有显卡上的所有进程 ！！！${NC}"
    read -p "你确定吗? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        fuser -ki /dev/nvidia*
        echo -e "${G}全卡已清空。${NC}"
    fi
}

# 5. 查看 GPU 拓扑 (多卡分布式训练前必看)
# 确认是 NVLink 还是 PCIe，以及 P2P 是否支持
function check_topo() {
    echo -e "${B}========== GPU 硬件拓扑与 P2P 状态 ==========${NC}"
    nvidia-smi topo -m
    echo ""
    echo -e "${Y}提示: NVLink 连接速度远快于 PHB (PCIe Bridge)${NC}"
}

# 6. 显存压力测试 (简易版)
# 博士生有时候需要测试系统稳定性
function gpu_burn_test() {
    echo -e "${Y}提示: 该功能需要安装 gpu-burn (如果未安装将报错)${NC}"
    echo "1. 下载并编译 gpu-burn"
    echo "2. 运行 ./gpu_burn 60 (测试60秒)"
}

# 菜单显示
function show_menu() {
    echo -e "
${G}┌──────────────────────────────────────────────────┐
│             GPU 深度管理一键通                        │
└──────────────────────────────────────────────────┘${NC}
  ${C}1.${NC} 实时监控 GPU (Watch mode)
  ${C}2.${NC} 谁在用显卡？(详细进程/用户清单)
  ${C}3.${NC} 指定清理某块卡 (Kill processes on specific GPU)
  ${C}4.${NC} 紧急重置：全卡清空 (Kill all GPU processes)
  ${C}5.${NC} 查看硬件拓扑/NVLink (Topo/P2P check)
  ${C}6.${NC} 刷新显卡驱动状态 (nvidia-smi -r / 重启尝试)
  ${C}0.${NC} 退出
"
}

# 循环主体
while true; do
    show_menu
    read -p "请选择操作 [0-6]: " choice
    case $choice in
        1) watch_gpu ;;
        2) list_gpu_procs ;;
        3) kill_gpu_specific ;;
        4) kill_gpu_all ;;
        5) check_topo ;;
        6) nvidia-smi -r ;; # 尝试重置 GPU 状态
        0) exit 0 ;;
        *) echo -e "${R}无效输入，请重新选择${NC}" ;;
    esac
    echo -e "\n${Y}操作完成，按回车键继续...${NC}"
    read
    clear
done
