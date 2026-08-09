bash -c '
set +e
echo "====================================================="
echo "GPU进程监控（卡号｜用户｜PID｜运行时长｜工作目录｜执行命令）"
echo "====================================================="
printf "%-5s %-10s %-8s %-12s  %-35s  %s\n" "GPU卡" "用户" "PID" "已运行时间" "工作目录" "执行命令"
echo "----------------------------------------------------------------------------------------------------------------------------------------"

declare -A uuid2id
while IFS="," read -r idx uuid;do
    idx=$(echo "$idx"|xargs)
    uuid=$(echo "$uuid"|xargs)
    uuid2id[$uuid]="$idx"
done < <(nvidia-smi --query-gpu=index,uuid --format=csv,noheader,nounits)

while IFS="," read -r gpu_uuid pid;do
    gpu_uuid=$(echo "$gpu_uuid"|xargs)
    pid=$(echo "$pid"|xargs)
    [[ -z "$pid" ]] && continue

    gpu_id=${uuid2id[$gpu_uuid]:-未知}
    user=$(ps -p "$pid" -o user= 2>/dev/null|xargs)

    start_time=$(ps -p "$pid" -o lstart= 2>/dev/null)
    run_str="--"
    if [[ -n "$start_time" ]];then
        start_ts=$(date -d "$start_time" +%s 2>/dev/null)
        now_ts=$(date +%s)
        run_sec=$((now_ts-start_ts))
        days=$((run_sec/86400))
        rem=$((run_sec%86400))
        hours=$((rem/3600))
        mins=$(((rem%3600)/60))
        run_str=$(printf "%dd%02dh%02dm" "$days" "$hours" "$mins")
    fi

    work_dir=$(readlink -f /proc/${pid}/cwd 2>/dev/null)
    [[ -z "$work_dir" ]] && work_dir="未知目录"

    cmd=$(cat /proc/${pid}/cmdline 2>/dev/null|tr "\0" " ")
    # 正确英文短横线截取前120字符
    cmd=${cmd:0:120}
    [[ -z "$cmd" ]] && cmd="[无法读取命令]"

    printf "%-5s %-10s %-8s %-12s  %-35s  %s\n" "$gpu_id" "$user" "$pid" "$run_str" "$work_dir" "$cmd"
done < <(nvidia-smi --query-compute-apps=gpu_uuid,pid --format=csv,noheader,nounits)

echo -e "\n===== 显卡显存概况 ====="
nvidia-smi --query-gpu=index,name,memory.used,memory.total --format=csv,noheader,nounits
'
