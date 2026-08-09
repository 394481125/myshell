#!/bin/bash
echo "====================================================="
echo "           GPU进程监控工具（卡号｜用户｜PID｜运行时长｜显存｜命令）"
echo "====================================================="
echo -e "GPU卡\t用户\tPID\t已运行时间\t显存占用\t执行命令"
echo "-----------------------------------------------------"

gpu_num=$(nvidia-smi --query-gpu=count --format=csv,noheader)
for((i=0;i<gpu_num;i++));
do
nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader -i $i |while IFS=, read -r pid mem;
do
pid=$(echo $pid|xargs)
mem=$(echo $mem|xargs)
[ "$pid" = "[Not Supported]" ]&&continue
user=$(ps -p $pid -o user= 2>/dev/null|xargs)
runtime=$(ps -p $pid -o etime= 2>/dev/null|xargs)
comm=$(ps -p $pid -o cmd= 2>/dev/null|xargs)
echo -e "$i\t$user\t$pid\t$runtime\t$mem\t$comm"
done
done
