#!/bin/bash
set +e
clear
echo "================================================================================"
echo "   一站式虚拟环境创建｜自动适配显卡CUDA、可自选国内镜像加速PyTorch"
echo "================================================================================"

read -p "请输入你的项目虚拟环境名称：" env_name
[[ -z "${env_name}" ]] && echo "环境名称不能为空，脚本退出" && exit 1
env_act_status=0

# 优先加载本地已存在 venv
if [[ -d "./${env_name}" ]];then
    echo -e "\n✅ 检测到已有venv环境，正在激活 ${env_name}"
    source ./${env_name}/bin/activate
    env_act_status=1
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
    elif [[ "$sel_type" == "2" ]];then
        python3 -m venv "${env_name}"
        source ./${env_name}/bin/activate
        env_act_status=1
        echo "✅ venv环境创建并激活成功"
    fi
fi
[[ $env_act_status -ne 1 ]] && echo "环境激活失败" && exit 1

# 普通pip包默认清华源
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

install_torch_gpu(){
    declare -a opt_tag=()
    declare -a opt_name=()

    echo -e "\n>>>>>>>>>> 检测本机显卡CUDA信息"
    if ! command -v nvidia-smi &> /dev/null;then
        echo "没有识别到N卡，仅可安装CPU‑PyTorch"
        pip install torch torchvision torchaudio
        return
    fi

    # 清洗版本，清除特殊符号
    cuda_version=$(nvidia-smi | grep -i "CUDA Version" | sed 's/[^0-9.]//g')
    major_ver=$(echo "$cuda_version" | cut -d '.' -f1)
    minor_ver=$(echo "$cuda_version" | cut -d '.' -f2)
    echo "✅ 显卡驱动最高支持 CUDA‑$cuda_version"

    # 根据硬件最大CUDA，动态生成向下兼容列表
    if (( major_ver >= 12 ));then
        opt_tag+=("cu121") ; opt_name+=("CUDA‑12.1（推荐）")
        opt_tag+=("cu118") ; opt_name+=("CUDA‑11.8")
    elif (( major_ver == 11 && minor_ver >= 8 ));then
        opt_tag+=("cu118") ; opt_name+=("CUDA‑11.8（推荐）")
        opt_tag+=("cu117") ; opt_name+=("CUDA‑11.7")
    elif (( major_ver == 11 ));then
        opt_tag+=("cu117") ; opt_name+=("CUDA‑11.7（推荐）")
    fi
    # 永远追加CPU选项
    opt_tag+=("cpu") ; opt_name+=("CPU‑版本")

    # 打印动态菜单
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

    # 镜像选择
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

# 处理 requirements.txt，自动过滤torch相关包
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

echo -e "\n================================================================================"
echo "✅ 整套环境搭建完毕"
echo "退出虚拟环境命令：deactivate"
echo "校验GPU：python -c 'import torch;print(torch.cuda.is_available())'"
echo "================================================================================"
