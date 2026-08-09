#!/bin/bash
set +e
clear
echo "================================================================================"
echo "   一站式虚拟环境创建｜CUDA自动适配｜PyTorch安装｜timm‑ResNet50 GPU基准测试"
echo "   指标：GFLOPS、吞吐、推理速度、训练速度、显存占用、设备信息、多卡测速"
echo "================================================================================"

read -p "请输入你的项目虚拟环境名称：" env_name
[[ -z "${env_name}" ]] && echo "环境名称不能为空，脚本退出" && exit 1
env_act_status=0
base_path=$(pwd)

# 优先加载本地已存在 venv
if [[ -d "./${env_name}" ]];then
    echo -e "\n✅ 检测到已有venv环境，正在激活 ${env_name}"
    source ./${env_name}/bin/activate
    env_act_status=1
    ENV_TYPE="venv"
    ACTIVATE_CMD="source ${base_path}/${env_name}/bin/activate"
    EXIT_CMD="deactivate"
else
    echo -e "\n⚠ 本地不存在该venv文件夹，请选择环境类型"
    echo "1 = Conda 虚拟环境"
    echo "2 = Python原生venv轻量虚拟环境"
    read -p "输入序号：" sel_type
    if [[ "$sel_type" == "1" ]];then
        command -v conda >/dev/null || { echo "本机未安装conda，退出";exit 1; }
        read -p "输入Python版本(默认3.10)：" py_version
        py_version=${py_version:-3.10}
        if conda env list | grep -w "${env_name}";then
            echo "conda环境已存在，直接激活"
        else
            conda create -n "${env_name}" python="${py_version}" -y
        fi
        eval "$(conda shell.bash hook)"
        conda activate "${env_name}"
        env_act_status=1
        ENV_TYPE="conda"
        ACTIVATE_CMD="conda activate ${env_name}"
        EXIT_CMD="conda deactivate"
    elif [[ "$sel_type" == "2" ]];then
        python3 -m venv "${env_name}"
        source ./${env_name}/bin/activate
        env_act_status=1
        ENV_TYPE="venv"
        ACTIVATE_CMD="source ${base_path}/${env_name}/bin/activate"
        EXIT_CMD="deactivate"
        echo "✅ venv环境创建并激活成功"
    fi
fi
[[ $env_act_status -ne 1 ]] && echo "环境激活失败" && exit 1

# pip 清华源
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

# 提前一次性装好所有测速依赖：numpy psutil timm
echo -e "\n>>> 预安装测速依赖 numpy psutil timm"
pip install -q numpy psutil timm

install_torch_gpu(){
    declare -a opt_tag=()
    declare -a opt_name=()

    echo -e "\n>>>>>>>>>> 检测本机显卡CUDA信息"
    if ! command -v nvidia-smi &> /dev/null;then
        echo "没有识别到N卡，仅可安装CPU‑PyTorch"
        pip install torch torchvision torchaudio
        return
    fi

    cuda_raw=$(nvidia-smi | grep -i "CUDA Version")
    cuda_version=$(echo "$cuda_raw" | sed 's/[^0-9.]//g')
    major_ver=$(echo "$cuda_version" | cut -d '.' -f1)
    minor_ver=$(echo "$cuda_version" | cut -d '.' -f2)
    echo "✅ 显卡驱动最高支持 CUDA‑$cuda_version"

    if (( major_ver >= 12 ));then
        opt_tag+=("cu121") ; opt_name+=("CUDA‑12.1（推荐）")
        opt_tag+=("cu118") ; opt_name+=("CUDA‑11.8")
    elif (( major_ver == 11 && minor_ver >= 8 ));then
        opt_tag+=("cu118") ; opt_name+=("CUDA‑11.8（推荐）")
        opt_tag+=("cu117") ; opt_name+=("CUDA‑11.7")
    elif (( major_ver == 11 ));then
        opt_tag+=("cu117") ; opt_name+=("CUDA‑11.7（推荐）")
    fi
    opt_tag+=("cpu") ; opt_name+=("CPU‑版本")

    echo ""
    for ((i=0;i<${#opt_tag[@]};i++));do
        num=$((i+1))
        echo "$num) ${opt_name[$i]}"
    done

    read -p "请选择安装版本序号：" sel
    index=$((sel - 1))
    if (( index < 0 || index >= ${#opt_tag[@]} ));then
        echo "无效序号，跳过PyTorch安装"
        return
    fi
    target_tag=${opt_tag[$index]}

    echo -e "\nPyTorch下载通道选择"
    echo "1 = 上海交大国内镜像（高速）"
    echo "2 = 官方原版源"
    read -p "输入序号：" mirror_opt

    install_cmd="pip install torch torchvision torchaudio"
    mirror_url="https://mirror.sjtu.edu.cn/pytorch-wheels"

    if [[ "$mirror_opt" == "1" && "$target_tag" != "cpu" ]];then
        if [[ "$target_tag" == "cu121" ]];then
            install_cmd+=" -f ${mirror_url}/torch_stable.html"
        else
            install_cmd+=" -f ${mirror_url}/${target_tag}"
        fi
    fi

    echo "执行安装命令：$install_cmd"
    eval "$install_cmd"
    echo -e "\n✅ PyTorch 安装流程结束"
}

read -p "是否开始安装 PyTorch？(y/n)：" op
[[ "${op,,}" == "y" ]] && install_torch_gpu

# 加载requirements依赖
req_file="./requirements.txt"
if [[ -f "$req_file" ]];then
    read -p "安装剩余第三方依赖（自动跳过torch系列）？(y/n)" op2
    if [[ "${op2,,}" == "y" ]];then
        grep -ivE 'torch|pytorch' "$req_file" > /tmp/clean_req.txt
        pip install -r /tmp/clean_req.txt
        rm -f /tmp/clean_req.txt
        echo "✅ 其余依赖安装完成"
    fi
fi

# -------------------------- PyTorch GPU 基础校验命令 --------------------------
CHECK_GPU_BOOL='python -c "import torch; print(torch.cuda.is_available())"'
CHECK_GPU_NUM='python -c "import torch; print(torch.cuda.device_count())"'
CHECK_GPU_NAME='python -c "import torch; print([torch.cuda.get_device_name(i) for i in range(torch.cuda.device_count())])"'
CHECK_TORCH_CUDA='python -c "import torch; print(f\"PyTorch CUDA版本:{torch.version.cuda}\")"'
CHECK_CUDNN='python -c "import torch; print(f\"cuDNN可用:{torch.backends.cudnn.enabled}, cuDNN版本:{torch.backends.cudnn.version()}\")"'
CHECK_GPU_ALL='python -c "
import torch
print(\"===== PyTorch GPU 完整信息 =====\")
print(f\"CUDA可用: {torch.cuda.is_available()}\")
print(f\"显卡数量: {torch.cuda.device_count()}\")
for idx in range(torch.cuda.device_count()):
    print(f\"显卡{idx}: {torch.cuda.get_device_name(idx)}\")
print(f\"Torch绑定CUDA版本: {torch.version.cuda}\")
print(f\"cuDNN开启: {torch.backends.cudnn.enabled}\")
print(f\"cuDNN版本: {torch.backends.cudnn.version()}\")
"'

echo -e "\n>>>>>>>>>> 正在自动执行PyTorch‑GPU自检"
eval "$CHECK_GPU_ALL"

# -------------------------- GPU基准测试（timm加载resnet50，抛弃torch‑hub） --------------------------
gpu_benchmark_test(){
cat > /tmp/gpu_benchmark.py << 'EOF'
import torch
import time
import timm
try:
    import psutil
except ImportError:
    psutil = None

def get_gpu_info():
    device_count = torch.cuda.device_count()
    if device_count == 0:
        print("无可用CUDA显卡，跳过GPU测速")
        return False
    for i in range(device_count):
        print(f"\n---------- 显卡{i}基础信息 ----------")
        print("显卡名称:", torch.cuda.get_device_name(i))
        prop = torch.cuda.get_device_properties(i)
        print("显存总容量(GB):", round(prop.total_memory / (1024**3),3))
        print("算力:", prop.major,".",prop.minor)
    return True

def benchmark_single_card(device_id=0,batch=32,warm_up=10,test_loop=50):
    dev = torch.device(f"cuda:{device_id}")
    # 标准输入
    x = torch.randn((batch,3,224,224),dtype=torch.float32,device=dev)
    # timm加载，无远程hub冲突
    model = timm.create_model("resnet50",pretrained=False).to(dev)
    model.train()

    # 预热
    for _ in range(warm_up):
        out = model(x)

    # 训练测速(前向+反向传播)
    torch.cuda.synchronize(dev)
    t0 = time.time()
    for _ in range(test_loop):
        out = model(x)
        loss = out.sum()
        loss.backward()
    torch.cuda.synchronize(dev)
    train_cost = (time.time()-t0)/test_loop

    # 推理测速
    model.eval()
    with torch.no_grad():
        torch.cuda.synchronize(dev)
        t1 = time.time()
        for _ in range(test_loop):
            out = model(x)
        torch.cuda.synchronize(dev)
        infer_cost = (time.time()-t1)/test_loop

    # ResNet50‑224 单样本 FLOPs ≈4.1 GFLOPs
    single_sample_flop = 4.1
    batch_flop = single_sample_flop * batch
    train_gflops = batch_flop / train_cost
    infer_gflops = batch_flop / infer_cost
    train_throughput = batch / train_cost
    infer_throughput = batch / infer_cost

    mem_allocated = torch.cuda.memory_allocated(dev) / (1024**2)
    mem_reserved = torch.cuda.memory_reserved(dev) / (1024**2)

    print(f"\n========== 显卡 {device_id} 性能指标 ==========")
    print(f"单轮训练耗时(s):{round(train_cost,5)}")
    print(f"单轮推理耗时(s):{round(infer_cost,5)}")
    print(f"训练 GFLOPS:{round(train_gflops,3)}")
    print(f"推理 GFLOPS:{round(infer_gflops,3)}")
    print(f"训练吞吐(sample/s):{round(train_throughput,2)}")
    print(f"推理吞吐(sample/s):{round(infer_throughput,2)}")
    print(f"已占用显存(MB):{round(mem_allocated,2)}")
    print(f"缓存显存(MB):{round(mem_reserved,2)}")

def benchmark_multi_gpu():
    device_num = torch.cuda.device_count()
    if device_num <=1:
        return
    from torch.nn import DataParallel
    batch = 64
    model = timm.create_model("resnet50",pretrained=False).cuda()
    model = DataParallel(model)
    x = torch.randn((batch,3,224,224),dtype=torch.float32).cuda()
    model.train()
    for _ in range(10):
        o = model(x)
    torch.cuda.synchronize()
    t0 = time.time()
    loop = 30
    for _ in range(loop):
        o = model(x)
        loss = o.sum()
        loss.backward()
    torch.cuda.synchronize()
    avg_t = (time.time()-t0)/loop
    throughput = batch / avg_t
    print(f"\n========== 多卡DataParallel综合训练测试 ==========")
    print(f"显卡总数:{device_num}")
    print(f"平均迭代耗时(s):{round(avg_t,5)}")
    print(f"多卡训练吞吐(sample/s):{round(throughput,2)}")

if __name__=="__main__":
    if not torch.cuda.is_available():
        exit()
    get_gpu_info()
    gpu_cnt = torch.cuda.device_count()
    for d in range(gpu_cnt):
        benchmark_single_card(device_id=d)
    benchmark_multi_gpu()
EOF
    python /tmp/gpu_benchmark.py
    rm -f /tmp/gpu_benchmark.py
}

read -p "是否执行GPU综合性能基准测试(单卡GFLOPS、吞吐、速度、多卡测速)？(y/n) " bench_opt
[[ "${bench_opt,,}" == "y" ]] && gpu_benchmark_test


echo -e "\n================================================================================"
echo "✅ 整套环境搭建完毕｜环境类型：${ENV_TYPE}"
echo ""
echo "👉 【激活环境‑绝对路径命令】"
echo "${ACTIVATE_CMD}"
echo ""
echo "👉 【退出虚拟环境命令】"
echo "${EXIT_CMD}"
echo ""
echo "👉 【常用PyTorch‑GPU校验命令合集】"
echo "1. 判断GPU是否可用：${CHECK_GPU_BOOL}"
echo "2. 查看显卡数量：${CHECK_GPU_NUM}"
echo "3. 读取显卡名称：${CHECK_GPU_NAME}"
echo "4. 查看PyTorch内置CUDA版本：${CHECK_TORCH_CUDA}"
echo "5. 查看cuDNN状态与版本：${CHECK_CUDNN}"
echo "6. 一键完整GPU硬件信息：${CHECK_GPU_ALL}"
echo ""
echo "👉 【GPU性能测试说明】"
echo "• 测试网络：timm‑ResNet50 输入尺寸 3*224*224"
echo "• 输出指标：训练耗时、推理耗时、GFLOPS、每秒样本吞吐、显存占用、显卡算力、多卡并行速度"
echo "================================================================================"
