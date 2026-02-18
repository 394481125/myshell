#!/bin/bash

# 确保脚本以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请使用 sudo 运行此脚本"
  exit 1
fi

echo "--- 1. 开始更新系统软件包 ---"
apt update && apt upgrade -y

echo "--- 2. 安装 Xorg 和 XFCE4 桌面环境 ---"
# 安装 xorg, xfce4 以及相关增强组件
apt install xfce4 xfce4-goodies xorg -y

echo "--- 3. 安装 xRDP 服务 ---"
apt install xrdp xorgxrdp -y

echo "--- 4. 配置防火墙 (开放 3389 端口) ---"
if command -v ufw > /dev/null; then
    ufw allow 3389/tcp
    ufw reload
    echo "防火墙规则已更新："
    ufw status | grep 3389
else
    echo "未检测到 ufw 防火墙，跳过此步骤。"
fi

echo "--- 5. 配置 xRDP 启动脚本 ---"
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

echo "--- 6. 重启 xRDP 并设置开机自启 ---"
systemctl restart xrdp
systemctl enable xrdp

echo "--- 7. 检查服务状态 ---"
systemctl status xrdp --no-pager

echo "-------------------------------------------------------"
echo "安装完成！"
echo "现在你可以使用 Windows 远程桌面连接 (RDP) 访问此服务器。"
echo "服务器 IP: $(hostname -I | awk '{print $1}')"
echo "端口: 3389"
echo "提示：如果连接后出现黑屏，请确保已注销该用户的本地登录会话。"
echo "-------------------------------------------------------"