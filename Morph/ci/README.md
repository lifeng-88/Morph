# Morph CI / App Store 自动打包上传

## 流程概览

```
推送 tag v* 或手动 Run  →  Archive  →  上传 App Store Connect  →  TestFlight 处理
```

| 工作流 | 文件 | 说明 |
|--------|------|------|
| iOS Build | `.github/workflows/ios-build.yml` | 模拟器编译（PR 检查） |
| **iOS Release** | `.github/workflows/ios-release.yml` | **打包并上传 App Store** |
| Export Options | `ci/ExportOptions.plist` | Archive 导出 App Store IPA |

无需 `.p12` 证书：使用 **Automatic Signing** + **App Store Connect API Key**。

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

- 工程须为 **Automatically manage signing**
- CI 运行 `ci/prepare_ci_signing.py` 自动写入 `DEVELOPMENT_TEAM` 并移除 Manual 配置
- CI 运行 `ci/ensure_ci_device.py`：团队 0 台设备时自动注册占位设备
- Archive 使用 Development 签名；`exportArchive` 重签为 App Store 分发证书

---

## 常见问题

| 现象 | 处理 |
|------|------|
| `no devices` | 确认 App ID 已注册；API Key 角色为 Admin/App Manager |
| `No profiles for 'com.morph.net'` | 确认 `APPLE_TEAM_ID` 正确；重新 Run workflow |
| Build Number 重复 | 重新 Run（CI 自动 Connect 最新 +1）或手动填更大 build_number |
| Bundle ID 不匹配 | 工程须为 `com.morph.net` |

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
  CODE_SIGN_IDENTITY=- \
  AD_HOC_CODE_SIGNING_ALLOWED=YES \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  -authenticationKeyPath ~/private_keys/AuthKey_XXX.p8 \
  -authenticationKeyID "Key ID" \
  -authenticationKeyIssuerID "Issuer ID"
```
