#!/bin/bash
# Caddy One-key by vlongx

# 1. 快速安装与预处理
if ! command -v caddy &> /dev/null; then
    echo "正在安装 Caddy..."
    apt update && apt install -y debian-keyring debian-archive-keyring apt-transport-https curl >/dev/null 2>&1
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg >/dev/null 2>&1
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null 2>&1
    apt update && apt install caddy -y >/dev/null 2>&1
    # 初始安装后清空默认页，防止冲突
    echo ":80" > /etc/caddy/Caddyfile
    systemctl restart caddy
fi

# 2. 交互配置
read -p "域名: " DOMAIN
while [[ -z "$BACKEND" ]]; do
    read -p "后端地址(IP:端口): " BACKEND
done

# 3. Prometheus 安全加固
AUTH_CONF=""
if [[ "$BACKEND" == *"9090"* ]]; then
    echo -e "\033[33m建议开启 Prometheus 身份认证\033[0m"
    read -p "开启? (y/n, 默认n): " NEED_AUTH
    if [[ "${NEED_AUTH:-n}" == "y" ]]; then
        read -p "用户名: " USERNAME
        read -s -p "密码: " PASSWORD; echo ""
        HASHED_PWD=$(caddy hash-password --plaintext "$PASSWORD")
        AUTH_CONF="basicauth * { $USERNAME $HASHED_PWD }"
    fi
fi

# 4. 写入配置 (使用覆盖+格式化)
cat <<EOF > /etc/caddy/Caddyfile
$DOMAIN {
    $AUTH_CONF
    reverse_proxy $BACKEND {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
    }
}
EOF

caddy fmt --overwrite /etc/caddy/Caddyfile
systemctl reload caddy || systemctl restart caddy

# 5. 结果检查
if systemctl is-active --quiet caddy; then
    echo -e "\033[32m✅ 配置成功: https://$DOMAIN\033[0m"
else
    echo -e "\033[31m❌ 启动失败！请确保域名 $DOMAIN 已解析到此 IP。\033[0m"
    journalctl -u caddy --no-pager | tail -n 5
fi
