#!/bin/bash

# 确保以 root 运行
if [ "$EUID" -ne 0 ]; then
  echo "请使用 sudo 运行此脚本"
  exit 1
fi

echo "--- 1. 更新系统并安装 XFCE4 桌面 ---"
apt update && apt upgrade -y
apt install xfce4 xfce4-goodies xorg -y

echo "--- 2. 安装 VNC 服务器与 noVNC (网页端) ---"
# 安装 TigerVNC 和 websockify (noVNC 的桥接工具)
apt install tigervnc-standalone-server novnc websockify -y

echo "--- 3. 配置 VNC 访问密码 ---"
# 设置一个默认密码，你可以运行完脚本后改掉
# 密码必须是 6-8 位
VNC_PASS="12345678"
mkdir -p ~/.vnc
echo "$VNC_PASS" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

echo "--- 4. 创建 VNC 启动脚本 ---"
cat <<EOF > ~/.vnc/xstartup
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
startxfce4 &
EOF
chmod +x ~/.vnc/xstartup

echo "--- 5. 启动 VNC 服务 (显示器 :1) ---"
# 先杀掉可能存在的进程
vncserver -kill :1 > /dev/null 2>&1
# 启动 VNC，默认分辨率 1280x720
vncserver :1 -geometry 1280x720 -depth 24

echo "--- 6. 启动 noVNC 网页服务 ---"
# 杀掉可能存在的 websockify
pkill websockify > /dev/null 2>&1

# 在后台启动 noVNC 监听 6080 端口，连接本地 5901 VNC 端口
# 我们将它设置为开机自启或简单的后台运行
nohup /usr/share/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 6080 > /dev/null 2>&1 &

echo "--- 7. 配置防火墙 ---"
if command -v ufw > /dev/null; then
    ufw allow 6080/tcp
    ufw reload
fi

echo "-------------------------------------------------------"
echo "安装完成！网页控制台已就绪。"
echo "请在浏览器中输入以下地址："
echo "http://$(hostname -I | awk '{print $1}'):6080/vnc.html"
echo ""
echo "连接密码: $VNC_PASS"
echo "提示：建议在云服务器防火墙中开启 6080 端口。"
echo "-------------------------------------------------------"
