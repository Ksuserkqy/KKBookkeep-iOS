# 羊阳记账 iOS

羊阳记账 iOS 是 KKBookkeep 的原生 iOS 客户端，面向高频、可信、顺手的移动端记账体验。应用优先完成普通记账 MVP，并在本地优先的数据架构上逐步扩展文件备份、多设备导入、AI 快捷记账、识图记账和智能分析。

当前 App 中文显示名为「羊阳记账」，英文显示名为「KKBookkeep」。

## 主要能力

- 首页查看余额、预算进度、本月收支和快捷入口
- 新增支出、收入、转账
- 浏览、筛选、编辑和删除流水
- 管理账户、分类、模板、预算和个人信息
- 查看报表与分类趋势
- App Lock、Face ID 解锁、隐私遮罩
- 桌面快捷操作与 Widget 深链入口
- WebDAV 与 iCloud Drive 文件备份/导入
- 增量 JSONL 同步日志、AES-GCM 文件加密 envelope
- 中英文本地化

## 技术栈

- SwiftUI
- SQLite 本地账本
- JSON / JSONL 增量同步记录
- iCloud Drive 与 WebDAV 文件传输
- CryptoKit AES-GCM 文件加密
- Font Awesome 业务图标资源
- Xcode 工程：`KsuserBookKeepingIOS.xcodeproj`

## 工程入口

- 主 App Target：`KsuserBookKeepingIOS`
- Widget Target：`KsuserBookKeepingWidget`
- 单元测试 Target：`KsuserBookKeepingIOSTests`
- 主 App 入口：`KsuserBookKeepingIOS/KsuserBookKeepingIOSApp.swift`
- 根容器：`KsuserBookKeepingIOS/ContentView.swift`
- Info.plist：`Config/KsuserBookKeepingIOS-Info.plist`
- Asset Catalog：`KsuserBookKeepingIOS/Assets.xcassets`
- 共享 Scheme：
  - `KsuserBookKeepingIOS`
  - `KsuserBookKeepingIOS-enUS`

## 本地开发

1. 使用 Xcode 打开 `KsuserBookKeepingIOS.xcodeproj`。
2. 选择 `KsuserBookKeepingIOS` Scheme。
3. 按需在 Scheme 的 `Run > Options > App Language` 中切换语言。
4. 由开发者在 Xcode 中执行构建、模拟器运行或真机验证。

> 协作约定：代码助手只负责代码与配置修改，不主动执行 iOS 构建、真机安装或真机运行。

## 目录结构

```text
KsuserBookKeepingIOS/
  Components/              # 复用 SwiftUI 组件
  Features/
    Sync/
      Coordinator/         # 跨个人信息和账本数据的同步编排
      Ledger/              # 账本同步 operation、facade、replayer
      Logs/                # 通用 JSONL 增量日志服务
      Models/              # 同步配置模型
      Profile/             # 个人信息备份与导入
      Settings/            # 同步设置页、ViewModel、凭据存储
      Storage/             # WebDAV、iCloud Drive、加密、传输抽象
  Pages/                   # 页面级 SwiftUI 视图
  Shared/                  # 共享 Store、模型、工具和格式化器
  Assets.xcassets/         # 主题色、App Icon 等资源
  en.lproj/                # 英文本地化
  zh-Hans.lproj/           # 简体中文本地化
```

## 数据与同步设计

本项目采用 local-first 架构：

- SQLite 是本机唯一直接读写的主账本。
- 不同步 SQLite 数据库文件本身，避免云盘覆盖、冲突和数据库损坏。
- 新增、编辑、删除业务数据时，先在本地 SQLite 事务中落库，再写入同步 outbox。
- 备份/同步通过 iCloud Drive 或 WebDAV 传输增量 JSONL 记录。
- 其他设备扫描同步目录，导入尚未处理过的 operation，并重放到本地 SQLite。
- `opId` 用于全局去重，`deviceId + seq` 用于设备内顺序，删除使用 tombstone。
- 简单冲突按 `occurredAt/deviceId/seq` 的确定性排序自动解决。

当前同步根目录固定为：

```text
KKBookKeep/
  v1/
    profile/
      personal-profile.json
    ledgers/
      default/
        metadata-devices/{deviceId}/
        devices/{deviceId}/
        template-devices/{deviceId}/
        budget-devices/{deviceId}/
```

已接入文件备份与导入的数据：

- 个人信息
- 账户与分类增量日志
- 流水增量日志
- 模板增量日志
- 预算增量日志

WebDAV 和 iCloud Drive 共享同一套 `SyncStorage`、目录语义、JSONL operation 格式和 AES-GCM envelope。WebDAV 凭据、访问令牌和同步加密密码只允许存入 Keychain。

## i18n 与品牌

- App 名称通过 `InfoPlist.strings` 本地化。
- SwiftUI 用户可见文案通过 `Localizable.strings` 本地化。
- 中文资源：`KsuserBookKeepingIOS/zh-Hans.lproj/`
- 英文资源：`KsuserBookKeepingIOS/en.lproj/`
- 中文显示名：`羊阳记账`
- 英文显示名：`KKBookkeep`
- 主题色：暖金币黄 `#F6C343`，位于 `Assets.xcassets/AccentColor.colorset`
- App Icon 位于 `Assets.xcassets/AppIcon.appiconset`，包含默认、暗黑和 tinted 版本。

新增或修改用户可见文案时，需要同时更新中英文 `Localizable.strings`。

## 安全边界

- 不在源码、资源、日志、同步 JSON 或普通配置中提交 API Key、OIDC client secret、证书、私钥、描述文件或本地环境变量。
- WebDAV 密码、访问令牌、同步加密密码必须存储在 Keychain。
- WebDAV token 只作为传输鉴权凭据，不能作为文件加密密钥。
- 若启用加密备份，远端个人信息 JSON 与账本 JSONL 文件必须写入 AES-GCM envelope。
- AI 解析和识图结果只能作为草稿展示，必须经用户确认后才能正式入账并产生同步增量记录。

## 账户、分类与流水引用规则

- 流水必须保存稳定的 `accountId`、`categoryId`、`fromAccountId`、`toAccountId`。
- 账户名、分类名、图标和颜色只用于展示，重命名不得影响历史流水关联。
- 已被流水引用过的账户或分类，删除时必须归档或写 tombstone，不得物理删除。
- 历史流水列表和详情仍应能展示已归档账户/分类的名称、图标、颜色，并提示归档状态。
- 导入远端账户/分类元数据时，不得让本机历史流水变成“未选择”。

## 测试与验收

本仓库包含 `KsuserBookKeepingIOSTests/LedgerSQLiteStoreTests.swift` 等单元测试。代码修改后应至少做文件级静态检查；涉及 i18n、图标、主题色或 asset catalog 时，应确认 key、路径和资源引用正确。

iOS 构建、模拟器运行和真机验证由开发者在 Xcode 中执行。

## 许可

见 `LICENSE`。
