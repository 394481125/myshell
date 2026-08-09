bash -c '
set +e
echo "====================================================="
echo "           GPU进程监控工具（卡号｜用户｜PID｜运行时长｜命令）"
echo "====================================================="
printf "%-5s %-10s %-8s %-12s  %s\n" "GPU卡" "用户" "PID" "已运行时间" "执行命令"
echo "-----------------------------------------------------"

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
    cmd=$(cat /proc/${pid}/cmdline 2>/dev/null|tr "\0" " "|cut -c1-100)
    [[ -z "$cmd" ]] && cmd="[无法读取命令]"
    printf "%-5s %-10s %-8s %-12s  %s\n" "$gpu_id" "$user" "$pid" "$run_str" "$cmd"
done < <(nvidia-smi --query-compute-apps=gpu_uuid,pid --format=csv,noheader,nounits)

echo -e "\n===== 显卡整体显存占用 ====="
nvidia-smi --query-gpu=index,name,memory.used,memory.total --format=csv,noheader,nounits
'
