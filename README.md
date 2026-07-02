# Site Migration & Backup Toolkit (业务域重构版)

*🇨🇳 中文版 | Chinese version*

欢迎使用 **Site Migration & Backup Toolkit**。本代码库提供了面向 AI Workspace 基础架构灾难恢复及跨机房整体迁移的自动化解决方案。

> ℹ️ **架构升级提示**：本工具集已经从旧版的“All-in-One”大一统架构，重构为以**业务域 (Business Domains)** 为边界的高内聚架构。这允许我们针对不同业务系统进行解耦、按需迁移及独立演进。

## 🌐 核心业务域导航 (Business Domains)

本工具集依据线上系统的实际业务链路，拆分为以下三大核心域：

1. **[domain-ai-workspace](domains/ai-workspace/README.md)** (AI 核心链路域)
   - 涵盖 LiteLLM、OpenClaw、QMD 等智能代理与模型路由调度链路。
2. **[domain-web-saas](domains/web-saas/README.md)** (SaaS 前端与加速域)
   - 涵盖 Web Console、Accounts、Billing 计费及底层的 Xray 隧道代理入口。
3. **[domain-open-platform](domains/open-platform/README.md)** (开放平台与基础设施域)
   - 涵盖 Gitea、Vault、IAM (Zitadel) 以及强大的全局可观测性底座 (Observability Stack - Grafana, VictoriaMetrics 等)。

详细的各个域的迁移、备份、与恢复策略，请查阅各个子域内的 `README.md` 文档。

## 🚀 迁移编排与使用 (Orchestration)

*注：编排层正在从旧版 Python 单体脚本向模块化 Ansible / Make 支持过渡中。*

您可以通过全局的入口命令，指定单个或多个 `DOMAIN` 来执行按需备份或迁移：

```bash
# 示例：仅对 AI 工作区及开放平台底座进行数据备份
make backup DOMAIN=ai-workspace,open-platform

# 示例：一键触发全站各域的迁移与恢复流水线
make migrate DOMAIN=all
```

## 🛠️ CI/CD 与 IaC 流水线

通过流水线触发整体或部分域的迁移时，底层同样会调用相应的业务域策略模块。

### ⚠️ Vault 鉴权配置

对于流水线的触发环境，依然需要确保具有提取敏感凭证的 Vault 权限（详见旧版文档中的 `github-actions-site-migration-toolkit` Role 设置过程）。对于各域的细节解密配置，依赖 Vault 中的参数分发。
