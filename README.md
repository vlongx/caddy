# Caddy 反代一键配置工具 (Caddy Proxy Manager)

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Caddy](https://img.shields.io/badge/Caddy-v2-green.svg)
![Platform](https://img.shields.io/badge/platform-Ubuntu%20%7C%20Debian-lightgrey.svg)

这是一个极简、健壮的 Bash 脚本，旨在帮助开发者在几秒钟内为自己的后端服务（如 Prometheus, Grafana, Laravel 等）建立安全的 HTTPS 反向代理。

## ✨ 功能亮点
- **全自动环境安装**：一键安装 Caddy 2 及相关依赖，省去繁琐的手动命令。
- **SSL 自动配置**：利用 Caddy 的强大功能，自动申请并续期来自 Let's Encrypt 的证书。
- **多站点管理**：支持在一次运行中连续添加多个域名和后端映射。
- **Prometheus 专属加固**：
    - 脚本会自动感应 `9090` 端口。
    - 针对无原生登录页面的服务，提供可选的 **Basic Auth** 身份认证。
    - 使用 **Bcrypt 哈希** 加密存储密码，确保配置文件安全。
- **网络优化**：预设了安全响应头、Gzip 压缩以及真实 IP 透传（X-Real-IP）。

## 🚀 快速使用

在你的 Linux 服务器上执行以下一行命令：

```bash
curl -sL https://raw.githubusercontent.com/vlongx/caddy/main/caddy.sh -o /tmp/caddy.sh && bash /tmp/caddy.sh
```
🛠 配置示例
脚本执行后，生成的 /etc/caddy/Caddyfile 结构示例：
# 监控面板示例 (带身份认证)
```bash
mon.example.com {
    basicauth * {
        admin $2y$05$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    }
    reverse_proxy localhost:9090 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
    }
    encode gzip
}

# 普通应用示例
app.example.com {
    reverse_proxy localhost:8080
    encode gzip
}
```
## ❓ 常见问题 (FAQ)

**Q: 如何查看当前配置了哪些域名？**

A: 重新运行脚本 `./caddy_proxy.sh`，选择选项 `2` 即可列出。

**Q: Caddy 启动失败怎么办？**

A: 
1. 运行 `systemctl status caddy` 查看状态。
2. 确保你的 80/443 端口没被占用。
3. 确保域名已经解析到服务器 IP，否则自动 SSL 证书申请会超时导致启动失败。

**Q: 如何彻底卸载？**

A: 运行脚本选择选项 `4`，脚本会自动停止服务并清理残留文件。


📖 使用须知
DNS 解析：请在运行脚本前，确保你的域名 A 记录已经指向该服务器 IP。
端口占用：请确保服务器的 80 和 443 端口没有被 Nginx 或 Apache 占用。
安全提醒：如果配置的是 Prometheus 或各种 Exporter，强烈建议在脚本提示时开启 Basic Auth。

---

### 💡 小贴士
1. **代码保存**：别忘了把我们之前写好的脚本内容保存为仓库里的 `caddy.sh` 文件。
2. **仓库描述**：在 GitHub 仓库主页的 **About** 栏目，可以填入：*“极简 Caddy 反代脚本，支持多域名配置与 Prometheus 安全加固”*。
3. **下一步建议**：如果你以后想支持 **Docker** 版的 Caddy，或者想增加 **一键查看所有运行中的反代站点** 的功能，我可以随时帮你修改脚本。

