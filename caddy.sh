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

echo -e "${GREEN}--- Caddy 自动化反代工具 ---${NC}"

# 2. 安装/检查 Caddy
if ! command -v caddy &> /dev/null; then
    echo "正在安装 Caddy..."
    apt update && apt install -y debian-keyring debian-archive-keyring apt-transport-https curl > /dev/null 2>&1
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg > /dev/null 2>&1
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null 2>&1
    apt update && apt install caddy -y
fi

# 3. 初始化配置
echo "# Caddy Config Generated" > /etc/caddy/Caddyfile

while true; do
    echo -e "\n${YELLOW}>> 正在配置新站点...${NC}"
    read -p "请输入要绑定的域名 (如 mon.example.com): " DOMAIN
    
    # 强制要求输入，不能为空
    while [[ -z "$BACKEND" ]]; do
        read -p "请输入后端地址和端口 (如 localhost:9090): " BACKEND
        if [[ -z "$BACKEND" ]]; then
            echo -e "${RED}错误: 后端地址不能为空，请重新输入。${NC}"
        fi
    done
    
    # --- 身份认证引导逻辑 ---
    AUTH_CONF=""
    echo -e "\n${YELLOW}[安全建议]${NC}"
    if [[ "$BACKEND" == *"9090"* ]]; then
        echo -e "检测到您输入了 9090 端口，这通常是 Prometheus。"
        echo -e "Prometheus 默认没有登录面板，建议开启 Basic Auth 认证。"
    else
        echo -e "如果后端服务自带登录页面（如 Grafana），则无需开启认证。"
    fi
    
    read -p "是否开启 Basic Auth 访问认证? (y/n, 默认 n): " NEED_AUTH
    NEED_AUTH=${NEED_AUTH:-"n"} 

    if [[ "$NEED_AUTH" == "y" ]]; then
        read -p "请输入用户名: " USERNAME
        read -s -p "请输入密码: " PASSWORD
        echo ""
        HASHED_PASSWORD=$(caddy hash-password --plaintext "$PASSWORD")
        AUTH_CONF="basicauth * {
        $USERNAME $HASHED_PASSWORD
    }"
        echo -e "${GREEN}认证配置已记录。${NC}"
    fi

    # 写入 Caddyfile
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
    
    # 重置 BACKEND 变量以便下一个循环使用
    BACKEND=""
    
    read -p "站点 $DOMAIN 配置完成。是否继续添加下一个域名? (y/n): " CONTINUE
    [[ "$CONTINUE" != "y" ]] && break
done

# 4. 应用配置
echo -e "\n${YELLOW}正在应用配置...${NC}"
caddy fmt --overwrite /etc/caddy/Caddyfile
systemctl restart caddy

if systemctl is-active --quiet caddy; then
    echo -e "${GREEN}--- 配置成功！反向代理已生效 ---${NC}"
else
    echo -e "${RED}启动失败，请检查配置或域名解析。${NC}"
fi
