#!/bin/bash
#===============================================================================
# 修复：废弃老旧whl源，改用pytorch官方自动识别安装方式
# 1.输入虚拟环境名称
# 2.优先读取本地venv文件夹，存在直接激活
# 3.不存在则选择conda / venv新建环境
# 4.读取CUDA版本、展示兼容版本，仅做提示，使用官方命令安装
# 5.requirements.txt自动过滤torch包
#===============================================================================

set +e
clear

echo "================================================================================"
echo "   一站式虚拟环境创建｜可选GPU‑PyTorch版本｜第三方依赖安装脚本"
echo "================================================================================"

read -p "请输入你的项目虚拟环境名称：" env_name
if [[ -z "${env_name}" ]];then
    echo "❌ 环境名称不能为空，脚本退出"
    exit 1
fi
env_act_status=0

# 检测当前目录venv
if [[ -d "./${env_name}" ]];then
    echo -e "\n✅ 在当前文件夹检测到venv环境：${env_name}"
    source ./${env_name}/bin/activate
    env_act_status=1
    echo "✅ venv虚拟环境激活成功"
else
    echo -e "\n⚠ 当前目录未检索到名为【${env_name}】的venv环境"
    echo "请选择需要创建的虚拟环境类型"
    echo "    1 = Conda 虚拟环境（深度学习项目推荐）"
    echo "    2 = Python原生venv轻量虚拟环境"
    read -p "输入序号1或者2：" sel_type

    if [[ "${sel_type}" == "1" ]];then
        if ! command -v conda &> /dev/null;then
            echo "❌ 本机未检测到conda，请先安装Miniconda或Anaconda"
            exit 1
        fi
        read -p "请指定环境Python版本，回车默认3.10：" py_version
        py_version=${py_version:-3.10}

        if conda env list | grep -w "${env_name}";then
            echo "⚠ conda环境${env_name}已经存在，直接进行激活"
        else
            echo "▶ 正在新建conda环境：${env_name} Python${py_version}"
            conda create -n "${env_name}" python="${py_version}" -y
        fi
        eval "$(conda shell.bash hook)"
        conda activate "${env_name}"
        env_act_status=1
        echo "✅ Conda虚拟环境激活成功"

    elif [[ "${sel_type}" == "2" ]];then
        if ! python3 -m venv --help &> /dev/null;then
            echo "❌ 系统缺少venv组件，Ubuntu执行：apt install python3-env"
            exit 1
        fi
        python3 -m venv "${env_name}"
        source ./${env_name}/bin/activate
        env_act_status=1
        echo "✅ 全新venv环境创建并激活成功"
    else
        echo "❌ 输入选项非法，脚本终止"
        exit 1
    fi
fi

if [[ ${env_act_status} -ne 1 ]];then
    echo "❌ 虚拟环境激活失败，程序退出"
    exit 1
fi

# PyTorch安装函数
install_torch_gpu(){
    echo -e "\n>>>>>>>>>> 开始检测本机NVIDIA显卡驱动以及最高支持CUDA版本"
    if ! command -v nvidia-smi &> /dev/null;then
        echo "⚠ 没有检测到nvidia‑smi，判定机器无NVIDIA独立显卡，安装CPU版本"
        pip install torch torchvision torchaudio
        return
    fi

    # 清洗CUDA版本
    cuda_version=$(nvidia-smi | grep -i "CUDA Version" | sed 's/[^0-9.]//g')
    echo "✅ 显卡驱动支持最高CUDA版本：${cuda_version}"
    echo "当前显卡向下兼容：CUDA‑12.1、CUDA‑11.8、CUDA‑11.7"
    echo "1) CUDA‑12.1（推荐，适配你的A40显卡）"
    echo "2) CUDA‑11.8"
    echo "3) CUDA‑11.7"
    echo "4) CPU‑版本"
    read -p "输入序号选择版本：" sel_num

    case $sel_num in
        1)
            echo "▶ 安装适配CUDA‑12.1的GPU版PyTorch"
            pip install torch torchvision torchaudio
            ;;
        2)
            echo "▶ 安装CUDA‑11.8版本PyTorch"
            pip install torch==2.4.0+cu118 torchvision==0.19.0+cu118 torchaudio==2.4.0 --index-url https://download.pytorch.org/whl/cu118
            ;;
        3)
            echo "▶ 安装CUDA‑11.7版本PyTorch"
            pip install torch==1.13.1+cu117 torchvision==0.14.1+cu117 torchaudio==0.13.1 --index-url https://download.pytorch.org/whl/cu117
            ;;
        4)
            echo "▶ 安装CPU版本PyTorch"
            pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
            ;;
        *)
            echo "❌ 无效序号，跳过torch安装"
            return
            ;;
    esac

    echo -e "\n✅ PyTorch 安装命令执行完毕"
}

read -p "是否打开显卡版本选择面板、安装PyTorch？(y/n)：" torch_flag
if [[ "${torch_flag}" == "y" || "${torch_flag}" == "Y" ]];then
    install_torch_gpu
fi

# 处理requirements.txt
echo -e "\n>>>>>>>>>> 开始检测项目依赖文件"
req_file="./requirements.txt"

if [[ -f "${req_file}" ]];then
    echo "✅ 当前目录找到requirements.txt依赖清单"
    read -p "是否现在安装其余第三方依赖（自动跳过torch系列包）？(y/n)：" install_flag
    if [[ "${install_flag}" == "y" || "${install_flag}" == "Y" ]];then
        echo "▶ 配置清华pip国内镜像源，加速包下载"
        pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
        grep -ivE 'torch|pytorch' "${req_file}" > /tmp/clean_req.txt
        pip install -r /tmp/clean_req.txt
        rm -f /tmp/clean_req.txt
        echo -e "\n✅ 除去PyTorch相关包以外的第三方依赖安装完成"
    else
        echo "▶ 用户跳过依赖安装步骤"
    fi
else
    echo "⚠ 当前文件夹没有找到requirements.txt，跳过依赖安装"
fi

echo -e "\n================================================================================"
echo "✅ 整套环境部署流程执行完毕，当前已经处于虚拟环境内部"
echo "退出环境输入命令：deactivate"
echo "================================================================================"
