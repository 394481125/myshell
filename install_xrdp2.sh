#!/bin/bash

# 确保脚本以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请使用 sudo 运行此脚本"
  exit 1
fi

echo "--- 1. 更新系统并安装 XFCE4 和 xRDP ---"
apt update && apt upgrade -y
# xorgxrdp 是实现自适应分辨率的关键
apt install xfce4 xfce4-goodies xorg xrdp xorgxrdp -y

echo "--- 2. 配置 xRDP 以支持动态分辨率调整 ---"
# 修改 xrdp.ini 允许动态调整分辨率
# 确保 ResizeSession 为 true (通常默认是 true，但显式设置更稳妥)
sed -i 's/#ls_title=My Remote Desktop/ls_title=Ubuntu-XFCE-Remote/g' /etc/xrdp/xrdp.ini

# 强制开启自适应分辨率相关的配置
if grep -q "ResizeSession" /etc/xrdp/xrdp.ini; then
    sed -i 's/ResizeSession=false/ResizeSession=true/g' /etc/xrdp/xrdp.ini
else
    echo "ResizeSession=true" >> /etc/xrdp/xrdp.ini
fi

echo "--- 3. 配置防火墙 (开放 3389 端口) ---"
if command -v ufw > /dev/null; then
    ufw allow 3389/tcp
    ufw reload
    echo "防火墙规则已更新："
    ufw status | grep 3389
else
    echo "未检测到 ufw 防火墙，跳过此步骤。"
fi

echo "--- 4. 配置 xRDP 启动脚本 ---"
# 备份原始配置文件
cp /etc/xrdp/startwm.sh /etc/xrdp/startwm.sh.bak

# 使用 sed 注释掉原有的最后两行，并添加 startxfce4
# 逻辑：匹配包含 Xsession 的行并在行首添加 #
sed -i 's/^test -x \/etc\/X11\/Xsession \&\& exec \/etc\/X11\/Xsession/# &/' /etc/xrdp/startwm.sh
sed -i 's/^exec \/bin\/sh \/etc\/X11\/Xsession/# &/' /etc/xrdp/startwm.sh

# 在文件末尾添加启动命令（如果不存在的话）
if ! grep -q "startxfce4" /etc/xrdp/startwm.sh; then
    echo "startxfce4" >> /etc/xrdp/startwm.sh
fi

echo "--- 5. 重启 xRDP 并设置开机自启 ---"
systemctl restart xrdp
systemctl enable xrdp

echo "--- 6. 检查服务状态 ---"
systemctl status xrdp --no-pager

echo "-------------------------------------------------------"
echo "安装完成！"
echo "现在你可以使用 Windows 远程桌面连接 (RDP) 访问此服务器。"
echo "服务器 IP: $(hostname -I | awk '{print $1}')"
echo "端口: 3389"
echo "提示：如果连接后出现黑屏，请确保已注销该用户的本地登录会话。"
echo "-------------------------------------------------------"