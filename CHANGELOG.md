# Fork 改动记录

本文件记录本 fork 的定制与修复；上游发布说明仍在原有文档中维护。
每次修改必须同步更新本文件，格式见 [改动记录规则](docs/guides/change-recording.md)。

iOS 定制分支：`ui/ios-customization`；当前 Mac 工作分支：`ui/macos-customization`；目标仓库：`KouriVar/Codync`。
以下记录根据 2026-11-03 本次实际修改补记，创建记录时均尚未提交或推送。
后续提交状态以 Git 历史为准，可用记录编号查询提交。

## 2026-11-03

### C0001 · 2026-11-03 · iOS 底部导航从三个增加到四个

- 原因：先通过一个小改动，跑通修改 iOS UI、编译和安装到个人手机的流程。
- 变化：在 State 与 Settings 之间新增“测试”导航和独立静态页面，保留 Bots、State、Settings。
  测试页不向上游分析服务上报新增页面事件。
- 文件：`apps/ios/App/CodyncApp.swift`、`apps/ios/Views/RootView.swift`、
  `apps/ios/Views/TestTabView.swift`；`apps/Codync.xcodeproj/project.pbxproj` 由 XcodeGen 重新生成。
- 验证：模拟器编译通过；真机编译、签名、安装和启动成功。按用户要求，未继续做完整交互测试。
- 限制/待办：测试页目前只有占位内容，未增加业务功能；仅修改 iOS。
- 关联：无。

### C0002 · 2026-11-03 · 增加独立身份的个人 iOS 构建配置

- 原因：将定制 App 装到个人 iPhone，并与官方 App 的身份和数据隔离。
- 变化：增加无第三方账号服务的 `ui-preview` 配置与专用签名权限文件；构建时覆盖 Bundle ID、App Group、
  Keychain Group 和 URL Scheme，使用 `com.suiyikou.codync.uipreview` 作为 App 标识。
  此构建不提供 Apple、Google、GitHub 登录和官方推送；本地配对能力由 C0003 补齐。
- 文件：`apps/shared/Config/ui-preview.plist`、`apps/ios/Resources/UIPreview.entitlements`、
  `docs/guides/ios-ui-preview.md`。
- 验证：Xcode 账号完成登录后，真机签名和安装成功。此阶段安装使用构建号 25（命令行覆盖）。
- 限制/待办：原版云端账号发现、登录和官方推送未配置。单独关闭账号服务的初版曾阻断本地配对，见 C0003。
- 关联：C0001、C0003、C0005。

### C0003 · 2026-11-03 · 恢复无账号的本地配对

- 原因：较新源码强制索取账号证书，无账号配置会在发送配对请求前提示“请连上网络……确认你的账户”。
  实际安装的官方 Mac Host 2.34.2 原本支持只用二维码配对。
- 变化：无云端账号客户端时，发送包含一次性配对码、设备名称和平台的本地配对请求，省略账号证书及账号认领；
  已配置云端客户端时仍按原流程取证书，失败时不自动降为本地配对。Host 继续负责验证配对码和授权设备。
- 文件：`apps/ios/Kit/Sources/CodyncKit/Client/HostConnector.swift`、
  `apps/ios/Kit/Sources/CodyncUI/Store/AccountStore.swift`、`docs/guides/ios-ui-preview.md`。
- 验证：真机编译、安装成功；最终通过直接传入一次性配对链接完成连接，Mac 端列出新的本地 iPhone 设备为 connected；
  用户确认已经能够直接连接。
- 限制/待办：兼容目标是已确认的官方 Host 2.34.2。要求账号证书的新 Host 可能拒绝本地配对；没有修改 Mac 官方程序。
  云端短配对码查询仍需要账号，本地无账号流程应使用完整二维码或配对链接。
- 关联：C0002、C0004、C0005。

### C0004 · 2026-11-03 · 调整扫码器生命周期并显示相机错误

- 原因：用户反馈扫码页面没有相机画面；原实现创建控制器时便启动扫描、忽略启动异常，且没有明确释放相机。
- 变化：将扫码器提取为独立文件；页面显示后请求相机权限并启动，离开或销毁时停止，回到前台时重新创建扫码器。
  增加权限/启动/中断错误提示和“重试相机”按钮，保留粘贴完整配对链接的入口。
- 文件：`apps/ios/Views/QRScanner.swift`、`apps/ios/Views/PairingView.swift`；Xcode 项目由 XcodeGen 重新生成。
- 验证：构建号 25 编译、安装成功。为完成实际连接，将 Mac 生成的一次性链接通过已有调试入口交给手机处理。
- 限制/待办：没有单独验证修订后的相机画面和二维码识别；最终连接成功的依据是链接配对，不应写成扫码识别已验证。
- 关联：C0003。

### C0005 · 2026-11-03 · 共享存储使用个人构建的 App Group

- 原因：共享存储原先只按 main/dev 环境选择上游固定 App Group，与个人签名配置中的 App Group 不一致。
- 变化：优先读取当前 App 的 `Info.plist` 中 `CodyncAppGroup`，未设置时回退原有环境值。
- 文件：`apps/ios/Kit/Sources/CodyncKit/Client/SharedStore.swift`。
- 验证：包含此变更的构建号 25 编译、安装和本地连接成功。
- 限制/待办：没有单独验证小组件共享数据或手机重启后的持久化。
- 关联：C0002、C0003。

### C0006 · 2026-11-03 · 建立每次改动必须记账的仓库规范

- 原因：避免后续定制变多，提交或推送时无法回顾改过什么。
- 变化：在根目录 `AGENTS.md` 增加必读与强制记账要求，新增本文件、记录规则和模板，并补记 C0001—C0005。
  将原有较长的上游代理规范保留到独立文档，通过必读入口继续引用。
  明确本 fork 当前以 iOS 定制为范围、保留本地连接，不自动发布或部署。
- 文件：`AGENTS.md`、`CHANGELOG.md`、`docs/guides/change-recording.md`、
  `docs/reference/upstream-agent-guidelines.md`。
- 验证：检查 Markdown 本地链接、记录编号、相关文件存在性及 diff 空白错误；这是文档改动，不重新编译或安装 App。
- 限制/待办：这是仓库工作规范，未安装 Git hook；手动绕过规范仍可提交，后续代理必须按规范执行。
- 关联：C0001—C0005。

### C0007 · 2026-11-03 · 首页底部改为插件按钮与搜索栏

- 原因：用户提供 Grok Bot 首页参考，要求左侧为插件图标、右侧为搜索栏，暂时隐藏状态和设置，后续再迁移。
- 变化：首页四项标签栏改为圆形插件入口与圆角搜索栏；状态、设置和临时测试入口隐藏，原页面实现保留。
  插件入口打开当前电脑已有的插件页面，无电脑时打开电脑管理。搜索即时筛选机器人/群聊名称和最近消息摘要，
  搜索时展开折叠分组并禁用拖动和辅助功能排序；重命名分组使用完整列表维护顺序，清空搜索恢复原列表。
  进入聊天后不显示首页底栏。
- 文件：`apps/ios/Views/RootView.swift`、`apps/ios/Views/BotListView.swift`、
  `apps/ios/Views/HomeBottomBar.swift`、`docs/guides/ios-ui-preview.md`；Xcode 项目由 XcodeGen 重新生成。
- 验证：构建号 26 真机编译、签名通过，并已覆盖安装到 iPhone。
  代码审查发现并修复搜索期间可能丢失隐藏分组排序的问题。自动启动因手机锁屏被系统拒绝，需用户解锁后打开。
  按用户此前要求，未进行完整交互测试或截图比对。
- 限制/待办：搜索范围为当前列表缓存的名称与最近消息摘要，不包含完整历史聊天；状态和设置的新位置等待用户后续指定。
- 关联：C0001、C0002、C0003。

### C0008 · 2026-11-03 · 插件图标略微缩小并加粗

- 原因：用户反馈首页左侧插件图标偏大、线条偏细，希望小一点、粗一点。
- 变化：图标字号从 10 调至 9.5，字重由 semibold 调至 bold，内部行列间距由 3 调至 2.5；
  圆形按钮和点击区域保持 48 点，搜索栏布局不变。
- 文件：`apps/ios/Views/HomeBottomBar.swift`。
- 验证：构建号 27 真机编译、签名通过，并已覆盖安装到 iPhone；按用户此前要求未做交互测试。
- 限制/待办：视觉大小和粗细需用户在手机上确认。
- 关联：C0007。

### C0009 · 2026-11-03 · 移除首页头像旁的下拉箭头

- 原因：用户希望左上角头像接近 Grok Bot 的圆形外观，去掉下拉箭头，并考虑先内置个人默认图片。
- 变化：移除头像按钮中的向下箭头，指定系统圆形按钮外框；保留头像点击后进入本地资料和配对页面的能力。
  本地模式使用相应的辅助功能名称，不显示为切换账号。
- 文件：`apps/ios/Views/AccountSwitcherView.swift`。
- 验证：构建号 28 真机编译、签名通过，并已覆盖安装到 iPhone；按用户此前要求未做交互测试。
- 限制/待办：默认个人头像图片尚待用户提供；暂时保留现有占位头像，没有添加头像设置功能。
- 关联：C0007。

### C0010 · 2026-11-03 · 内置狗狗照片作为本地默认头像

- 原因：用户提供照片，要求先作为本地默认头像使用。
- 变化：将用户提供的原图加入 App 资源；本地模式使用该照片代替人物占位符，沿用圆形裁剪和系统按钮外框。
  原有账号头像和姓名首字母的显示规则保留；没有增加头像设置页面或下拉箭头。
- 文件：`apps/ios/Views/AccountSwitcherView.swift`、
  `apps/ios/Resources/Assets.xcassets/LocalDefaultAvatar.imageset/Contents.json`、
  `apps/ios/Resources/Assets.xcassets/LocalDefaultAvatar.imageset/avatar.jpg`。
- 验证：构建号 29 真机编译、签名通过，并已覆盖安装到 iPhone；按用户此前要求未做交互测试。
- 限制/待办：当前头像内置于 App，用户不能在手机界面中更换；视觉效果待用户确认。
- 关联：C0009。

### C0011 · 2026-11-03 · 插件图标从 Bold 加粗到 Heavy

- 原因：用户希望插件图标在上一版基础上再加粗一档。
- 变化：组合图标使用 Apple SF Symbols 的 square 与 plus，字体字重由 bold 调为 heavy；
  字号保持 9.5、内部间距保持 2.5、圆形按钮和点击区域保持 48 点。
- 文件：`apps/ios/Views/HomeBottomBar.swift`。
- 验证：与 C0010 一同以构建号 29 编译、签名并安装成功；按用户此前要求未做交互测试。
- 限制/待办：视觉粗细待用户在手机上确认。
- 关联：C0008。

### C0012 · 2026-11-03 · 头像贴近系统玻璃外框并移除过宽留白

- 原因：用户对比 Grok Bot、Apple Music 和 App Store 截图，反馈头像外侧灰色留白过宽、照片与外框不融合。
- 变化：首页头像从 30 点增至 40 点，按钮内容区域为 44 点；iOS 27 使用 Apple 官方
  `ToolbarContent.contentMarginsRemoved()` 去掉默认内容边距，保留系统圆形玻璃背景，仅留约 2 点边缘。
  不额外叠加玻璃背景或自绘描边；保留头像点击、本地配对和无下拉箭头的行为。
- 文件：`apps/ios/Views/AccountSwitcherView.swift`、`apps/ios/Views/BotListView.swift`。
- 验证：已查阅 Apple API 文档并在本机 SDK 确认方法及可用版本；构建号 30 编译、签名、安装及启动成功。
  尝试通过 Device Hub 读取更新后的画面，但 Mac 锁屏阻止截图，未完成视觉比对。
- 限制/待办：移除系统边距的 API 需要 iOS 27；iOS 26 保留原生工具栏的默认边距。最终视觉效果待用户确认。
- 关联：C0009、C0010。

### C0013 · 2026-11-03 · 插件图案等比缩小 4 像素并加粗到 Black

- 原因：用户对比截图后，要求插件内部图案等比缩小 4 个像素，再加粗一档查看效果。
- 变化：SF Symbols 字重由 heavy 调到 black；按屏幕 displayScale 将图案宽度减少 4 个物理像素，
  高度按相同比例缩放。当前 iPhone 为 3× 屏幕，对应宽度减少约 1.33 点。
  圆形按钮和点击区域仍为 48 点，底栏间距和搜索栏不变。
- 文件：`apps/ios/Views/HomeBottomBar.swift`。
- 验证：已读取真机屏幕比例；构建号 31 真机编译、签名通过，并已覆盖安装到 iPhone；按用户此前要求未做交互测试。
- 限制/待办：Black 为当前使用的最粗系统字重，最终视觉效果待用户确认。
- 关联：C0008、C0011。

### C0014 · 2026-11-03 · 修正插件图标微调不明显的实现方式

- 原因：用户多次反馈图标没有明显变化。核实手机安装的是构建号 31；测量用户前后截图的亮色图案边界，
  仅由约 34×32 像素变为 33×32 像素。先前把 4 像素当作物理像素只缩小约 1.33 点，
  又使用四个独立 SF 字形拼接，未直接控制整体图案尺寸与实际线宽。
- 变化：用一个完整 SwiftUI Shape 绘制三个空心方框和加号，明确指定 18×18 点和 1.8 点线宽；
  将描边向图案边界内缩半个线宽，使实际绘制保持在指定范围。移除字体字重和几何缩放的间接控制。
  外部 48 点圆形按钮、点击区域与搜索栏布局保留。
- 文件：`apps/ios/Views/HomeBottomBar.swift`。
- 验证：确认先前已安装构建号为 31，完成前后截图量测；提取实际 Shape 进行本机离线渲染，
  3× 输出及可见边界均为 54×54 像素，设定线宽为 5.4 像素。构建号 32 编译、签名及安装成功。
- 限制/待办：此插件图案改为自绘矢量，不再是 SF 字形组合；线宽直接按点控制。真机最终观感待确认。
- 关联：C0008、C0011、C0013。

### C0015 · 2026-11-03 · 压低聊天输入栏并移除两个语音入口

- 原因：用户反馈聊天输入栏过高、加号按钮过大，并要求去掉麦克风听写和波形语音通话入口，提供明确尺寸。
- 变化：原默认加号直径按代码计算为 54 点，改为固定 44 点；单行输入框最小高度设为 44 点。
  发送/停止圆钮由 34 点改为 32 点，独立保留 44×44 点点击区域；加号图形仍为 18 点，发送箭头仍为 14 点。
  去掉输入栏的听写按钮、听写引擎菜单/录音状态及波形通话入口。文字保留最多八行增长、附件、引用、发送和停止。
  输入组件外围上留白为 6 点、下留白从 16 改为 8 点，普通单行区域合计 58 点，不包含底部系统安全区。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Thread/Composer.swift`、
  `apps/ios/Kit/Sources/CodyncUI/Thread/ThreadView.swift`。
- 验证：已核对旧尺寸计算、玻璃封装没有额外内边距及 Apple 的触控区域建议；构建号 33 编译、签名及安装成功。
  按用户此前要求未做交互测试。
- 限制/待办：尺寸以 iOS 点为单位；多行、引用、附件及大字体会按内容增高。此次移除输入栏入口，
  保留底层通话模块与快捷指令能力，未更改系统键盘自带的听写。真机观感待用户确认。
- 关联：C0014。

### C0016 · 2026-11-03 · 聊天页右上角改为更多菜单

- 原因：用户认为右上角电脑显示器图标不够简洁，希望改为更多按钮。
- 变化：将原显示器按钮换成系统圆形“···”按钮，使用 SF Symbols ellipsis（18 点、semibold）。
  点击打开原生菜单，提供“查看电脑屏幕”；机器人操作电脑时显示对应文字，并继续传入 watching botId。
  沿用原有屏幕能力可用时才显示入口的条件，保留实际远程屏幕连接逻辑。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Thread/ThreadView.swift`。
- 验证：构建号 34 真机编译、签名通过，并已覆盖安装到 iPhone；按用户此前要求未做交互测试。
- 限制/待办：查看屏幕现在需要先展开更多菜单，再点击菜单项；菜单后续可按用户需求调整。
- 关联：C0015。

### C0017 · 2026-11-03 · Bot 资料与设置改为原生分组页面

- 原因：用户对比 Grok Bot 的资料页和编辑页，希望去掉原有四个标签、自绘描边卡片和自定义开关，采用原生 iOS 层级与样式。
- 变化：点击聊天顶部名称后以系统导航进入独立资料页，显示 88 点头像、名称和编辑按钮；下方为定时任务、资料库、电脑三行原生入口，以及独立通知开关。
  页面和分组区域分别使用系统 secondary/tertiary grouped 背景色，形成参考图中的深灰层次；编辑头像保留铅笔角标，不显示导航箭头。
  分享按钮保留模板导出；更多菜单承接指令与智能体、工作区与权限、能力与插件、记忆，保留备用智能体、创建者和创建时间信息。
  编辑页使用原生 Form、名称输入、头像入口和“完成”按钮；编辑与高级设置从旧资料页的自动保存改为点击完成保存，返回放弃草稿。
  保存前合并电脑端对未编辑字段的更新，失败保留草稿并展示错误；通知、电脑使用及记忆开关仍即时写入电脑。
  定时任务、资料库与记忆增加原生列表容器，保留已有加载、编辑、文件操作与错误处理；模型默认项与选项规则抽取为共享 helper，供原有模型选择器与新表单共用。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Bots/BotDetailsView.swift`、`BotProfileEditView.swift`、`BotNativeSettingsView.swift`、
  `BotEditSession.swift`、`AgentModelSelection.swift`、`AgentModelPicker.swift`、`LeadAgentAvatar.swift`、`FallbackRows.swift`、`MemoryView.swift`；
  `apps/ios/Kit/Sources/CodyncUI/Thread/ThreadView.swift`、`Store/BotStore+Actions.swift`、`Routines/RoutinesView.swift`、`Artifacts/LibraryView.swift`；
  `docs/guides/ios-ui-preview.md`。
- 验证：构建号 35 及微调后的构建号 36 真机编译、签名、安装和启动成功；构建号 35 已通过 Device Hub 看到首页和电脑连接状态。
  完成正确性、完整性及重构三项只读代码检查，并补回创建信息、合并重复模型规则，git diff --check 通过。
  Device Hub 能镜像真机但点击没有响应，后续截图返回不可用；已请用户在手机打开资料页，尚未完成资料页/编辑页视觉比对。
- 限制/待办：此次仅改造从聊天进入的 Bot 资料/设置；新建 Bot、列表长按的独立编辑表单与群设置仍保留旧版。
  自定义头像上传沿用原账号/服务要求及即时生效行为，不属于“完成”提交的草稿；本地预览不具备官方推送能力，通知开关不会新增云端推送。未重新加入语音输入。
  未执行自动化测试；未修改真实 Bot 设置进行写入验证。仅修改 iOS，未改变 Host、桌面端或连接协议。
- 关联：C0015、C0016。

### C0018 · 2026-11-03 · 修复点击 Bot 名称进入资料页时闪退

- 原因：用户反馈 C0017 的构建 36 点击聊天顶部 Bot 名称会立即闪退。读取真机崩溃报告，确认版本为 36，主线程在 SwiftUI EnvironmentValues 对必需环境对象的读取处触发断言。
  根导航栈在 ChatScreen 之外托管新目的地，而 BotStore 原本只注入聊天子树，资料页缺少对应电脑的 Store。
- 变化：聊天到资料页、资料页到编辑/高级设置/定时任务/资料库/电脑/记忆，以及编辑页的两个头像入口，都显式传递同一个 BotStore。
  同时修复三个列表入口向根 `[BotReference]` 路径推入另一种 BotProfilePage 值的问题，改为直接 destination 的原生 NavigationLink，保留系统箭头。
  Debug 构建新增只在启动时生效的 `CODYNC_PROFILE_PREVIEW=details|edit`，用于在真机镜像无法点击时通过真实导航栈检查当前账户电脑的主 Bot 页面。
  该检查不发送聊天消息、不保存 Bot 设置；打开聊天仍可能发送正常的已读回执，退出并不带参数重启即可恢复普通导航。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Thread/ThreadView.swift`、`Bots/BotDetailsView.swift`、`Bots/BotProfileEditView.swift`；
  `apps/ios/App/CodyncApp.swift`、`docs/guides/ios-ui-preview.md`。
- 验证：构建号 37 真机编译、签名、覆盖安装并启动成功，完成三项只读代码复核和 git diff --check。
  使用真机启动参数实际进入新导航；Device Hub 已看到正常显示的定时任务页和“编辑 Bot”页，包含姓名输入、头像入口和完成按钮；观察期间没有新的导航环境断言。
  崩溃报告仍仅包含修复前 10:02/10:03 的记录。此次未执行自动化测试，未修改真实 Bot 设置进行保存验证。
- 限制/待办：验证时手机处于浅色模式；深色模式的最终视觉比对及其他设置页面的逐项操作尚未完成。
  修复前的崩溃报告与运行日志仅保存在被忽略的 build 目录，没有写入用户聊天内容、密钥或完整配对链接。
- 关联：C0017。

### C0019 · 2026-11-03 · 补齐自定义头像及推理选项的中文显示

- 原因：用户截图中的头像上传按钮、格式说明仍为英文；“Reasoning effort / High”也直接显示电脑返回的英文。
- 变化：自定义头像的标题、上传图片、粘贴网址、恢复默认、图标着色、网址辅助标签和格式/即时保存说明显式调用现有翻译表。
  按钮改用系统 bordered 样式、网址输入改为系统 roundedBorder，图标着色使用系统开关。
  新增共享的模型选项显示翻译，将推理强度及常见档位显示为中文，同时用于原生表单、旧模型选择器和推理滑杆，补齐默认项文字。
  只转换显示标签，不改变选项 ID、模型 ID 或发送给电脑的值；未知选项及产品/模型名称保留原文。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Bots/CustomIconEditor.swift`、`AgentModelLabels.swift`、`BotNativeSettingsView.swift`、
  `AgentModelPicker.swift`、`AgentModelSelection.swift`、`ReasoningSlider.swift`；
  `apps/ios/Kit/Sources/CodyncKit/Resources/Languages/zh-Hans.json`、`zh-Hant.json`、`docs/guides/ios-ui-preview.md`。
- 验证：构建号 38 真机编译、签名、覆盖安装和启动成功；简繁中文 JSON 格式与重复键检查通过，17 个目标文案均有翻译。
  三项只读代码检查发现显式 Default (recommended) 分支仍为英文，已统一显示为本地化默认并重新编译安装。
  通过扩展页确认真机正在使用中文翻译表；头像编辑与模型选项的文字尚未逐页截图核对。
- 限制/待办：头像上传的账号/服务依赖和即时保存行为保持原样；来自电脑的未知说明或错误不做自动翻译。
  未执行自动化测试，未上传图片或修改真实模型配置。
- 关联：C0017、C0018。

### C0020 · 2026-11-03 · 扩展入口改为原生导航并收窄左右留白

- 原因：用户认为首页扩展按钮打开的页面仍是自绘样式，右上角关闭按钮不统一，左右 44 点留白太宽。
- 变化：扩展页使用独立系统 NavigationStack；标题、凭证按钮和圆形关闭按钮移至原生工具栏，搜索框改用 searchable，
  智能体/连接器/技能改用系统分段 Picker。内容左右边距由 44 点减为 20 点，去掉重复的自绘页头、搜索框、关闭按钮与侧栏。
  已安装连接器/技能改由原生导航推入并使用系统返回，显式传递当前电脑的 BotStore，避免再次出现缺少页面环境的问题。
  搜索时本地智能体/技能立即筛选，连接器在停止输入 300 毫秒后重新加载；保留连接器分页和既有安装动作。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Marketplace/MarketplaceView.swift`、`MarketplaceTabs.swift`、`InstalledView.swift`；
  `docs/guides/ios-ui-preview.md`。
- 验证：与 C0019 一同以构建号 38 真机编译、签名、覆盖安装和启动成功，三项只读代码检查及 git diff --check 通过。
  使用既有 Debug 打开入口，在 Device Hub 实际看到新的扩展页、系统工具栏圆形关闭/凭证按钮、系统搜索框、分段控件和完整智能体名称；内容左右边距为 20 点。
  观察期间没有新的环境对象或导航类型断言；未逐项验证搜索、关闭按钮点击或已安装页的交互。
- 限制/待办：此次处理扩展入口和已安装页导航；智能体目录网格、安装详情、凭证等二级页面保留现有实现。
  未执行真实安装、卸载或凭证修改。仅改 iOS，未修改 Host 协议、本地扫码配对与官方 Mac 客户端。
- 关联：C0007、C0018、C0019。

### C0021 · 2026-11-03 · 头像页改为原生容器并暂时收纳状态和设置

- 原因：用户希望头像弹窗采用与扩展页一致的原生风格，并将 C0007 隐藏的状态、设置两栏暂时放进该弹窗，用分段控件切换。
- 变化：头像打开独立系统 NavigationStack，使用原生圆形关闭按钮和“账户 / 状态 / 设置”分段 Picker；内容左右遵循系统分组表单与 20 点分段边距。
  账户改为 Form/Section，显示与首页相同的本地默认头像，保留扫码配对、已配置账号的登录/切换/退出/删除能力，确认弹窗采用原生样式。
  状态恢复小组件、实时活动、灵动岛三个预览，次级分段也采用系统 Picker；用量入口和用量链接接到该状态区，用量弹窗和电脑切换使用原生导航/菜单。
  设置恢复外观、语言、思考详情、快捷指令主 Bot、通知、分析、版本/反馈/源码与重新开始，改为原生 Form、Picker、Switch 和确认。
  三栏保活以保留浏览状态；隐藏栏禁用点击和辅助功能，小组件设置动画仅在其状态页可见时播放。
  设置页按账户 contextID 重建，防止切账户后沿用上一账户的快捷指令主 Bot；切账户和重新开始清理旧用量弹窗。
  页面统计按实际分段记录，原 Widget/Usage Debug 入口随新导航迁移，新增 Debug 专用 CODYNC_ACCOUNT_PANE 便于真机镜像检查。
- 文件：`apps/ios/Views/AccountSwitcherView.swift`、`RootView.swift`、`SettingsView.swift`、`AppearanceSettings.swift`、`LanguageSettings.swift`、
  `ShortcutLeadSettings.swift`、`WidgetGalleryView.swift`、`ActivityGalleryView.swift`；`apps/ios/App/CodyncApp.swift`；
  `apps/ios/Kit/Sources/CodyncUI/Thread/ThinkingDetailsSettings.swift`；
  `apps/ios/Kit/Sources/CodyncKit/Resources/Languages/zh-Hans.json`、`zh-Hant.json`、`docs/guides/ios-ui-preview.md`。
- 验证：构建号 39 及最终微调后的 40 均已真机编译、签名、覆盖安装和启动；三项只读代码检查发现跨账户偏好与页面统计问题，已修复并复核。
  通过 Debug 分别直达三栏，Device Hub 实际看到原生账户页、默认头像、配对入口、状态双层分段/小组件预览，以及设置中的主题/语言/开关。
  最终构建 40 已实际核对设置开关靠右，并通过 usage 链接成功打开新的原生用量弹窗，显示当前电脑报告的数据。
  简繁中文 JSON 格式和重复键检查、git diff --check 均通过；观察期间没有环境对象或导航类型断言。
- 限制/待办：这是临时入口安排；状态预览内的绘制与部分既有选项组件继续复用。未执行自动化测试，未更改用户设置值、退出/删除账户、重新配对或重新开始。
  账户切换与配对保留代码并经过静态检查，但未实际换账号或重新配对；深色模式和各设置子页面尚未逐项操作核对。
  本地构建仍使用现有二维码配对方式和原服务依赖；仅改 iOS，没有更改 Host 或其他客户端。
- 关联：C0007、C0010、C0012、C0018、C0020。

### C0022 · 2026-11-03 · 首页 Bot 行比例按参考图调整

- 原因：用户希望首页 Bot 之间的间距、头像尺寸、标题和摘要排布/字号接近 Grok Bot 参考图 1。
- 变化：按 1206×2622 参考截图测得约 240 像素的行节距，以 3× 换算为约 80 点；原行高约为 66 点。
  头像从 46 改为 48 点，上下留白从各 10 改为各 16 点，默认行高为 80 点；图文间隔 12→14 点，标题/摘要间隔 4→3 点。
  标题使用 17.5 点 semibold，摘要 15.5 点，时间 13 点；主要字号、头像和纵向留白使用 ScaledMetric，保留动态字体缩放。
  列表左边距 16→20 点、右边距 16→22 点，顶部内容边距 12 点；普通标题/摘要/已读时间分别使用系统 label/secondaryLabel/tertiaryLabel。
  时间保留完整宽度，长标题和摘要维持单行截断；保留置顶、未读、工作/审批/错误状态、电脑使用提示及点击/长按/排序功能。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Bots/BotRow.swift`、`apps/ios/Views/BotListView.swift`、`docs/guides/ios-ui-preview.md`。
- 验证：构建号 41 真机编译、签名、覆盖安装和启动成功；完成正确性、完整性和重构只读检查，git diff --check 通过。
  Device Hub 已看到新版首页布局；用户在真机查看后确认“已完美 ok了”。
- 限制/待办：尺寸为默认文字大小下的点值；大字体会随系统缩放。不同头像轮廓的可见面积不同，并非逐像素复制参考图。
  未执行自动化测试，未更改 Bot 数据、聊天内容或其他页面布局。
- 关联：C0007、C0014、C0020、C0021。

### C0023 · 2026-11-03 · 首页顶部恢复柔和的渐进模糊过渡

- 原因：用户对比滚动截图，反馈 iOS 27 默认导航栏边缘出现硬分界，希望恢复图 4 中 iOS 26 风格的渐进模糊。
- 变化：在首页 List 显式调用 `.scrollEdgeEffectStyle(.soft, for: .top)`，使用系统柔和滚动边缘效果。
  仅指定首页顶部，不叠加自绘模糊层、不使用私有 API，也不改变底部工具条或其他页面。
- 文件：`apps/ios/Views/BotListView.swift`、`docs/guides/ios-ui-preview.md`。
- 验证：查阅 Apple WWDC26《Modernize your UIKit app》关于 iOS 27 automatic 样式变化的说明，并在本机 SDK 核对 soft 及 scrollEdgeEffectStyle 自 iOS 26 起可用。
  与 C0022 一同以构建号 41 编译、签名、安装和启动成功；镜像未能通过鼠标拖动列表，已请用户在手机滑动核对，用户随后确认“已完美 ok了”。
- 限制/待办：效果由系统渲染，会受系统外观与辅助功能设置影响；未做自动化滚动截图或深色模式逐项比对。
- 关联：C0022。

### C0024 · 2026-11-03 · 新建 Bot 使用原生表单，头像形状改用短线选中标记

- 原因：用户希望新建 Bot 页面继续采用 iOS 原生组件，头像形状的选中圆圈过于拥挤，要求改为下方短线并保留颜色圆环。
- 变化：新建 Bot 改为 NavigationStack、Form/Section、系统导航栏关闭和创建按钮，名称使用原生输入行，多电脑使用 navigationLink Picker。
  保留原来的默认智能体、离线提示、保存与错误处理；保存中禁止编辑与交互关闭，避免重复提交。
  新建群聊共用该容器，导航与分组同步更新，成员选择、默认群名和创建逻辑保留。
  头像形状改为下方 12×3 点 Capsule，未选中项保留透明占位以免布局跳动；颜色仍用圆环，点击区域至少 44×44 点。
  共享头像选择器使既有 Bot 的头像编辑也同步使用短线。Debug 新增仅打开新建页的启动入口，不自动提交。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Bots/NewBotView.swift`、`AvatarPicker.swift`；
  `apps/ios/Views/BotListView.swift`、`docs/guides/ios-ui-preview.md`。
- 验证：构建号 42 真机编译、签名、覆盖安装和启动成功，正确性、完整性与重构三项只读检查未发现确认问题，git diff --check 通过。
  真机带预览参数启动成功；Device Hub 的 Computer Use 接口重复超时，重置连接后仍未取得页面截图，因此未完成视觉核对。
- 限制/待办：未执行自动化测试，未实际创建 Bot 或群聊，也未逐项操作多电脑选择、离线及错误状态。
  头像点阵仍复用原组件；仅容器和控件采用系统表单，不改变头像资源或电脑协议。
- 关联：C0017、C0019、C0023。

### C0025 · 2026-11-03 · 列表删除 Bot 改为原生确认弹窗

- 原因：用户反馈列表删除确认仍是巨大的自绘按钮，标题夹杂英文，希望采用 iOS 原生样式。
- 变化：将列表删除入口的 codyncDialog 替换为系统 alert，使用 destructive 删除与 cancel 取消角色。
  标题通过 `Delete {name}?` 模板本地化，补齐简繁中文；Bot 与群聊分别保留原有说明和删除按钮文案。
  用 presenting 捕获当前项目，确认后仍调用对应电脑的原删除逻辑，取消不发送删除。
  Debug 新增只展示确认框的启动入口，该模式下即使点击删除也会拦截，普通启动和发布构建不受影响。
- 文件：`apps/ios/Views/BotListView.swift`；`apps/ios/Kit/Sources/CodyncKit/Resources/Languages/zh-Hans.json`、`zh-Hant.json`；
  `docs/guides/ios-ui-preview.md`。
- 验证：包含在构建号 42 中，编译、签名、安装、带确认框预览参数启动成功；三项只读检查未发现确认问题。
  简繁中文 JSON 格式、重复键和姓名占位检查通过，git diff --check 通过。
- 限制/待办：Device Hub Computer Use 接口超时，未取得最终确认框截图；没有实际删除任何 Bot 或群聊，未执行自动化测试。
  本次只调整首页列表删除确认，不批量改动其他删除入口；完成后已恢复不带预览参数的普通启动。
- 关联：C0024。

> 补记说明：以下 C0026–C0029 是事后补记。这批改动（构建号 43，2026-11-03 12:46–12:50）先前已实际完成并通过编译，但未及时写入本文件；现依据工作区实际 diff 与构建产物补记，不改变代码。C0001–C0025 已覆盖同一批文件中更早的变化，本组仅记录上一记录之后新增的行为。

### C0026 · 2026-11-03 · 列表与聊天改用原生菜单，新增长按对话预览

- 原因：多处菜单仍是自绘或只支持一层子菜单，长按机器人行没有预览；希望更贴近系统原生外观与交互。
- 变化：`MenuItem` 的子菜单由“只允许一层、更深层会断言失败”改为**递归渲染原生系统菜单**，可用多层 `More ▸`；新增 `contextActions(preview:items:)`，在长按系统菜单上方显示独立、只读的对话预览。
  首页机器人行长按改用该预览（新增 `BotMenuPreview`，刻意不进入 `ThreadView`，避免长按被当作已读而误标）；行菜单把更多操作收进 `More` 子菜单，仍保留标为已读/未读、置顶、新建分区、分享为模板、隐藏、复制 ID、编辑、移到分区、设为 Lead、删除等全部动作。
  聊天右上角由电脑显示器按钮改为系统“···”更多菜单：保留“查看电脑屏幕”（机器人操作电脑时改为“查看正在操作的电脑屏幕”并继续传 watching botId），并把原标题下的连接状态与主机名移入该菜单，移除旧屏幕按钮与连接副标题。
- 文件：`apps/ios/Kit/Sources/CodyncUI/MenuItem.swift`、`Bots/BotMenuPreview.swift`、`Thread/ThreadView.swift`、`apps/ios/Views/BotListView.swift`。
- 验证：构建号 43 真机编译、签名、覆盖安装成功（`build/ios-device.log` 为 BUILD SUCCEEDED）。按用户此前要求未做完整交互测试；Device Hub 可镜像但点击无响应。
- 限制/待办：聊天“更多”里屏幕项文字为硬编码中文，未走 `L10n`；长按预览与多层子菜单的实际点按效果待真机确认。
- 关联：C0016、C0017。

### C0027 · 2026-11-03 · 首页 Bot 行比例调整并新增“手动未读”

- 原因：让首页行距/头像/字号贴近 Grok Bot 参考图；并为不提供“标为未读”操作的旧电脑端补一个仅本机的未读提醒。
- 变化：`BotRow` 头像 46→48 点，上下留白 10→16、行距 4→3，标题 17.5、摘要 15.5、时间 13 点，主要尺寸用 `ScaledMetric` 保留动态字体；列表左右边距 16→20/22、顶部内容边距 12 点，标题/摘要/时间改用系统 label/secondaryLabel/tertiaryLabel。
  新增 `ManualUnreadMarks`：仅设备端、按 account/computer/bot 记录，存入 `AppStorage` 的 JSON；行尾显示未读圆点，长按菜单可“标为未读/已读”，进入会话时清除。**不改动电脑端的未读计数**。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Bots/BotRow.swift`、`Bots/ManualUnreadMarks.swift`、`apps/ios/Views/BotListView.swift`。
- 验证：构建号 43 编译、签名、覆盖安装成功；行比例效果在此前构建号 41 已由用户确认“已完美 ok了”。
- 限制/待办：未执行自动化测试；手动未读是旧 Host 的兜底，不同步到其他设备。
- 关联：C0022。

### C0028 · 2026-11-03 · 扩展页与相关弹窗改为原生导航/原生表单

- 原因：扩展页仍是自绘页头、搜索框、关闭按钮与卡片，左右 44 点留白偏宽；希望统一成系统原生导航与表单，并顺带修正安装连接器的重复提交与离线处理。
- 变化：`MarketplaceView` 改为独立 `NavigationStack`，标题、凭证、圆形关闭移入原生工具栏，搜索改为 `.searchable`（连接器输入停止 300ms 后重载），智能体/连接器/技能改为系统分段 `Picker`，内容左右边距 44→20；已安装页改为 `navigationDestination` 推入并显式 `.environment(model)`。
  新增通用原生弹窗/表单容器 `NativeExtensionSheet` 与 `NativeFormSection`；安装连接器、新建技能、技能详情、自定义连接器、Composio 视图、连接请求卡、智能体详情、设置终端、创建模板（`BotTemplateView`）等改用该容器与 `Form`/`Picker(.navigationLink)`；安装逻辑补 `saving` 防重入、`defer` 复位与离线报错。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Marketplace/` 下 `MarketplaceView`、`NativeExtensionSheet`、`InstallConnectorSheet`、`NewSkillSheet`、`SkillSheet`、`CustomConnectorSheet`、`ComposioViews`、`ConnectionRequestCard`、`AgentBrings`、`AgentSheet`、`InstalledView`、`SetupTerminal`、`MarketplaceTabs`；`apps/ios/Kit/Sources/CodyncUI/Bots/BotTemplateView.swift`。
- 验证：构建号 43 真机编译、签名、覆盖安装成功；此前构建号 38 的扩展页原生样式已在 Device Hub 看过。编译通过不等于交互通过。
- 限制/待办：仅处理扩展入口、已安装页导航及上述弹窗；智能体目录网格、安装详情、凭证等二级页面保留既有实现；未逐项点按验证搜索、关闭、安装、卸载与凭证修改。
- 关联：C0020。

### C0029 · 2026-11-03 · 聊天气泡与引用改用 Bot 主题色

- 原因：用户消息气泡与引用希望体现当前 Bot 的主题色，同时保证白色正文仍可读。
- 变化：新增 `ChatAccent`，取机器人头像调色板并按亮度逐级降低到白色文字可读的阈值；用户消息气泡的背景、文字与引用行改用该色；`ChatRow` 的相等比较纳入 `avatarColor`，避免换色后列表不刷新。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Thread/ChatAccent.swift`、`Thread/ChatRows.swift`。
- 验证：构建号 43 真机编译、签名、覆盖安装成功；未逐条消息截图核对。
- 限制/待办：只改用户消息气泡外观，不影响系统/机器人消息；深色模式观感待用户确认。
- 关联：C0022。

### C0030 · 2026-11-03 · 首页底部插件图标与搜索框改为透明玻璃

- 原因：用户指出首页底部左侧插件按钮与右侧搜索框不是透明的（叠了一层实心浅灰填充），要求像 Grok Bot 参考那样透出背景。
- 变化：`HomeBottomBar` 去掉插件圆形按钮与搜索胶囊上的不透明填充 `Palette.bubbleAgent`，只保留系统 `glassEffect` 玻璃；`SearchField` 新增 `opaqueBackground` 参数（默认 `true`，`FolderPicker`/`TimeZonePicker` 两处不受影响），底栏传 `opaqueBackground: false`，让搜索胶囊不再自带底色。
- 文件：`apps/ios/Views/HomeBottomBar.swift`、`apps/ios/Kit/Sources/CodyncUI/Controls.swift`。
- 验证：构建号 44 真机编译、签名、覆盖安装、启动成功；真机截图确认底部图标与搜索框已为玻璃透明（不再实心灰），首页 bot 列表正常加载。最终观感待用户在手机上确认。
- 限制/待办：底栏仍用 `safeAreaInset` 占位，列表内容不会滚到栏下方，浅色背景下玻璃接近白色；若要像 Grok 那样“内容从栏后滚过”的半透效果，需改为 overlay + 底部内边距。仅改 iOS。
- 关联：C0007、C0008、C0013、C0014。

### C0031 · 2026-11-03 · 头像弹窗改版：去三段、标题改「设置」、状态改为二级页

- 原因：用户觉得头像弹窗把「账户 / 状态 / 设置」三段塞在一起太拥挤；希望标题改为「设置」、去掉分段，账户块保留在顶部，设置直接在一级页往下排，「状态」改成单独的第二级页。
- 变化：`AccountSwitcherView` 由「顶部分段 + 三层叠加」改为单个 `Form`，自上而下为：账户资料（头像/本地账户/二维码配对提示）→ 扫描配对码 → 电脑 → **新增「状态」导航行** → 原设置各段（外观/语言/思考详情/快捷指令/通知/分析/评价反馈版本源码/重新开始）；标题固定为「设置」，右上角保留关闭。
  `AccountProfileView`、`SettingsView` 由各自的 `Form` 改为仅提供 Section（外层改 `Group`），以便合并进同一页；「状态」用 `NavigationLink` 推入二级页（`StateTab`，保留小组件/实时活动/灵动岛内层分段）。`StateTab` 的「用量限制」按钮由 `topBarLeading` 改到 `topBarTrailing`，避免与推送页返回按钮冲突。debug/深链 `CODYNC_ACCOUNT_PANE=state`、`codync://usage` 改为监听 `accountPane` 变化后推入状态页并复位。
- 文件：`apps/ios/Views/AccountSwitcherView.swift`、`apps/ios/Views/SettingsView.swift`、`apps/ios/Views/RootView.swift`。
- 验证：构建号 46 真机编译、签名、覆盖安装、启动成功；真机截图确认一级页标题「设置」、账户块在顶部、含「状态」入口、设置各段向下排列；二级「状态」页可正常推入，带返回按钮与右上用量按钮、小组件画廊正常。最终观感待用户确认。
- 限制/待办：仅改头像弹窗的信息架构与导航，账户内各动作（配对/退出/删除）逻辑不变；未改其它客户端；深色模式与各设置子页未逐项点按。
- 关联：C0021、C0007。

### C0032 · 2026-11-03 · 设置页合并入口、删除关于链接、版本十连点显露「重新开始」

- 原因：用户要求按 Grok 把「通知/外观/语言」合成一张原生卡，「对话/用量分析」合成一张，删除 App Store 评分/报告问题/源代码，并把「重新开始」做成防误触（连点版本号 10 次才出现），图标改红与文字一致。
- 变化：设置一级页改为两组原生卡：① 通知 + 外观(主题) + 语言(应用语言)；② 对话(显示思考细节) + 用量分析(分享使用分析)。删除「在 App Store 评分 / 报告问题 / 源代码」三项；保留「应用版本」行，连续点击 10 次（两次间隔超过 2 秒重新计数）后以动画显露「重新开始」，图标与文字统一红色（destructive + `foregroundStyle(.red)`）。`AppearanceSettings`、`LanguageSettings`、`ThinkingDetailsSettings` 由「各自 Section」改为「裸行」以便合并进同一卡。
- 文件：`apps/ios/Views/SettingsView.swift`、`apps/ios/Views/AppearanceSettings.swift`、`apps/ios/Views/LanguageSettings.swift`、`apps/ios/Kit/Sources/CodyncUI/Thread/ThinkingDetailsSettings.swift`。
- 验证：构建号 47 真机编译、签名、覆盖安装、启动成功；真机截图确认「通知 / 主题 / 应用语言」已合并为一张原生卡，其下为「对话 / 用量分析」卡。十连点显露与删除项效果待用户在真机确认。
- 限制/待办：「重新开始」只在本次打开弹窗内显露（关闭重开恢复隐藏）；连点阈值 10 次、2 秒窗口为固定值；未改其它客户端；深色模式未逐项核对。
- 关联：C0031。

### C0033 · 2026-11-03 · 头像页账户区合并为 Grok 式卡片，新增本机可编辑资料与「保管库」

- 原因：用户要按 Grok 把「头像+名称/说明 + 扫描配对码 + 电脑 + 状态」合成一个分类卡，并新增「保管库」（等同扩展页左侧的凭证按钮），且头像/名称/说明可手动修改、仅存本机、用 iOS 原生组件。
- 变化：账户资料区由多个 Section 合并为**一张原生卡**——顶部「头像 + 名称 + 说明」行（点按进入编辑），其下依次为 扫描电脑上的配对码 / 电脑 / 状态 / 保管库；「状态」由原独立 Section 移入该卡。
  新增 `LocalProfile`（名称/说明存 `UserDefaults`，头像压缩为 JPEG 存 Application Support，仅本机、不上传）与 `ProfileEditView`（原生 `Form`：`PhotosPicker` 选照片/移除照片、名称、说明、完成按钮，实时写入本机）。
  「保管库」用 `.codyncSheet` 弹出 `CredentialsView().environment(currentStore)`，即扩展页左上凭证功能页；为在 App 层复用，把 `CredentialsView` 改为 `public` 并加 `public init()`。
- 文件：`apps/ios/Views/AccountSwitcherView.swift`、`apps/ios/Kit/Sources/CodyncUI/Marketplace/ConnectionRequestCard.swift`。
- 验证：构建号 48 真机编译、签名、覆盖安装、启动成功；真机截图确认账户区已是一张卡（头像/本地账户/编辑名称与说明 → 扫描配对码/电脑/状态/保管库），其下为合并后的通知外观语言卡、对话用量分析卡、应用版本。资料编辑页与保管库弹窗的实际交互待用户真机确认。
- 限制/待办：资料仅存本机、不随账户同步；未登录时名称默认「本地账户」、说明占位「编辑名称与说明」；保管库需已连接一台电脑（无电脑时该行禁用）；仅改 iOS。
- 关联：C0031、C0020。

### C0034 · 2026-11-03 · 账户卡去图标改名、凭证加副标题、新增「连接应用」入口、头像缩小

- 原因：用户要求去掉账户卡各行的前置图标；头像再缩小一点（先缩小 4）；文案改为「配对 / 电脑 / 状态 / 凭证」；「凭证」加副标题「可以使用的登录信息、卡片和联系信息」；并在下面单独开一个「连接应用 / 搜索插件」列表，跳转到首页扩展页。
- 变化：账户卡各行去掉前置图标（配对 / 电脑 / 状态 / 凭证）；头像 48→44 点；「扫描电脑上的配对码」改为「配对」，「保管库」改为「凭证」并加副标题。新增独立 Section「连接应用 / 搜索插件」，点击以 sheet 打开 `MarketplaceView().environment(currentStore)`（即首页扩展页）。无电脑时「凭证」「连接应用」两行禁用。
- 文件：`apps/ios/Views/AccountSwitcherView.swift`。
- 验证：构建号 49 真机编译、签名、覆盖安装、启动成功；真机截图确认账户卡无图标、文案为 配对/电脑/状态/凭证、凭证带副标题、头像缩小，下方新增「连接应用 / 搜索插件」入口。
- 限制/待办：「连接应用」「凭证」需已连接一台电脑；仅改 iOS；深色模式未核对。
- 关联：C0033。

### C0035 · 2026-11-03 · 修复「设置页里点配对/凭证/连接应用会退回首页」

- 原因：C0033 把账户区并进外层 `Form` 后，「配对 / 凭证 / 连接应用」三个 `.codyncSheet` 被挂在了 Form 内部的行级视图（`AccountProfileView`）上。从 Form/List 的行内去 present 原生 sheet，呈现锚点会随行重建失效，导致内层 sheet 一出现就把外层设置页一起顶掉、退回首页。
- 变化：把 `showPairing`、`showVault`、`showExtensions` 三个状态上提到 `AccountSwitcherView`，三个 `.codyncSheet` 改挂到稳定的 `Form` 上（等价于 C0021 时期可正常配对/弹窗的层级）；`AccountProfileView` 改为接收三个 `@Binding`，按钮只置位、不再自己 present。
- 文件：`apps/ios/Views/AccountSwitcherView.swift`。
- 验证：构建号 50 真机编译、签名、覆盖安装、启动成功；真机已见「凭证」sheet 叠加在设置 sheet 之上正常显示，未再退回首页。配对/连接应用待用户逐一点按确认。
- 限制/待办：未改动其它 sheet；仅改 iOS。
- 关联：C0033、C0034。

### C0036 · 2026-11-03 · 「电脑」改为叠加在设置页上的二级 sheet（电脑管理）

- 原因：用户觉得「电脑」行原来会先关掉设置、跳到首页再打开电脑管理，单独呈现出有点丑；希望也像其它二级页一样放进 sheet。
- 变化：账户卡「电脑」行由 `ComputerFilterHeader`（下拉筛选菜单；点击时关设置 + 根级打开电脑管理）改为普通行按钮——显示「电脑 + N 台已连接 + ›」，点击以 `.codyncSheet(isPresented: $showComputersSheet) { ComputersView() }` 叠在设置页之上打开「电脑管理」。其开关状态与配对/凭证/连接应用一起上提到 `AccountSwitcherView` 的 `Form`（稳定锚点）。
- 文件：`apps/ios/Views/AccountSwitcherView.swift`。
- 验证：构建号 51 真机编译、签名、覆盖安装、启动成功；真机截图确认「电脑管理」作为二级 sheet 叠加在设置页之上正常显示，未再关设置/回首页。
- 限制/待办：「电脑」行不再提供原下拉菜单的“筛选对话/重连”（这些属首页 roster 的筛选；电脑管理详细操作在二级页内）；仅改 iOS。
- 关联：C0034、C0035。

### C0037 · 2026-11-03 · 电脑管理页改为原生 Form/Section 与原生控件

- 原因：用户发现「电脑管理」页仍是自绘（`CardForm/CardSection/RowLabel/DropdownMenu` 与自定义开关），要求改成原生组件。
- 变化：顶层 `CardForm`→`Form`；`CardSection`→`Section`（含 footer 段落与「已隐藏的 Bot」段落）；行内 `RowLabel`→`Label`（扩展/语音/屏幕/网络/移除）；推送通知行 `RowLabel`→`Label` 且 `.toggleStyle(.codync)`→`.toggleStyle(.switch)`；连接方式由 `DropdownMenu` 改为原生 `Picker(...).pickerStyle(.menu)`；隐藏 Bot 的 `IconButton`→原生按钮；「配对电脑」按钮保留原生 `Label`。
- 文件：`apps/ios/Views/ComputersView.swift`。
- 验证：构建号 52 真机编译、签名、覆盖安装成功；页面结构与行控件已改为系统原生（自动截图未成功，最终视觉待用户真机确认）。
- 限制/待办：`ComputerRows` 的 summary 上下文菜单/颜色面板、语音/网络二级 sheet 仍沿用原实现；页头沿用 `.page`（ModalHeader）；仅改 iOS。
- 关联：C0036。

### C0038 · 2026-11-03 · 首页下拉唤醒取景，一键「贴图」给主 Bot

- 原因：用户想把旧 App（Halfsaid/半句）里「首页下拉 → 灵动岛取景 → 拍照」的设计搬进 Codync，但简化：下拉唤醒取景 → 点「贴图」→ 跳到主 Bot 输入框贴为附件（不做保存/预览/Live Photo/拾遗）。
- 变化：新增 `QuickCapture.swift`——`QuickCamera`（AVCapture 静图 + 前后台启停 + 权限）、`QuickCameraPreview`（实时预览层）、`QuickCaptureModel`（下拉状态/开合/拍照）、`QuickCaptureOverlay`（顶部灵动岛式取景卡，含「贴图」/「✕」/无权限提示）。
  `BotListView` 首页列表：`onScrollGeometryChange` 判定在顶部 + `DragGesture` 竖直下拉过 72pt → 弹出取景卡；点「贴图」抓当前帧转 JPEG → `BotStore.attachPendingFile` 存到当前电脑的 **lead bot（星标主 Bot，无 lead 退列表第一个）** → `accounts.selection` 跳到该 Bot；`Composer.onAppear` 消费待贴附件放进输入框（**不自动发送**）。新增 `BotStore.pendingComposerFiles` 与 `attachPendingFile`/`takePendingFiles`。
- 文件：`apps/ios/Views/QuickCapture.swift`（新）、`apps/ios/Views/BotListView.swift`、`apps/ios/Kit/Sources/CodyncUI/Store/BotStore.swift`、`Store/BotStore+Sending.swift`、`Thread/Composer.swift`；`apps/Codync.xcodeproj` 由 XcodeGen 重新生成。
- 验证：构建号 53 真机编译、签名、覆盖安装、启动成功、无崩溃，首页正常。下拉手势/取景/贴图的实际交互待用户真机确认（无法远程下拉）。
- 限制/待办：仅静图，不做 Live Photo/保存/拾遗；相机权限沿用 Info.plist 既有相机用途描述；主 Bot 取当前电脑 lead；下拉阈值、卡片尺寸与动画可再调；仅改 iOS。
- 关联：C0037、C0007。

### C0039 · 2026-11-03 · 收紧下拉取景卡为小号灵动岛并修复相机权限

- 原因：C0038 的取景浮层占满整屏、贴图按钮过大，且下拉开卡时未先请求相机权限就 `start()`，导致取景区黑屏；用户反馈太占地方。
- 变化：`QuickCaptureOverlay` 改为约 208×236 的**居中灵动岛卡**（不再全宽、不再忽略安全区，落在工具栏下方）；「贴图」改为紧凑白色胶囊，`✕` 缩小；下拉过阈值时先 `await requestAccess()` 再 `start()`（修黑屏）；开卡阈值 64。
- 文件：`apps/ios/Views/QuickCapture.swift`。
- 验证：构建号 54 真机编译、签名、覆盖安装、启动成功；下拉取景/贴图交互待用户真机确认（无法远程下拉）。
- 限制/待办：卡片尺寸/触发阈值/动画仍可再微调；仅改 iOS。
- 关联：C0038。

### C0040 · 2026-11-03 · 下拉取景改为「底部上滑召出原生 sheet 相机」

- 原因：用户觉得自绘灵动岛实现复杂且占位，决定改成 iOS 原生 `.sheet`（从底部滑上来），内含系统感相机与圆形快门，拍完直接贴给主 agent。
- 变化：首页不再用下拉自绘取景（`QuickCaptureOverlay` 保留但不再挂在首页）；新增 `QuickCaptureSheet`（原生 sheet + AVCapture 实时预览 + 圆形快门 + `✕` + 权限处理）。`BotListView` 在底部插件条上方加一个小把手：**上滑 >24pt 或点按** → 以 `.sheet` + `.presentationDetents([.large])` + 拖动指示 弹出相机；按快门拍摄 → `attachCapturedPhoto` 关闭 sheet → 把 JPEG 作为附件贴到当前电脑 **lead Bot（星标主 agent）** 的输入框并跳转（不自动发送）。保留 `CODYNC_QUICKCAPTURE` debug 直达。
- 文件：`apps/ios/Views/QuickCapture.swift`、`apps/ios/Views/BotListView.swift`。
- 验证：构建号 55 真机编译、签名、覆盖安装、启动成功；真机截图确认弹出原生 sheet 相机、实时预览、圆形快门与关闭按钮。拍摄→贴附件的实际动作待用户真机确认（无法远程按快门）。
- 限制/待办：仅静图；主 Bot 取 lead；sheet 用 `.large`；`✕` 走 dismiss；仅改 iOS。
- 关联：C0038、C0039。

### C0041 · 2026-11-03 · 相机 sheet 改半屏（.medium）

- 原因：用户要求相机 sheet 先改半屏；首页那条上滑把手「小横条」的观感另行处理。
- 变化：`BotListView` 相机 `.sheet` 的 `presentationDetents` 由 `[.large]` 改为 `[.medium]`——半屏、带系统抓手、可下滑关闭。
- 文件：`apps/ios/Views/BotListView.swift`。
- 验证：构建号 56 真机编译、签名、覆盖安装、启动成功；截图确认半屏 sheet、实时取景、圆形快门、✕ 均正常（相机首帧约需 1–2 秒才出画面）。
- 限制/待办：首页上滑把手「小横条」观感待用户后续处理；仅静图；仅改 iOS。
- 关联：C0040。

### C0042 · 2026-11-03 · 首页底栏加相机按钮、搜索栏收窄，去掉上滑小横条

- 原因：用户觉得首页那条上滑把手「小横条」不雅；改为在搜索栏右侧加一个相机按钮（与左侧扩展按钮对称），点击弹出半屏相机 sheet。
- 变化：`HomeBottomBar` 增加 `openCamera` 与右侧相机圆钮（glass 圆形，风格同扩展按钮），搜索栏因此收窄；`BotListView` 底部改为 `HomeBottomBar(searchText:openCamera:openPlugins:)`，移除上滑把手小横条。
- 文件：`apps/ios/Views/HomeBottomBar.swift`、`apps/ios/Views/BotListView.swift`。
- 验证：构建号 57 真机编译、签名、覆盖安装、启动成功；截图确认底栏为「扩展 · 搜索(窄) · 相机」三件套、无小横条；点相机弹半屏相机 sheet（沿用 C0040/C0041）。拍摄→贴附件整体流程待用户确认。
- 限制/待办：仅改 iOS；相机按钮/搜索栏尺寸可再微调。
- 关联：C0040、C0041、C0007。

### C0043 · 2026-11-03 · 相机底部改为「返回 / 快门 / 更多」三键（ChatGPT 式）

- 原因：用户要求照 ChatGPT 相机：加返回、加更多（空占位），原生按钮 44pt；快门内 52 白圆、外 56 玻璃框，底部距 sheet 12px。
- 变化：`QuickCaptureSheet` 底部改为 HStack：左返回（`chevron.left`，44 玻璃圆，dismiss）、中快门（56 玻璃圆框 + 52 白圆）、右更多（`ellipsis`，44 玻璃圆，空 `Menu` 占位）；底部 padding 12；移除原右上 ✕。
- 文件：`apps/ios/Views/QuickCapture.swift`。
- 验证：构建号 58 真机编译、签名、覆盖安装、启动成功；截图确认三键布局、半屏、实时取景。
- 限制/待办：更多菜单为空占位；仅静图；仅改 iOS。
- 关联：C0040、C0041、C0042。

### C0044 · 2026-11-03 · 相机底部更贴底、收紧间距、快门 64

- 原因：用户反馈底部偏高、返回/更多离快门远、快门 56 偏小。
- 变化：底部 HStack 改固定间距 44（居中，返回/更多贴近快门）；底部内边距 12→8，并 `.ignoresSafeArea(.container, edges: .bottom)` 让控制贴近 sheet 底边；快门外 56→64、内 52→60。
- 文件：`apps/ios/Views/QuickCapture.swift`。
- 验证：构建号 59 真机编译、签名、覆盖安装、启动成功；截图确认三键更贴底、间距收紧、快门变大。
- 限制/待办：更多空占位；数值可再调；仅改 iOS。
- 关联：C0043。

### C0045 · 2026-11-03 · 相机底部：返回/更多外扩、快门内圈 54、底部 24

- 原因：用户要返回/更多往外扩（不再太靠里）、快门内圈 54（外 64 不变）、底部间距 8→24。
- 变化：底部 HStack 改 `Spacer(minLength: 24)` + 水平内边距 36（返回/更多靠外）；底部 padding 24；快门内圈 60→54（外 64 不变）。
- 文件：`apps/ios/Views/QuickCapture.swift`。
- 验证：构建号 60 真机编译、签名、覆盖安装、启动成功；截图确认返回/更多外扩、快门内 54、底部间距 24。
- 限制/待办：数值可再调；仅静图；仅改 iOS。
- 关联：C0044。

### C0046 · 2026-11-03 · 相机 sheet 支持半屏/全屏两档，可拖动拉满

- 原因：用户想按住抓手在半屏/全屏间切换。
- 变化：`BotListView` 相机 `.sheet` 的 `presentationDetents` 由 `[.medium]` 改为 `[.medium, .large]`（保留拖动指示），可上拉拉满、下拉回半屏。
- 文件：`apps/ios/Views/BotListView.swift`。
- 验证：构建号 61 真机编译、签名、覆盖安装、启动成功。
- 限制/待办：仅改 iOS。
- 关联：C0041。

### C0047 · 2026-11-03 · 换成半句 App 图标并把 App 改名为「半句」

- 原因：用户删掉了旧半句 App，要求把半句的图标搬进当前工程、App 改名为「半句」，作为「半句第二次生命」重新开始。
- 变化：把 Halfsaid（v5.0.0）的 `AppIcon.appiconset`（`AppIcon-Light.png`、`AppIcon-Dark.png` 两个 1024 + `Contents.json`）覆盖到 `apps/ios/Resources/Assets.xcassets/AppIcon.appiconset`，删除旧 `image.png`；构建时 `CODYNC_APP_NAME=半句`，App 显示名「半句」，产物 `半句.app`。Bundle ID 仍为 `com.suiyikou.codync.uipreview`（沿用现有描述文件与免费名额）。
- 文件：`apps/ios/Resources/Assets.xcassets/AppIcon.appiconset/{AppIcon-Light.png,AppIcon-Dark.png,Contents.json}`（来自 Halfsaid 仓库）。
- 验证：构建号 62 真机编译、签名、覆盖安装、启动成功；`devicectl` 已装列表显示名称「半句」；产物图标 `AppIcon` 经核对为半句图标。主屏图标最终观感待用户确认。
- 限制/待办：Bundle ID 未改（仍 uipreview）；显示名通过构建覆盖（若日后不经指定命令构建，需在 `project.yml` 固定 `CODYNC_APP_NAME`）；仅改 iOS。
- 关联：无（沿用品牌重开）。

### C0048 · 2026-11-03 · 电脑管理页行改为原生（去图标 + 箭头），连接改半屏 sheet

- 原因：用户觉得「设置 → 电脑」点进去的 sheet 仍非原生：设置行前面有图标、没有箭头；连接是下拉菜单。希望用原生组件并改成半屏 sheet。
- 变化：`ComputerRows` 各行（扩展 / 语音 / 屏幕 / 网络）改为「文字 + 右侧箭头」、去掉前置图标；推送通知去掉铃铛图标（原生 `Toggle`）；Codync 版本行去掉前置箭头图标；移除行去掉垃圾桶图标；「配对一台电脑」改为文字 + 箭头。连接由 `Picker(.menu)` 改为按钮行（右侧显示当前路由 + 箭头），点击在 Form 稳定锚点弹出 **`.sheet` 半屏 `ConnectionRouteSheet`**（列出可选路由、当前项打勾、点选即保存并关闭）。
- 文件：`apps/ios/Views/ComputersView.swift`。
- 验证：构建号 64 真机编译、签名、覆盖安装、启动成功；截图确认电脑管理页为原生行（无前置图标、有箭头、原生开关、连接带当前值 + 箭头）。连接半屏 sheet 的交互待用户点按确认。
- 限制/待办：页头仍用 App 的 `ModalHeader`（齿轮 + 标题 + ✕）；「语音 / 网络」二级仍走原 `codyncSheet`；仅改 iOS。
- 关联：C0037、C0036、C0007。

### C0050 · 2026-11-03 · 【全原生化 第1批】AnalyticsSheet / ArtifactRenameSheet / NetworkSheet 改原生

- 原因：用户要求把剩余所有自绘 UI 全部原生化（原生 sheet + 原生列表，去图标/补箭头），分批处理。
- 变化：`AnalyticsSheet`、`ArtifactRenameSheet`、`NetworkSheet` 由「ModalHeader + CardForm/CardSection」改为「NavigationStack + Form/Section」原生导航栏（系统标题 + 关闭按钮）；Analytics 去掉每项前置图标；Network 用 Section/LabeledContent。
- 文件：`apps/ios/Kit/Sources/CodyncUI/AnalyticsSheet.swift`、`Artifacts/ArtifactRenameSheet.swift`、`NetworkSheet.swift`。
- 验证：构建号 67 编译、签名、装机成功。
- 限制/待办：全原生化仍在进行，后续批次继续。
- 关联：全原生化总任务（goal）。

### C0051 · 2026-11-03 · 【全原生化 第2批a】MemoryInfoSheet / MemoryFileView 改原生

- 原因：全原生化继续（见 goal）。
- 变化：`MemoryInfoSheet`、`MemoryFilesView.swift` 里的 `MemoryFileView`（查看笔记）由「ModalHeader + CardForm/CardSection」改为「NavigationStack + Form/Section」原生导航栏（系统标题 + 关闭）；去掉每项前置图标。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Bots/MemoryInfoSheet.swift`、`Bots/MemoryFilesView.swift`。
- 验证：构建号 68 编译、签名、装机成功。
- 限制/待办：全原生化继续（GroupEditor/FolderPicker/VoiceChat/BotEditor 等下一批）。
- 关联：全原生化总任务（goal）。

### C0052 · 2026-11-03 · 【全原生化 第3批】GroupEditorView / FolderPicker 改原生导航栏

- 原因：全原生化继续（见 goal）。
- 变化：`GroupEditorView`、`FolderPicker` 由「ModalHeader 自绘页头」改为「NavigationStack 原生导航栏」（系统标题 + 关闭；群设置另有保存按钮）；内容保留。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Bots/GroupEditorView.swift`、`Bots/FolderPicker.swift`。
- 验证：构建号 70 编译、签名、装机成功。
- 限制/待办：全原生化继续（VoiceChat/BotEditor/AccessRequest/Trace/Handoff/Attachments/RoutineEditor/TimeZonePicker/CallRows/FallbackRows、codyncDialog 批、DropdownMenu 批、LibraryView/MemoryView/PluginToggles）。
- 关联：全原生化总任务（goal）。

### C0053 · 2026-11-03 · 【全原生化 第4批】TimeZonePicker / AccessRequestView 改原生导航栏

- 原因：全原生化继续（见 goal）。
- 变化：`TimeZonePicker` 改为 NavigationStack + List + `.searchable` + 原生关闭；`AccessRequestView` 改为 NavigationStack 导航栏（标题「Access」+ 关闭），去掉安全区里的 ModalHeader。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Routines/TimeZonePicker.swift`、`apps/ios/Views/AccessRequestView.swift`。
- 验证：构建号 71 编译、签名、装机成功。
- 限制/待办：全原生化继续（VoiceChat/BotEditor/Trace/Handoff/Attachments/RoutineEditor/CallRows/FallbackRows、codyncDialog 批、DropdownMenu 批、LibraryView/MemoryView/PluginToggles）。
- 关联：全原生化总任务（goal）。

### C0054 · 2026-11-03 · 【全原生化 第5批】TraceView / HandoffEditorView / AttachmentViewer / CallConversationView 改原生

- 原因：全原生化继续（见 goal）。
- 变化：`TraceView` → NavigationStack + Form/Section（原生列表 + 原生关闭）；`HandoffEditorView`（HandoffRows）→ NavigationStack + Form + 保存/关闭；`AttachmentViewer`（Attachments）→ 原生导航栏看图；`CallConversationView`（CallRows）→ 原生导航栏。
- 文件：`Thread/TraceView.swift`、`Thread/HandoffRows.swift`、`Thread/Attachments.swift`、`Call/CallRows.swift`。
- 验证：构建号 72 编译、签名、装机成功。
- 限制/待办：全原生化继续（VoiceChat/BotEditor/RoutineEditor/FallbackRows/LibraryView/MemoryView/PluginToggles、codyncDialog 批、DropdownMenu 批）。
- 关联：全原生化总任务（goal）。

### C0055 · 2026-11-03 · 【全原生化 第6批】codyncDialog 改为原生 alert

- 原因：全原生化继续；codyncDialog 原是自绘弹卡，需改原生 alert/confirmationDialog。
- 变化：直接改 `codyncDialog` modifier 的内部实现——从自绘 overlay 弹卡改为原生 SwiftUI `.alert`（支持 `DialogField` 文本框与动态按钮，destructive 映射 `.destructive`，cancel 映射 `.cancel`）。所有调用点（ComputersView/SectionNameDialog/RootView/RoutineWebhookPanel/RoutineEditor/Dialogs/CustomIconEditor/ArtifactView 等）一次性变为系统 alert。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Dialog.swift`。
- 验证：构建号 73 编译、签名、装机成功（alert 运行时按钮为原生，个别多按钮对话框待用户实际触发确认）。
- 限制/待办：`inPlace` 等旧字段保留但不再使用；其余全原生化继续。
- 关联：全原生化总任务（goal）。

### C0056 · 2026-11-03 · 【全原生化 第7批】LeadAgentInfo / AddFallbackSheet / FallbackInfoSheet 改原生

- 原因：全原生化继续（见 goal）。
- 变化：`LeadAgentInfo`（LeadAgentAvatar 内）、`AddFallbackSheet`、`FallbackInfoSheet`（FallbackRows 内）由 ModalHeader+CardForm → NavigationStack + Form/ScrollView + 原生导航栏（关闭/添加按钮）。
- 文件：`Bots/LeadAgentAvatar.swift`、`Bots/FallbackRows.swift`。
- 验证：构建号 74 编译、签名、装机成功。
- 限制/待办：全原生化继续（RoutineEditorView、BotEditorView、VoiceChatSettingsView、PluginToggles、MemoryView、LibraryView）。
- 关联：全原生化总任务（goal）。

### C0057 · 2026-11-03 · 【全原生化 第8批】RoutineEditorView 改原生导航栏

- 原因：全原生化继续（见 goal）。
- 变化：`RoutineEditorView` 由 ModalHeader → NavigationStack 原生导航栏（动态标题「Set up a routine / Edit routine」+ 关闭），内容 `ScrollView{form}` 保留。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Routines/RoutineEditorView.swift`。
- 验证：构建号 75 编译、签名、装机成功。
- 限制/待办：全原生化继续（BotEditorView、VoiceChatSettingsView、PluginToggles、MemoryView、LibraryView）。
- 关联：全原生化总任务（goal）。

### C0058 · 2026-11-03 · 【全原生化 第9批】VoiceChatSettingsView 改原生

- 原因：全原生化继续（见 goal）。
- 变化：`VoiceChatSettingsView` 由 ModalHeader+CardForm → NavigationStack 导航栏 + Form/Section；主「Voice」段与 `ProviderVoiceSettings` 的 CardSection 都改为 Section（保留 ValueRow/ChoicePicker 等行组件）。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Call/VoiceChatSettingsView.swift`。
- 验证：构建号 76 编译、签名、装机成功。
- 限制/待办：仅剩 `BotEditorView`（及内部的 BotSettingsForm / PluginToggles）待原生化；LibraryView/MemoryView/RoutinesView 在 App 中已走 nativeStyle 原生分支。
- 关联：全原生化总任务（goal）。

### C0059 · 2026-11-03 · 【全原生化 第10批a】BotEditorView 改原生导航栏

- 原因：全原生化继续（见 goal）。
- 变化：`BotEditorView` 的 ModalHeader（Settings + 保存）改为 NavigationStack 原生导航栏（标题 + 右侧保存、左侧关闭）。`BotSettingsForm` 内容暂保留（内部 CardSection 卡片待下一步精确改造）。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Bots/BotEditorView.swift`。
- 验证：构建号 77 编译、签名、装机成功。
- 限制/待办：仅剩 `BotSettingsForm` 内部 6 个 CardSection 与 `PluginToggles` 的卡片容器待转 Section（风险较高，下一步带回退保护地做）。
- 关联：全原生化总任务（goal）。

### C0060 · 2026-11-03 · 【全原生化 第10批b · 完成】BotSettingsForm / PluginToggles 改 Form/Section

- 原因：全原生化收尾。
- 变化：`BotSettingsForm` 由 ScrollView+VStack+CardSection → **Form + Section**（Profile / Agent|Workspace / Activity / Instructions 各成 Section）；`PluginToggles` 的 CardSection → Section。`BotEditorView` 上一批已换原生导航栏。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Bots/BotEditorView.swift`、`Bots/PluginToggles.swift`。
- 验证：构建号 78 编译、签名、装机、启动成功、无崩溃。
- 全局复核：`ModalHeader`=0、`CardForm`=0、`RowLabel`=0；`codyncDialog` 已原生 alert；`DropdownMenu` 本就原生 Menu。`CardSection` 仅剩 `nativeStyle=false` 死分支（MemoryView legacyContent、LibraryView legacy else；App 始终 nativeStyle:true 不渲染），可在后续清理。
- 关联：全原生化总任务（goal）——本次全原生化实际界面完成。

### C0061 · 2026-11-03 · 全原生化收尾：清除 nativeStyle=false 死分支里的 CardSection

- 变化：把 `MemoryView`（legacyContent）与 `LibraryView`（legacy else）里残留的 `CardSection` 换成 `Section`/`SwiftUI.Section`（均为 nativeStyle=false 的死分支，App 不会渲染），并更新 BotEditorView 注释。全局 `CardSection` 使用清零。
- 文件：`Bots/MemoryView.swift`、`Artifacts/LibraryView.swift`、`Bots/BotEditorView.swift`。
- 验证：构建号 79 编译、签名、装机、启动成功、无崩溃。
- 结论：全原生化完成——`ModalHeader`=0、`CardForm`=0、`CardSection`=0、`RowLabel`=0；`codyncDialog` 走原生 alert；`DropdownMenu` 原生 Menu。
- 关联：全原生化总任务（goal）完成。

### C0062 · 2026-11-03 · 长按预览卡圆角对齐 + destructive 菜单图标变红

- 原因：Grok Bot 长按「预览卡」和「功能菜单」圆角一致（视觉对得上），我们的预览卡是直角、对不上；且「隐藏」是红字但图标仍是黑色，用户要图标也红。
- 变化：`BotMenuPreview` 外层背景后加 `.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))`，把预览卡裁成连续圆角（与系统菜单圆角对齐、不再露直角边）；`MenuItem` 的 `menuLabel` 中，对 `destructive` 且带图标的项改用 `Image(systemName:).foregroundStyle(.red)`，使图标与文字同为红色。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Bots/BotMenuPreview.swift`、`apps/ios/Kit/Sources/CodyncUI/MenuItem.swift`。
- 验证：构建号 80 编译、签名、装机成功；长按菜单的实际观感待真机确认（如圆角仍需微调，可改数值 16→13/18）。
- 关联：C0060（全原生化）。

### C0063 · 2026-11-03 · 预览卡圆角按 Figma=34 + More 汉化 + destructive 图标红色增强

- 原因：用户指出预览卡圆角不是 16（iOS Figma 组件为 34），「隐藏」图标仍黑，「More」需汉化。
- 变化：`BotMenuPreview` 圆角 clipShape 由 16 → **34**（continuous，对齐 iOS 26 大圆角菜单）；zh-Hans/zh-Hant 词典补 `"More": "更多"`；`MenuItem.systemMenuAction` 对 destructive 按钮加 `.tint(.red)`，配合图标 `foregroundStyle(.red)` 力争图标与文字同红。
- 文件：`Bots/BotMenuPreview.swift`、`MenuItem.swift`、`CodyncKit/Resources/Languages/zh-Hans.json`、`zh-Hant.json`。
- 验证：构建号 81 编译、签名、装机成功；JSON 合法。长按观感待真机确认。
- 关联：C0062。

### C0064 · 2026-11-03 · 自绘长按菜单（预览卡+菜单同一 34 玻璃圆角）

- 原因：系统 contextMenu 的预览卡圆角固定约 20，无法与 iOS26 玻璃菜单的 34 对齐；必须两层一起自绘。
- 变化：新增 `CardMenuOverlay`（CodyncUI/Bots/CardMenuOverlay.swift）：长按弹出，暗色遮罩 + 预览卡(34 连续圆角, .regularMaterial 玻璃) + 菜单面板(34 连续圆角, .regularMaterial)，左对齐；行内图标/红色 destructive/更多中文/子菜单进入+返回；长按 medium 震动、点按 selection 震动、点外部关闭。`BotMenuPreview` 去掉实心背景改为透明（由 overlay 提供玻璃）。`BotListView` Bot 行由 `.contextActions` 改为 `.onLongPressGesture` 打开自绘菜单；把菜单项抽成 `botMenuItems`。
- 文件：新增 `Bots/CardMenuOverlay.swift`；改 `Bots/BotMenuPreview.swift`、`Views/BotListView.swift`；`xcodegen generate` 已重生成工程。
- 验证：构建号 82 编译、签名、装机成功。长按观感待真机确认。
- 关联：C0062、C0063。

### C0065 · 2026-11-03 · 自绘长按菜单：贴行定位 + 修复"长按无反应"

- 原因：build82 长按无反应（`Button`/拖拽 itemProvider 吞掉了 `onLongPressGesture`）；且菜单固定顶部而非贴在按下的行。
- 变化：`CardMenuState` 增加 `anchor: CGRect`；Bot 行用 `.onGeometryChange` 记录在 `.named("botlist")` 坐标系里的位置，菜单据此**贴行弹出**；Bot 行由 `Button` 改为 `onTapGesture`(选中) + `.simultaneousGesture(LongPressGesture(0.35))`(长按开菜单) + 保留 `.itemProvider`(拖动)，三者共存。
- 文件：`Bots/CardMenuOverlay.swift`、`Views/BotListView.swift`。
- 验证：构建号 83/84/85 编译、签名、装机成功；长按触发与定位待真机确认。
- 关联：C0064。

### C0067 · 2026-11-03 · 长按菜单回归原生 system contextMenu（自绘版太丑，弃用）

- 原因：自绘长按菜单观感太差（玻璃/排版不理想），用户要求换回原生。
- 变化：Bot 行恢复 `.contextActions(preview:){ botMenuItems }`（系统 contextMenu + 预览）；移除自绘 overlay 挂载与手势；`BotMenuPreview` 恢复实心背景；保留之前成果：destructive 图标红色、More 汉化、**拖动排序已移除并迁到设置→列表排序**。`CardMenuOverlay.swift` 保留但不再使用。
- 文件：`Views/BotListView.swift`、`Bots/BotMenuPreview.swift`。
- 验证：构建号 87 编译、签名、装机成功。
- 关联：C0062–C0066。

### C0068 · 2026-11-03 · 长按去掉消息预览卡，只保留菜单按钮

- 原因：用户要求移除长按的「消息预览」功能，只保留菜单按钮。
- 变化：Bot 行的 `.contextActions(preview:{...})` 改为不带 preview 的 `.contextActions { botMenuItems(...) }`（原生 contextMenu，无自定义预览卡；长按仅出现菜单）。
- 文件：`Views/BotListView.swift`（`BotMenuPreview.swift` 暂留但不再使用）。
- 验证：构建号 88 编译、签名、装机成功。
- 关联：C0067。

### C0069 · 2026-11-03 · 长按给透明 preview，去掉整行抬起/灰色圆角块

- 原因：去掉预览卡后系统以整行为预览，出现整行抬起 + 灰色圆角遮罩；用户不要。
- 变化：Bot 行 `.contextActions(preview: { Color.clear })`（透明预览，不显示预览卡也不抬整行，只出现菜单）；`.contentShape` 去掉 `.contextMenuPreview` 圆角形状。
- 文件：`Views/BotListView.swift`。
- 验证：构建号 89 编译、签名、装机成功；观感待确认。
- 关联：C0068。

### C0070 · 2026-11-03 · 长按菜单改为每行「⋯」按钮点开原生 Menu（无预览/白点/抬起）

- 原因：原生 contextMenu 无论怎么调 preview 都会带预览卡/透明白点/整行抬起，观感差；用户要求"只留按钮"。
- 变化：Bot 行移除 `.contextActions`；改在行右侧 overlay 一个 `DropdownMenu`（原生 Menu）以「⋯」为触点，点开即原生菜单列表（原生 popover，无预览）。
- 文件：`Views/BotListView.swift`。
- 验证：构建号 90 编译、签名、装机成功；观感待确认。
- 关联：C0068、C0069。

### C0071 · 2026-11-03 · 找到根因：.contextMenuPreview 形状半径=16 裁掉了预览卡；改 34 即对齐

- 原因：行上一直有 `.contentShape([.dragPreview, .contextMenuPreview], card)`，`card` 是 16 圆角——系统拿它当预览卡可见路径，所以预览被裁成 16/20，怎么 clip 都无效。
- 变化：恢复「自绘预览卡(BotMenuPreview) + 原生 contextMenu」；把 `.contentShape` 改成 `.contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 34, style: .continuous))`，预览卡与原生菜单同为 34 圆角。移除「⋯」按钮。
- 文件：`Views/BotListView.swift`。
- 验证：构建号 91 编译、签名、装机成功；观感待确认。
- 关联：C0070。

### C0072 · 2026-11-03 · 长按预览卡：整段正文最多 8 行 + 气泡 + 尺寸对齐 Grok

- 原因：`MessagePreview.text()` 只取第一行，卡片只有一行；Grok 给到 8 行并在气泡里；用户要求对齐。
- 变化：`BotMenuPreview` 改用完整 `bot.lastMessage`（轻去 markdown），`lineLimit(8)`，正文放进 22 连续圆角灰气泡（secondarySystemGroupedBackground），去掉分隔线，卡片宽 300→320。
- 文件：`Bots/BotMenuPreview.swift`。
- 验证：构建号 92 编译、签名、装机成功；像素对齐待用户确认。
- 关联：C0071。

### C0073 · 2026-11-03 · 长按预览卡深色配色：卡片 #141414、气泡 #232323

- 原因：用户指定深色模式下卡片底 #141414、气泡 #232323（浅色不变）。
- 变化：`BotMenuPreview` 加 `@Environment(\.colorScheme)`，深色时 `cardBackground=#141414`、`bubbleBackground=#232323`；浅色仍用 systemBackground / secondarySystemGroupedBackground。
- 文件：`Bots/BotMenuPreview.swift`。
- 验证：构建号 93 编译、签名、装机成功；深色观感待确认。
- 关联：C0072。

### C0075 · 2026-11-03 · 接入 Remix Icon 并全量首轮替换 SF Symbols

- 原因：用户计划用 Remix Icon 替换 Apple 原生图标。
- 变化：引入 Remix Icon 4.9.1（Apache-2.0）：`apps/ios/Resources/Fonts/`（remixicon.ttf / codepoints.json / LICENSE），Info.plist 加 `UIAppFonts`；新增 `RemixIcon` 视图与 `RemixSymbolMap`（SF 名 → Remix 名，88 条）。自动替换 167 处：`Image(systemName:)` 108、`Label(_, systemImage:)` 31、`Button/Menu(_, systemImage:)` 23、`IconButton` 与 `MenuItem` 改为经 `RemixSymbolMap` 渲染（动态名回退 SF）。
- 修复：`NavigationLink` 行重复箭头；ForEach `$0` 作用域；`AgentIcon`/WidgetSetupDemo 需要真 `Image` 处保留 SF；工具栏 `Menu` 自定义 label 会丢图标 → 保留系统加号。
- 文件：`Resources/Fonts/*`、`Resources/Info.plist`、`CodyncUI/RemixIcon.swift`、`CodyncUI/Chrome.swift`、`CodyncUI/MenuItem.swift` 及 60+ 视图文件。
- 验证：构建号 96 编译、签名、安装、启动成功；首页/设置截图确认字体渲染正常（无豆腐块）。
- 限制/待办：图标尺寸与基线尚未逐个微调（RemixIcon 默认 17pt，不随调用点 `.font` 缩放）；少数动态 `systemImage`、ContentUnavailableView 仍为 SF；待用户逐点反馈后定点替换。
- 关联：C0074。

### C0076 · 2026-11-03 · 修复图标按钮退化成文字（labelStyle(.iconOnly) 对自定义 Label 无效）

- 原因：首轮替换把 `Button(_, systemImage:)` 变成 `Label { Text } icon: {}`，而 `.labelStyle(.iconOnly)` 对自定义 Label 不生效，导致「关闭」「凭证」「分享模板」「添加定时任务」「更多」等图标按钮显示成文字。
- 变化：此类按钮统一改成 `Button { RemixIcon(...) } + .accessibilityLabel(...)`；共修 18 处（工具栏、设置关闭、重试、删除、跳到最新、重发、Added 状态等）。
- 文件：MarketplaceView、BotDetailsView、RoutinesView、RootView、AccountSwitcherView、NewBotView、InstalledView、ScreenView、ConversationList、MarketRows、ChatRows 等。
- 验证：构建号 97/98 编译、签名、安装成功；截图确认设置「关闭」为 ✕ 图标、首页「新建」为 ＋ 图标。
- 限制/待办：工具栏「新建」仍用系统 SF 加号；「电脑管理」的「关闭」是设计上的文字按钮。
- 关联：C0075。

### C0077 · 2026-11-03 · 首页三枚图标改 24pt；底部圆按钮 48→44（对齐 HIG）

- 原因：图标在圆按钮里显得偏小、撑不满；用户指出官方尺寸是 44，而首页底部是 48（本项目自定，非 Apple 规范）。
- 变化：`HomeBottomBar` 圆按钮 48→44；图标 18/17→24（10pt 内边距）；扩展按钮由手绘 `PluginGlyph` 改为 Remix `apps-2-line`；右上「新建」由系统 SF 加号改为 Remix `add-line` 24（无障碍标签保留）。
- 文件：`Views/HomeBottomBar.swift`、`Views/BotListView.swift`。
- 验证：构建号 99/100 编译、签名、安装成功；截图确认三个图标大小与圆按钮比例。
- 限制/待办：其余圆形按钮统一规则待用户确认（44→24，工具栏→20~22，行内 IconButtonStyle 36→17）。
- 关联：C0075、C0076。

### C0078 · 2026-11-03 · 底部栏三者统一 44 高 + 搜索框玻璃改 interactive

- 原因：圆按钮改 44 后与搜索框（≈50）不齐；用户还指出搜索框没有"果冻"按压反馈。
- 变化：`SearchField` 在底部栏固定 `.frame(height: 44)`（与两个 44 圆同高），去掉外层 4pt；玻璃由 `.glassEffect(.regular, in:)` 改为 `.regular.interactive()`，获得按压缩放/形变反馈。
- 文件：`Views/HomeBottomBar.swift`。
- 验证：构建号 101/102 编译、签名、安装、启动成功。
- 限制/待办：若用户说的"果冻"是指聚焦时搜索框展开/玻璃融合动画，需要给 SearchField 增加 focus 绑定 + `glassEffectID` 过渡，另行实现。
- 关联：C0077。

### C0082 · 2026-11-03 · 底部栏间距跟随键盘；键盘上沿间距 = 横向 12

- 原因：`.ignoresSafeArea(.container, .bottom)` + 28 底距在键盘弹起时仍把 home indicator 的 34 算进去，出现约 62pt 大缝；改 8 又偏小。
- 变化：键盘弹起时底距 12（与搜索框/两个圆按钮的横向 `HStack(spacing: 12)` 一致）且不忽略安全区；键盘收起时仍 28 + 忽略安全区。
- 文件：`Views/HomeBottomBar.swift`。
- 验证：构建号 110/111 编译、签名、安装成功；键盘状态观感待用户确认。
- 关联：C0078。

### C0086 · 2026-11-03 · 统一设置页行尾箭头大小（自定义 17 → 14）

- 原因：NavigationLink 行用系统箭头（约 13pt），手写行用 `RemixIcon("arrow-right-s-line")` 且 `.font(...)` 对 RemixIcon 无效（内部字号固定），导致 13/17 两种箭头并存。
- 变化：手写行的箭头改为 `RemixIcon("arrow-right-s-line", size: 14)`，与系统箭头视觉一致（settings 内 5 处）。
- 文件：`Views/AccountSwitcherView.swift`、`Views/SettingsView.swift`。
- 验证：构建号 115 编译、签名、安装成功；截图确认箭头一致。
- 限制/待办：分隔线右侧是否顶死、线宽是否变细：已调研（见下），未改。
- 关联：C0084。

### C0087 · 2026-11-03 · 建立独立 Mac 定制工作目录与开发约定

- 原因：用户开始 Mac 桌面端定制，要求保留既有 iOS 成果、其他助手的工作现场，以及官方 2.34.2 Host 与 iPhone 本地配对。
- 变化：从已提交的 iOS 定制版本 `9583dd51` 新建 `/Users/halfsignal/src/Codync-macos-ui` worktree 和 `ui/macos-customization` 分支；
  保留基线中的 iOS 定制，不复制或改动 iOS 工作目录的未提交修改。明确本分支只改 Mac，禁止自行提交、推送、合并或发布。
  新增 Mac 开发说明，确认主界面为 Electron + React + TypeScript，并记录已有独立沙盒的启动方式、专用数据目录与端口分配，
  以及禁止复用官方 Host、凭据和手机配对的边界；显式清空开发密钥以避免启动脚本自动创建云端测试账户。
- 文件：`AGENTS.md`、`docs/guides/macos-ui-preview.md`、`CHANGELOG.md`。
- 验证：核对 fork 远端、基线与 worktree 分支；基线比远端 iOS 分支多 6 个本地提交，现有成果均包含。
  在独立 Mac 目录安装桌面依赖；`npm run typecheck` 与 `npm run build` 通过；`npm test` 共 371 项，370 通过、1 失败。
  失败项为 `all shipped catalogs have the same keys and preserve interpolation tokens`，测试读取 `apps/ios/Kit` 的共享语言文件，
  基线已有翻译键不一致；本轮所有运行时代码与语言目录均无 diff，未为通过测试改动 iOS。
  只读确认官方应用为 2.34.2 且应用/Host 正在运行，没有停止或替换它们。文档链接检查与 `git diff --check` 通过。
- 限制/待办：本轮仅完成工作区与开发约定准备，尚未启动开发沙盒、构建独立开发 Host、打包/安装开发应用或进行界面验收，待具体需求与截图后执行。
  本次构建有已有的未知 SF Symbol `arrow.down.doc.on.clipboard` 和静态/动态导入混用警告，不影响构建退出成功；全套测试未全绿。
  未打包 Electron 的系统权限/通知身份仍可能与其他 Electron 开发实例共享，数据与会话按沙盒隔离；需要完整应用身份时另行核对本机签名并打开发包。
  未验证新的 iPhone 配对，不更改原配对；没有提交、推送、合并、发布或升级任何官方服务。
- 关联：C0002、C0003、C0006、C0086。

### C0088 · 2026-11-03 · Mac 红绿灯与顶部操作按钮对齐

- 原因：用户指出原生红绿灯靠左上，和自绘顶部栏的电脑、搜索、新建按钮不在同一水平线，要求修正布局。
- 变化：Mac 聊天主窗口由默认红绿灯位置改为 `trafficLightPosition: { x: 14, y: 20 }`；
  按原生按钮预期 14 点高度，将中心放在 27 点，对齐已有 54px 顶部栏的垂直中心，左侧留白设为 14 点。
  保留原生关闭、最小化与全屏能力，仅在 `isMac` 条件下应用；不修改其他客户端、Host 或连接认证协议。
  按用户最新要求，后续普通界面调整改好后交由用户测试，不继续耗时的自动界面检查。
- 文件：`apps/desktop/src/main/index.ts`、`docs/guides/macos-ui-preview.md`、`CHANGELOG.md`。
- 验证：`npm run typecheck`、`npm run build` 通过；环境隔离、沙盒与窗口关闭行为的 10 项现有回归检查全部通过。
  完成正确性、完整性、重构三项只读复核，未发现确认的代码缺陷；没有为两行窗口配置增加抽象或镜像测试。
  独立 Electron 预览复用生产代码窗口选项和现有 demo 内存 Host，实际返回按钮坐标 `{x:14,y:20}`；
  已看到普通窗口顶部布局并成功进入原生全屏。开发依赖 Electron 44.5.1 从官方 GitHub 下载并核对官方 SHA256。
- 限制/待办：本机缺少 Rust 工具链，开发 Host 构建尝试失败，未修改工具链或使用官方 Host 替代；预览为演示数据，不能作为真实连接验收。
  截图时 macOS 的“窗口共享”胶囊替代显示红绿灯，尚无完整三色按钮的最终截图。
  用户要求自行测试后停止继续检查，最小宽度、紧凑侧栏、退出全屏后的最终对齐与原生按钮逐项操作未完成验收。
  本轮未重跑全套测试，C0087 已记录的语言目录基线失败仍未处理。预览 Electron 窗口及本地 8930 HTTP 服务留作用户查看，数据目录独立。
  没有打包安装、提交、推送、合并或发布，官方 2.34.2 应用、Host、原有 iPhone 配对不变。
- 关联：C0087。

### C0089 · 2026-11-03 · 基于官方 2.34.2 打包并覆盖安装 Mac 定制版

- 原因：用户明确改为要求“直接打包，覆盖原版”，并要求后续自行验收，避免继续耗时的自动界面测试。
- 变化：新增本机打包脚本，以当前未修改的官方 2.34.2 为底包，读取本分支 C0088 的窗口位置配置，
  仅修改官方 ASAR 主进程的红绿灯位置以及禁用官方应用更新，避免更新重新覆盖定制并升级 Host。
  其余 ASAR 文件核对保持一致；重算 ASAR 完整性头并使用本机有效开发证书重新签名 Electron 部分，
  保留官方 2.34.2 Host、语音、屏幕辅助程序与账号配置原文件，不编译或安装工作树 2.36.0 的 Host。
  生成 DMG 后完整替换 `/Applications/Codync.app`，沿用官方身份和现有本地数据；此项按用户新指令覆盖此前并行安装约定。
  安装前备份原版压缩包和本地数据，保留原应用目录便于回退。安装后停止旧演示窗口与本地演示 HTTP 服务。
- 文件：`apps/desktop/tools/package-mac-local.cjs`、`AGENTS.md`、`docs/guides/macos-ui-preview.md`、`CHANGELOG.md`；
  已有源码变化仍见 C0088。安装包为被忽略的 `build/releases/Codync-2.34.2-local-C0089.dmg`，不提交二进制或用户数据。
- 验证：签名证书代码签名用途及 OCSP 验证通过，脚本检查修改后的主进程 JS 语法、原 ASAR 完整性与未修改条目的内容，
  深层严格代码签名校验通过，DMG 生成成功。已完成原版应用、本地数据与 1 个 Host SQLite 数据库一致快照备份。
  替换后应用已启动，19222 健康接口仍报告 2.34.2，Host 二进制及 launchd 服务配置的 SHA256 与安装前一致。
- 限制/待办：本机包使用开发证书而非官方 Developer ID，未做公开分发公证；系统权限、钥匙串及屏幕辅助程序重新注册行为待用户验收。
  最初打包识别了非代码资源为二进制签名目标，已收紧为 Mach-O/应用/框架目标后打包成功；
  Chromium DIPS 数据库不接受普通只读 SQLite 打开，已改为 UI 停止后的整个 Chromium 数据目录复制，Host 数据库仍使用在线一致备份。
  安装包保留 2.34.2 功能，不包含工作树中其他 2.36.0 功能；禁用的是该本地包的应用更新，没有修改独立 Host 的更新设置。
  没有重跑全套测试或继续界面操作，未验证手机重新连接，但配对数据原样保留，未重新配对或改变认证协议。
  原版与数据备份位于本人 Library 下的 `Codync Backups/20261103-212547-C0089/`，详细回退说明见 Mac 开发说明。
  没有提交、推送、合并、公开发布或部署；没有修改 iOS 工作目录。
- 关联：C0003、C0087、C0088。

### C0090 · 2026-11-03 · Mac 界面与原生菜单接入 iOS 同款 Remix 图标

- 原因：用户已在 iOS 使用 Remix 图标字体，希望 Mac 也统一为同一套图标，并沿用当前可用的覆盖安装方式。
- 变化：复制 iOS 已有 Remix 4.9.1 字体、码点表和许可证，在桌面共享 `Icon` 增加仅 Mac 使用的字体分支；
  保留原有 iOS 映射并扩充到 186 条，覆盖全部 165 个登记图标以及 10 个原生菜单操作图标。
  保留既有颜色、标题、无障碍标签、应用文字缩放与按钮外部尺寸，图标使用 1.2 倍字号方框和字体自身字重；
  未知名称保留 SF/Lucide 回退。原生菜单使用同一字体生成的 1×/2× 模板 PNG，菜单本身仍由 macOS 绘制。
  GitHub 等专有品牌图、Bot 头像、应用/菜单栏品牌图和系统红绿灯保留；其他平台的图标分支不变。
  本地打包复用同一字体 helper，精确加入原官方 2.34.2 的 renderer 与主进程，不升级到工作树 2.36.0 的完整客户端或 Host。
  生成新 DMG，备份上一版及本地数据后完整覆盖并启动 `/Applications/Codync.app`。
- 文件：`apps/desktop/src/renderer/components/Icon.tsx`、`remix-icons.ts`、`remix-icons.css`、`remix-symbols.json`；
  `apps/desktop/src/renderer/assets/remix/` 的字体、码点表及许可证；`apps/desktop/src/main/tray.ts`；
  `apps/desktop/tools/export-remix-menu.swift`、`local-mac-remix.cjs`、`package-mac-local.cjs`；
  `apps/desktop/electron.vite.config.ts`、`electron-builder.yml`、`.gitignore`；`README.md`、
  `docs/guides/desktop-styles.md`、`docs/guides/macos-ui-preview.md`、`CHANGELOG.md`。
- 验证：与活跃 iOS 工作目录只读比对，字体/码点表/许可证 SHA256 与共享映射一致；全部映射目标存在，165 个登记图标和 10 个原生菜单图标均覆盖。
  `npm run typecheck`、`npm run build` 通过，菜单字体导出成功生成 20 张 PNG；底包覆盖的主进程和 renderer JS 语法检查、其他原有 ASAR 文件哈希校验及深层严格代码签名校验通过，DMG 已生成。
  完成正确性、完整性、重构三项只读复核，无确认代码缺陷；复核提醒的许可证名称已按实际资源记录。
  覆盖后应用进程已运行，Host 健康且仍为 2.34.2，Host 二进制和 launchd 配置 SHA256 与安装前一致；已有数据与 1 个 Host SQLite 数据库一致快照已备份。
- 限制/待办：实际资源许可证为 Remix Icon License v1.0（January 2026），与历史 C0075 的 Apache-2.0 描述不同，本轮完整保留实际许可证原文。
  本轮仅 Mac 使用 Remix，未修改 iOS 工作目录；未知动态图标与专有品牌资源不强制替换。Remix 单一字重不等同于 SF Symbols 的各档笔画，个别图标比例与基线留给用户反馈微调。
  按用户要求未运行自动界面验收或全套测试，没有发送聊天、重新配对或修改认证协议；原生菜单、深浅外观及各页面的最终观感由用户验收。
  本地开发签名仍未公证，官方应用更新继续禁用。上一版与数据备份在 `Codync Backups/20261103-215810-C0090/`，安装包为被忽略的 `build/releases/Codync-2.34.2-local-C0090.dmg`。
  没有提交、推送、合并或公开发布。
- 关联：C0075、C0088、C0089。

## 2026-11-05

### C0091 · 2026-11-05 · 合并上游 upstream/main e34b319a（保留我方 Mac/iOS 定制）

- 原因：上游 `upstream/main` 更新到 `e34b319a`（自共同祖先 `5e6b1c93` 起 81 个提交）。在保留我方全部定制的前提下同步；冲突文件保留我方，非冲突的上游改动照常合入。
- 变化：
  - 从 `ui/macos-customization` 新建 `sync/upstream-20261105-macos-customization`，`git merge upstream/main e34b319a`（merge 提交，未 push）。
  - 20 个冲突：17 个取我方版本（`AGENTS.md`、`README.md`、iOS `BotRow`/`CallRows`/`CustomConnectorSheet`/`InstallConnectorSheet`/`InstalledView`/`MarketplaceView`/`AccountStore`/`ChatRows`/`Composer`/`RoutineNoticeRow`/`ThreadView`/`TraceView`/`AccessRequestView`/`BotListView`/`RootView`）。
  - 语言 `zh-Hans.json`/`zh-Hant.json` 按 key 并集（我方值优先），并入上游 299 个新 key；双方都改过的 key 1 个：`Delete {name}?` 保留我方「删除「{name}」？/刪除「{name}」？」。
  - `apps/Codync.xcodeproj/project.pbxproj` 由 `xcodegen generate` 按并集重新生成：保留我方工程身份（本分支仍为 Clerk/`DEVELOPMENT_TEAM=7FUM8A8H72`，因其基线早于 Google 登录改动，属我方既有状态）；并入上游 `ChooseComputerView.swift` 等新文件引用；`MARKETING_VERSION=2.39.1`。
  - 接口适配（只改我方调用处，不改上游文件）：`ConnectorSignInFlow` 改无参并补 `.signInCodeDialog`（`CustomConnectorSheet`/`InstallConnectorSheet`/`InstalledView`）；`reviewInvitation(blocked:)` 改 `.reviewInvitation()`（`BotListView`）。
  - 上游移除了「评审打断/评审阅读」机制（删除 `ReviewCompletion.swift`/`ReviewInterruption.swift`/`ReviewReading.swift`，并从 `ReviewInvitation` 移除 `setInterrupted`/`viewed`/`returned`/`cancel` 等）。这些是上游基线代码、非我方定制，故采用上游删除；移除我方调用处：`Composer.swift`、`ThreadView.swift`、`RootView.swift`。
  - 锁文件：`host/Cargo.lock` 为 2.39.1；`apps/desktop/package-lock.json` 含 `@playwright/test`；`npm ci` 通过。
- 文件：`apps/project.yml`、`apps/Codync.xcodeproj/project.pbxproj`、`apps/ios/Kit/Sources/CodyncUI/Marketplace/*`、`apps/ios/Kit/Sources/CodyncUI/Thread/{Composer,ThreadView}.swift`、`apps/ios/Views/{BotListView,RootView}.swift`、`apps/ios/Kit/Sources/CodyncKit/Resources/Languages/zh-Hans.json`、`zh-Hant.json`、`CHANGELOG.md`。
- 验证：iOS `iOS Dev`/`DevDebug`（模拟器）编译通过；桌面 `npm run typecheck`、`npm run build` 通过；`Screen Dev`（macOS，`CODE_SIGNING_ALLOWED=NO`）编译通过。未安装真机、未做功能自测。
- 限制/待办：
  - 冲突文件里放弃的上游功能（同 C0122）：每 bot 的 agent logo、通话条/通话会话改进、connector 验证码登录入口（共享类型已合入）、手机设置选账户电脑、消息排队入口、GitHub 点星/App Store 评分邀请、routine/trace 的 i18n 等。
  - 上游新增文件里因入口被放弃而未接线的代码（仅列出，未删未接）：`apps/ios/Kit/Sources/CodyncKit/Models/Entry+Queue.swift`、`apps/ios/Kit/Sources/CodyncUI/Thread/QueuedMessages.swift`、`apps/ios/Kit/Sources/CodyncUI/Bots/AgentBadge.swift`、`apps/ios/Views/ChooseComputerView.swift`（本分支无桌面 Electron 改动，故不含桌面三项）。
  - 本分支我方基线仍为 Clerk 登录（早于 Google ID token 改动），本次按「保留我方」未改动；如需同步 Google 登录需另行移植。
  - 未做真机/功能验证；未 push。
- 关联：C0122（同批上游同步）。

### C0092 · 2026-11-05 · 稳定 Mac 屏幕权限的签名身份并加入拖拽授权

- **原因** 当前安装包的 Codync 和 Codync Screen 使用 ad hoc 签名。重新打包改变代码哈希时，macOS 可能无法把已保存的授权关联到新包。
- **变化** Screen target 使用团队 `KQQ6SD2P4C` 的固定 Apple Development 证书。本机主版与开发版打包使用同一签名身份，并校验整包及包内 Screen。LaunchAgent 继续负责启动 Screen，现有 Bundle ID 沿用。
  录屏前由实际采集进程检查当前权限，并将状态交给 Mac 和手机共用。新进程探测到授权时，由 launchd 重启采集进程并重新上报状态。
  Mac「屏幕录制」和「控制应用」增加真实 helper 图标、原生文件拖拽和「在访达中显示」。保留权限请求、系统设置入口和刷新，并在页面底部显示按当前版本生成的可复制重置命令。
- **文件** `apps/project.yml` 与 XcodeGen 生成的 `apps/Codync.xcodeproj/project.pbxproj`、`apps/screen-macos/{Permissions,ScreenHelper}.swift`、
  `apps/desktop/{package.json,tools/{native-host.mjs,native-screen.mjs,package-mac-personal.cjs}}`、
  `apps/desktop/src/{main/{screen,updates}.ts,preload/index.ts,shared/{computer-access,ipc}.ts}`、
  `apps/desktop/src/renderer/{demo/bridge.ts,lib/{computer-access-phrases,l10n}.ts,store/computer-access.ts,views/computer-access/}`、
  `docs/{architecture/desktop-app.md,guides/macos-ui-preview.md}`、`web/content/docs/computer-use.mdx`。
- **验证** Electron `npm run typecheck` 和 `npm run build` 通过。Xcode `Screen Dev` 的 `DevDebug` 编译及严格签名校验通过。
  连续两次完成本机主版打包，严格签名校验通过，主程序和 helper 的 Team ID 及各自的 designated requirement 在两次构建间一致。
- **限制与待办** 验证范围为编译、打包和签名。安装、系统授权、拖拽、手机连线及权限跨安装保留由用户验收。
  本机主版包随附 Host 2.39.1，首次打开时现有启动逻辑会切换到该 Host。替换前需备份旧应用及 Host 数据。
  新增界面文案提供简体与繁体中文，其余语言回退至英文。
- **关联** C0089、C0090、C0091。
