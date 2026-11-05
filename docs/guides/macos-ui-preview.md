# Mac 桌面端定制开发

## 工作范围与基线

- Fork：`KouriVar/Codync`。
- 独立 worktree：`/Users/halfsignal/src/Codync-macos-ui`；分支：`ui/macos-customization`。
- 创建基线：iOS 定制分支的已提交版本 `9583dd51`（`fix(ios): one chevron size in Settings`），保留其中所有 iOS 定制。
  创建时该版本比远端 `origin/ui/ios-customization` 的 `d3231f0c` 多 6 个本地提交，没有同步上游或合并其他分支。
- `/Users/halfsignal/src/Codync-ios-ui` 留给 iOS 助手；其中未提交的修改不复制、不提交、不重置。
- 已建立 Mac 开发环境，界面变化按用户需求与参考截图逐项实施；C0088 起开始 Mac 界面定制。
- 用户现要求普通界面调整改好后直接交付，由用户自行测试；不继续耗时的自动界面检查。实际已执行与未执行的验证仍分别记账。
- 最新安装决策（C0089）：用户明确要求打包并覆盖本机官方版。安装沿用官方身份与数据；开发预览的隔离方式仍可使用，不再限制这次覆盖安装。
- 桌面代码由 macOS、Linux、Windows 共用；Mac 专属视觉变化使用已有的 `window.codync.platform` 或主进程平台条件，避免改变其他平台。
- 不自行提交、推送、合并、发布或部署，不为本地定制修改全平台发布版本。

## 已确认的技术栈

当前桌面端位于 `apps/desktop/`，是 Electron + React + TypeScript，由 electron-vite 构建、electron-builder 打包，
不是旧的 SwiftUI Mac App。当前清单版本为 2.36.0；依赖以 `package-lock.json` 为准。

- `src/main/`：窗口、应用身份、Host 管理和本地代理。
- `src/preload/`：`window.codync` IPC 桥接。
- `src/renderer/views/`：界面；`components/` 与 `styles/theme.css`：已有组件与设计变量。
- `host/`：Rust Host。本轮不改其代码、协议或认证规则。
- Swift/Xcode 仅用于现有的语音、屏幕等原生辅助程序，不是桌面主界面实现方式。

## 独立运行方式

在本 worktree 的 `apps/desktop/` 执行：

```sh
npm ci
CODYNC_CLERK_SECRET_KEY= npm run dev -- --name macos-ui --cdp
```

使用仓库已有沙盒能力：

| 资源 | 本任务开发沙盒 |
| --- | --- |
| 应用显示名 | `Codync Dev (macos-ui)` |
| Host 数据目录 | `/Users/halfsignal/.codync-dev-macos-ui` |
| Electron 会话、偏好与账户目录 | `/Users/halfsignal/.codync-dev-macos-ui/desktop` |
| Host 端口 | 首次启动从 19300–19399 选择空闲端口，保存在该目录的 `sandbox.json` |
| 调试端口 | 所选 Host 端口 + 10000 |
| Host 生命周期 | 独立前台子进程，由本次运行管理；不安装 launchd 服务 |
| Host 云连接 | 默认关闭，不传 `--cloud` |

显式清空 `CODYNC_CLERK_SECRET_KEY` 会阻止脚本回退读取共享开发密钥并自动创建或登录 Clerk 测试账户；
沙盒从空白本地状态开始，不借用官方或其他开发实例的凭据与配对数据。
首次运行会构建本 worktree 的开发 Host，或使用显式指定且确认兼容的开发二进制；不能指向官方 Host 二进制。
停止时只停止本任务启动的进程，不使用笼统的 `pkill codync-host`。

开发身份在 Electron 的单实例锁、会话恢复前设置；已有 HostController 拒绝开发版使用官方端口 19222 或 `~/.codync`。
不使用 `--shared`，不将开发版连接到官方端口，也不复制官方 token、身份密钥、数据库或设备配对。

未打包运行仍使用 Electron 本身的 macOS 身份，可能与其他未打包 Electron 开发实例共享系统权限或通知；
会话与数据按沙盒分开。若修改涉及系统权限或完整安装包，再使用独立的 `com.pokai.Codync.dev` 开发包，
先核对本机签名配置，仅安装到本任务的开发位置，不覆盖 `/Applications/Codync.app`。
仓库的 `npm run dist:mac:dev` 生成固定开发证书签名的本机开发包，见下方 C0092。

## 官方应用与 iPhone 配对

初始化时只读确认 `/Applications/Codync.app` 为 2.34.2、标识 `com.pokai.Codync`，官方应用与 Host 正在运行。
上述为 C0087 初始化状态。C0089 按用户最新授权覆盖应用本体，Host、launchd 服务及 `~/.codync` 继续保留。
iPhone 继续使用原本地配对；不将现有手机重新配对到开发沙盒，不升级官方 Host，不更改连接或认证协议。
沙盒是另一台逻辑电脑，不会自动出现官方实例的 Bot、聊天和配对设备。

### 本机签名与电脑访问（C0092）

在 `apps/desktop` 下运行 `npm run dist:mac:local`，生成
`build/dd/desktop-personal/Codync.app`，使用现有主版应用身份和数据目录。
`npm run dist:mac:dev` 生成同目录下的 `Codync Dev.app`，使用独立数据和配对。
命令需要 Xcode、项目指定的 Rust 工具链和本机 Apple Development 签名身份。两种本机包都使用
`KQQ6SD2P4C`，主程序和包内 Screen 签名校验通过后才输出。安装由用户在 Finder 完成。

首次启动主版本机包时，现有启动逻辑会安装并重启随包的 Host 2.39.1。覆盖前请备份旧应用和
`~/.codync` 数据。主版配对是否仍可使用属于验收项，Host 2.39.1 要求手机端 Codync 至少为 2.36.0。

首次从旧签名迁移时，先关闭菜单栏的「远程屏幕」，退出 Codync，再按版本重置授权。
macOS 可能把 helper 的录屏请求归到主程序名下。正式身份的命令如下。

```sh
tccutil reset ScreenCapture com.pokai.Codync
tccutil reset ScreenCapture com.pokai.Codync.screen
tccutil reset Accessibility com.pokai.Codync.screen
```

开发身份使用 `com.pokai.Codync.dev` 和 `com.pokai.Codync.dev.screen`。在 Finder 备份旧包后，将新包放到原安装路径，再打开 Codync。
在「设置 → 电脑访问」启用 Codync Screen。分别打开系统设置的「屏幕与系统音频录制」和「辅助功能」，
把对应栏的 Codync Screen 卡片拖进列表并打开开关。系统未接收拖拽时，可用「在访达中显示」定位 helper，
通过系统设置的「+」选中同一个 `.app`，也可以点 Codync 的授权按钮唤起系统提示。
如果 Codync Screen 已授权而录屏仍未就绪，用「+」选中当前安装的 Codync 主程序并打开录屏开关。

返回 Codync 确认三项就绪，再从手机上已配对电脑的「屏幕」入口打开画面。重复打包并替换同一个安装路径，
这次直接确认三项就绪、手机能看到画面。首次授权和重复打包之间应保留系统权限记录。

### 内置后台任务接管（C0093）

从 C0092 升级时，已恢复录屏的 Mac 可以直接沿用当前权限。先在旧版菜单栏关闭「远程屏幕」来注销旧的内置任务，
然后退出 Codync，备份旧应用后把新包复制到原安装路径。重新打开后，在「电脑访问」启用 Codync Screen，
按系统提示允许其在后台运行。如果升级前漏了关闭步骤，可在新版菜单栏关闭再开启「远程屏幕」完成切换。
正式身份的本机包使用 `com.pokai.Codync.screen.personal` 作为 LaunchAgent 标签，开发身份使用
`com.pokai.Codync.dev.screen.personal`。标签与应用的 Bundle ID 分开，权限记录继续用原应用身份。

用以下命令确认正式身份的内置任务已经出现 `state = running` 和 `pid =`。
「电脑访问」就绪时，可能仍是旧任务在提供连接，所以接管时以任务标签为准。

```sh
launchctl print "gui/$(id -u)/com.pokai.Codync.screen.personal" | grep -E 'state = running|pid ='
```

只在这台 Mac 上确实有旧的手工任务 `com.suiyk.codyncscreen` 时，等内置任务显示运行后，才在终端停用并保留它的配置。

```sh
codync_legacy_plist="$HOME/Library/LaunchAgents/com.suiyk.codyncscreen.plist"
test ! -e "$codync_legacy_plist.disabled" &&
  mv "$codync_legacy_plist" "$codync_legacy_plist.disabled" &&
  launchctl bootout "gui/$(id -u)/com.suiyk.codyncscreen"
```

回到 Codync 刷新并从手机重新打开屏幕，确认旧任务退出后仍可使用。
如果需要回退，先在 Codync 关闭「远程屏幕」并退出，将旧应用放回原路径，恢复手工任务配置，
然后打开旧版并重新开启「远程屏幕」。

```sh
codync_legacy_plist="$HOME/Library/LaunchAgents/com.suiyk.codyncscreen.plist"
test ! -e "$codync_legacy_plist" &&
  mv "$codync_legacy_plist.disabled" "$codync_legacy_plist" &&
  launchctl bootstrap "gui/$(id -u)" "$codync_legacy_plist"
```

## 验证与记账

基线和后续变更按需要执行 `npm run typecheck`、`npm test`、`npm run build`。
界面改动完成后，在独立开发实例中按参考截图检查实际窗口；构建成功与界面验收分别记录。
需要原生辅助程序时才打包，不为普通界面检查替换官方服务。
日志放本 worktree 被忽略的 `build/validation/`，Apple 派生构建放本 worktree 的 `build/dd`。

每项实际改动写入根目录 `CHANGELOG.md`，记录中文原因、前后行为、文件、实际验证结果与限制。
以追加前的最高已有编号递增，不补填历史空号；当前基线最高为 C0086。
并行 iOS 分支后续产生的编号冲突应在用户要求整合时检查，不擅自修改另一个 worktree 的记录。

### 初始化验证（2026-11-03，C0087）

- 桌面依赖安装完成；类型检查、Electron 主进程/preload/renderer 构建通过。
- 测试 371 项，370 通过、1 失败：共享语言目录的键集合不一致（`catalogs.test.ts`）。
  所有运行时代码和语言文件与创建基线一致，属于基线现状；本轮未修改这些文件。
- 构建报告未知符号 `arrow.down.doc.on.clipboard` 及混用静态/动态导入的既有警告。
- 尚未启动开发应用/Host 或打包安装；尚无界面变更，截图对照与真实窗口验收待具体需求后执行。

### 原生窗口控件对齐（C0088）

Mac 主窗口保留原生红绿灯，显式使用 `trafficLightPosition: { x: 14, y: 20 }`，
将预期 14 点按钮的中心对齐现有 54px 顶部栏中心（27 点）。其他平台的窗口配置保持原样。

> C0108 起改为 `trafficLightPosition: { x: 16, y: 16 }`（以内容区左上角为 (0,0)；原生 14pt 控件、9pt 间距，故红 (16,16)、黄 (39,16)、绿 (62,16)），标题栏其他控件从 x ≥ 95 起排。上面 C0088 的旧值仅作历史记录。

类型检查、桌面构建及应用环境/沙盒/关闭行为相关的 10 项现有回归检查通过。
本机没有 Rust 工具链，未构建或启动新的开发 Host；实际界面检查使用仓库已有 demo 内存 Host，
放在从生产代码窗口选项生成的独立 Electron 预览窗口中，数据在 `~/.codync-dev-macos-ui/desktop-ui-preview`。
预览入口脚本和日志在被忽略的 `build/validation/`，没有官方 Bot、聊天或配对数据。
当时预览窗口及本地 HTTP 服务继续运行，供用户查看；当时没有安装或覆盖官方应用。C0089 安装实际定制版后已停止这两个演示进程。

已看到普通窗口的顶部布局并成功进入原生全屏；截图时 macOS 的“窗口共享”系统胶囊替代显示红绿灯，
未取得完整三色按钮的最终视觉截图。用户要求自行测试后停止继续检查，最小宽度、紧凑侧栏、退出全屏后的最终对齐与完整 Host 集成尚未验收。

### 本机覆盖安装（C0089）

用户明确要求直接覆盖官方版后，改用现有官方 **2.34.2** 为本地安装底包，而不是将工作树 2.36.0 全量升级安装。
这样能够只加入本次窗口布局变化，保留原有 Host、屏幕/语音辅助程序、原生运行时以及账号配置。
完整工作树中的 iOS 定制与桌面源码继续保留，安装包不包含其他 2.36.0 新功能。

`apps/desktop/tools/package-mac-local.cjs` 实现本地打包：

```sh
cd apps/desktop
node tools/package-mac-local.cjs \
  /path/to/unmodified-official/Codync.app \
  /path/to/new-output/Codync.app \
  '<本机已验证的 Apple Development 签名身份>'
```

脚本只接受未修改的官方 2.34.2 和不存在的输出目录。它核对原 ASAR 完整性，读取本分支窗口位置配置，
修改官方主进程中的红绿灯位置和应用更新开关；C0090 起还包含下述 Remix 图标覆盖，断言其他 ASAR 文件保持一致；重算 ASAR 完整性头，
重新签名 Electron 部分，保留 Host、语音与屏幕辅助程序原文件/签名。更新模块在此本地包中禁用，避免官方更新覆盖定制或升级 Host。
本次使用的开发签名证书通过了代码签名证书及 OCSP 验证，包通过深层严格签名校验；未做公开分发公证。

- 已安装：`/Applications/Codync.app`，仍为版本 2.34.2，Info.plist 带 `CodyncLocalCustomization` 标记。
- 安装包：`build/releases/Codync-2.34.2-local-C0089.dmg`，包含 `Codync.app`、Applications 快捷方式和安装说明。
- 原版与数据备份：`/Users/halfsignal/Library/Application Support/Codync Backups/20261103-212547-C0089/`。
  其中原版为 `Codync-2.34.2-official.zip` 和 `Codync-original.bundle`；`host-data`、`desktop-data` 保存本地数据快照，备份目录仅本人可访问。
- 安装时仅停止桌面 UI，Host 继续运行；Host 的 SQLite 数据通过在线备份取得一致快照。
  Chromium 数据在 UI 停止后完整复制，包含其数据库及旁路文件，不再尝试用普通 SQLite 接口打开 Chromium 的私有锁定数据库。
- 替换整个应用目录后已启动新应用。安装检查确认应用进程存在，19222 的 Host 健康且版本为 2.34.2，Host 二进制和 launchd 配置的 SHA256 与安装前一致。
- 未重新配对、升级 Host、修改认证协议或写入聊天；依用户要求，没有继续做界面走查或全套测试。
  新签名与官方团队不同，系统权限、钥匙串和屏幕辅助程序重新注册的行为尚未逐项验收。

需要回退时，先退出本地定制应用，将当前应用另存，再从上述原版压缩包恢复 `/Applications/Codync.app`。
通常不需要恢复数据；恢复 Host 数据库必须先停止对应 Host，不能在运行中直接覆盖。备份含本地凭据和数据，不应提交或分享。

### Mac Remix 图标（C0090）

Mac 界面的共享 `Icon` 组件优先使用与 iOS 相同的 Remix 4.9.1 字体和码点表；已只读核对活跃 iOS 工作目录，
字体、码点表、许可证的 SHA256 以及已有映射均一致，没有修改 iOS 文件。
`remix-symbols.json` 保留 iOS 原有对应关系并补齐 Mac 图标，共 186 条映射，覆盖当前 165 个登记图标及原生菜单的 10 个操作图标。
源字体与许可证在 `src/renderer/assets/remix/`。实际资源许可证是 **Remix Icon License v1.0（January 2026）**，
本轮按原文完整保留；历史 iOS C0075 与 Swift 注释中的 Apache-2.0 描述不作为本轮许可证依据。

窗口内图标通过 `remix-icons.ts` 和 `remix-icons.css` 加载本地字体，继承颜色、大小、应用文字缩放及既有外部按钮尺寸；
图标方框与字体尺寸按既有 Lucide 回退的 1.2 倍字号计算。字体使用自身单一字重，不伪造 SF Symbols 的多档笔画。
装饰图标保持对辅助功能隐藏；有标题的图标提供图像角色及可读标签。
未知动态图标名称继续走原 SF/Lucide 路径，不显示空字符；GitHub 等专有品牌图、Bot 头像、应用/菜单栏品牌图与系统红绿灯保留原实现。
Linux/Windows 继续使用既有图标分支，不随本轮替换。

macOS 原生菜单不能直接使用网页字体，因此 `tools/export-remix-menu.swift` 使用同一字体生成 10 个操作图标的 1×/2× 模板 PNG，
通过 `Tray.symbol` 使用系统菜单的颜色、深浅外观和高亮；菜单仍是原生菜单。生成物 `resources/remix-menu/` 已忽略，
构建自动生成并纳入 Mac 打包，同时保留缺图时的 SF 回退。

为了保留已可用的 2.34.2，`tools/local-mac-remix.cjs` 将同一个源代码 helper 编成独立 IIFE，
精确接入官方共享 Icon 函数，并附加字体样式/资源和原生菜单模板图；未全量替换为 2.36.0 renderer。
它对旧包注入点做唯一性断言，对修改后的主进程和 renderer JS 做语法检查，打包脚本核对其余原有 ASAR 文件不变。

- 已安装并启动：`/Applications/Codync.app`，版本继续为 2.34.2，定制标记包含 C0090。
- 安装包：`build/releases/Codync-2.34.2-local-C0090.dmg`。
- 本轮安装前备份：`/Users/halfsignal/Library/Application Support/Codync Backups/20261103-215810-C0090/`，
  内含上一版应用压缩包、原应用目录及本地数据；官方未修改底包仍保留在 C0089 备份。
- 类型检查、桌面构建、映射/码点覆盖检查及深层严格签名校验通过；生成 20 张原生菜单 PNG。
  完成三项只读代码复核，无确认代码缺陷；许可证名称按资源原文记录。
- 替换后确认应用进程运行，Host 2.34.2 健康，Host 二进制及 launchd 配置的 SHA256 与安装前一致。
  按用户要求没有自动界面验收、发送聊天、重新配对或重跑全套测试；各页面图标比例、原生菜单和深浅外观留给用户验收。
