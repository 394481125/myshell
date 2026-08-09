#!/bin/bash
#===============================================================================
# 脚本名称：env_auto_install.sh
# 问题修复：cu124源失效，更换官方可用下载地址
# 1.输入虚拟环境名称
# 2.优先检测当前目录同名venv文件夹，存在直接激活
# 3.未找到环境，手动选择 conda / venv 创建全新虚拟环境
# 4.剔除nvidia‑smi输出的竖线特殊符号，正常读取CUDA版本
# 5.只保留官方现存可用的Torch‑CUDA版本，最高cu121作为推荐
# 6.requirements.txt自动过滤torch家族包，防止版本冲突
# 使用方式：curl下载至/tmp临时目录运行，执行结束自动清理脚本
# 注意事项：
#   1.禁止sudo运行，虚拟环境会出现权限异常
#   2.conda模式需要提前装好Miniconda / Anaconda
#   3.venv需要系统安装 python3‑env
#===============================================================================

set +e
clear

echo "================================================================================"
echo "   一站式虚拟环境创建｜可选GPU‑PyTorch版本｜第三方依赖安装脚本"
echo "================================================================================"

# --------------------------1.接收环境名称--------------------------------
read -p "请输入你的项目虚拟环境名称：" env_name
if [[ -z "${env_name}" ]];then
    echo "❌ 环境名称不能为空，脚本退出"
    exit 1
fi
env_act_status=0

# --------------------------2.检测当前目录venv环境------------------------
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

# --------------------------3.读取CUDA、向下兼容版本选择（修复失效源）------------------------
install_torch_gpu(){
    echo -e "\n>>>>>>>>>> 开始检测本机NVIDIA显卡驱动以及最高支持CUDA版本"
    if ! command -v nvidia-smi &> /dev/null;then
        echo "⚠ 没有检测到nvidia‑smi，判定机器无NVIDIA独立显卡"
        echo "▶ 直接安装CPU版本PyTorch"
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
        return
    fi

    # 只提取纯数字版本号，清除竖线、特殊字符
    cuda_version=$(nvidia-smi | grep -i "CUDA Version" | sed 's/[^0-9.]//g')
    echo "✅ 显卡驱动支持最高CUDA版本：${cuda_version}"
    major_ver=$(echo "${cuda_version}" | cut -d '.' -f 1)

    ver_index=0
    declare -A cuda_menu
    menu_str=""

    # A40驱动13.2，向下兼容官方现存可用版本：cu121、cu118、cu117、cpu
    if (( major_ver >= 12 ));then
        ((ver_index++)); cuda_menu[$ver_index]="cu121" ; menu_str+="$ver_index) CUDA‑12.1（最新可用‑推荐）"$'\n'
        ((ver_index++)); cuda_menu[$ver_index]="cu118" ; menu_str+="$ver_index) CUDA‑11.8"$'\n'
        ((ver_index++)); cuda_menu[$ver_index]="cu117" ; menu_str+="$ver_index) CUDA‑11.7"$'\n'
        ((ver_index++)); cuda_menu[$ver_index]="cpu" ; menu_str+="$ver_index) CPU版本"$'\n'
    elif (( major_ver == 11 ));then
        minor_ver=$(echo "${cuda_version}" | cut -d '.' -f 2)
        if (( minor_ver >= 8 ));then
            ((ver_index++)); cuda_menu[$ver_index]="cu118" ; menu_str+="$ver_index) CUDA‑11.8（最适配‑推荐）"$'\n'
            ((ver_index++)); cuda_menu[$ver_index]="cu117" ; menu_str+="$ver_index) CUDA‑11.7"$'\n'
            ((ver_index++)); cuda_menu[$ver_index]="cpu" ; menu_str+="$ver_index) CPU版本"$'\n'
        else
            ((ver_index++)); cuda_menu[$ver_index]="cu117" ; menu_str+="$ver_index) CUDA‑11.7（最适配‑推荐）"$'\n'
            ((ver_index++)); cuda_menu[$ver_index]="cpu" ; menu_str+="$ver_index) CPU版本"$'\n'
        fi
    else
        echo "⚠ 当前显卡驱动CUDA版本较低，仅可选用CPU版PyTorch"
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
        return
    fi

    echo -e "\n请选择你需要安装的PyTorch‑CUDA版本："
    echo "$menu_str"
    read -p "输入序号：" sel_num
    target_cuda=${cuda_menu[$sel_num]}

    if [[ -z "$target_cuda" ]];then
        echo "❌ 无效序号，终止torch安装"
        return
    fi

    echo "▶ 开始安装 $target_cuda 版本 PyTorch"
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/${target_cuda}
    echo -e "\n✅ PyTorch 安装完成"
}

read -p "是否打开显卡版本选择面板、安装PyTorch？(y/n)：" torch_flag
if [[ "${torch_flag}" == "y" || "${torch_flag}" == "Y" ]];then
    install_torch_gpu
fi

# --------------------------4.加载requirements.txt，过滤torch包再安装------------------------
echo -e "\n>>>>>>>>>> 开始检测项目依赖文件"
req_file="./requirements.txt"

if [[ -f "${req_file}" ]];then
    echo "✅ 当前目录找到requirements.txt依赖清单"
    read -p "是否现在安装其余第三方依赖（自动跳过torch系列包）？(y/n)：" install_flag
    if [[ "${install_flag}" == "y" || "${install_flag}" == "Y" ]];then
        echo "▶ 配置清华pip国内镜像源，加速包下载"
        pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
        echo "▶ 过滤 torch、pytorch、torchvision、torchaudio 等依赖开始安装"
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
