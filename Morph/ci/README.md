# Morph CI / App Store 自动打包上传

## 流程概览

```
推送 tag v* 或手动 Run  →  Archive  →  上传 App Store Connect  →  TestFlight 处理
```

| 工作流 | 文件 | 说明 |
|--------|------|------|
| iOS Build | `.github/workflows/ios-build.yml` | 模拟器编译（PR 检查） |
| **iOS Release** | `.github/workflows/ios-release.yml` | **打包并上传 App Store** |
| Export Options | `ci/generate_export_options.py` | 运行时生成含 `teamID` 的 ExportOptions |

无需 `.p12` 证书：使用 **Automatic Signing** + **App Store Connect API Key**。

> **Runner 要求**：App Store Connect 现要求 **iOS 26 SDK（Xcode 26+）**。Workflow 使用 `macos-26` 并固定 `Xcode_26.5.app`。

---

## 一、Apple 后台准备

1. [Developer](https://developer.apple.com/account/) 注册 App ID：`com.morph.net`
2. 勾选所需 Capability（Push Notifications、In-App Purchase 等）
3. [App Store Connect](https://appstoreconnect.apple.com/) 创建 App，Bundle ID 选 `com.morph.net`
4. 创建 **App Store Connect API Key**（角色 **Admin** 或 **App Manager**），下载 `.p8`（仅一次）

---

## 二、配置 GitHub Secrets

仓库 **Settings → Secrets and variables → Actions**：

| Secret | 说明 |
|--------|------|
| `APPLE_TEAM_ID` | 10 位 Team ID（工程当前为 `Y62CFM5H2H`） |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID |
| `APP_STORE_CONNECT_KEY_ID` | Key ID |
| `APP_STORE_CONNECT_API_PRIVATE_KEY` | `.p8` 全文（含 `BEGIN/END`） |

---

## 三、触发打包上传

### 方式一：打 Tag（推荐）

```bash
git tag v1.0.0
git push origin v1.0.0
```

- Tag `v1.0.0` → Marketing Version = `1.0.0`
- 自动上传 App Store Connect

### 方式二：手动运行

1. GitHub → **Actions** → **iOS Release** → **Run workflow**
2. 填写 **Marketing Version**、**Build Number**（可选）
3. 勾选 **上传到 App Store Connect**

---

## 四、上传之后

Workflow 只负责上传构建。还需在 App Store Connect：

1. **TestFlight** 或 **App 版本** 中选择刚上传的构建（处理约 5–30 分钟）
2. 填写截图、描述、隐私问卷
3. **提交审核**

---

## 五、签名说明

- 工程本地可为 Manual；CI 运行 `ci/prepare_ci_signing.py` 切到 Automatic 并写入 `DEVELOPMENT_TEAM`
- **Archive** 使用 ASC API Key + **Apple Distribution** 签名（含 AppsFlyer 等嵌套 framework）
- **不使用** `-allowProvisioningDeviceRegistration`，避免每次 CI 新建 Development 证书耗尽配额
- **Export IPA** 指定 `signingCertificate = Apple Distribution`
- `ci/generate_export_options.py` 写入 `teamID`，避免 `exportArchive No Team Found in Archive`

---

## 常见问题

| 现象 | 处理 |
|------|------|
| `maximum number of certificates` / `Choose a certificate to revoke` | 打开 [Certificates](https://developer.apple.com/account/resources/certificates/list)，撤销多余的 **Apple Development**（尤其 `Created via API`）；保留本机开发用 1–2 个 + **Apple Distribution** |
| `Invalid Signature` / `AppsFlyerLib` / code 90035 | 嵌套 framework 未用 Distribution 签名；确认 CI Archive 使用 `Apple Distribution`，且未设置 `CODE_SIGNING_ALLOWED=NO` |
| `No profiles for 'com.morph.net'` | 多为证书配额问题连带错误；先清 Development 证书配额，确认 `APPLE_TEAM_ID` 正确后再跑 |
| `no devices` | 确认 App ID 已注册；API Key 角色为 Admin/App Manager |
| Build Number 重复 | 重新 Run（CI 自动 Connect 最新 +1）或手动填更大 build_number |
| Bundle ID 不匹配 | 工程须为 `com.morph.net` |
| SDK version issue (iOS 18.x) | 确认 workflow 使用 `macos-26` + `Xcode_26.5.app` |
| Artifact 上传 ENOTFOUND | 多为 GitHub 临时网络问题；已设 `continue-on-error`，不影响 ASC 上传 |

---

## 本地调试（与 CI 一致）

```bash
cd Morph
python3 ci/prepare_ci_signing.py

xcodebuild archive \
  -project Morph.xcodeproj \
  -scheme Morph \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath /tmp/Morph.xcarchive \
  DEVELOPMENT_TEAM="你的 Team ID" \
  CODE_SIGN_STYLE=Automatic \
  "CODE_SIGN_IDENTITY[sdk=iphoneos*]=Apple Distribution" \
  -allowProvisioningUpdates \
  -authenticationKeyPath ~/private_keys/AuthKey_XXX.p8 \
  -authenticationKeyID "Key ID" \
  -authenticationKeyIssuerID "Issuer ID"

APPLE_TEAM_ID="你的 Team ID" python3 ci/generate_export_options.py

xcodebuild -exportArchive \
  -archivePath /tmp/Morph.xcarchive \
  -exportOptionsPlist ci/ExportOptions.generated.plist \
  -exportPath /tmp/export \
  DEVELOPMENT_TEAM="你的 Team ID" \
  -allowProvisioningUpdates \
  -authenticationKeyPath ~/private_keys/AuthKey_XXX.p8 \
  -authenticationKeyID "Key ID" \
  -authenticationKeyIssuerID "Issuer ID"
```
