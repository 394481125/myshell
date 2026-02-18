#!/usr/bin/env bash

# 定义色彩
BLUE='\033[1;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# 输出美化函数
print_banner() {
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${CYAN}      🛡️  Linux 应急处置/信息搜集/漏洞检测脚本 V3.1${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo -e " ${BLUE}#${NC} 支持系统：Centos, Debian, Ubuntu"
    echo -e " ${BLUE}#${NC} 作者：al0ne"
    echo -e " ${BLUE}#${NC} 更新：2024年4月20日 (UI 美化版)"
    echo -e "${CYAN}----------------------------------------------------------------${NC}"
}

# 格式化打印函数
# $1: 级别 (sec/sub/info/warn/err), $2: 内容, $3: 图标
log_msg() {
    local type=$1
    local msg=$2
    local icon=$3
    case $type in
        "sec") # 主章节
            echo -e "\n${PURPLE}${BOLD}==== $icon $msg ====${NC}"
            echo -e "\n## $icon $msg" >> "$filename"
            ;;
        "sub") # 子标题
            echo -e "${CYAN}--- $icon $msg ---${NC}"
            echo -e "### $icon $msg" >> "$filename"
            ;;
        "info") # 普通信息
            echo -e "${GREEN}[+]${NC} $msg"
            echo -e "$msg" >> "$filename"
            ;;
        "warn") # 警告
            echo -e "${YELLOW}[!] $msg${NC}"
            echo -e "**⚠️ $msg**" >> "$filename"
            ;;
        "err") # 危险/错误
            echo -e "${RED}[×] $msg${NC}"
            echo -e "**🚨 $msg**" >> "$filename"
            ;;
    esac
}

print_code() {
    local content="$1"
    if [ -n "$content" ] && [ "$content" != " " ]; then
        echo -e "${NC}$content"
        echo -e "\`\`\`shell\n$content\n\`\`\`\n" >> "$filename"
    else
        echo -e "${YELLOW}无相关记录${NC}"
        echo -e "*无相关记录*\n" >> "$filename"
    fi
}

# --- 逻辑初始化 ---

# 设置保存文件
ipaddress=$(ip address | grep -oP '(?<=inet )\d+\.\d+\.\d+\.\d+(?=\/2)' | head -n 1)
filename="${ipaddress}_$(hostname)_$(whoami)_$(date +%s)_report.md"

# 覆盖原始 print_msg 以保持兼容
print_msg() {
    echo -e "$1" >> "$filename"
}

reverse_shell_check() {
    local results
    results=$(grep -P '(tftp\s\-i|scp\s|sftp\s|bash\s\-i|nc\s\-e|sh\s\-i|wget\s|curl\s|\bexec|/dev/tcp/|/dev/udp/)' "$1" "$2" "$3" 2>/dev/null)
    if [ -n "$results" ]; then
        log_msg "err" "发现疑似反弹跳板命令!" "🧨"
        print_code "$results"
    fi
    results=$(grep -P '(useradd|groupadd|chattr|fsockopen|socat|base64|socket|perl|openssl)' "$1" "$2" "$3" 2>/dev/null)
    if [ -n "$results" ]; then
        log_msg "warn" "发现敏感系统命令调用" "🛠️"
        print_code "$results"
    fi
}

# --- 执行开始 ---

clear
print_banner

# 1. 环境检查
log_msg "sec" "环境检测" "🌍"
if [ "$UID" -ne 0 ]; then
    log_msg "err" "请使用 root 权限运行！" "🚫"
    exit 1
else
    log_msg "info" "当前为 root 权限，检查继续..." "✅"
fi

# 操作系统识别
OS='None'
if [ -e "/etc/os-release" ]; then
    source /etc/os-release
    case ${ID} in
    "debian" | "ubuntu" | "devuan") OS='Debian' ;;
    "centos" | "rhel" | "fedora") OS='Centos' ;;
    *) ;;
    esac
fi

if [ "$OS" = 'None' ]; then
    if command -v apt-get >/dev/null 2>&1; then OS='Debian'
    elif command -v yum >/dev/null 2>&1; then OS='Centos'
    else
        log_msg "err" "不支持的操作系统类型" "❌"
        exit 1
    fi
fi
log_msg "info" "检测到系统架构: $OS" "🖥️"

# 安装工具 (静默美化)
cmdline=("net-tools" "telnet" "nc" "wget" "lsof" "tcpdump")
for prog in "${cmdline[@]}"; do
    if ! command -v "$prog" >/dev/null 2>&1; then
        echo -ne "${YELLOW}[*] 正在准备必备工具: $prog...${NC}\r"
        if [ "$OS" = 'Centos' ]; then
            yum install -y "$prog" >/dev/null 2>&1
        else
            apt install -y "$prog" >/dev/null 2>&1
        fi
    fi
done
echo -e "\n${GREEN}[+] 基础工具环境检查完成!${NC}"

base_check() {
    log_msg "sec" "基础配置检查" "📊"
    
    log_msg "sub" "系统核心信息" "📋"
    echo -e "${BOLD}USER:${NC}       $(whoami)"
    echo -e "${BOLD}OS Version:${NC} $(uname -r)"
    echo -e "${BOLD}Hostname:${NC}   $(hostname -s)"
    echo -e "${BOLD}Uptime:${NC}     $(uptime | awk -F ',' '{print $1}')"
    echo -e "${BOLD}CPU Model:${NC}  $(grep -m 1 'model name' /proc/cpuinfo | awk -F: '{print $2}')"
    
    # 写入MD
    print_msg "**USER:** $(whoami)  \n**OS:** $(uname -a)  \n**IP:** ${ipaddress}"

    log_msg "sub" "资源占用情况" "📈"
    print_code "$(free -mh)"
    print_code "$(df -mh | grep -E 'Filesystem|/dev/')"

    log_msg "sub" "Hosts 配置" "🏠"
    print_code "$(grep -v "#" /etc/hosts)"
}

process_check() {
    log_msg "sec" "进程信息检查" "🚀"

    log_msg "sub" "CPU 占用 TOP 10" "🔥"
    print_code "$(ps aux --sort=-pcpu | head -n 11)"

    log_msg "sub" "内存占用 TOP 10" "🧠"
    print_code "$(ps aux --sort=-pmem | head -n 11)"

    log_msg "sub" "反弹 Shell 进程扫描" "🕵️"
    local tcp_reverse
    tcp_reverse=$(ps -ef | grep -P 'sh -i' | grep -v 'grep')
    if [ -n "$tcp_reverse" ]; then
        log_msg "err" "检测到活跃的反弹 Shell 进程!" "🚨"
        print_code "$tcp_reverse"
    else
        log_msg "info" "未发现已知反弹 Shell 特征" "🛡️"
    fi
}

network_check() {
    log_msg "sec" "网络与流量检查" "🌐"

    log_msg "sub" "监听端口" "👂"
    print_code "$(netstat -tulpen | grep -P 'tcp|udp')"

    log_msg "sub" "外部网络连接 (ESTABLISHED)" "🔗"
    print_code "$(netstat -antop | grep ESTABLISHED)"

    log_msg "sub" "DNS 服务器" "🔍"
    print_code "$(grep 'nameserver' /etc/resolv.conf)"

    log_msg "sub" "防火墙策略" "🧱"
    print_code "$(iptables -L -n --line-numbers | head -n 20)"
}

crontab_check() {
    log_msg "sec" "任务计划检查" "⏰"
    log_msg "sub" "当前用户 Cron" "👤"
    print_code "$(crontab -l 2>/dev/null | grep -v '#')"
    
    log_msg "sub" "系统级 Cron 目录" "📂"
    print_code "$(ls -alht /etc/cron.*/* 2>/dev/null | head -n 15)"

    log_msg "sub" "计划任务后门特征扫描" "🔎"
    reverse_shell_check /etc/cron*
}

user_check() {
    log_msg "sec" "用户信息检查" "👤"
    log_msg "sub" "可登录账号" "🔑"
    print_code "$(cat /etc/passwd | egrep -v 'nologin$|false$')"

    log_msg "sub" "特权账号 (UID 0)" "👑"
    local superusers
    superusers=$(cat /etc/passwd | awk -F ':' '$3==0' | grep -v '^root:')
    if [ -n "$superusers" ]; then
        log_msg "err" "发现非 root 的特权账号!" "☢️"
        print_code "$superusers"
    else
        log_msg "info" "未发现异常特权账号" "✅"
    fi

    log_msg "sub" "当前登录 & 最近登录" "📅"
    print_code "$(who)"
    print_code "$(last -n 10)"
}

file_check() {
    log_msg "sec" "文件与后门检查" "📁"
    
    log_msg "sub" "敏感文件修改时间" "🕒"
    local cmdline=("/bin/ls" "/bin/ps" "/bin/netstat" "/usr/sbin/sshd" "/etc/passwd")
    for soft in "${cmdline[@]}"; do
        [ -f "$soft" ] && echo -e "${CYAN}[$soft]${NC} \t $(stat "$soft" | grep -P -o '(?<=Modify: )[\d-\s:]+')"
    done

    log_msg "sub" "隐藏文件扫描 (...)" "👻"
    print_code "$(find / ! -path "/proc/*" ! -path "/sys/*" ! -path "/run/*" -name ".*." 2>/dev/null)"

    log_msg "sub" "临时目录可执行文件" "📦"
    print_code "$(ls -alht /tmp /var/tmp /dev/shm 2>/dev/null | head -n 20)"

    log_msg "sub" "最近 7 天变动文件" "🆕"
    print_code "$(find /etc /bin /sbin /usr/bin /usr/sbin -mtime -7 -type f 2>/dev/null | head -n 20)"
}

rootkit_check() {
    log_msg "sec" "Rootkit 深度检查" "🛡️"
    log_msg "sub" "内核模块检查" "🧠"
    local kernel
    kernel=$(grep -E 'hide_tcp4_port|diamorphine|module_hide|hacked_getdents' /proc/kallsyms 2>/dev/null)
    if [ -n "$kernel" ]; then
        log_msg "err" "发现内核敏感函数，疑似 Rootkit 已加载!" "💀"
        print_code "$(echo "$kernel" | head -n 5)"
    else
        log_msg "info" "未发现明显内核级 Rootkit 特征" "✅"
    fi
}

ssh_check() {
    log_msg "sec" "SSH 安全检查" "🔐"
    log_msg "sub" "SSH 登录失败统计 (TOP 10)" "🚫"
    if [ "$OS" = 'Centos' ]; then
        print_code "$(grep -i 'authentication failure' /var/log/secure 2>/dev/null | awk '{print $14}' | cut -d= -f2 | sort | uniq -c | sort -nr | head -n 10)"
    else
        print_code "$(grep -i 'authentication failure' /var/log/auth.log 2>/dev/null | awk '{print $14}' | cut -d= -f2 | sort | uniq -c | sort -nr | head -n 10)"
    fi

    log_msg "sub" "SSH Authorized Keys" "🔑"
    [ -s "/root/.ssh/authorized_keys" ] && print_code "$(cat /root/.ssh/authorized_keys)" || log_msg "info" "Root 无 SSH 授权密钥" "ℹ️"
}

webshell_check() {
    log_msg "sec" "Webshell 静态查杀" "🕸️"
    log_msg "info" "查杀目录: $webpath" "📂"
    # 这里保持原有的逻辑，仅美化输出
    local results
    results=$(grep -P -i -r -l 'eval\(|base64_decode\(|shell_exec\(|passthru\(|system\(|phpinfo\(' "$webpath" --include='*.php*' 2>/dev/null | head -n 20)
    if [ -n "$results" ]; then
        log_msg "warn" "发现疑似 PHP 风险文件" "☣️"
        print_code "$results"
    else
        log_msg "info" "未发现已知静态 Webshell 特征" "✅"
    fi
}

miner_check() {
    log_msg "sec" "挖矿木马专项检查" "💎"
    log_msg "sub" "挖矿进程/配置扫描" "⛏️"
    local miner
    miner=$(ps aux | grep -P "xmrig|xmr-stak|minerd|hashvault|ddgs|stratum" | grep -v 'grep')
    if [ -n "$miner" ]; then
        log_msg "err" "发现疑似挖矿进程!" "💰"
        print_code "$miner"
    else
        log_msg "info" "未检测到活跃挖矿程序" "✅"
    fi
}

risk_check() {
    log_msg "sec" "高风险服务检查" "⚠️"
    log_msg "sub" "Redis 弱密码/配置" "💾"
    if [ -f "/etc/redis/redis.conf" ]; then
        local redis_risk
        redis_risk=$(grep -P 'requirepass (123|root|admin|password)' /etc/redis/redis.conf)
        [ -n "$redis_risk" ] && log_msg "err" "Redis 存在弱密码配置!" "🔓"
    fi
    
    log_msg "sub" "JDWP/调试端口检查" "🐛"
    local jdwp
    jdwp=$(ps aux | grep -P 'jdwp' | grep -v 'grep')
    if [ -n "$jdwp" ]; then
        log_msg "warn" "发现活跃的 JDWP 调试进程" "⚙️"
        print_code "$jdwp"
    fi
}

docker_check() {
    if command -v docker >/dev/null 2>&1; then
        log_msg "sec" "Docker 容器环境" "🐳"
        log_msg "sub" "运行中的容器" "📦"
        print_code "$(docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}")"
    fi
}

# --- 主程序执行 ---
base_check
process_check
network_check
crontab_check
user_check
file_check
rootkit_check
ssh_check
webshell_check
miner_check
risk_check
docker_check

echo -e "\n${GREEN}================================================================${NC}"
echo -e "${BOLD} ✨ 检查完成!${NC}"
echo -e " 📝 报告已生成: ${CYAN}$filename${NC}"
echo -e "${GREEN}================================================================${NC}"

# 上传报告逻辑保持不变
if [[ -n $webhook_url && $webhook_url != "http://localhost:5000/upload" ]]; then
    echo -e "${YELLOW}[*] 正在上传报告...${NC}"
    curl -s -X POST -F "file=@$filename" "$webhook_url" > /dev/null
fi
