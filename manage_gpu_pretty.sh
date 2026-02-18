#!/bin/bash

# 强制使用 bash 运行，防止 dash 兼容性问题
# 深度学习 GPU 管理工具 v2.0 - 稳定版

# 颜色
G='\033[0;32m'
R='\033[0;31m'
Y='\033[1;33m'
B='\033[0;34m'
NC='\033[0m'

# 检查环境
if ! command -v nvidia-smi &> /dev/null; then
    echo "错误: 未找到 nvidia-smi，请检查驱动。"
    exit 1
fi

function show_menu() {
    # 每次显示菜单前清理一次屏幕，防止闪烁
    clear
    echo -e "${G}=====================================================${NC}"
    echo -e "${G}          GPU 深度管理工具 (PhD Stable Edition)      ${NC}"
    echo -e "${G}=====================================================${NC}"
    echo -e "${B}1.${NC} 实时监控 (nvidia-smi watch)"
    echo -e "${B}2.${NC} 详细进程清单 (查看谁在用显存)"
    echo -e "${B}3.${NC} 按编号杀掉某卡进程 (清理残留)"
    echo -e "${B}4.${NC} 【慎用】全卡紧急清理"
    echo -e "${B}5.${NC} 查看硬件拓扑与 P2P 状态"
    echo -e "${B}0.${NC} 退出"
    echo "-----------------------------------------------------"
}

# --- 功能函数 ---
function watch_gpu() {
    watch -d -n 0.5 nvidia-smi
}

function list_procs() {
    echo -e "\n${Y}--- 当前各显卡 PID 详细信息 ---${NC}"
    # 遍历所有存在的 nvidia 设备
    for dev in /dev/nvidia[0-9]*; do
        id=$(echo $dev | grep -o '[0-9]*$')
        echo -e "${G}[GPU $id]${NC}"
        fuser -v $dev 2>/dev/null || echo "无进程占用"
    done
}

function kill_specific() {
    read -p "请输入要清理的 GPU 编号: " id
    if [[ ! $id =~ ^[0-9]+$ ]]; then
        echo -e "${R}输入无效，请输入数字。${NC}"
        return
    fi
    echo -e "${Y}清理 GPU $id...${NC}"
    fuser -ki /dev/nvidia$id
}

# --- 主循环 ---
while true; do
    show_menu
    # 使用 -r 防止反斜杠转义，确保 read 能够阻塞等待
    read -r -p "请输入选项 [0-5]: " choice

    case "$choice" in
        1) watch_gpu ;;
        2) list_procs ;;
        3) kill_specific ;;
        4) 
            read -p "确定清空所有显卡？(y/n): " confirm
            if [[ "$confirm" == "y" ]]; then fuser -ki /dev/nvidia*; fi
            ;;
        5) 
            nvidia-smi topo -m
            ;;
        0) 
            echo "退出程序..."
            exit 0 
            ;;
        *) 
            # 如果输入为空或无效，不执行 clear，而是稍微停顿提示
            echo -e "${R}无效输入，请重新选择...${NC}"
            sleep 1
            continue
            ;;
    esac

    # 关键：操作完成后等待用户按回车，不直接进入下一次循环
    echo -e "\n${Y}操作完成，按 [回车键] 返回菜单...${NC}"
    read -r
done
