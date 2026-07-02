# 多云架构 CI/CD OIDC 免密认证指南

在自动化部署（CI/CD）工作流中，OIDC (OpenID Connect) 是一种现代且安全的机制。它利用 GitHub Actions 临时颁发的短效 JWT Token，直接向各大云厂商“自证身份”并换取云端访问权限。这种方式彻底消除了在代码库或 CI 环境变量中长期存储 `Access Key` / `Secret Key` 所带来的泄露风险。

对于主流的云厂商，只要它们支持 OIDC 联邦认证（Identity Federation），接入的核心逻辑都是一致的：
1. **在云厂商侧**：创建一个 OIDC 身份提供商（指向 `https://token.actions.githubusercontent.com`），并创建一个授权角色（Role/Service Account），配置“信任关系”以允许特定的 GitHub 仓库/分支扮演该角色。
2. **在 GitHub Actions 侧**：流水线必须声明对 OIDC Token 的写入权限，即 `permissions: { id-token: write, contents: read }`，然后使用对应厂商的官方 Action 插件去完成握手。

以下是我们在 `iac_modules` 及相关基础设施部署中所支持的各个云厂商的具体接入方案和配置步骤：

---

## 1. AWS (Amazon Web Services)
AWS 利用 IAM OIDC Identity Provider 机制进行联合身份验证。

*   **AWS 侧配置**：
    1. 在 IAM 控制台中添加一个身份提供商，类型选择 **OpenID Connect**，Provider URL 填 `https://token.actions.githubusercontent.com`，Audience 填 `sts.amazonaws.com`。
    2. 创建一个 IAM 角色，在“信任关系 (Trust Policy)”中限定条件：`"StringEquals": {"token.actions.githubusercontent.com:sub": "repo:ai-workspace-infra/iac_modules:ref:refs/heads/main"}`。
*   **流水线 Action 配置**：
    ```yaml
    permissions:
      id-token: write
      contents: read

    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/my-github-actions-role
          aws-region: ap-northeast-1
    ```

---

## 2. GCP (Google Cloud Platform)
Google Cloud 采用工作负载身份联邦（Workload Identity Federation）来支持 OIDC。

*   **GCP 侧配置**：
    1. 在 GCP 控制台创建一个 Workload Identity Pool 和一个 OIDC Provider（Issuer URL 填 GitHub 的 Token 地址）。
    2. 创建一个 GCP Service Account（服务账号）并赋予需要的操作权限（比如 Compute Admin, Storage Admin）。
    3. 将该服务账号绑定到刚才创建的 Identity Pool，通过条件限制只有来自指定 repo 和分支的请求才能扮演。
*   **流水线 Action 配置**：
    ```yaml
    permissions:
      id-token: write
      contents: read

    steps:
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: 'projects/123456789/locations/global/workloadIdentityPools/my-pool/providers/my-provider'
          service_account: 'my-service-account@my-project.iam.gserviceaccount.com'
    ```

---

## 3. Azure
Azure 使用 Entra ID（原 Azure AD）的联合凭据来实现 OIDC 身份验证。

*   **Azure 侧配置**：
    1. 在 Entra ID 中创建一个“应用注册 (App Registration)”或对应的服务主体 (Service Principal)。
    2. 为该应用注册添加“联合凭据 (Federated credentials)”，选择方案为 `GitHub Actions deploying Azure resources`。
    3. 填写您的 GitHub Organization、Repository 和 Branch（例如 `main`）。
    4. 将该应用的 Service Principal ID 赋予相关的 Azure 订阅权限（如 Contributor）。
*   **流水线 Action 配置**：
    ```yaml
    permissions:
      id-token: write
      contents: read

    steps:
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}      # 应用的 Client ID
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}      # Azure 租户 ID
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    ```

---

## 4. Alibaba Cloud (阿里云)
阿里云的访问控制（RAM）也已经全面支持了 OIDC 身份提供商。

*   **阿里云侧配置**：
    1. 在 RAM 控制台创建一个 **OIDC 身份提供商 (IdP)**，填入 GitHub 提供的 Issuer URL (`https://token.actions.githubusercontent.com`) 和 Client ID (`sts.aliyuncs.com`)。
    2. 创建一个 **RAM 角色**，信任类型选择“OIDC 角色”。在信任策略中精确限制条件，比如 `StringEquals: { "token.actions.githubusercontent.com:sub": "repo:ai-workspace-infra/iac_modules:ref:refs/heads/main" }`。
*   **流水线 Action 配置**：
    ```yaml
    permissions:
      id-token: write
      contents: read

    steps:
      - uses: aliyun/oidc-github-actions@v1
        with:
          role-arn: 'acs:ram::1234567890123456:role/github-actions-role'
          oidc-provider-arn: 'acs:ram::1234567890123456:oidc-provider/github-actions-provider'
    ```

---

## 5. Vultr (非原生支持的补偿方案)
> [!WARNING]
> **Vultr 属于中小型云厂商，目前其原生 API 尚不支持 OIDC 联合身份认证 (Federation)。**
这意味着您不能像 AWS/GCP/Azure 那样直接拿着 GitHub 的临时 Token 去 Vultr 换取管理权限。

针对此类不支持 OIDC 的云服务商，通常采用以下补偿方案，这也是我们的系统预留底层 `vault_integration` 能力的核心原因：

*   **方案 A (传统做法)**：使用 GitHub Secrets 存入长效的静态凭证（例如 `VULTR_API_KEY`）。
*   **方案 B (高级联邦做法)**：利用 **HashiCorp Vault** 作为中间桥梁。
    - GitHub Actions 使用 OIDC Token 去向您的自建 Vault 服务器证明身份（Vault 原生支持对接 Github OIDC）。
    - 验证通过后，Vault 负责动态生成或下发存管好的 Vultr API Key 给流水线环境。
    - 这种方式曲线实现了所有不受 OIDC 支持的云厂商的安全密钥流转，做到了流水线凭证的不落地。
