#!/bin/bash

# 确保以 root 运行
if [ "$EUID" -ne 0 ]; then
  echo "请使用 sudo 运行此脚本"
  exit 1
fi

echo "--- 1. 更新系统并安装关键组件 (增加 dbus 兼容性) ---"
apt update && apt upgrade -y
# 显式安装 dbus-x11 和 x11-xserver-utils 确保环境完整
apt install xfce4 xfce4-goodies xorg dbus-x11 x11-xserver-utils -y

echo "--- 2. 安装 VNC 服务器与 noVNC ---"
apt install tigervnc-standalone-server novnc websockify -y

echo "--- 3. 配置 VNC 访问密码 ---"
VNC_PASS="12345678"
mkdir -p ~/.vnc
echo "$VNC_PASS" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

echo "--- 4. 创建修正后的 VNC 启动脚本 (去掉 & 并增加 dbus) ---"
cat <<EOF > ~/.vnc/xstartup
#!/bin/sh
# 清理环境变量
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# 确保 X 资源加载
[ -r \$HOME/.Xresources ] && xrdb \$HOME/.Xresources

# 关键修正：使用 exec dbus-launch 启动且末尾不加 &
exec dbus-launch --exit-with-session startxfce4
EOF
chmod +x ~/.vnc/xstartup

echo "--- 5. 强制清理并启动 VNC 服务 ---"
# 杀掉残留进程并删除锁文件
vncserver -kill :1 > /dev/null 2>&1
pkill Xvnc > /dev/null 2>&1
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

# 启动 VNC 服务
vncserver :1 -geometry 1280x720 -depth 24

echo "--- 6. 启动 noVNC 网页服务 ---"
pkill websockify > /dev/null 2>&1
# 后台启动 novnc_proxy
nohup websockify --web=/usr/share/novnc/ 6080 localhost:5901 > /dev/null 2>&1 &

echo "--- 7. 配置防火墙 ---"
if command -v ufw > /dev/null; then
    ufw allow 6080/tcp
    ufw reload
fi

echo "-------------------------------------------------------"
echo "安装完成！"
echo "请在浏览器访问：http://$(hostname -I | awk '{print $1}'):6080/vnc.html"
echo ""
echo "连接密码: $VNC_PASS"
echo ""
echo "验证状态:"
vncserver -list
echo "-------------------------------------------------------"
