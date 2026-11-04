# Fork 改动记录

本文件记录本 fork 的定制与修复；上游发布说明仍在原有文档中维护。
每次修改必须同步更新本文件，格式见 [改动记录规则](docs/guides/change-recording.md)。

当前工作分支：`ui/ios-customization`；目标仓库：`KouriVar/Codync`。
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

### C0087 · 2026-11-03 · 设置页箭头统一为系统 chevron；分隔线调淡

- 原因：NavigationLink / `.pickerStyle(.navigationLink)` 行由系统绘制 disclosure 箭头，手写 Button 行用 Remix `arrow-right-s-line`，字形与尺寸天然不同，无法只用 size 调一致。
- 变化：手写行箭头改为 `Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)`（与系统箭头同源同参）；Form 加 `.listRowSeparatorTint(Color.white.opacity(0.08))` 让分隔线更淡。
- 文件：`Views/AccountSwitcherView.swift`、`Views/SettingsView.swift`。
- 验证：构建号 116–119 编译、签名、安装成功；截图确认箭头大小一致。
- 限制/待办：`.alignmentGuide(.listRowSeparatorTrailing)` 在当前 iOS 27 SDK 的 Form 上不生效（行级与 Form 级都试过），分隔线右侧仍留 16pt；若要顶死右侧需改为自绘分隔线（隐藏系统线 + overlay 1px hairline）。
- 关联：C0086。

### C0091 · 2026-11-03 · Switch 开关统一黑色高亮

- 原因：开关的 ON 态跟随 tint，深色下被 `.tint(.primary)` 变成白色；用户要求统一黑色。
- 变化：全部 7 处 `.toggleStyle(.switch)` 追加 `.tint(.black)`（设置页思考细节、共享分析、电脑管理推送通知、记忆、定时任务、自定义图标等）。
- 文件：SettingsView、ThinkingDetailsSettings、ComputersView、MemoryView、RoutinesView、CustomIconEditor。
- 验证：构建号 124 编译、签名、安装成功；截图确认（截图为 OFF 态，灰色轨道）。
- 限制/待办：ON 态为黑色轨道，深色卡片对比度偏低，若观感不佳可改 `Palette.text`/`Color(white:0.2)`。
- 关联：C0084。

### C0092 · 2026-11-03 · 设置页按组重构 + 版本页脚 + 相机页按钮 24/44

- 原因：用户要求精简设置页：删配对（电脑管理里有入口）、凭证与连接应用同组、排序上移改名、思考细节归入系统组并改名、删共享用量分析、版本改成 App 图标页脚（保留连点 Start over）；相机页返回/更多图标偏小。
- 变化：第一组 = 头像/电脑/状态/排序；连接组 = 凭证/连接应用；系统组 = 通知/主题/语言/思考细节；页脚 = AppMark 68pt + 半句 + 版本号（连点 10 次）；新增 `apps/ios/Resources/AppMark.png`（256px，xcodegen 重新生成工程）。`QuickCapture` 返回/更多改 `RemixIcon(..., size: 24)`（44 圆）。
- 文件：`Views/AccountSwitcherView.swift`、`Views/SettingsView.swift`、`ThinkingDetailsSettings.swift`、`Views/QuickCapture.swift`、`Resources/AppMark.png`。
- 验证：构建号 125/126 编译、签名、安装成功；截图确认分组、黑色开关、页脚图标、相机页按钮尺寸。
- 关联：C0091。

### C0093 · 2026-11-03 · 对话页顶部工具栏：24/44 返回与更多、标题固定高度

- 原因：系统返回箭头约 17pt；更多图标写了 `.font(.system(size: 18))` 对 RemixIcon 无效；标题胶囊用 `minHeight: 36` + 内边距，总高 > 44 被工具栏裁切。
- 变化：`navigationBarBackButtonHidden(true)` + 自定义 `ToolbarItem(.topBarLeading)`（`RemixImage("arrow-left-s-line", 24)`，44 圆），并用 `SwipeBackEnabler` 恢复侧滑返回；更多按钮改 `RemixImage("more-line", 24)`；标题 `.frame(height: 38)`（先 44 偏大，按用户反馈收回到 38）。
- 文件：`CodyncUI/Thread/ThreadView.swift`。
- 验证：构建号 127/128 编译、签名、安装成功；通过 `CODYNC_OPEN_URL=codync://bot/...` 深链接进入对话页截图确认。
- 限制/待办：侧滑返回需真机确认（隐藏系统返回键会默认禁用边缘手势）。
- 关联：C0092。

### C0094 · 2026-11-03 · 对话页标题胶囊实测 44（内容 frame 35 + glass 内边距）

- 原因：标题胶囊看起来比 44 大，用户判断"还有一层套着"——`.buttonStyle(.glass)` 会在内容 frame 外再加约 9pt 内边距。
- 变化：内容 `.frame(height: 35)`，实测外胶囊 = 132px = **44.0pt**，与返回/更多 44 圆完全等高（标定：返回圆实测 44.0pt）。
- 文件：`CodyncUI/Thread/ThreadView.swift`。
- 验证：构建号 129/130 + 像素测量（x=470 处 132px；返回圆 x=110 处同为 132px）。
- 关联：C0093。

### C0095 · 2026-11-03 · 标题胶囊改自绘玻璃，严格 42pt（与工具栏圆等高）

- 原因：`.buttonStyle(.glass)` 会在 label 外再补约 10pt，导致胶囊 44.7pt、圆按钮 42pt，滚动时胶囊上下各被裁 2pt。
- 变化：改为 `Button { } label: { title.padding(.horizontal,14).frame(height:42).glassEffect(.regular.interactive(), in: Capsule()) }` + `.buttonStyle(.plain)`，玻璃不再额外撑高。
- 文件：`CodyncUI/Thread/ThreadView.swift`。
- 验证：构建号 132 编译、签名、安装成功；截图三个元素等高（返回/更多实测 126px=42pt，胶囊目视等高）。
- 关联：C0094。

### C0096 · 2026-11-03 · 对话输入区与首页底栏统一（48 高 + 24 加号 + Remix 发送）

- 原因：输入框/加号与首页搜索框、扩展按钮规格不一致；加号偏小；发送仍是 SF。
- 变化：`buttonHitSize` 44→48、`buttonSize` 32→36；胶囊圆角 22→24；加号 `RemixIcon("add-line", 24)` + 48 圆；标题胶囊改严格 44（`.glassEffect` 显式 frame，去掉 `.buttonStyle(.glass)` 的隐式内边距）；发送/停止改 Remix（`arrow-up-line` 20 / `stop-fill` 14）；底部间距键盘收起 28、弹起 12（与首页一致）。
- 文件：`CodyncUI/Thread/Composer.swift`、`CodyncUI/Thread/ThreadView.swift`。
- 验证：构建号 133–135 编译、签名、安装成功；截图确认输入区与首页同规格。
- 关联：C0094、C0095。

### C0097 · 2026-11-03 · 输入框加号菜单重做 + 复用相机 sheet

- 原因：原菜单只有 Photos / Files / Paste，语义粗糙；用户要「照片或视频 / 拍照 / 选择文件」，拍照复用首页相机并把照片推进输入框。
- 变化：菜单三项（Remix `image-line` / `camera-line` / `folder-line`）；新增 `CameraCaptureAction` 环境值 + RootView 挂 `QuickCaptureSheet`，拍照回传后 `withAnimation` 追加到附件；PhotosPicker 支持视频（`matching: .any(of: [.images, .videos])`，视频按 `video-*.mov` 入列）；`MenuGlyph` 支持直接传 Remix 名。
- 文件：`CodyncUI/Thread/Composer.swift`、`CodyncUI/Chrome.swift`、`CodyncUI/MenuItem.swift`、`Views/RootView.swift`。
- 验证：构建号 136 编译、签名、安装成功（菜单交互需真机点按确认）。
- 关联：C0096。

### C0098 · 2026-11-03 · 系统菜单图标改 RemixImage（菜单只接受 Image）

- 原因：系统 `Menu`/`UIMenu` 只保留 `Image` 类型的图标；`RemixIcon` 是 Text 字形，被系统丢弃，所以加号菜单三项没图标。
- 变化：`MenuGlyph` 改用 `RemixImage`（template UIImage），同时保留 SF 回退；影响全 App 所有系统菜单项。
- 文件：`CodyncUI/MenuItem.swift`。
- 验证：构建号 137 编译、签名、安装成功；菜单展开需真机确认。
- 关联：C0097。

### C0099 · 2026-11-03 · 新增只读查询交接单 docs/HANDOFF-QUERY.md

- 原因：需要在新会话里只读查询本项目，需一份可复用的项目背景与规则说明。
- 变化：新增 78 行交接单：只读硬性规则、仓库/分支、目录与关键文件索引、Remix 图标系统与踩坑、构建与设备参数（仅供理解）、调试环境变量、协作约定、未完成项。
- 文件：`docs/HANDOFF-QUERY.md`。
- 验证：文件写入成功；内容与当前代码/构建号 137 一致。
- 关联：C0098。

### C0100 · 2026-11-03 · 交接单修正：构建参数改为"以代码为准 + 搜索命令"

- 原因：Bundle ID 等参数在工程里是变量（`PRODUCT_BUNDLE_IDENTIFIER = $(CODYNC_IOS_BUNDLE_ID)`），交接单直接写死具体值会误导新会话。
- 变化：第 5 节改成"原则：以代码为准"，并给出 4 条自查命令与结论（Bundle ID 默认 `com.pokai.Codync.ios` / Dev `com.pokai.Codync.ios.dev`，本机覆盖为 `com.suiyikou.codync.uipreview`；构建号 137；显示名 半句）。
- 文件：`docs/HANDOFF-QUERY.md`。
- 关联：C0099。

### C0101 · 2026-11-03 · 首页搜索态：左键隐藏、相机变关闭（带弹簧动画）

- 原因：点击搜索框时希望收起无关按钮，并提供一键关闭搜索的入口。
- 变化：`SearchField` 增加可选 `active: Binding<Bool>` 焦点双向同步；`HomeBottomBar` 增加 `searching` 状态：搜索激活时左侧扩展按钮 `scale+opacity` 过渡移除、右侧相机变 `close-line`，点它清空搜索并收起键盘；HStack 加 `.animation(.snappy(0.26))`（尊重 Reduce Motion）。
- 文件：`CodyncUI/Controls.swift`、`Views/HomeBottomBar.swift`。
- 验证：构建号 138 编译、签名、安装成功；交互需真机点按确认。
- 关联：C0096。

### C0102 · 2026-11-03 · 首页搜索态动画去"玻璃融合"

- 原因：`GlassEffectContainer(spacing: 12)` 会让相邻玻璃元素在出现/消失时形变融合，左键消失时像"钻进"搜索胶囊，观感卡顿。
- 变化：移除容器包裹，三个元素各自 `.glassEffect`；左键过渡由 `scale+opacity` 改为纯 `.opacity` 淡出；保留 `.snappy(0.26)` 与 Reduce Motion。
- 文件：`Views/HomeBottomBar.swift`。
- 验证：构建号 139 编译、签名、安装成功；观感需真机确认。
- 限制/待办：若希望保留玻璃融合但只在"贴住"时发生，可换回容器并把 spacing 调小（如 0），待用户反馈。
- 关联：C0101。

### C0103 · 2026-11-03 · 搜索态保留玻璃融合，用"布局不变"消除卡顿

- 原因：C0102 去掉容器后融合消失，观感变差；但带容器又因"移除按钮 + 搜索框变宽"的布局动画导致玻璃形变卡顿。
- 变化：恢复 `GlassEffectContainer(spacing: 12)`；扩展按钮**常驻容器**，搜索态只切 `opacity`/`allowsHitTesting`/`accessibilityHidden`（布局零变化，不再触发布局驱动的玻璃重排）；过渡改 `.easeInOut(0.2)`。
- 文件：`Views/HomeBottomBar.swift`。
- 验证：构建号 140 编译、签名、安装成功；交互需真机确认。
- 限制/待办：搜索框不再变宽（这是换取不卡顿的代价）；若要变宽需接受一次布局动画。
- 关联：C0101、C0102。

### C0104 · 2026-11-03 · 搜索态恢复变宽；用 geometryGroup 抑制玻璃重绘抖动

- 原因：用户明确要求"左键消失 → 搜索框变宽"，C0103 为不卡而牺牲变宽不可接受。
- 变化：左键恢复条件显示（`.transition(.opacity)`），搜索框随之变宽；给 `SearchField` 与 `HStack` 加 `.geometryGroup()`（几何动画与内容渲染隔离，减少逐帧重绘），动画改 `.snappy(0.24)`。
- 文件：`Views/HomeBottomBar.swift`。
- 验证：构建号 141 编译、签名、安装成功；流畅度需真机确认。
- 关联：C0102、C0103。

### C0105 · 2026-11-03 · 用 iOS 26 官方玻璃转场（glassEffectID + materialize）替代普通过渡

- 原因：搜索框变宽必须伴随布局动画，普通 `.transition` 会让容器逐帧重排玻璃导致卡顿。
- 变化：容器内三个玻璃元素加 `glassEffectID`（extensions/search/camera），扩展按钮加 `glassEffectTransition(.materialize)`，让容器用系统转场溶解/形变，而不是移除视图触发重排；动画 `.snappy(0.26)`。
- 文件：`Views/HomeBottomBar.swift`。
- 验证：构建号 142 编译、签名、安装成功；流畅度需真机确认。
- 关联：C0102–C0104。

### C0106 · 2026-11-03 · 长按菜单图标全量换 Remix（首页 Bot 菜单 + 更多子菜单）

- 原因：首页 Bot 长按菜单与「更多」子菜单仍传 SF 名，`MenuGlyph` 回退成系统图标，与全 App 图标体系不一致。
- 变化：17 处 `MenuItem` 图标改为 Remix（edit-line / close-circle-line / mail-open-line / mail-unread-line / pushpin-2-line / unpin-line / folder-add-line / share-forward-line / eye-off-line / file-copy-line / group-line / star-line / delete-bin-line / more-line / inbox-line / add-line / indeterminate-circle-line）；顺带修 4 处其它菜单（回退项删除、作品重命名/分享、屏幕选择）。
- 文件：`Views/BotListView.swift`、`CodyncUI/Bots/FallbackRows.swift`、`CodyncUI/Artifacts/LibraryView.swift`、`CodyncUI/Screen/ScreenView.swift`。
- 验证：构建号 143 编译、签名、安装成功；菜单展开需真机确认。
- 关联：C0098（菜单图标必须是 Image）。

### C0107 · 2026-11-03 · 配对身份改用 Google 登录（ID token 校验），移除 Clerk

- 原因：用 Google 登录替代 Clerk / 上游云端证书，作为 codync 配对时的身份验证；配对后沿用现有设备签名 + E2E 通道，不改每请求流程。
- 变化（host，Rust）：
  - 新增 `remote/google_auth.rs`：从 Google JWKS 以 RS256 验签，校验 `iss` / `aud` / `exp` / `email_verified` / 邮箱白名单；Client ID 与允许邮箱可用 `CODYNC_GOOGLE_CLIENT_IDS` / `CODYNC_ALLOWED_EMAILS` 覆盖。
  - `channel/pairing.rs` 用 `google_auth` 替换 `certificate::check`；配对请求新增 `google_id_token`；一次性配对码、TTL、限频保留；设备记录新增 `email`（schema v8）。
  - 云依赖“关而不删”：host LaunchAgent 增加 `CODYNC_CLOUD=off`（与 `CODYNC_EXTERNAL_URL` 并存，改前已备份）。
- 变化（iOS）：
  - 移除 Clerk（`project.yml`、`AccountSession`）；新增 GoogleSignIn SPM；`Info.plist` 加 `GIDClientID` 与 Google URL scheme；删除 Sign in with Apple entitlement；登录界面仅保留 Continue with Google。
  - 配对请求带 `google_id_token`（过期先 `refreshTokensIfNeeded`）；`cloudClient` 返回 nil；PostHog 与 APNs relay 用开关关闭（`Analytics.remoteDisabled`、`PushRegistrar.relayDisabled`），代码不删。
  - 三个 target 的 bundle / team / app group 以真机可签名那套为准：`com.suiyikou.codync.uipreview`（+ `.LiveActivity` / `.NotificationService`）、Team `KQQ6SD2P4C`、App Group / Keychain 同名；未新增 App ID。
- 文件：`host/src/remote/google_auth.rs`（新增）、`host/src/remote/channel/pairing.rs`、`host/src/remote/mod.rs`、`host/src/store/devices.rs`、`host/src/store/schema.rs`、`host/src/api/remote.rs`、`host/src/remote/{owner,cloud,relay}.rs`、`host/src/analytics/observe/tests.rs`、`host/tests/{common/mod.rs,e2e.rs}`；`apps/project.yml`、`apps/ios/Resources/{Info.plist,iOS.entitlements}`、`apps/ios/App/{AccountSession,CodyncApp,Push}.swift`、`apps/ios/Kit/Sources/CodyncKit/{Client/HostConnector.swift,Analytics/Analytics.swift}`、`apps/ios/Kit/Sources/CodyncUI/{Store/AccountStore.swift,Bots/CustomIconEditor.swift}`、`apps/ios/Views/SignInButtons.swift`、`apps/ios/Kit/Tests/CodyncKitTests/ChannelTransportTests.swift`。
- 验证：host `cargo build` 成功、`cargo test` 全绿（单元 666 passed + 全部 e2e 通过）；iOS Simulator（iPhone 18 Pro，DevDebug）`BUILD SUCCEEDED`。真机 Google 登录 → 配对 → `https://bot.suiyk.link` 收发、换号被拒由用户验证。
- 限制：真机需重新生成 host 二进制并替换 App 内 `codync-host` 才启用新校验；CloudClient / 账号证书相关代码保留但未使用。
- 关联：C0106。

### C0108 · 2026-11-04 · host 安装保留 plist 环境变量；本地重建 Codync.app（ad-hoc、默认关自动更新）

- 原因：`codync-host install` 重写 LaunchAgent 时只写 `PATH`/`CODYNC_HOME`，会丢掉 `CODYNC_CLOUD`/`CODYNC_EXTERNAL_URL`；换入自定义 host 后 `/Applications/Codync.app` 签名失效、版本仍 2.34.2。
- 变化：
  - `host/src/service/unix.rs`：抽出 `launchd_plist_xml`；`install` 重写 plist 时保留旧 plist 里的 `CODYNC_CLOUD`/`CODYNC_EXTERNAL_URL`（没有则取当前进程 env），并补两条单测。
  - `apps/desktop`：`updates.ts` 默认 `autoCheck/autoDownload = false`；`resources/entitlements.mac.plist` 增加 `com.apple.security.cs.disable-library-validation`（ad-hoc 构建需要）；`package.json` 记录 npm `allowScripts`。
- 文件：`host/src/service/unix.rs`、`apps/desktop/src/main/updates.ts`、`apps/desktop/resources/entitlements.mac.plist`、`apps/desktop/package.json`。
- 验证：`cargo test --bin codync-host` 668 passed；release 重编；`codync-host install` 后 plist 仍含两项；本地 `npm ci` + `electron-vite build` + `electron-builder --mac --dir --arm64`（ad-hoc）产出 2.36.0，替换 `/Applications/Codync.app`（原版备份 `~/Backups/Codync.app.bak-20261104-002447`）；`/health` 2.36.0/main、host 环境含 `CODYNC_CLOUD=off`/`CODYNC_EXTERNAL_URL`、`cloudStatus.enabled=false`、`codesign --verify --deep --strict` 通过、autoCheck/autoDownload=false。
- 限制：本机只有 Apple Development 证书（无 Developer ID / 公证凭据）→ App 为 ad-hoc 签名、arm64-only，`spctl` 仍 rejected；可分发需另行签名公证。
- 关联：C0107。

### C0115 · 2026-11-04 · 云端关闭时桌面端跳过登录欢迎页，隐藏账号入口

- 原因：本机 host 以 `CODYNC_CLOUD=off` 运行（C0107），账号已无法把任何东西送到别处；但桌面端仍按 `pk_live_` 判断 `configured=true`（`main/account.ts:35`），`welcome-gate.ts` 于是在未登录时把窗口拦在 Apple/Google/GitHub 登录页上，账号入口也照旧显示。
- 变化（只加开关，不删代码）：
  - `apps/desktop/src/renderer/lib/account-mode.ts`（新）：`accountsInUse(configured, cloud)` / `accountHidden(configured, cloud)`。账号生效 = 构建里有账号 **且** 本机 host 的 `cloudStatus.enabled !== false`。host 尚未应答（`cloud` 为 null）时按「未知不等于关闭」处理，沿用构建的结论，避免窗口先闪后现账号入口。
  - `apps/desktop/src/renderer/views/AccountWelcomeView.tsx`：`useWelcomeGate` 用 `accountsInUse` 计算 `configured` 再交给 `showsWelcome`；云端关闭时欢迎页不再盖住窗口。
  - `apps/desktop/src/renderer/views/ChatWindow.tsx`：`ChatSplitView` 新增 `accountInUse`；窄栏头像与 `RailAccountNotice`、侧栏底部账号按钮、账号面板 `AccountPanelLayer` 均按它隐藏。
  - `apps/desktop/src/renderer/views/SidebarFooter.tsx`：新增 `showAccount` prop（默认 true），false 时账号按钮与该菜单里的账号不一致提示都不渲染。
  - `apps/desktop/src/renderer/views/settings/SettingsView.tsx`：General › Account 卡片按 `accountInUse` 隐藏。
  - `apps/desktop/src/renderer/lib/account-mode.test.ts`（新）：4 条单测覆盖「云开/云关/未知/无账号构建」四种情形。
- 保留：`AccountService`、Clerk 登录、`account.*` IPC、`store/cloud.ts`、欢迎页组件本身都没删；云端恢复为开启时全部原样回来。
- 验证：`npm run typecheck` 通过；`npm test` 347 条 346 通过，仅剩既有的 catalogs 键不一致（HEAD 上 zh-Hans 比 ja 多键，与本次无关）。未构建、未替换 `/Applications/Codync.app`、未重启 host。
- 关联：C0107、C0110。

### C0116 · 2026-11-04 · 本机 host 版本行在 macOS/Windows 重新显示

- 原因：`apps/desktop/src/renderer/views/settings/ComputersView.tsx:244` 用 `!(store === app.local && platform !== 'linux')` 隐藏本机版本行，注释理由是「版本与更新在 Updates 页」；但该页已随 C0110 删除，于是 macOS 与 Windows 上再也看不到本机 host 版本号。
- 变化：`apps/desktop/src/renderer/views/settings/ComputersView.tsx`：去掉该平台排除条件，本机与其它电脑一样显示 `CodyncVersionRow`；注释同步改写，说明前提已不成立。
- 保留：`CodyncVersionRow` 里的 host 更新入口（`installHostUpdate`、`hostUpdateStatus`、`UpdateNeededCard` 的 host 分支）未动 —— 停用的只是 App 自动更新，host 二进制更新仍然有效。
- 验证：`npm run typecheck` 通过；`npm test` 见 C0115。未实机核对三平台观感。
- 关联：C0110。

### C0117 · 2026-11-04 · iOS 首页新增「DSH 对话」分组（Phase 1：列会话、发消息、流式回复）

- 原因：DSH（DeepSeek Harness）的会话现在经 `dsh-plugin-mobile-gateway` 的 `wss://<host>/ws/mobile` 提供，手机端需要一个能看到并继续这些会话的入口。Phase 1 只做最小闭环：连上网关、列出会话、发一句话、看到流式回复；工具调用、审批、文件、语音等留在后续阶段。
- 变化：
  - `apps/ios/DSHKit/`（新）：Swift 5 模式的独立 Swift Package（宿主是 Swift 6 + 完整并发检查，所以不共用语言模式）。
    - `DSHGateway.swift`：单条 `URLSessionWebSocketTask`（legacy 通道，兼容所有网关）、`hello`/`sessions`/`subscribe`/`message`/`sent`/`event`/`assistant-stream`/`session-snapshot` 处理、指数退避重连、`4003`/`4004`/`401` 处理、配对 25 秒超时与多地址兜底。
    - `DSHPairing.swift`：解析 Mac 上 DSH 生成的配对二维码（payload v2，base64url 原文或 URL 形式、百分号解码、去空白）、Keychain 保存设备 token（service `com.suiyikou.codync.dsh-gateway`）、稳定 `X-DSH-Device-ID`。
    - `DSHViews.swift`：首页分组、会话列表、聊天页（流式气泡）、连接/扫码表单。
    - `DSHModels.swift`：会话摘要（`items[].projections.values.title`）、消息、hello。
    - `build-kmp-framework.sh`：把 KMP `shared` 编成 Release framework 再合并 XCFramework 的脚本（P0 产物，P1 不链接；`Vendor/` 已忽略）。用 `DEVELOPER_DIR` 指向完整 Xcode、`JAVA_HOME` 指向 Homebrew JDK 17，不改系统 `xcode-select`。
  - `apps/project.yml`：新增 `DSHKit` 本地包、加为 iOS target 依赖、并把 `DSHKit` 排除出 app target 的源码目录（避免重复编译）。
  - `apps/ios/Views/RootView.swift`：首页在 BotListView 上方加 DSH 分组（`DSHHomeSection`），扫码复用现有 `QRScanner`。
  - `apps/ios/Views/QRScanner.swift`：新增 `acceptedPrefixes` 参数（默认仍是 codync 的 scheme，`PairingView` 行为不变；DSH 传 `nil` 接受任意 payload）；`qualityLevel` 可配（DSH 用 `.accurate` 以便读高密度二维码）；扫到的内容先 trim 再判断前缀。
- 保留：codync 自身的配对扫码、Bot 列表与拖动排序、Coe/DS Bot 的现有行为都未改；KMP 共享层本轮不链接。
- 验证：`xcodebuild` DevDebug 对真机（`generic/platform=iOS`）与模拟器均构建通过；真机安装后，配对、会话列表、发消息、流式回复均实测正常。旧网关的兼容路径未改。
- 已知待办（未在本条处理）：DSH 注入的「Time sampled…」系统时间消息会被显示成用户气泡；Coe 的后台会话（`<bot-profile>` / `You keep the memory` 开头或「未命名」）应隐藏；首页 DSH 分组样式待改为「会话切换菜单 + 混排列表」。

### C0118 · 2026-11-04 · iOS 首页：来源切换、混排/分页、隐藏后台会话

- 原因：三种来源（Coe / DS Bot / DSH）要能在同一个首页按需显示；首页原先的 DSH 状态区占位且把连接细节暴露在首页；Coe 的后台会话与 DSH 注入的时间消息是噪音。
- 变化：
  - 首页改为统一的 `HomeSourcesView`（`apps/ios/Views/HomeSourcesView.swift`，新）；移除 `DSHHomeSection` 状态区，DSH 配对状态移到设置「DSH 连接」，连不上时只在 DSH 行前显示一行小字。
  - 右上角「+」左边新增漏斗按钮（SF Symbol `line.3.horizontal.decrease.circle`），复用「+」同款系统菜单；Coe / DS Bot / DSH 三行多选、右侧 checkmark，分隔线后「全部显示 / 恢复默认」；默认只 Coe，至少保留一项；`@AppStorage("homeEnabledSources")` 记忆；未勾来源不渲染，DSH 未勾时 `dsh.disconnect()`，不建 WebSocket。
  - 来源归类（`HomeSource.of(bot:)`）：分组与无 `command` 的 bot 是 Coe，`command` 非空是 DS Bot，DSHKit 会话是 DSH。
  - 设置「调试」区新增「首页布局：混排 / 分页」（`@AppStorage("homeLayout")`）；混排按最近时间倒序、头像右下角显示来源角标，分页每个来源一页、顶部圆点 + 当前页名。
  - `HomeSessionVisibility.isHidden(title:isDSH:)` 集中隐藏 `<bot-profile>` / `You keep the memory` 开头与未命名 DSH 会话（只隐藏不删除）；`DSHSystemMessageFilter.isInjected` 过滤 DSH 注入的「Time sampled while preparing turn…」，实时事件与 `session-snapshot` 回放都跳过。
  - DSH 网关改为共享单例 `DSHGateway.shared`；`DSHConnectSheet` / `DSHChatScreen` 补公开 init，供设置页复用。
  - `BotRow` 未改（当时在别的未提交改动里），来源角标用行级 overlay 叠在头像右下角。
- 文件：`apps/ios/Views/HomeSourcesView.swift`、`apps/ios/Views/HomeSource.swift`（均新）、`apps/ios/Views/RootView.swift`、`apps/ios/Views/SettingsView.swift`、`apps/ios/DSHKit/Sources/DSHKit/DSHGateway.swift`、`DSHModels.swift`、`DSHViews.swift`、`apps/Codync.xcodeproj/project.pbxproj`（XcodeGen 重新生成）。
- 验证：DevDebug 模拟器与 `generic/platform=iOS` 真机构建通过；签名安装并启动到 iPhone 16 Pro（`com.suiyikou.codync.uipreview`），首页混排列表、来源角标、DSH 状态区移除均实测可见。
- 限制/待办：分页布局与来源菜单弹层尚未截图；「未连接」小字要网关失败时才出现；角标按 48pt 头像 + 16pt 行内边距固定偏移，超大字号下会偏。
- 关联：C0117。编号说明：桌面端已占用 C0119–C0121，本条把原 C0118–C0121 合并为 C0118；iOS 后续从 C0122 起。

### C0122 · 2026-11-04 · 首页：方形头像、顶部模糊、来源角标与 DSH 消息预览

- 原因：真机验收发现左上头像在工具栏里被拉宽变形、列表上滚会从顶栏透出来、来源角标与约定不符、DSH 会话副标题没有信息量。
- 变化：
  - 左上头像改用 iOS 27 的 `contentMarginsRemoved()` toolbar 项，保持 40pt 正方形（`AccountAvatar` 已是 scaledToFill + Circle，问题在工具栏的胶囊内缩）。
  - 顶栏加 `.toolbarBackground(.visible/.ultraThinMaterial)`，列表上滚不再透出。
  - 角标：Coe 不加；DS Bot 用字母 `D`（绿）；DSH 用终端图标（橙）。
  - DSH 会话副标题改为最后一条消息预览：读网关连接时推送的 `projection-baseline` 和 `turn-outline-updated` 里的 `turnOutline` 最后一项（response 优先、prompt 兜底）。不再为每行发 `history` 请求——一次发 12 条会让 WebSocket 反复掉线。
  - 截图用调试开关：`CODYNC_HOME_LAYOUT`、`CODYNC_HOME_SOURCES`、`CODYNC_OPEN_DSH_SESSION`（均 `#if DEBUG`）。
- 文件：`apps/ios/Views/HomeSourcesView.swift`、`apps/ios/Views/HomeSource.swift`、`apps/ios/DSHKit/Sources/DSHKit/DSHGateway.swift`、`CHANGELOG.md`。
- 验证：DevDebug 真机构建、安装并启动到 iPhone 16 Pro；真机截图确认头像方形、顶栏模糊、Coe 无角标 / DSH 终端角标、DSH 副标题为最后一条消息。
- 限制/待办：预览是 `turnOutline` 原文，可能带 Markdown 记号；超大字号下 17pt 角标的固定偏移会偏。
- 关联：C0118。

### C0123 · 2026-11-04 · 抽出 ChatTranscriptView 与 DSH 对话页骨架（默认关闭）

- 原因：第四部分的方向是 DSH 对话页复用 Coe 聊天页；先把滚动容器抽成可复用组件，再接 DSH。
- 变化：
  - 新增 `apps/ios/Kit/Sources/CodyncUI/Thread/ChatTranscript.swift`：`TranscriptSummary` / `TranscriptItem` / `ChatTranscriptList`（Coe 和 DSH 共用的 `ConversationList` 容器）/ `ChatTranscriptView`（不需要 `BotStore` 的聊天页，气泡样式与 Coe 一致）。
  - `ThreadView` 只把 `ConversationList(...)` 换成 `ChatTranscriptList(...)`，参数与行为不变。
  - DSHKit：`DSHMessage` 增加 `reasoning` / `tools` / `turn` / `durationSeconds` / `createdAt`；`DSHGateway` 从 `turn/start`、`tool/call`、`tool/result`、`assistant/message` 收集并写入；`session-snapshot` 改为按 `{type, time, data}` 读取（修掉快照文本取错层的问题）；新增 `DSHTranscriptItem` / `DSHSummary` / `DSHConversationAdapter` 中间结构（DSHKit 不依赖 CodyncKit）。
  - 新增宿主 `apps/ios/Views/DSHConversationView.swift`：`ChatTranscriptView` + 每轮一行摘要（「思考了 N 秒 · 运行了 N 个命令」）+ 点开 sheet 看思考/工具全文。
  - 新页默认不启用：旧的 `DSHChatScreen` 仍是默认；`CODYNC_DSH_CHAT_PAGE=1`（`#if DEBUG`）切到新页。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Thread/ChatTranscript.swift`（新）、`ThreadView.swift`、`apps/ios/DSHKit/Sources/DSHKit/DSHGateway.swift`、`DSHModels.swift`、`apps/ios/Views/DSHConversationView.swift`（新）、`apps/ios/Views/HomeSourcesView.swift`、`apps/Codync.xcodeproj/project.pbxproj`（XcodeGen 重新生成）。
- 验证：DevDebug 真机构建、安装通过；新页能打开，但当前会话历史为空（`session-snapshot` 未到达/未解析，正在排查），所以默认仍走旧页；Coe 页未做人工点按回归（`ThreadView` 只换了滚动容器，参数一致）。
- 限制/待办：新 DSH 页历史为空待修；修好后把默认切到新页并补 Coe/DSH 回归截图。
- 关联：C0118、C0122。

### C0124 · 2026-11-04 · 修 DSH 对话页历史为空，默认改用新对话页

- 原因：新 DSH 对话页打开后历史为空。
- 排查（对照网关源码，不猜）：
  - `dsh-plugin-mobile-gateway/lib/session-follower.mjs` 的 `createFollowDecoder` 首个帧是 `{ type: 'snapshot', history: readSessionSnapshot(...) }`，其中 `history.events` 是 `{ event }` 包装。
  - `lib/index.mjs` 的 `onFrame` 用 `historyPage(frame.history, …)` 把它变成 `kind: 'session-snapshot'`，`events` 是 host 原始事件 `{ type, time, data }`（`assistant/message` 的正文在 `data.message.content`，思考在 `content` 的 `reasoning` 块）。
  - 客户端之前把 snapshot 事件当成 wire 结构 `{ type, text }` 取文本，取错了层；而且只依赖 subscribe 的 snapshot，snapshot 没到/为空就是空白。`subscribe` 的请求方式（`sessionId` + `assistantStream`）和字段名本身是对的。
- 变化：
  - `open(sessionId:)` 时同步只发**一条**该会话的 `history`（`maxMessages: 60`、`view: "conversation"`、`requestId: "open-history-<id>"`），不按行批量发。
  - `session-snapshot` 与 `history` 共用 `decodeHistory`：按 `{type, time, data}` 解码 `user/message`、`assistant/message`（text + reasoning 块）、`tool/call`、`tool/result`，按 turn 边界折叠。
  - 首页 DSH 会话默认打开 `DSHConversationView`，去掉 `CODYNC_DSH_CHAT_PAGE` 开关；旧 `DSHChatScreen` 文件保留但不再作为入口。
- 文件：`apps/ios/DSHKit/Sources/DSHKit/DSHGateway.swift`、`apps/ios/Views/HomeSourcesView.swift`。
- 验证：按要求本轮只验证编译通过（DevDebug 真机构建），未做运行/截图验证。
- 限制/待办：工具归属按同一 turn 内的 `tool/call` 顺序聚合；跨轮复用同一 callId 的情况未遇到。
- 关联：C0123。

### C0125 · 2026-11-04 · 首页改版：置顶页 + 来源分页

- 原因：首页要先把钉住的会话放第一页，其余按来源分页；来源多选移到设置。
- 变化：
  - 第一页改为「置顶页」：只显示钉过的会话，Coe / DS Bot / DSH 都能钉，按钉的先后排序；没有钉任何会话时显示「长按会话，选『钉在首页』」。
  - 钉选入口在会话长按菜单的 More 子菜单：`钉在首页` / `从首页移除`（SF Symbol `pin` / `pin.slash`）。`@AppStorage("homePinned")` 存 `source|id`，换行分隔。
  - 置顶页后用 `TabView(.page)` + 原生 page control 圆点，按勾选来源各一页，顺序固定 Coe、DS Bot、DSH；置顶页永远第 0 页。
  - 去掉右上角漏斗菜单，右上只留「+」。来源多选移到设置新增的「首页来源」（默认只勾 Coe，至少保留一项），只决定置顶页后面有哪几页。
  - 删掉设置调试区的「混排/分页」开关与旧混排列表代码；DSH 连接条件改为「DSH 页已勾选或钉了 DSH 会话」。
- 文件：`apps/ios/Views/HomeSourcesView.swift`（重写）、`apps/ios/Views/HomeSource.swift`、`apps/ios/Views/SettingsView.swift`。
- 验证：按要求本轮只验证编译通过（DevDebug 真机构建）。
- 限制/待办：钉住的会话只在当前在线列表可见（未保存标题做离线占位）；长按菜单仍是自绘菜单，不是系统 contextMenu 的 More。
- 关联：C0118、C0122。

### C0126 · 2026-11-04 · 首页与会话页恢复顶部渐进模糊

- 原因：上一版首页用了整块 `.toolbarBackground(.ultraThinMaterial)`，不是原来的从上往下渐隐效果。
- 变化：
  - 用 `git log -S "scrollEdgeEffectStyle"` 找到原实现：`BotListView` 用过 `.scrollEdgeEffectStyle(.soft, for: .top)`（iOS 26 的渐进模糊）。
  - 首页置顶页/各来源页的 `List` 恢复该修饰；聊天页共用的 `ChatTranscriptList` 也加上，Coe 与 DSH 对话页同时生效。
  - 去掉首页的 `.toolbarBackground(.visible)` + `.toolbarBackground(.ultraThinMaterial)`；头像的修法保留；sheet 里的 `.softScrollEdges()` 不变。
- 文件：`apps/ios/Views/HomeSourcesView.swift`、`apps/ios/Kit/Sources/CodyncUI/Thread/ChatTranscript.swift`。
- 验证：按要求本轮只验证编译通过（DevDebug 真机构建）。
- 限制/待办：聊天页底层是 UIKit 集合视图，`.scrollEdgeEffectStyle` 在聊天页是否生效需要真机确认（未截图）。
- 关联：C0122、C0125。

### C0127 · 2026-11-04 · 首页长按恢复自绘消息卡片与完整菜单

- 原因：首页改版换了行组件，长按只剩整行高亮，消息预览卡片没了，菜单项也少了。
- 变化：
  - 从 `BotListView`（含工作树里未提交的改动）复用原实现：`BotMenuPreview` + 原生 `contextMenu` 的 preview，圆角用 `.contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 34, style: .continuous))` 控制（不是 clipShape），行仍用 `onTapGesture`、不包在 Button 里。
  - 置顶页和三个来源页都走这套；DSH 新增 `DSHSessionMenuPreview`（标题 + 最后一条消息预览）。
  - 菜单恢复：标为未读/标为已读、置顶/取消置顶、新建分组（host 支持时）、分享为模板、更多；「更多」里含 复制 ID、钉在首页/从首页移除、编辑资料/编辑群、移到分组、设为主 Bot、隐藏、删除。DSH 只保留它支持的：复制 ID、钉选。
- 文件：`apps/ios/Views/HomeSourcesView.swift`。
- 验证：按要求本轮只验证编译通过（DevDebug 真机构建）。
- 限制/待办：长按卡片的视觉（34 圆角、卡片宽度）沿用 BotMenuPreview，未截图核对。
- 关联：C0125。

### C0128 · 2026-11-04 · 去掉分页圆点，恢复顶部渐进模糊

- 原因：页面上方的原生圆点要去掉；`.scrollEdgeEffectStyle(.soft)` 在现在的结构里被裁掉，看不到渐隐。
- 排查：裁切来自 `TabView(.page)` 的分页容器——每一页被裁剪在自己的 bounds 内，页内 `List` 的滚动边缘效果也被一起裁掉；聊天页底层是 UIKit 集合视图，SwiftUI 的滚动边缘效果对它不生效；`toolbarBackground` 已移除，不是它盖的。
- 变化：
  - `TabView` 改为 `.page(indexDisplayMode: .never)`：保留左右滑动，去掉圆点；页序仍是 置顶、Coe、DS Bot、DSH。
  - 新增 `ProgressiveTopBlur`（`CodyncUI/Thread/ChatTranscript.swift`）：`ultraThinMaterial` 按垂直渐变蒙版，从上往下渐隐，`ignoresSafeArea(.top)` 盖住状态栏/导航栏下方。
  - 首页 `chromeView` 和聊天页共用的 `ChatTranscriptList` 各叠一层；去掉各 `List` 上的 `scrollEdgeEffectStyle`；sheet 里的 `.softScrollEdges()` 保持不变。
- 文件：`apps/ios/Views/HomeSourcesView.swift`、`apps/ios/Kit/Sources/CodyncUI/Thread/ChatTranscript.swift`。
- 验证：按要求本轮只验证编译通过（DevDebug 真机构建）。
- 限制/待办：模糊高度暂定 110pt，真机可再调。
- 关联：C0126。

### C0129 · 2026-11-04 · DSH 会话改为二级页打开

- 原因：点 DSH 会话应像 Coe 一样 push 进二级页，而不是 sheet。
- 变化：
  - 首页去掉 DSH 的 sheet，改用 `.navigationDestination(item: $openDSHSession)` 在同一个 `NavigationStack` 里 push `DSHConversationView`（系统返回按钮 + 侧滑返回）。
  - `DSHConversationView` 去掉外层 `NavigationStack` 和「关闭」按钮，只保留新建会话按钮；sheet 只留给「思考 / 工具详情」。
- 文件：`apps/ios/Views/HomeSourcesView.swift`、`apps/ios/Views/DSHConversationView.swift`。
- 验证：按要求本轮只验证编译通过（DevDebug 真机构建）。
- 限制/待办：返回手势依赖系统 NavigationStack，未在真机验证。
- 关联：C0124。

### C0130 · 2026-11-04 · 修 DSH 连接反复断开重连

- 原因：DSH 连接反复断开又自动重试，一直循环。
- 根因（对照网关源码与客户端代码）：
  1. **旧 socket 的取消回响**：`receiveLoop` 对任何 socket 的 failure 都调用 `handleDrop`；当新一轮 `openSocket` 取消旧 socket 时，旧 socket 稍后报「已取消」，于是 `handleDrop → scheduleReconnect → start → 再取消新 socket → 新 socket 又报已取消`，形成循环。日志里的「已取消」「Socket未连接」与此一致。
  2. **连接非幂等**：`connectLastPaired()` 在 profile 已存在时无条件 `start()`，每次调用都拆掉现有连接（首页任务重跑/前后台切换都会触发）。
  3. **没有心跳**：网关支持 `ping` 并回 `pong`（`PROTOCOL.md`），但客户端从不发；空闲时隧道层会断开，客户端重连后又断，表现为周期性循环。
  4. 之前「一次发 12 条 history」确实会导致掉线；现已改为打开会话只发一条，且重连后只恢复当前打开的那一个会话，没有批量请求。
- 变化：
  - 旧 socket 的 failure 在 `receiveLoop` 里按 identity 忽略，不触发 `handleDrop`。
  - `connectLastPaired()` 幂等：`ready`/`connecting` 时不再重建连接。
  - 每 20 秒发一次 `ping` 心跳；断开/配对失效/主动断开时停止。
  - 重连仍是指数退避（上限 30 秒），同一时间只有一个 `reconnectTask`；进入后台 `disconnect()`，回到前台再连。
  - 重连后只对当前打开的会话重发一次 `subscribe` + 一条 `history`。
  - 日志：记录断开时的 `NSError` domain/code/message（URLSession 不暴露 WebSocket close code）与重连间隔，便于区分客户端主动断开和隧道/服务端断开。
- 文件：`apps/ios/DSHKit/Sources/DSHKit/DSHGateway.swift`、`apps/ios/Views/HomeSourcesView.swift`。
- 验证：按要求本轮只验证编译通过（DevDebug 真机构建）。
- 限制/待办：若日志显示为隧道层断开（domain 为 NSURLErrorDomain、code 1006/57 等），需要你在 Cloudflare/网络侧处理；本轮未重启任何服务。
- 关联：C0124、C0129。

### C0131 · 2026-11-04 · 首页头像内缩 4pt；长按菜单改成系统快捷图标 + 分行

- 原因：头像内图偏大；长按菜单项过少、排版不像系统菜单。
- 变化：
  - `AccountSwitcherButton` 增加 `avatarSize` 参数（默认 40）；首页传 36，外层按钮/圆框仍是 44pt，内图继续 `scaledToFill` + `Circle` 居中裁切。
  - 长按菜单顶部用 `ControlGroup` 放一枚横排的图标快捷键：置顶/取消置顶、标为未读/标为已读、编辑（编辑资料/编辑群统一叫「编辑」）。
  - 分隔线后按常用度排：钉在首页/从首页移除、新建分组、移到分组、分享为模板、设为主 Bot、复制 ID、更多；「隐藏」「删除」收进「更多」，避免误点。
  - DSH 行只显示它支持的项：钉在首页/从首页移除、复制 ID（没有快捷图标行，也没有「更多」）。
  - 预览卡片与 34 圆角保持 C0127 的实现不变。
  - `MenuItem.swift` 新增 `QuickAction` 与 `contextActions(quick:preview:_:)`。
- 文件：`apps/ios/Kit/Sources/CodyncUI/MenuItem.swift`、`apps/ios/Views/AccountSwitcherView.swift`、`apps/ios/Views/HomeSourcesView.swift`。
- 验证：按要求本轮只验证编译通过（DevDebug 真机构建）。
- 限制/待办：ControlGroup 的系统样式在不同 iOS 版本可能略有差异，未截图核对。
- 关联：C0127。

### C0132 · 2026-11-04 · 首页顶部渐进模糊被导航栏背景盖住

- 原因：首页顶部不是从上往下渐隐，像被裁掉。
- 根因：`ProgressiveTopBlur` 是 `.overlay(alignment: .top)` 挂在 `chromeView`（`NavigationStack` 的内容层），位于导航栏**下面**。`.ignoresSafeArea(edges: .top)` 只能让绘制伸进安全区，而 iOS 27 的导航栏默认 `.automatic` 背景（整块材质/不透明）画在内容之上，把渐变的上半段盖住，于是在栏底出现一条硬边，看起来像被裁。已排除：`TabView(.page)`（overlay 在它外面，不经过分页容器）、safeArea（已忽略）、`scrollEdgeEffect`（上一版已移除）、toolbarBackground（上一版已移除）。
- 变化：首页导航栏改为 `.toolbarBackground(.hidden, for: .navigationBar)`，让栏透明：overlay 和列表都能透到栏下，导航栏按钮仍在上层且清晰；`ProgressiveTopBlur` 的方向/高度不变；聊天页的模糊没有动。
- 文件：`apps/ios/Views/HomeSourcesView.swift`。
- 验证：按要求本轮只验证编译通过（DevDebug 真机构建）。
- 限制/待办：未截图；若栏底仍有硬边，下一步把 overlay 提到 `NavigationStack` 外层（覆盖导航栏层）。
- 关联：C0128。

### C0133 · 2026-11-04 · 设置页重新分组，新增触感档位

- 原因：设置页分组混乱；App 内震动强弱不可调。
- 变化：
  - 分组（从上到下）：
    1. 个人资料、状态、排序、凭证、连接应用（合并成一张卡）。
    2. 电脑、DSH 连接、Coe、DS Bot、DSH 对话（无组标题；后三个是原「首页来源」开关，保留「至少保留一项」与说明）。
    3. 通知、主题、应用语言、触感、思考细节。
    4. 退出登录、删除账户、重新开始（最底部；默认隐藏，连续点 10 次版本号显示；三者都保留二次确认）。
  - 新增「触感」：sheet 五档单选（关/轻/中/强/很强），选中立即 `Haptics.preview` 震一下；`@AppStorage("hapticsLevel")` 持久化。
  - 新增 `CodyncKit/Design/Haptics.swift` 统一入口；CodyncUI 里原来的 `UIImpactFeedbackGenerator`（CardMenuOverlay、ScreenCanvas、ConversationList）改为 `Haptics.impact()`，选「关」全部不震。
  - 未提及项的放置：多账户/登录按钮/添加账户/错误提示仍在账户卡之后；`ShortcutLeadSettings`（快捷指令默认主 Bot）放在组 2 之后；版本号区块保持独立且始终可见（10 连击触发器），放在组 3 与组 4 之间。
- 文件：`apps/ios/Kit/Sources/CodyncKit/Design/Haptics.swift`（新）、`apps/ios/Views/SettingsView.swift`、`apps/ios/Views/AccountSwitcherView.swift`、`apps/ios/Kit/Sources/CodyncUI/Bots/CardMenuOverlay.swift`、`Screen/ScreenCanvas.swift`、`Thread/ConversationList.swift`。
- 验证：按要求本轮只验证编译通过（DevDebug 真机构建）。
- 限制/待办：`BotListView.swift` 里还有一处直接 `UIImpactFeedbackGenerator`，它属于工作树里未提交的 20 项，本轮未改；等那批改动落地后再统一。触感「很强」映射到 `.rigid`，可再调。
- 关联：C0125。

### C0134 · 2026-11-04 · 设置页文案与开关调整

- 原因：设置页文字与实际不符，通知应是开关而不是跳转行。
- 变化：
  - 「DSH 连接」右侧只显示「已连接」，不再带电脑/网关名字（连接中/失败/未连接不变）。
  - 删除「首页来源只决定置顶页后面有哪几页；至少保留一项」的说明文字。
  - 「通知」改为 `Toggle`：打开时请求通知权限；关闭时跳到系统设置（iOS 不允许 App 自行关闭）。
  - 「应用语言」改为「语言」（列表行、语言页标题）。
  - 首页来源名称：Coe → `COE`、DS Bot → `DSHB`、DSH 对话 → `DSHC`。
  - 「连接应用」改为「连接」。
- 文件：`apps/ios/Views/SettingsView.swift`、`apps/ios/Views/HomeSource.swift`、`apps/ios/Views/LanguageSettings.swift`、`apps/ios/Views/AccountSwitcherView.swift`。
- 验证：按要求本轮只验证编译通过（DevDebug 真机构建）。
- 限制/待办：通知开关关闭时只能跳系统设置，回来后才反映真实状态。
- 关联：C0133。

### C0135 · 2026-11-04 · 降低 DSH 会话打开时的断线概率

- 原因：DSH 连接经常失败。
- 排查：
  - 网关开着 Cloudflare 命名隧道（`~/.dsh/mobile-gateway-devices.json.cloudflare.json`: enabled, mode=named），手机保存的 endpoint 很可能是隧道地址；隧道对空闲和大帧都更敏感。
  - 打开会话时的 `history` 原来请求 60 条且无 `maxBytes`，大历史会生成很大的 WebSocket 帧；之前的日志显示 history 之后容易掉线。现在改为 30 条并 `maxBytes: 262_144`。
  - 认证失效（`authentication-required`）会删除本地凭证并停在「连接失败」，必须重新配对；设备文件里当前有 2 台设备。
  - 已在上轮修掉：旧 socket 取消回响导致的重连循环、非幂等 `connectLastPaired`、无心跳；本轮再把握手成功（收到 `sessions`）时清零退避计数。
- 变化：`open`/重连恢复会话的 `history` 请求改为 `maxMessages: 30`、`maxBytes: 256KB`；`sessions` 成功时 `reconnectAttempt = 0`。
- 文件：`apps/ios/DSHKit/Sources/DSHKit/DSHGateway.swift`。
- 验证：按要求本轮只验证编译通过（DevDebug 真机构建）。
- 限制/待办：若仍频繁失败，看 Console 里 `com.suiyikou.codync.dsh-gateway` 的 `DSH socket dropped`：`NSURLErrorDomain/-1005/1006` 多为隧道/网络；网关 `authentication-required` 则需要重新配对。需要你在网络侧确认 Cloudflare 隧道稳定性。
- 关联：C0130、C0124。

### C0136 · 2026-11-04 · 修设置里打开「触感 / DSH 连接」后跳回首页

- 原因：从设置 sheet 里打开「触感」或「DSH 连接」的子 sheet 时，设置页被一起关掉、退回首页。
- 根因：C0035 记录过同类问题——从 `Form`/`List` 的行内（或 Form 内容的 `Group`）去 present sheet，呈现锚点会随行/内容重建失效，内层 sheet 一出现就把外层设置 sheet 顶掉。C0133 把这两个 `.sheet` 挂在了 `SettingsView` 的 `Group`（Form 内容）上，复发了同一个问题（不是 @AppStorage/Haptics 状态刷新导致的）。
- 变化：把 `showDSHConnect` / `showHaptics` 提升到 `AccountSwitcherView`（设置 sheet 的根），在 Form 外层挂 `.sheet`；`SettingsView` 只保留 `@Binding` 并置位；`HapticsSettingsView` 改为模块内可见以便在根部使用。
- 文件：`apps/ios/Views/AccountSwitcherView.swift`、`apps/ios/Views/SettingsView.swift`。
- 验证：按要求本轮只验证编译通过（DevDebug 真机构建）。
- 限制/待办：其余设置子页沿用原来的呈现方式，未改。
- 关联：C0035、C0133。

### C0137 · 2026-11-04 · 长按菜单快捷按钮显示图标 + 文字

- 原因：`ControlGroup` 里的三个快捷按钮只有图标，没有文字。
- 变化：每项 `Button` 的 label 改为 `Label { Text(title) } icon: { MenuGlyph(...) }`，并显式 `.labelStyle(.titleAndIcon)`；没有使用 `.compactMenu` 或 `.iconOnly`。最多仍放三项。
- 文件：`apps/ios/Kit/Sources/CodyncUI/MenuItem.swift`。
- 验证：按要求本轮只验证编译通过（DevDebug 真机构建）。
- 限制/待办：系统在 context menu 里的排列（图标在上、文字在下）由 ControlGroup 决定，未截图核对。
- 关联：C0131。

### C0138 · 2026-11-04 · 首页顶部渐变改挂到滚动视图（与聊天页同一层）

- 原因：首页顶部渐进模糊仍被裁；C0132 认为「导航栏背景盖住」的结论不完整。
- 结构（本次修前）：`NavigationStack` → `chromeView`（`baseView` = `TabView(.page)` + navigationTitle + toolbar）→ `chromeView.overlay(alignment: .top) { ProgressiveTopBlur() }`；而列表在 `TabView` 的每一页里（`List`）。即 overlay 与滚动的 `List` 不在同一层，挂在被导航栏/内容安全区约束的外层上，`ignoresSafeArea(.top)` 无法让它跨出该层被裁剪的范围。
- 对比聊天页（正常）：`NavigationStack` → `ThreadView` → `ChatTranscriptList` = `ConversationList(...)` 的 `.overlay(alignment: .top) { ProgressiveTopBlur() }`，overlay 直接挂在**滚动视图**上。
- 变化：把 `ProgressiveTopBlur` 从 `chromeView` 移到 `pinnedPage` / `sourcePage` 各自的 `List` 上（`.plainRosterList().overlay(alignment: .top) { ProgressiveTopBlur() }`），与聊天页同一层级；去掉 `chromeView` 上的 overlay 和 `.toolbarBackground(.hidden)`。聊天页的模糊没动。
- 备选（未改，按你要求先说明）：若仍有裁切，可去掉 `TabView(.page)`，改成普通 `List` + 自己处理左右切换（或顶部四页切换），就能完全照聊天页的结构挂。
- 文件：`apps/ios/Views/HomeSourcesView.swift`。
- 验证：按要求本轮只验证编译通过（DevDebug 真机构建）。
- 限制/待办：`TabView(.page)` 的分页容器是否仍会裁页内 overlay 需要真机确认；若裁则采用上面的备选。
- 关联：C0128、C0132。

### C0139 · 2026-11-04 · 首页改用横向 ScrollView 分页，顶部渐变从屏幕顶开始

- 原因：首页顶部渐变从导航栏下方才开始，导航栏区域是一整块白底，中间有硬边。
- 根因：聊天页的 `ConversationList` 是显式延伸到安全区外的——它用 `safeFrame` / `fullFrame` 计算 `outsets`，让集合视图到达导航栏和状态栏下面；而首页的 `TabView(.page)` 把每一页限制在安全区内，页内 `List` 的 frame 到不了导航栏下，挂在其上的 overlay 自然从栏底开始。`toolbarBackground(.hidden)` 只去掉栏背景，不能让页面延伸，所以 C0138 的做法不完整。
- 变化：
  - 去掉 `TabView(.page)`，改成横向 `ScrollView` + `LazyHStack` + `.scrollTargetBehavior(.paging)`；页序（置顶、COE、DSHB、DSHC）和左右滑动不变，仍然没有圆点。
  - 整个分页 ScrollView `.ignoresSafeArea(edges: .top)`，`ProgressiveTopBlur` 挂在这个滚动视图的上沿（与聊天页挂在 `ConversationList` 上同一层级），从屏幕顶部开始渐隐。
  - 首页导航栏 `.toolbarBackground(.hidden, for: .navigationBar)`。
  - 每页 `List` 的滚动内容顶部留出「状态栏 + 44pt 导航栏 + 12pt」的边距，第一行不会被头像/「+」挡住。
- 文件：`apps/ios/Views/HomeSourcesView.swift`。
- 验证：按要求本轮只验证编译通过（DevDebug 真机构建）。
- 限制/待办：`topBarInset` 以「状态栏 + 44pt inline 栏」估算，若系统栏高度不同可能差几 pt；横向 ScrollView 与竖向 List 的手势组合需真机确认。
- 关联：C0138、C0128。

### C0140 · 2026-11-04 · 设置里的三个首页来源加上图标

- 原因：设置里 COE / DSHB / DSHC 三个来源开关没有图标。
- 变化：
  - COE 用设计文件 `样式文件/dsh-style/icons/sidebar/IconAgentPresetOutlineRegular.svg`，复制为 `apps/ios/Resources/Assets.xcassets/coe-agent.imageset`（SVG，template 渲染，随主题着色）。
  - DSHB 用 Remix `deepseek-line`；DSHC 用 Remix `chat-ai-line`。
  - 三个来源的 `Toggle` 改用 `Label`，图标 22×22。
- 文件：`apps/ios/Views/SettingsView.swift`、`apps/ios/Resources/Assets.xcassets/coe-agent.imageset`（新）。
- 验证：按要求本轮只验证编译通过（DevDebug 真机构建）。
- 限制/待办：COE 图标是 480 viewBox 的路径，缩到 18pt 后的清晰度未截图核对。
- 关联：C0134。
### C0141 · 2026-11-04 · 设置里来源图标统一为 22pt，设置标题加粗一档

- 原因：COE 的 22pt 图标比 DSHB/DSHC 的 18pt 好看，希望三处一致；设置页标题希望更粗。
- 变化：
  - `HomeSourceIcon` 的容器仍是 22×22；COE 的矢量图按 22 绘制，Remix 的 `deepseek-line`、`chat-ai-line` 从 18 提到 22，三者视觉尺寸一致。
  - 设置页导航标题改为自定义 principal 文本，`17pt bold`（比默认 inline 标题粗一档）。
- 文件：`apps/ios/Views/SettingsView.swift`、`apps/ios/Views/AccountSwitcherView.swift`。
- 验证：按要求本轮只验证编译通过（DevDebug 真机构建）。
- 限制/待办：`bold`（700）比默认 semibold（600）粗一档；若还想更粗可换 heavy。
- 关联：C0140。
### C0142 · 2026-11-04 · 回退 C0141 的加粗标题与 22pt 图标，COE 改用 ghost-4-line

- 原因：C0141 的加粗标题和 22pt 图标观感不好；COE 不想再用给定的 SVG。
- 变化：
  - 设置页标题回退为系统默认 inline 标题（去掉自定义 principal 文本）。
  - 三个来源图标回到 18pt（COE/DSHB/DSHC 一致，容器仍 22×22）。
  - COE 图标改用 Remix `ghost-4-line`；删除 `coe-agent.imageset` 及其 SVG。
- 文件：`apps/ios/Views/AccountSwitcherView.swift`、`apps/ios/Views/SettingsView.swift`、删除 `apps/ios/Resources/Assets.xcassets/coe-agent.imageset`。
- 验证：按要求本轮只验证编译通过（DevDebug 真机构建）。
- 限制/待办：无已知新增限制。
- 关联：C0140、C0141。
### C0143 · 2026-11-04 · 设置行统一：图标 20/28、标题 medium、同一个行组件

- 原因：设置里开关行和箭头行用的布局不同，COE/DSHB/DSHC/通知的文字比别的行往右偏；图标大小、字重、间距也不一致。
- 变化：
  - `SettingsRow`：图标 18→20，固定 28pt 宽的框居中，图标与标题间距 12；标题字重改为 `.body.weight(.medium)`（原 regular 加粗一档）。
  - 新增 `SettingsToggleRow`：与 `SettingsRow` 完全相同的 HStack/图标框/间距/字重，右侧 `Toggle` 加 `.labelsHidden()`，不再带 Toggle 自带的 label 间距。
  - 来源开关（COE/DSHB/DSHC）改用 `SettingsToggleRow`，图标统一 Remix：`ghost-4-line`、`deepseek-line`、`chat-ai-line`（20pt/28pt 框）。
  - 「通知」「思考细节」改用 `SettingsToggleRow`。
  - 「退出登录」「删除账户」从纯文字按钮改为 `SettingsRow`（`logout-box-line` / `delete-bin-line`，destructive）。
  - 个人资料行：头像 44→28（与图标框同宽），标题 `.body.weight(.medium)`。
- 对齐审计（修前哪些行偏了）：
  - COE / DSHB / DSHC / 通知 / 思考细节：走 `Toggle` 自带 label，标题比 `SettingsRow` 右偏（Toggle 内部间距，约 8–12pt），且图标尺寸不一致（18/22）。
  - 退出登录 / 删除账户：纯文字行没有图标，标题比其它行左偏约 34pt。
  - 个人资料：头像 44 + 12 间距，标题比其它行右偏约 22pt。
  - 状态 / 排序 / 凭证 / 连接 / 电脑 / DSH 连接 / 主题 / 语言 / 触感 / 重新开始：彼此已经对齐（18/22+12），本轮随统一参数整体右移 6pt（22→28 框，18→20 图标）。
  - 未改：多账户切换列表、登录按钮、`ShortcutLeadSettings`（不在本次清单内）。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Controls.swift`、`Thread/ThinkingDetailsSettings.swift`、`apps/ios/Views/HomeSource.swift`、`SettingsView.swift`、`AccountSwitcherView.swift`。
- 验证：按要求本轮只验证编译通过（DevDebug 真机构建）。
- 限制/待办：多账户/登录/快捷指令 Picker 仍沿用原样；若需要也统一可另开一条。
- 关联：C0133、C0141、C0142。
### C0144 · 2026-11-04 · 例行任务新建/编辑页改为原生 Form 并汉化

- 原因：两个例行任务 sheet 还是手写灰底输入框、描边胶囊按钮和英文文案。
- 变化：
  - 整页改为 `Form` + `Section`：名称 `TextField`、指令 `TextField(axis: .vertical)`；「何时运行 / 重复 / 时区」用原生 `Picker(.menu)`；「时间」用 `DatePicker(.hourAndMinute)`；Cron 用等宽 `TextField` 并关闭自动大写/纠错；「下次运行」放在定时 Section 的 footer。
  - 顶部工具栏：左「关闭」、右「创建 / 保存」（原底部 Create routine / Save changes 移除）。
  - 编辑页：删除放到最底部独立 Section，`role: .destructive` + 二次确认（原生 alert）；「立即运行」为普通一行。
  - 图标全部 Remix（`time-line`、`settings-3-line`、`error-warning-line`、`wifi-off-line`、`play-circle-line`、`delete-bin-line`），按设置页 20pt/28pt 框渲染。
  - 汉化：Edit routine→编辑例行任务、Instruction→指令、Schedule→定时、Repeat→重复、Daily→每天、Custom→自定义、At→时间、Create routine→创建、Save changes→保存、Next run→下次运行，以及 Picker 选项/星期/footer/提示文案；文案加在 `zh-Hans.json` / `zh-Hant.json`，代码用 `L10n.tr`。
  - 保存、删除、立即运行、定时校验逻辑未改（仍走 `saveRoutine` / `routineAction` / `routineSchedule`）。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Routines/RoutineEditorView.swift`、`apps/ios/Kit/Sources/CodyncKit/Resources/Languages/zh-Hans.json`、`zh-Hant.json`。
- 验证：按要求只验证编译；`generic/platform=iOS` 构建通过。真机安装本轮遇到设备隧道断开（`The tunnel connection failed`），待手机解锁/重连后重试。
- 限制/待办：真机安装与界面观感未核对。
- 关联：C0097。

### C0145 · 2026-11-04 · 语音胶囊的语音转写层（本机 Speech + 中文权限说明）

- 原因：首页语音胶囊要把说的话转成文字，并且以后能换成云端服务，所以先只做一层可替换的转写。
- 变化：
  - 新增 `SpeechTranscriber` 协议（`locale` / `permission()` / `start()` / `pause()` / `resume()` / `finish()` / `cancel()`）：界面只依赖协议，换云端实现时不改胶囊。
  - 新增 `OnDeviceSpeechTranscriber`：`SFSpeechRecognizer` 流式给部分结果；`supportsOnDeviceRecognition` 为真时设 `requiresOnDeviceRecognition`，优先本机识别；音量按 -50…0 dB 映射到 0…1；静音 2 秒上报一次 `.silence`；暂停保留已听到的内容，恢复后继续追加；`finish()` 最多等 1.2 秒拿最终文字，等不到就用已有的。
  - 权限：先 `AVAudioApplication.requestRecordPermission()`，再 `SFSpeechRecognizer.requestAuthorization`，结果分 `granted` / `denied` / `unavailable`，拒了不抛异常由界面给提示。
  - 麦克风与语音识别的用途说明改为中文。本工程这两条走 `project.yml` 的 `INFOPLIST_KEY_*`（构建设置，覆盖 Info.plist 文件里的同名键），改完重新生成 `project.pbxproj`；生成时被重写的 4 个 scheme 文件已按原样还原，另一会话的未提交改动没有被带走。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Voice/SpeechTranscriber.swift`（新）、`apps/project.yml`、`apps/Codync.xcodeproj/project.pbxproj`。
- 验证：按要求只验证编译，`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug -destination 'generic/platform=iOS'` 通过；构建产物 Info.plist 里两条用途说明已是中文。
- 限制/待办：没有真机录音自测；`Speech` 在模拟器上的行为未验证。
- 关联：C0148。

### C0146 · 2026-11-04 · 设置里可以选择或切换主 Bot

- 原因：语音胶囊要发给「主 Bot」，此前只能在会话长按菜单里设置，没有一个能看见当前是谁的入口。
- 变化：
  - 设置首页第一组新增「主 Bot」行（Remix `star-line`，与其它设置行同一套 20pt/28pt 图标框），右侧显示「Bot 名 · 电脑名」。
  - 点开是系统 sheet：按电脑分组列出所有 Bot（组聊不参与），当前主 Bot 打勾；点一行调用与长按菜单完全相同的 `store.setLead(bot)`，同一份数据。
  - 行和 sheet 都挂在设置 sheet 的根视图上（C0035 的坑：挂在 Form 行上会被重建并带走整个设置页）。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Bots/LeadBotPickerView.swift`（新）、`apps/ios/Views/SettingsView.swift`、`apps/ios/Views/AccountSwitcherView.swift`。
- 验证：按要求只验证编译通过。
- 限制/待办：宿主低于 2.33.0 时 `setLead` 会被拒（与长按菜单一致），本轮没有按 `supportsLeadChoice` 隐藏这一行；多电脑时按电脑分组显示。
- 关联：C0148。

### C0147 · 2026-11-04 · 通用玻璃吐司

- 原因：发送后要像系统「从某某粘贴了某某」那样用一条玻璃胶囊提示，而且以后别的地方也要用。
- 变化：新增 `GlassToastItem`（图标 + 文案 + 可选点击动作）、`GlassToast`（`.glass(in: Capsule())`，46pt 高，20pt Remix 图标，subheadline 单行截断）与 `.glassToast($item, topPadding:)` 修饰器：从顶部落下淡入、2 秒自动消失、点一下执行动作后消失、只盖住胶囊本身不挡别处点击、跟随「减少动态效果」、VoiceOver 可读。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Toast/GlassToast.swift`（新）。
- 验证：按要求只验证编译通过；第一次真正使用在 C0148 的发送提示。
- 限制/待办：垂直位置由调用方的 overlay 与 `topPadding` 决定，本轮只在首页顶部使用。
- 关联：C0148。

### C0148 · 2026-11-04 · 首页语音胶囊：录音、转写、确认并发送给主 Bot

- 原因：首页左下角原来是扩展入口，而扩展在设置里已经有入口；把它换成对主 Bot 说话。
- 变化：
  - 入口：底部左下角改为 Remix `mic-line` 语音按钮（同为 48pt 玻璃圆、同一套渲染），移除原来的扩展按钮。
  - 胶囊：点击后整排（左下按钮、搜索栏、拍照）在同一个 `GlassEffectContainer` 里动画换成一条玻璃胶囊（`.glassEffect(.regular.interactive(), in: Capsule())`，48pt 高、16pt 边距，与底栏同尺寸同位置）；结束、发送或取消后动画还原。
  - 胶囊内容（左→右）：主 Bot 头像（录音时呼吸缩放）、`LevelDots` 随音量起伏的波形、设置按钮、麦克风按钮、红色取消按钮（`Palette.danger`）。
  - 结束录音：录音中点麦克风为暂停，暂停后同一个按钮变成结束并转写；另外连续 2 秒无声自动结束。取消立刻停麦克风、丢掉结果、什么都不发。
  - 确认：结束后胶囊里显示转写文字，1.5 秒倒计时环到点自动发送；倒计时内可点红色取消，点文字进入编辑（停止倒计时），改完点发送。识别为空不发，提示「没听清」。
  - 发给主 Bot（`lead == true` 的那个），走 `store.send(_:to:)`，与会话里打字发送同一条路径；还没有主 Bot 时点语音只弹吐司提示先去设置里选。
  - 发送后留在首页，顶部弹玻璃吐司「已发送给 XX」，2 秒消失，点一下进入该会话。
  - 胶囊里的设置按钮：`presentationDetents([.medium])` 半屏 sheet，先只有识别语言（中文 / English，默认中文，`@AppStorage("voiceRecognitionLanguage")`）；sheet 挂在首页根视图上，不会一打开就跳回首页。
  - 触感：开始、结束、发送成功各一次，取消一次，全部走现有 `Haptics`，跟随设置里的档位。
  - 文案：新增 19 条简体/繁体词条，代码统一 `L10n.tr`，不硬编码。
  - 退到后台自动取消录音（系统的麦克风会被收走）。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Voice/VoiceSession.swift`（新）、`VoiceCapsule.swift`（新）、`VoiceRecognitionSettings.swift`（新）、`apps/ios/Views/HomeBottomBar.swift`、`apps/ios/Views/HomeSourcesView.swift`、`apps/ios/Views/BotListView.swift`（旧列表同步底栏签名）、`apps/ios/Kit/Sources/CodyncKit/Resources/Languages/zh-Hans.json`、`zh-Hant.json`。
- 验证：按要求只验证编译通过（真机构建 DevDebug），并安装到 iPhone 16 Pro；界面观感、动画和真机识别未自测。
- 限制/待办：ja/ko/fr/de/es 词条本轮未补，回退英文原文；云端转写只留了协议位置，未接 mimo；「结束」并入麦克风按钮（录音中=暂停，暂停后=结束）。
- 关联：C0145、C0146、C0147。
### C0149 · 2026-11-04 · 修首页语音按钮一按就闪退（音频线程碰主线程状态）

- 原因：真机点语音按钮立即闪退。崩溃报告（`Sully Coe-2026-11-04-155818.ips`，同一栈共 4 份）：
  `EXC_BREAKPOINT / SIGTRAP`，终止原因 `Trace/BPT trap: 5`，栈为
  `_dispatch_assert_queue_fail` ← `dispatch_assert_queue` ← `_swift_task_checkIsolatedSwift` ← `closure #1 in OnDeviceSpeechTranscriber.openMic()` ← `AVAudioNodeTap::TapMessage::RealtimeMessenger_Perform`。
  即 `installTap` 的 block 被 Swift 推断成 `@MainActor`（它写在 `@MainActor` 类的方法里、同步碰了 `self.request` / `self.report`），而 AVFAudio 在音频实时线程上调它，隔离断言当场 `SIGTRAP`。
  另外点按钮前就卡顿：`AVAudioEngine` 在 `OnDeviceSpeechTranscriber` 的存储属性里同步构造，而首页每次重绘都会构造一个 `VoiceSession`（`@State` 的初值表达式会被反复求值），等于反复造音频引擎。
- 变化：
  - 音频 tap 移到 `nonisolated static func tap(_:onLevel:)` 里构造：block 内只把 buffer 交给识别器（`request.append`），音量通过 `@Sendable` 回调 `Task { @MainActor in … }` 回主线程再改状态，音频线程不再碰任何 actor 隔离状态。
  - 识别结果回调同样改成 `nonisolated static func results(generation:into:)`（与本仓库 `Dictation` 的写法一致），识别器在自己队列上回调时不会再触发同样的断言。
  - 音量上报节流：`TapClock` 每 55ms 放行一次（约 18 次/秒），tap 的 buffer 从 1024 提到 2048 帧；波形不再每帧都往主线程丢更新。
  - `AVAudioEngine` 改成 `lazy`，首页绘制不再构造音频引擎（卡顿的主要来源）。
  - 收尾顺序改正：先 `removeTap(onBus: 0)` 再 `engine.stop()`，`tapped` 标志保证同一 bus 不会重复 remove/install；暂停、结束、取消都走同一条收尾路径。
  - `VoiceSession` 增加 `ending` 守卫：`finish()` 等识别器收尾的 1.2 秒里再点麦克风不会再起一次，取消/失败时清零。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Voice/SpeechTranscriber.swift`、`apps/ios/Kit/Sources/CodyncUI/Voice/VoiceSession.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 147）并启动。权限说明在安装包 Info.plist 里确认为中文两条。
- 限制/待办：按要求未自测交互，真机点按结果待你验收；云端转写仍只留协议位置。
- 关联：C0145、C0148。
### C0150 · 2026-11-04 · 首页语音胶囊改成厚实的 Grok 风格（只改外观与布局）

- 原因：胶囊跟搜索框一样只有 48pt 高，按钮小而挤，不像一个可以对着说话的控件。
- 变化：
  - 尺寸：胶囊 88pt 高、左右各 16pt、圆角 44（全圆角），玻璃材质沿用 `.glassEffect(.regular.interactive(), in: Capsule())`；外面加一层白色 0.15 描边（`strokeBorder`，1pt，向内不裁切）和一层柔和阴影（黑 0.18、半径 18、y 8），从列表上浮起来。底部避让安全区的逻辑没动。
  - 布局（左右内边距各 16pt，段间距 16pt）：左侧主 Bot 头像直径 48，呼吸动画在 1.0…1.06 之间，外加一层用 Bot 自身颜色做的模糊外光（同步明暗与放大）。
  - 中间：音量波形换成 `VoiceWaveform`——竖条 3pt 宽、3pt 间距、圆头，最矮 4pt、最高 36pt，条高随音量逐帧缓动（约 90ms 收敛，等效 spring 的 ease-out），并且始终带一点缓慢起伏，静音时不会变成一排死点；条形高度按中间高两端低的包络分布。
  - 右侧三个按钮，间距 10pt：设置 44pt 圆形浅底（`Palette.text` 7%）+ 20pt Remix 图标；麦克风 52pt 主按钮，录音中强调色底 + 白色图标，暂停时浅色底 + 深色图标；取消 44pt 浅红底（`Palette.danger` 14%）+ 18pt 红色 ✕（加粗一档）。
  - 图标全部复用现有 Remix：`settings-3-line`、`pause-line` / `mic-fill` / `arrow-up-line`、`close-line`。
  - 转写/倒计时：文字在胶囊中间（原波形位置），17pt、最多两行、超出在前面加省略号（`truncationMode(.head)`）；1.5 秒倒计时改成麦克风按钮外面一圈 3pt 环形进度（`trim`，从 12 点方向顺时针），不加数字，编辑时环停住；此时麦克风按钮变成发送箭头。
  - 出现/收起：从原麦克风按钮所在位置（左下）用 `scale(0.72, anchor: .bottomLeading)` + 透明度展开，spring `response 0.35 / dampingFraction 0.85`，收起反向。
  - 点击区域：三个按钮都不小于 44pt（麦克风连外圈 60pt）；按下缩放到 0.92（`VoicePress`），触感仍走 `Haptics` 与设置里的档位。
  - 录音、识别（`SpeechTranscriber`）、发送与吐司逻辑一行未改。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Voice/VoiceCapsule.swift`、`VoiceWaveform.swift`（新）、`apps/ios/Views/HomeBottomBar.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 148）并启动。按要求未自测交互、未截图。
- 限制/待办：两行文本的头部省略依赖 `truncationMode(.head)`，真机上若显示为尾部省略需要再换成自己截断；非中文语种词条未补。
- 关联：C0148、C0149。
### C0151 · 2026-11-04 · 语音胶囊 v2：玻璃按钮 + 提手 + 上拉半屏看转写

- 原因：C0150 的三个按钮是平面纯色圆，不是玻璃；72 之外先做成了 88pt，头像、波形、按钮之间空隙不均，波形被挤得很短，跟按钮之间还空出一大块。
- 变化：
  - 收起态：高度 72（`VoiceCapsule.collapsed`），左右各 16、圆角全圆（半径取高度一半 36）内容左右内边距 14pt、元素垂直居中；从左到右：头像 40、波形（铺满中间，两侧各 12）、三个按钮（设置 40 / 麦克风 48 / 取消 40，间距 8）。
  - 玻璃：胶囊本体 `.glassEffect(.regular.interactive(), in: 圆角矩形)`；三个按钮同在一个 `GlassEffectContainer` 里，各自 `.glassEffect(.regular.tint(…).interactive(), in: Circle())`——麦克风录音/待发送时 tint 用强调色、图标白色，暂停时去掉 tint；取消用 `Palette.danger.opacity(0.25)` 玻璃 + 红色 ✕。删除 C0150 加的外描边与大阴影。
  - 兜底：`if #available(iOS 26, *)` 不成立时改用 `.ultraThinMaterial` + 0.5pt 白色描边 + 顶部高光渐变（`VoiceCapsuleGlass` / `VoiceGlass`）。
  - 提手：胶囊顶部正中 36×5、`.secondary` 0.5、距上沿 6pt，点一下展开/收起；可点区域 96×24。
  - 上拉：`DragGesture` 让胶囊随手指变高（松手阈值 120pt 或快速上滑吸附），下拉同样阈值收起；吸附时 `Haptics.impact()` 跟随档位；展开/收起统一 spring response 0.4 / damping 0.85。
  - 展开态：约屏高 45% 的玻璃面板（圆角 32），顶部提手 + 头像 + 「正在听…」/主 Bot 名，中间 20 号转写全文可滚动并自动跟到最新一行（空时显示「说点什么…」占位），底部波形 + 三个按钮（与收起态同一组，`matchedGeometryEffect` 平移过去），编辑态直接在这块面板里改字，1.5 秒倒计时环仍挂在麦克风按钮外。
  - 底栏只保留收起态的 72pt 高度（`.frame(height: collapsed, alignment: .bottom)`），面板向上溢出盖住列表，列表不会被顶上去。
  - 展开时首页列表上方加 `Color.black.opacity(0.08)` 遮罩，点遮罩收起；胶囊消失（发送/取消）时面板状态一并复位。
  - 波形沿用 C0150 的竖条，最高 28pt，条数按可用宽度自动计算铺满。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Voice/VoiceCapsule.swift`、`VoiceWaveform.swift`、`apps/ios/Views/HomeBottomBar.swift`、`apps/ios/Views/HomeSourcesView.swift`、`apps/ios/Views/BotListView.swift`（旧列表同步底栏签名）、`apps/ios/Kit/Sources/CodyncKit/Resources/Languages/zh-Hans.json`、`zh-Hant.json`（新增「说点什么…」）。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 149）并启动。按要求未自测、未截图。
- 限制/待办：`SpeechTranscriber`、`VoiceSession` 未改；面板溢出底栏靠父视图不裁剪实现，若真机上溢出区域点不动需要改成把面板挂到首页 overlay。
- 关联：C0148、C0149、C0150。
### C0152 · 2026-11-04 · 语音胶囊 v3：改用原生 sheet（76 / 半屏 / 全屏），替代 C0151 的手写拖拽面板

- 原因：C0151 用 DragGesture + 自绘提手 + 溢出布局自己搭了一个半屏面板，提手、圆角、遮罩、命中测试都得自己维护。按 Figma 量的 iOS 26 官方 sheet：76pt 高时 44pt 圆按钮四边各 16pt、提手在顶部正中，正好可以直接借原生 sheet 承载。
- 变化：
  - 点首页麦克风后弹出一个原生 sheet，内容就是语音胶囊；sheet 挂在首页根视图上（不挂列表/Form 行，避免 C0035/C0136 那种被重建后跳回首页）。
  - `.presentationDetents([.height(76), .medium, .large], selection:)`，打开时固定在 `.height(76)`；`.presentationDragIndicator(.visible)` 用系统提手（删掉 C0151 自绘的）；`.presentationBackgroundInteraction(.enabled(upThrough: .height(76)))`——小档时首页还能滑动点击，半屏以上系统自己变暗并挡住；`.interactiveDismissDisabled()` 不允许下拉关闭，只能点 ✕ 或发送完自动关。背景、圆角、描边全部用系统默认，不设 `presentationBackground`。
  - 删掉 C0151 的 DragGesture、自绘提手、手写面板、溢出布局与 0.08 遮罩；`HomeBottomBar` 回到原来的单排底栏（只有麦克风按钮触发 sheet）。
  - 小档 76pt：✕ 取消 44、主 Bot 头像 36（呼吸动画保留）、波形（铺满中间，最高 24pt）、设置 44、麦克风 44；按钮都在 `GlassEffectContainer` 里、各自 `.glassEffect(.regular.tint(…).interactive(), in: Circle())`，麦克风录音时 tint 强调色 + 白图标，暂停去掉 tint；取消是浅红 tint 玻璃 + 红 ✕；iOS 26 以下仍走 `.ultraThinMaterial` + 0.5pt 描边的兜底。
  - 半屏：顶部一行 — 左 ✕、中间标题（录音中「正在听…」，结束后「发给 XX」）、右麦克风/发送；中间 20 号转写全文可滚动、自动跟到最新一行，空时「说点什么…」；底部波形 + 设置；编辑态在本页直接改字，1.5 秒倒计时环挂在麦克风/发送按钮上。
  - 识别结束（或权限提示）时如果还停在小档，自动切到 `.medium` 显示文字，倒计时结束照常发送。
  - 三档共用同一个视图，靠 detent 切换内容；按钮用 `matchedGeometryEffect` 从小档一行平移到半屏的标题栏。全屏 `.large` 暂时复用半屏那套布局，代码里留了 TODO（二期做连续通话）。
  - 语音设置（识别语言）改成从语音 sheet 内再弹一层 `.medium` sheet（一个 presenter 同时只能一个 sheet），不再从首页弹。
  - detent 变化时 `Haptics.selection()`（新增，跟随触感档位、关就静音）；发送或取消后关闭 sheet 并把 detent 复位到 `.height(76)`；发完仍在首页弹玻璃吐司「已发送给 XX」。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Voice/VoiceSheetView.swift`（新，替代删除的 `VoiceCapsule.swift`）、`VoiceWaveform.swift`、`apps/ios/Views/HomeBottomBar.swift`、`HomeSourcesView.swift`、`BotListView.swift`（旧列表同步底栏签名）、`apps/ios/Kit/Sources/CodyncKit/Design/Haptics.swift`、`Resources/Languages/zh-Hans.json`、`zh-Hant.json`（新增「发给」）。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 150）并启动。按要求未自测、未截图。
- 限制/待办：`.large` 一档暂无独立内容；`SpeechTranscriber`、`VoiceSession` 未改。
- 关联：C0148、C0149、C0150、C0151。
### C0153 · 2026-11-04 · 语音 sheet v3.1：持续录音、手动/自动发送、按钮归位

- 原因：C0152 真机试出来的五件事——底栏没有一起收起、2 秒静音就结束太急、小档就能发送、按钮位置和官方 sheet 不一致、图标粗细不统一。
- 变化：
  - 底栏动画：`HomeBottomBar` 增加 `hidden`，语音 sheet 打开时底栏下移 30pt 并淡出（spring 0.3/0.9）、同时关闭点击，关闭 sheet 时同路径回来；由 `showVoice` 与 sheet 弹出同一时刻驱动。
  - 持续录音：删掉「连续 2 秒无声自动结束」——`SpeechEvent.silence`、静音看门狗、`VoiceSession` 的 `.silence` 分支一并移除；不点暂停/结束就一直录。
  - 识别任务续接：SFSpeechRecognizer 单个任务约 1 分钟，`OnDeviceSpeechTranscriber` 现在把一长段录音拆成任务链——任务给出最终结果（或被系统结束）时把文字并入 `committed`，麦克风不断、立刻用新 request 起下一个任务，文字无缝接上；麦克风缓冲区通过一把锁的 `BufferSink` 写进「当前」request，音频线程不再为了拿 request 每帧回主线程。
  - 空结果：用户主动结束且文字为空时不再收尾/关闭，标题区下方显示「没听清，再说一次」（`notHeard`），sheet 保持打开、麦克风可直接继续录。
  - 发送方式（新设置）：`VoiceSendMode`（`@AppStorage("voiceSendMode")`，默认手动），在语音设置 sheet 里「识别语言」下面新增「发送方式」两行（自动发送 / 手动发送，带说明）。手动：结束后升到半屏、无倒计时、点发送才发；自动：升到半屏并显示 1.5 秒倒计时环，点文字编辑即停表转为手动。发送按钮在文字为空时置灰不可点（`canSend`）。
  - 按钮布局：小档从左到右 = 头像 36（呼吸保留）→ 波形 → 设置 44 → 暂停/继续 44 → 关闭 44（最右），离边缘 16、间距 12，小档不再有发送；半屏/全屏 = 左对齐标题（正在听… / 发给 XX，失败时「发送失败，点发送重试」并转红）+ 右上发送 44、关闭 44；底部波形 + 设置 44 + 暂停 44（最右）。关闭用 `matchedGeometryEffect` 从小档最右移到半屏右上，设置与暂停移到右下。
  - 关闭时机：只有发送成功才自动关 sheet（并弹玻璃吐司「已发送给 XX」）；没听清、识别出错、暂停、结束都不关；发送失败 sheet 不关、文字保留，可再点发送重试。发送改成 `BotStore.sendAndConfirm(_:to:)`（await 投递结果，`failed` 才算失败，走与会话打字完全相同的 `send` 入口）。
  - 图标：所有 44pt 圆按钮里的 Remix 图标统一 24pt、同一字重；关闭=浅红 tint 玻璃 + 红 ✕，暂停录音时=强调色 tint + 白 pause 图标，发送=强调色 tint + 白色向上箭头，设置=普通玻璃。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Voice/SpeechTranscriber.swift`、`VoiceSession.swift`、`VoiceRecognitionSettings.swift`、`VoiceSheetView.swift`、`VoiceSend.swift`（新）、`apps/ios/Views/HomeBottomBar.swift`、`HomeSourcesView.swift`、`BotListView.swift`、`Resources/Languages/zh-Hans.json`、`zh-Hant.json`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 151）并启动。按要求未自测、未截图。
- 限制/待办：`.large` 仍复用半屏布局（二期连续通话）；识别任务续接真机上的实际断点只有跑长句才能确认。
- 关联：C0148、C0150、C0151、C0152。
### C0154 · 2026-11-04 · 语音 sheet v3.2：波形改成「一条线」，识别续接不再丢字

- 原因：C0153 的波形还是竖条，和要的样子（一条线两种状态）不符；任务链续接是「旧任务结束后再开新的」，接缝处可能丢音频、也可能重复字。
- 变化：
  - 波形重写：`VoiceWaveform` 用 `TimelineView(.animation)` + `Canvas` 画一条 4pt 圆头线（`.primary`，自动适配深浅色），旧的竖条代码删干净。
    - 静音/待机：`.primary` 0.25 的完整轨道，上面一段实色线（轨道 15% 长）在轨道里左右往返，easeInOut，单程 1.2 秒。
    - 有声音：轨道与移动段淡出，线变成流动正弦——振幅随音量 0…8pt、波长 40pt、约 1 秒向右流过一个波长、两端用 `sin(πx/宽)` 包络收到 0 接回直线；振幅按 120ms 平滑插值。
    - 状态切换：音量阈值 0.14 + 300ms 释放防抖（避免来回闪），两态之间约 0.25 秒交叉过渡（轨道淡出/波浪淡入，振幅从 0 长成波浪再收回）。
    - 暂停：`VoiceWaveform(paused:)` 冻结相位与时间（形状停住、不再流动），整体 0.4 透明；继续后接着走。
    - 帧内全部在 Canvas 里画，状态存在一个类里，不逐帧重建 View 树。
  - 识别续接加固（`OnDeviceSpeechTranscriber`）：
    - 任务换班改成「先开新、再关旧」：新任务启动后旧任务再听 0.3 秒才 `endAudio`，这段时间 `BufferSink` 把每个音频 buffer 同时写给两个 request，接缝不再掉音。
    - 换班由时间主动触发（每个任务约 44 秒，早于识别器自身约 1 分钟上限），另加「任务提前结束」兜底：没有任务在听且仍在录音就立刻补一个。
    - 文字按任务分段：正在听的任务实时给部分结果，已结束的任务把最终文字并入 `committed`；拼装时按「旧文字尾部 = 新文字开头」找最长重复（≥2 字符、最多 60）去重，中英文分别处理空格，接缝不再重复字。
    - UI 无感：换班不触发 detent 变化、不闪标题、波形不中断（音量与阶段状态都不动）。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Voice/VoiceWaveform.swift`、`SpeechTranscriber.swift`、`VoiceSheetView.swift`（传 `paused`）。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 152）并启动。按要求未自测、未截图。
- 限制/待办：去重是字符级启发式，识别器给的标点恰好落在接缝时可能留下一个多余标点；`.large` 仍复用半屏布局（二期连续通话）。
- 关联：C0148、C0151、C0152、C0153。
### C0155 · 2026-11-04 · 语音 sheet v3.3：进出对称、半屏标题栏、按状态显示按钮、去掉关闭按钮

- 原因：C0154 真机上关闭 sheet 时它往右下角缩没（`matchedGeometryEffect` 的 zoom 转场）、底栏也不原路回来；半屏标题栏还挂着「正在听…」这类状态文字；按钮不看状态、四处都有 ✕。
- 变化：
  - 动画进出对称：删掉 sheet 内所有 `matchedGeometryEffect`（以及随之的 morph 命名空间），只留系统默认的 sheet 上下滑；底栏改成 `barAway` 状态驱动，打开时先置位（整排下移 30pt + 淡出），`showVoice` 变 false 的瞬间（sheet 开始下滑）再置回（从下方升回 + 淡入），`onDismiss` 兜底复位，进出同一组 spring（0.3 / 0.9）。
  - 关闭即结束录音：删掉所有档位的 ✕ 按钮；去掉固定 `.interactiveDismissDisabled()`，改为只在「暂停/有文字」时禁用系统下拉（否则下拉直接关）；关闭时 `voice.discard()` 停止录音、丢弃本次文字、不发送，`onDismiss` 里复位 detent 与底栏。
  - 丢弃确认：暂停或已结束且**有文字**时，下拉（sheet 内加了 `DragGesture` 阈值 70pt）先弹 `confirmationDialog`「丢弃这段语音？」→「丢弃」（红色，关闭）／「继续编辑」；录音中或没文字直接关。
  - 半屏/全屏标题栏：左侧主 Bot 头像 32 + 名字（17pt semibold），去掉「正在听…」「录音已暂停」等状态文字；头像只在录音时呼吸（1.0↔1.06 + 外光），暂停时静止 1.0、不发光（小档同一规则）。右上按状态显示：录音中不显示；暂停/已结束且有文字才显示发送按钮（44，强调色 tint，白色 24pt 向上箭头），自动发送模式的 1.5 秒倒计时环挂在该按钮上；没文字时文字区显示「没听清，再说一次」。「发送失败，点发送重试」从标题移到文字区顶部的红色小字。
  - 小档 76pt：头像 36 → 波形 → 设置 44 → 暂停/继续 44（贴右边距 16），没有关闭按钮、也没有发送按钮。
  - 暂停/继续：图标换成 Remix `pause-fill` / `play-fill`（24pt）；显示播放三角时给图标 `.offset(x: 1.5)` 做光学居中，按钮尺寸与内边距不变。
  - 流畅度：音量从 `VoiceSession` 里拆出来成独立的 `VoiceLevelModel`，只有波形读它（在 Canvas 里读，不订阅就不会重绘 sheet）；档位切换的布局变化统一走 `withAnimation(.spring(response: 0.35, dampingFraction: 0.9))` / 同参数的 `.animation(..., value: isSmall)`；没有不带 `value` 的隐式动画。
  - 语义修正（顺带）：暂停按钮现在同时承担「结束」——暂停时把已听到的文字定格，有文字就进入可发送状态（自动模式开始倒计时），没文字就提示「没听清」；继续则接着录。
  - 退到后台：直接关闭 sheet 并丢弃本次录音（`showVoice = false` + `discard()`），不再在后台挂一个录音界面。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Voice/VoiceSheetView.swift`、`VoiceSession.swift`、`VoiceWaveform.swift`、`apps/ios/Views/HomeSourcesView.swift`、`Resources/Languages/zh-Hans.json`、`zh-Hant.json`（新增「丢弃这段语音？」「丢弃」「继续编辑」）。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 153）并启动。按要求未自测、未截图。
- 限制/待办：`.large` 仍复用半屏布局（二期连续通话）；「丢弃」确认依赖 sheet 内下拉手势 + 系统下拉禁用，若真机上从文字区下拉没弹确认，需要改成按钮触发。
- 关联：C0151、C0152、C0153、C0154。
### C0156 · 2026-11-04 · 语音波形两端圆角、半屏标题栏上边距改 16

- 原因：真机看波形线的两端是方的（不是圆头）；半屏 sheet 里头像和名字贴着顶部太紧。
- 变化：
  - 波形：`VoiceWaveform` 的轨迹、移动段和波浪都从 2pt（半个线宽）内缩起画——之前起点落在 `x = 0`，圆头的一半被 Canvas 边界裁掉，看上去就成了方角；移动段的活动范围也扣掉这段内缩，两端仍是完整圆头。波浪按 `x` 取值的取样收进一个局部函数，逻辑不变。
  - 半屏/全屏标题栏：内容顶部内边距 8 → 16，头像与名字往下让出 16pt（系统提手额外占用自己的空间不变）。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Voice/VoiceWaveform.swift`、`VoiceSheetView.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 154）并启动。按要求未自测、未截图。
- 限制/待办：无。
- 关联：C0154、C0155。
### C0157 · 2026-11-04 · 修语音识别不出字：任务链在初始化时自我重启成死循环，退回单任务识别

- 原因：C0153 引入的任务链（每个任务结束就立刻开下一个）在真机上变成了自我重启：第一个任务一创建就回 `isFinal` 或报错，`taskEnded` 无条件 `startTask()`，于是每几毫秒换一次 request，麦克风的 buffer 落在永远刚创建的任务上，识别器没机会出结果——表现就是「一直转不出文字」，暂停时文字为空，于是走到「没听清」。C0152 不做重启，所以那一版能识别。
- 变化：
  - **默认退回 C0152 的单任务识别**：`OnDeviceSpeechTranscriber.relayTasks = false`，麦克风 tap 直接把 buffer 写进当前 `SFSpeechAudioBufferRecognitionRequest`（不再经过 BufferSink 间接层）；`startTask()` 在换 request 时会重装 tap（这次也补上了这条：之前换 request 后 tap 仍指向旧的）。
  - 任务链保留但改为可选（`relayTasks` 打开时走原来的重叠续接 + `BufferSink` + 去重），默认关，等真机验证后再开。
  - 防死循环：任务结束（final 或报错）时**只有活得超过 1.5 秒**才续一个任务；短命任务不再重启（记一条日志），避免"刚建就结束"的循环。
  - 本机识别兜底：首个任务若在 1.5 秒内报错、且当时要求了 `requiresOnDeviceRecognition`，就关掉本机要求重试一次（机型缺少该语言本机模型时会出现这种立即报错）。
  - 诊断日志（os_log，subsystem `com.pokai.Codync`，category `voice`）：启动时的语言/是否支持本机识别/relay 开关；每秒一条 `buffers N/s, feeding request|nothing|sink, chars M`；每个任务的开始、最终/报错（NSError 的 domain 与 code、存活时长、累计字数）；暂停时结算的字数与是否为空；发送时的字数。均为长度与状态，不记录识别内容。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Voice/SpeechTranscriber.swift`、`VoiceSession.swift`（两处日志）。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 155）并启动。按要求未自测交互。
- 限制/待办：单任务识别仍受 SFSpeechRecognizer 单次约 1 分钟上限约束（超过后按 1.5 秒规则续接一次；更长的连续通话留待改用 SpeechAnalyzer）；relay 默认关。
- 关联：C0149、C0152、C0153、C0154。
