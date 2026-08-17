# MyShell

Linux 服务一键配置工具。

### 一键 交互式的 Swap (虚拟内存) 管理脚本
> 适用场景： Swap 状态和内存使用情况增加虚拟内存。
```bash
curl -sSL "https://raw.githubusercontent.com/394481125/myshell/main/add_swap.sh" -o /tmp/add_swap.sh && sudo bash /tmp/add_swap.sh && rm -f /tmp/add_swap.sh
```

### 一键 xrdp 服务安装
> 适用场景：Windows 自带远程桌面连接。
```bash
curl -sSL https://raw.githubusercontent.com/394481125/myshell/main/install_xrdp.sh | sudo bash
```

### 一键noVNC 服务安装
> 适用场景：通过 Web 浏览器访问桌面。
```bash
curl -sSL https://raw.githubusercontent.com/394481125/myshell/main/install_web_desktop.sh | sudo bash
```

### 一键FRP服务端安装
> 适用场景：通过内网穿透外网访问内网。
```bash
curl -sSL https://raw.githubusercontent.com/394481125/myshell/main/install_frp_server.sh | sudo bash
```

### 一键查看系统信息
> 适用场景：查看Ubuntu系统信息。
```bash
curl -sSL https://raw.githubusercontent.com/394481125/myshell/main/check_info_pretty.sh | sudo bash
```

### 一键查看系统日志
> 适用场景：查看Ubuntu系统日志。
```bash
curl -sSL https://raw.githubusercontent.com/394481125/myshell/main/check_logs_pretty.sh | sudo bash
```

### 一键查看CPU&GPU详情
> 适用场景：查看CPU&GPU详情。
```bash
curl -sSL https://raw.githubusercontent.com/394481125/myshell/main/check_core_pretty.sh | sudo bash
```

### 一键查看谁在用GPU详情
> 适用场景：一键查看谁在用GPU详情。
```bash
curl -sSL https://raw.githubusercontent.com/394481125/myshell/main/check_gpu_all.sh | sudo bash
```

### 一键安装torch-gpu还有requirements
> 适用场景：一键安装环境。
```bash
curl -sSL "https://raw.githubusercontent.com/394481125/myshell/main/install_env_auto.sh" -o /tmp/install_env_auto.sh && bash /tmp/install_env_auto.sh && rm -f /tmp/install_env_auto.sh
```

### 一键部署 changedetection.io 网页监控服务
> 适用场景：一键部署全功能网页变动监控与告警平台（含无头 Chrome 浏览器，支持 JS 动态网页抓取、可视化选择与截图对比），内置交互式菜单支持启动、停止、重启、查看实时日志、一键升级及卸载。首次运行后可直接输入 `cdio` 管理。

```bash
curl -sSL "https://raw.githubusercontent.com/394481125/myshell/main/install_changedetection.sh" -o /tmp/install_changedetection.sh && sudo bash /tmp/install_changedetection.sh && rm -f /tmp/install_changedetection.sh

### 常用 Git 命令
- **提交代码**：
```bash
git add . && git commit -m "update" && git push
```
