# 加速代理与网关域 (Domain: agent-proxy)

本域包含用于客户端连接加速、请求加密传输与状态上报的边缘代理服务器（Gateway）。

## 1. 资产与组件清单

- **Caddy**: 边缘反向代理，负责接收公网 TLS 请求并转发到 Xray。
- **Xray (xHTTP / TCP)**: 加密通道传输核心。
- **Xray Exporter (xHTTP / TCP)**: 收集 Xray 容器/服务的连接数、上下行流量等核心指标并暴露 prometheus 指标。
- **Vector Agent**: 收集 node_exporter, process_exporter 及 xray-exporter 指标，统一 remote write 到中心 VictoriaMetrics 观测端。
- **Agent Service Plus (agent-svc-plus)**: 与 Accounts 控制面通讯的心跳控制器，上报节点健康状态、同步动态隧道配置。

## 2. 部署与配置架构

1. **证书与网络**: 
   - 依赖主 Caddy 提供外网入口。
   - Xray 通过 Localhost 或 UDS (Unix Domain Socket) 与 Caddy 通信。
2. **状态上报与同步**:
   - `agent-svc-plus` 每隔一段时间向 `https://accounts.<domain>` 上报一次心跳并拉取最新配置，动态更新 `/usr/local/etc/xray/config.json` 并重载 Xray 进程。
