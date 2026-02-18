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

echo "--- 3. 配置 XFCE 启动脚本 ---"
# 备份并修改 startwm.sh
cp /etc/xrdp/startwm.sh /etc/xrdp/startwm.sh.bak
# 注释掉默认的 Xsession 启动行
sed -i 's/^test -x \/etc\/X11\/Xsession \&\& exec \/etc\/X11\/Xsession/# &/' /etc/xrdp/startwm.sh
sed -i 's/^exec \/bin\/sh \/etc\/X11\/Xsession/# &/' /etc/xrdp/startwm.sh

# 确保启动的是 xfce4
if ! grep -q "startxfce4" /etc/xrdp/startwm.sh; then
    echo "startxfce4" >> /etc/xrdp/startwm.sh
fi

echo "--- 4. 解决 XFCE 锁屏与权限弹窗问题 (RDP 优化) ---"
# 禁用某些在远程桌面下会导致黑屏或卡顿的特性（如电源管理）
# 修复“需要身份验证才能创建色彩管理设备”的弹窗
cat <<EOF > /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF

echo "--- 5. 设置防火墙与重启服务 ---"
if command -v ufw > /dev/null; then
    ufw allow 3389/tcp
    ufw reload
fi

systemctl restart xrdp
systemctl enable xrdp

echo "-------------------------------------------------------"
echo "安装完成！"
echo "【关键操作】为了让分辨率自适应，请在 Windows 远程桌面连接时："
echo " 1. 点击 '显示选项' -> '显示' 选项卡。"
echo " 2. 在 '显示配置' 中，将滑块拉到最右侧 (全屏)。"
echo " 3. 勾选 '在所有监视器上使用我的所有显示器' (可选)。"
echo " 4. 连接后，如果你调整远程窗口大小，Ubuntu 会自动适配。"
echo "-------------------------------------------------------"