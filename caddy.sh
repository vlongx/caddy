#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. 环境检查
[[ "$(id -u)" != "0" ]] && echo -e "${RED}错误: 请使用 root 权限运行。${NC}" && exit 1

# 强制将标准输入重定向到当前终端，彻底解决“无效选项”循环
exec < /dev/tty

# 菜单函数
show_menu() {
    echo -e "${GREEN}=================================${NC}"
    echo -e "${GREEN}   Caddy 反代一键管理脚本       ${NC}"
    echo -e "${GREEN}=================================${NC}"
    echo -e "1. 添加/修改 反代配置 (HTTPS)"
    echo -e "2. 添加/修改 反代配置 (仅 HTTP - 无证书)"
    echo -e "3. 查看当前所有配置域名"
    echo -e "4. 重启 Caddy 服务"
    echo -e "5. 卸载 Caddy"
    echo -e "0. 退出脚本"
    echo -e "${GREEN}=================================${NC}"
    read -p "请输入选项 [0-5]: " choice
}

# 安装 Caddy
install_caddy() {
    if ! command -v caddy &> /dev/null; then
        echo -e "${YELLOW}正在安装 Caddy...${NC}"
        apt update && apt install -y debian-keyring debian-archive-keyring apt-transport-https curl > /dev/null 2>&1
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg > /dev/null 2>&1
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null 2>&1
        apt update && apt install caddy -y
    fi
}

# 添加配置
add_config() {
    local MODE=$1  # HTTPS 或 HTTP
    install_caddy
    
    read -p "请输入要绑定的域名 (如 g.gzus.cc): " DOMAIN
    read -p "请输入后端地址和端口 (如 localhost:3000): " BACKEND
    [[ -z "$DOMAIN" || -z "$BACKEND" ]] && echo -e "${RED}错误: 输入不能为空。${NC}" && return

    # 处理 Prometheus 逻辑
    local AUTH_BLOCK=""
    if [[ "$BACKEND" == *"9090"* ]]; then
        read -p "检测到 Prometheus，是否开启认证? (y/n): " NEED_AUTH
        if [[ "$NEED_AUTH" == "y" ]]; then
            read -p "用户名: " USERNAME
            read -s -p "密码: " PASSWORD; echo ""
            local HASHED_PWD=$(caddy hash-password --plaintext "$PASSWORD")
            AUTH_BLOCK=$(printf "    basicauth * {\n        %s %s\n    }" "$USERNAME" "$HASHED_PWD")
        fi
    fi

    # 确定站点标记 (如果是 HTTP 模式，在域名后加 :80)
    local SITE_NAME=$DOMAIN
    [[ "$MODE" == "HTTP" ]] && SITE_NAME="http://$DOMAIN"

    # 写入配置
    printf "\n%s {\n" "$SITE_NAME" >> /etc/caddy/Caddyfile
    [[ -n "$AUTH_BLOCK" ]] && printf "%s\n" "$AUTH_BLOCK" >> /etc/caddy/Caddyfile
    printf "    reverse_proxy %s {\n        header_up Host {host}\n        header_up X-Real-IP {remote_host}\n    }\n" "$BACKEND" >> /etc/caddy/Caddyfile
    printf "    encode gzip\n}\n" >> /etc/caddy/Caddyfile

    caddy fmt --overwrite /etc/caddy/Caddyfile > /dev/null 2>&1
    systemctl restart caddy
    
    if systemctl is-active --quiet caddy; then
        echo -e "${GREEN}✅ 配置已应用！访问地址: ${SITE_NAME}${NC}"
        [[ "$MODE" == "HTTPS" ]] && echo -e "${YELLOW}注: 若 SSL 报错，请检查 80 端口放行及 DNS 解析。${NC}"
    fi
}

# 脚本逻辑
while true; do
    show_menu
    case $choice in
        1) add_config "HTTPS" ;;
        2) add_config "HTTP" ;;
        3) [[ -f /etc/caddy/Caddyfile ]] && grep "{" /etc/caddy/Caddyfile || echo "无配置" ;;
        4) systemctl restart caddy ;;
        5) systemctl stop caddy && apt purge caddy -y && rm -rf /etc/caddy ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
    esac
done
