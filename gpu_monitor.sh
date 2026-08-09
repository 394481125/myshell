#!/bin/bash
set -euo pipefail

echo "====================================================="
echo "           GPU进程监控工具（卡号｜用户｜PID｜运行时长｜命令）"
echo "====================================================="
printf "%-5s %-10s %-8s %-12s  %s\n" "GPU卡" "用户" "PID" "已运行时间" "执行命令"
echo "-----------------------------------------------------"

# 获取所有gpu‑pid映射 nvidia-smi --query-compute-apps
nvidia-smi --query-compute-apps=gpu_uuid,pid --format=csv,noheader,nounits | while IFS=',' read -r gpu_uuid pid;
do
    # 根据uuid拿到gpu编号
    gpu_id=$(nvidia-smi --query-gpu=index,uuid --format=csv,noheader,nounits | grep "${gpu_uuid}" | awk -F',' '{print $1}' | xargs)

    # 获取进程所属用户
    user=$(ps -o user= -p "$pid" 2>/dev/null || echo "N/A")

    # 获取进程启动时间，计算运行时长
    start_time=$(ps -o lstart= -p "$pid" 2>/dev/null)
    if [ -n "$start_time" ];then
        start_ts=$(date -d "$start_time" +%s 2>/dev/null || echo 0)
        now_ts=$(date +%s)
        run_sec=$((now_ts - start_ts))
        # 秒转天时分
        days=$((run_sec / 86400))
        rem=$((run_sec % 86400))
        hours=$((rem / 3600))
        rem=$((rem % 3600))
        mins=$((rem /60))
        run_str=$(printf "%dd%02dh%02dm" $days $hours $mins)
    else
        run_str="--"
    fi

    # 获取完整命令行（截断太长避免乱屏）
    cmd=$(cat /proc/${pid}/cmdline 2>/dev/null | tr '\0' ' ' | cut -c1-100)
    if [ -z "$cmd" ];then
        cmd="[无法读取命令]"
    fi

    printf "%-5s %-10s %-8s %-12s  %s\n" "${gpu_id}" "${user}" "${pid}" "${run_str}" "${cmd}"
done

echo -e "\n===== 显卡整体显存占用（nvidia‑smi简版） ====="
nvidia-smi --query-gpu=index,name,memory.used,memory.total --format=csv,noheader,nounits
echo "====================================================="
echo "⚠注意：系统无法读取【预估剩余时间】，只能显示已经运行时长！"
