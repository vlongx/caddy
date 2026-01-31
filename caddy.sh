#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. 环境检查
if [ "$(id -u)" != "0" ]; then
   echo -e "${RED}错误: 请使用 root 权限运行此脚本。${NC}"
   exit 1
fi

# 菜单函数 - 使用 /dev/tty 获取输入
show_menu() {
    echo -e "${GREEN}=================================${NC}"
    echo -e "${GREEN}   Caddy 反代一键管理脚本       ${NC}"
    echo -e "${GREEN}=================================${NC}"
    echo -e "1. 添加/修改 反代配置"
    echo -e "2. 查看当前所有配置域名"
    echo -e "3. 重启 Caddy 服务"
    echo -e "4. 卸载 Caddy"
    echo -e "0. 退出脚本"
    echo -e "${GREEN}=================================${NC}"
    # 核心修复：从终端读取输入
    read -p "请输入选项 [0-4]: " choice < /dev/tty
}

# 安装 Caddy
install_caddy() {
    if ! command -v caddy &> /dev/null; then
        echo -e "${YELLOW}正在安装 Caddy...${NC}"
        apt update && apt install -y debian-keyring debian-archive-keyring apt-transport-https curl > /dev/null 2>&1
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg > /dev/null 2>&1
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null 2>&1
        apt update && apt install caddy -y || echo -e "${YELLOW}初始启动跳过...${NC}"
    fi
}

# 添加配置
add_config() {
    install_caddy
    while true; do
        echo -e "\n${YELLOW}>> 正在配置新站点...${NC}"
        read -p "请输入要绑定的域名 (如 mon.example.com): " DOMAIN < /dev/tty
        
        BACKEND=""
        while [[ -z "$BACKEND" ]]; do
            read -p "请输入后端地址和端口 (如 localhost:9090): " BACKEND < /dev/tty
            [[ -z "$BACKEND" ]] && echo -e "${RED}错误: 后端地址不能为空。${NC}"
        done
        
        AUTH_CONF=""
        if [[ "$BACKEND" == *"9090"* ]]; then
            echo -e "${YELLOW}[建议] 检测到 Prometheus (9090)，建议开启认证。${NC}"
        fi
        
        read -p "是否开启 Basic Auth 认证? (y/n, 默认 n): " NEED_AUTH < /dev/tty
        if [[ "${NEED_AUTH:-n}" == "y" ]]; then
            read -p "请输入用户名: " USERNAME < /dev/tty
            read -s -p "请输入密码: " PASSWORD < /dev/tty; echo ""
            HASHED_PASSWORD=$(caddy hash-password --plaintext "$PASSWORD")
            AUTH_CONF="basicauth * {
                $USERNAME $HASHED_PASSWORD
            }"
        fi

        cat <<EOF >> /etc/caddy/Caddyfile
$DOMAIN {
    $AUTH_CONF
    reverse_proxy $BACKEND {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
    }
    encode gzip
}
EOF
        read -p "配置完成。是否继续添加下一个域名? (y/n): " CONTINUE < /dev/tty
        [[ "$CONTINUE" != "y" ]] && break
    done

    caddy fmt --overwrite /etc/caddy/Caddyfile
    systemctl restart caddy
    echo -e "${GREEN}配置已生效！${NC}"
}

# 列表、重启、卸载函数保持不变，但 read 加 < /dev/tty
list_configs() {
    if [ -f /etc/caddy/Caddyfile ]; then
        echo -e "${YELLOW}当前已配置的域名如下：${NC}"
        grep -E '^[a-zA-Z0-9.-]+ \{' /etc/caddy/Caddyfile | sed 's/ {//g'
    else
        echo -e "${RED}未找到 Caddyfile 配置文件。${NC}"
    fi
}

uninstall_caddy() {
    read -p "确定要卸载 Caddy 并删除所有配置吗? (y/n): " confirm < /dev/tty
    if [[ "$confirm" == "y" ]]; then
        systemctl stop caddy
        apt purge -y caddy
        rm -rf /etc/caddy
        echo -e "${GREEN}Caddy 已彻底卸载。${NC}"
    fi
}

# 脚本主逻辑
# 针对 curl 直接运行的引导
if ! command -v caddy &> /dev/null; then
    echo -e "${YELLOW}检测到未安装 Caddy，直接进入安装配置流程...${NC}"
    add_config
fi

while true; do
    show_menu
    case $choice in
        1) add_config ;;
        2) list_configs ;;
        3) systemctl restart caddy && echo -e "${GREEN}重启成功${NC}" ;;
        4) uninstall_caddy ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选项: $choice ${NC}" ;;
    esac
done
