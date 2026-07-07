# Site Migration Toolkit: 基于 AI 驱动的站点级自动化迁移容灾解决方案

**Site Migration Toolkit** 绝不仅仅是一条普通的 CI/CD 流水线，而是一套面向现代化基础设施和高并发应用集群的**开源级自动化搬站与容灾解决方案**。

在面对跨云、跨主机迁移等高风险、重载场景时，它彻底摒弃了传统的本地打包中转模式，创新性地依托 **S3 对象存储作为高速流式传输隧道**，并深度结合 **HashiCorp Vault 动态 JWT 鉴权**，实现全链路的“零本地磁盘占用”与“零密钥明文落盘”。无论是 TB 级体量的 Gitea 源码库、重型 PostgreSQL 业务数据库集群、复杂的 Docker 容器镜像集，还是 AI 应用的持久化工作区数据，本工具包均能提供安全、智能、极速的“平滑数据漂移”。

## 🌟 核心理念与特性 (Core Features)

- 🤖 **AI 驱动的架构自进化**：不仅迁移数据，更通过大模型自动化生成迁移策略、动态渲染复杂配置文件（如跨域 Caddy Domain 级联重写）。
- 🌊 **极致的流式中转 (Zero-Disk Overhead)**：彻底消灭由于 `tar` 打包引发的“源服务器磁盘打爆”事故。全程基于 Linux Pipes 与 S3 底层网络，导出数据瞬间上云，目标端“边下边解”，**对服务器磁盘容量实现零附加要求**。
- 🛡️ **Vault 零信任安全底座**：彻底告别 `.env` 或静态密钥配置文件。在迁移时瞬间向 `HashiCorp Vault` 发起 JWT 短期认证，提取 S3 AK/SK 凭证放入运行时内存，任务结束凭证即焚。
- ⚡ **原生增量与断点续传**：深度整合底层 `aws s3 sync` 增量比对协议，在动辄几十 GB 大文件或跨国弱网环境中，天然免疫网络闪断。
- 📦 **Docker 镜像真空打包**：针对目标集群可能遭遇的镜像拉取限流（如 DockerHub Rate Limit），支持在源端一键 `docker save` 存活镜像并直推 S3，在无外网环境下亦可极速冷启动。

## 🛠️ 技术栈与生态圈 (Technology Stack)

- **核心编排引擎**: Ansible / Ansible Vault
- **安全与身份网关**: HashiCorp Vault (动态 JWT / KV2)
- **底层对象存储隧道**: AWS S3 (或兼容的 MinIO / OSS / OBS)
- **CLI/自动化底座**: AWS CLI v2 / Shell Pipelines (`gzip` / `gunzip` stream)
- **首批支持开箱即用的技术栈**:
  - PostgreSQL (通过 `pg_dump` 管道)
  - Gitea Server (含静态归档向 S3 原生引擎的无缝切库)
  - Docker Containers (容器热备份)
  - Caddy / APISIX (网关配置自适应渲染)
  - QMD / OpenClaw (自定义数据目录热同步)

## 📖 目录导航

更详尽的灾备计划、系统概览及实施流程，请参考以下目录：

- [系统级实时概览 (Systems Overview)](ZH/Systems-Overview/PROD/live_systems_overview.md)
- [备份与容灾预案 (Backup & DR Plan)](ZH/BackUP/backup_dr_plan.md)
- [PostgreSQL 容灾实战 (PostgreSQL DR)](ZH/BackUP/postgresql_disaster_recovery.md)
- [Vault OIDC 策略与 403 排障 (Vault OIDC DR & Troubleshooting)](ZH/BackUP/vault_oidc_policy_troubleshooting.md)
- [迁移实施方案历史文档 (Site Migration Implementation)](ZH/BackUP/Site-Migration/implementation_plan.md)
