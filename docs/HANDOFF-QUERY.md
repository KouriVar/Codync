# 半句（Codync iOS）· 只读查询用交接单

> 用途：在新会话里**只读查代码/查逻辑**，不改代码、不构建、不安装、不提交。
> 载入方式：新会话里让 agent 先读本文件，再开始回答。

## 0. 硬性规则（务必先看）
- **只读**：不改任何文件、不跑 `xcodebuild`、不 `xcrun devicectl install/launch`、不 `git commit/push`。
- 允许：`read` / `grep` / `glob`、`git log|show|diff|blame`、读 plist/json/sqlite。
- 回答请给**文件路径 + 行号**，结论要能追溯到代码。
- 用户语言：中文；语气直接，别猜，不确定就说不确定。

## 1. 仓库与分支
- 路径：`/Users/halfsignal/src/Codync-ios-ui`
- 分支：`ui/ios-customization`（HEAD `550589f8`，工作区干净）
- 远程：`origin https://github.com/KouriVar/Codync.git`（fork），上游 `leepokai/Codync`，分叉点 `5e6b1c93`
- 这是 Codync iOS 客户端的一个 UI 定制分支：自绘 UI 全面换成原生 iOS 控件，品牌改名为「半句」，图标系统换成 Remix Icon。

## 2. 目录结构
```
apps/
  project.yml                # XcodeGen 规格（新增文件后必须 xcodegen generate）
  Codync.xcodeproj           # 生成物
  ios/
    App/                     # App 入口（CodyncApp.swift、debug 环境变量）
    Views/                   # App 目标页面（首页/设置/相机/配对/根导航…）
    Resources/               # Info.plist、字体、图片、entitlements
    Kit/Sources/
      CodyncKit/             # 数据/网络/模型/本地化资源（原则上不要动 UI）
      CodyncUI/              # 全部 UI 组件（Chrome、Controls、Thread、Bots…）
    Widgets/ NotificationService/
```

## 3. 关键文件索引
| 内容 | 文件 |
| --- | --- |
| 根导航、相机 sheet 注入 | `apps/ios/Views/RootView.swift` |
| 首页底栏（搜索/扩展/相机） | `apps/ios/Views/HomeBottomBar.swift` |
| 相机拍摄 sheet | `apps/ios/Views/QuickCapture.swift` |
| 设置页 | `apps/ios/Views/AccountSwitcherView.swift` + `Views/SettingsView.swift` |
| 通用组件（IconButton/ModalHeader/BackButton/codyncSheet/SwipeBackEnabler/softScrollEdges） | `Kit/Sources/CodyncUI/Chrome.swift` |
| SearchField / SettingsRow | `Kit/Sources/CodyncUI/Controls.swift` |
| Remix 图标系统（RemixIcon / RemixImage / RemixFont / RemixSymbolMap） | `Kit/Sources/CodyncUI/RemixIcon.swift` |
| 菜单渲染（系统菜单图标必须 Image） | `Kit/Sources/CodyncUI/MenuItem.swift` |
| 对话页（工具栏/标题/消息） | `Kit/Sources/CodyncUI/Thread/ThreadView.swift` |
| 输入区（加号/拍照/发送） | `Kit/Sources/CodyncUI/Thread/Composer.swift` |
| 变更日志（改了什么，为什么） | `CHANGELOG.md`（C0001–C0098） |

## 4. 图标系统（最容易踩坑的地方）
- 字体：`apps/ios/Resources/Fonts/remixicon.ttf`，码点表 `remixicon-codepoints.json`，`Info.plist` 里 `UIAppFonts`；字体名 `remixicon`。
- `RemixIcon("name", size:)`：基于 Text，**适合普通 UI**；调用点外层 `.font(...)` 无效（内部字号固定）。
- `RemixImage("name", size:)`：把字形渲染成 template UIImage，**工具栏 / 系统菜单必须用它**（系统只接受 Image，Text 字形会被丢弃）。
- `RemixSymbolMap`：SF 名 → Remix 名，用于仍传 `systemImage:` 的动态位置。
- 尺寸规范（本分支）：行图标 18；菜单图标 17；工具栏/圆按钮 44 圆 + 24 图标；设置行箭头 `arrow-right-s-line` 20；首页/输入区行高 48。
- 布局边距统一：水平 **16**；设置行无分隔线（`.listRowSeparator(.hidden)` **必须加在 Section 级**，行级/Form 级无效）。
- 玻璃按钮：`.buttonStyle(.glass)` 会在 label 外**再加约 10pt**；需要精确高度时改用 `.frame(height:).glassEffect(...)` + `.buttonStyle(.plain)`。

## 5. 构建 / 设备（仅供理解，不要执行）
- Xcode 27.1，必须 `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`。
- 工程由 XcodeGen 生成：`xcodegen generate --spec apps/project.yml`。
- scheme `iOS Dev`，配置 `DevDebug`，产物 `build/dd/Build/Products/DevDebug-iphoneos/半句.app`。
- 设备 iPhone 16 Pro，UDID `00008140-000A31311AE3001C`；bundle id `com.suiyikou.codync.uipreview`；Team `KQQ6SD2P4C`。
- 最近构建号：**137**。

## 6. 调试入口（理解行为时有用）
- `CODYNC_OPEN_URL=codync://bot/<botId>?scope=local&computer=<hostId>` 启动直接进某个对话。
- `CODYNC_ACCOUNT_PANE=settings|state`、`CODYNC_SHOW_COMPUTERS=1`、`CODYNC_QUICKCAPTURE=1`、`CODYNC_CREATE_PREVIEW=bot`。
- 设备内 App 数据（只读参考）：
  `xcrun devicectl device copy from --device <UDID> --domain-type appDataContainer --domain-identifier com.suiyikou.codync.uipreview --source Library/Preferences --destination /tmp/prefs`

## 7. 协作约定（若之后要改）
- 每个变更在 `CHANGELOG.md` 追加 `### C00xx · 日期 · 标题`，含 原因/变化/文件/验证/限制待办/关联。
- 提交信息英文 Conventional Commits + 末尾 `Change-Id: C00xx`；提交邮箱用 GitHub noreply 地址。

## 8. 当前未完成/待定项
- 设置页是否恢复分隔线（已全部去掉，`.listRowSeparator(.hidden)` 加在 Section 上）。
- 图标是否全量 Remix 化：目前 SF 残留集中在 `CodyncKit` 与 `ContentUnavailableView` 等动态位置。
- 相机「拍照 → 输入框」链路、加号菜单三项图标：build 137 已实现，待真机点按验收。
- 侧滑返回在隐藏系统返回键后由 `SwipeBackEnabler` 兜底，待真机确认手感。
