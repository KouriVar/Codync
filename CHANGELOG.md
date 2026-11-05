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

> 说明：下面 C0109–C0114 六节是同一批工作的补记，**部分内容已于更早的提交落地**
> （例如 C0110 的桌面端代码、C0109 的 zh-Hans/zh-Hant 文案），实际提交状态以 Git 历史为准。

### C0109 · 2026-11-04 · 对话页思考状态行（去掉工具名胶囊）

- 原因：对话底部原先是胶囊（转圈 + 工具名如 `bash` + 计时器），像终端日志，且把工具名暴露给用户。
- 变化：
  - 新增 `apps/ios/Kit/Sources/CodyncUI/Thread/ThinkingStatus.swift`：状态行 = 24pt 角色头像 + 14pt 灰字 + 可选耗时；头像按状态呼吸/扫光，"减少动态效果"时静止；文案切换 180ms 淡入淡出，每句至少显示 600ms。
  - 工具标题在客户端映射为人话（`bash`→跑一下命令、`read_file`→看一下文件、`edit`→改一下文件、`search`→查查资料，未知→正在处理）；`needsInput`→等你点一下同意。
  - 前 10 秒不显示耗时，10 秒后显示 `Ns`；60 秒后追加"，有点久，再等等"。
  - `ChatRows.swift` 的 `WorkingIndicator` 去掉背景胶囊，改为左对齐一行；"思考详情"展开保留（步骤区改圆角底）。
  - `BotRow.swift` 列表预览同样走这套人话映射，列表里也不再出现工具名。
  - `Resources/Languages/zh-Hans.json`、`zh-Hant.json` 各新增 9 条文案。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Thread/ThinkingStatus.swift`（新）、`apps/ios/Kit/Sources/CodyncUI/Thread/ChatRows.swift`、`apps/ios/Kit/Sources/CodyncUI/Bots/BotRow.swift`、`apps/ios/Kit/Sources/CodyncKit/Resources/Languages/zh-Hans.json`、`zh-Hant.json`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug -destination 'iPhone 18 Pro'` 通过；真机效果待你验收。
- 未做（需 host 改动）：文档 §5 的主路径"模型每次调工具前输出 `status_title`"；当前用工具类型映射兜底。§7 的可展开过程沿用现有"思考详情"。
- 关联：C0107、C0108。

### C0110 · 2026-11-04 · 桌面端移除 App 自动更新

- 原因：二开版本不应被官方 release 覆盖。
- 变化：
  - `apps/desktop/src/main/updates.ts`：`enabled = false`，检查/下载/安装全部短路（`install()` 也加守卫），不再注册 electron-updater 的定时检查。
  - `apps/desktop/src/main/tray.ts`：托盘菜单去掉「Updates」子菜单（含自动检查/下载开关），删除 `updatesMenu()`。
  - `apps/desktop/src/renderer/views/settings/SettingsView.tsx`：设置页去掉「Updates」页（类型、导航、`UpdateSettings` 一并删除）。
  - `apps/desktop/src/renderer/views/ChatWindow.tsx`：移除左下角 `UpdateBadge`。
  - `apps/desktop/src/renderer/views/UpdateNeededCard.tsx`：不再提供「Update this app」（`updateApp` 卡片直接不显示），只保留本机/其他电脑 host 的重启更新。
  - 删除 `apps/desktop/src/shared/updates.test.ts`、`apps/desktop/src/shared/test-support/updater.ts`（功能已移除）。
  - `Resources/Languages/ja|ko|fr|de|es.json` 补齐 C0109 的 9 条状态文案。
- 验证：`npm run typecheck` 通过；`npm run build` + `electron-builder --mac --dir --arm64`（ad-hoc）产出 2.36.0 并替换 `/Applications/Codync.app`，`codesign --verify --deep --strict` 通过，App 运行中（pid 23741）；`/health` 2.36.0/main。`npm test` 仅剩既有的 catalogs 键不一致（HEAD 上 zh-Hans 比 ja 多 15 个键，与本次无关）。
- 已知：`views/UpdateButton.tsx` 保留但已无入口；`UpdateNeededCard` 对 `updateApp` 静默。
- 关联：C0108、C0109。

### C0111 · 2026-11-04 · iOS 端移除 App 更新

- 原因：自编译版本不在 App Store，更新入口只会打开官方页面，或让电脑更新成官方包。
- 变化：
  - `apps/ios/App/CodyncApp.swift`：移除 `AppUpdates` 环境、`\.appUpdate`（App Store 跳转）和前台刷新。
  - `apps/ios/Views/BotListView.swift`：移除「有新版本」提醒条 `AppUpdateReminder`。
  - `apps/ios/Kit/Sources/CodyncUI/UpdateNeededCard.swift`：删除 `AppUpdateAction`/`AppUpdates`/`UpdateReminderCard`/`AppUpdateReminder`；版本不匹配卡只保留说明，不再有「Update Codync」（App Store）或「Update now」（让电脑更新）按钮。
  - `apps/ios/Kit/Sources/CodyncKit/Models/Compatibility.swift`：删除 `AppStoreRelease`、`UpdateReminder`。
  - `apps/ios/Kit/Sources/CodyncUI/Store/BotStore+HostUpdate.swift`：版本行不再给「Update / Try again」按钮，改为提示手动更新；`apps/ios/Views/ComputersView.swift` 对应去掉按钮。
- 验证：`xcodebuild -scheme 'iOS Dev' -configuration DevDebug` 模拟器与真机均通过；已安装并启动到 iPhone 16 Pro（`com.suiyikou.codync.uipreview`）。
- 保留：`BotStore.requestHostUpdate()`（已无入口）、`HostUpdateOffer` 展示状态。
- 关联：C0110。

### C0112 · 2026-11-04 · 思考状态行：12pt 间距、16pt 文字与文字扫光

- 变化：
  - `ThreadView.swift`：状态行上间距 6 → 12。
  - `ChatRows.swift`：去掉状态行左侧 16pt 缩进，头像左缘与消息气泡左缘对齐。
  - `ThinkingStatus.swift`：文字 14 → 16pt、行高 24；新增文字扫光——主文字色 95% 的柔边高光带（约文字宽 36%），从左到右 1.6s 线性、停 0.3s 循环，只作用于文字；换文案时从头开始；"减少动态效果"时关闭。
- 验证：模拟器 DevDebug 截图 + 录屏确认（高光带逐帧右移）；真机 DevDebug 编译安装到 iPhone 16 Pro。
- 关联：C0109、C0111。

### C0113 · 2026-11-04 · 状态行头像 32、文字 17pt

- `ThinkingStatus.swift`：头像 24 → 32、文字 16 → 17（行高仍 24）；扫光与 12pt 间距不变。
- 验证：模拟器 DevDebug 截图/连拍确认；真机 DevDebug 编译安装到 iPhone 16 Pro。
- 关联：C0112。

### C0114 · 2026-11-04 · 输入框长按菜单汉化（系统编辑菜单）

- 原因：输入框长按弹出的是 UIKit 系统编辑菜单（复制/粘贴/翻译/自动填充），它按 App 声明的语言本地化；App 的 Info.plist 没声明 `CFBundleLocalizations`（只有英文），所以在中文手机上也是英文。
- 变化：
  - `apps/ios/Resources/Info.plist`：新增 `CFBundleLocalizations`（en、zh-Hans、zh-Hant、ja、ko、fr、de、es）与 `CFBundleDevelopmentRegion`。
  - `CodyncKit/L10n.swift`：新增 `AppLanguage.applyToSystemMenus(in:)`，`setPreference` 时同步写入 `AppleLanguages`。
  - `apps/ios/App/CodyncApp.swift`：`@main` 改为 `CodyncAppLauncher`，在 SwiftUI 启动前调用 `applyToSystemMenus()`，让 UIKit 系统菜单跟随 App 内选择的语言。
- 说明：翻译/自动填充是系统提供项，不能单独改名，只能随语言整体切换。
- 验证：模拟器与真机 DevDebug 构建通过；真机安装。
- 关联：C0113。

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
### C0158 · 2026-11-04 · 语音 sheet v3.4：系统式标题栏、✕ 关闭与确认、line 图标、低音量提示

- 原因：C0155 把 ✕ 全部删掉后只剩下拉一条出路；标题栏是自己摆的而不是系统样式；暂停/继续用了 fill 图标；没有声音偏小、或什么都没听清时的提示区分。
- 变化：
  - 半屏/全屏标题栏按系统 sheet 重排：左 ✕ 44pt（普通玻璃、`close-line` 24pt，不再用红色 tint）；中间主 Bot 头像 24pt + 昵称（17pt semibold）居中，录音时头像呼吸跳动、暂停时静止；右侧发送 44pt（强调色 tint、白色 `arrow-up-line` 24）只在「暂停/已结束且有文字」时出现，否则留 44pt 空占位，保证标题始终居中；自动发送的倒计时环仍挂在发送按钮上。小档 76pt 不变（头像 36、波形、设置、暂停/继续，无关闭无发送）。
  - 关闭规则统一（✕ 与下拉同一套）：没文字直接关闭（停止录音、丢弃、底栏回来）；有文字（录音中或暂停）先弹 `confirmationDialog`「丢弃这段语音？」→「丢弃」（destructive，关闭并清空）／「继续编辑」。下拉用 `.interactiveDismissDisabled(voice.hasWords)` 挡住，配合 sheet 内下拉手势（阈值 70pt）触发同一个确认；没文字时下拉直接关。
  - 编辑态：键盘上方加 `ToolbarItemGroup(placement: .keyboard)`「完成」收起键盘；点文字区以外的空白处也收起；标题栏位于 sheet 顶部，键盘弹出时 ✕ 与发送仍可点。
  - 图标改回线性：暂停 `pause-line`、继续 `play-line`，24pt 与其它按钮同一粗细；显示 `play-line` 时图标 `.offset(x: 1.5)` 做视觉居中。
  - 提示分档：识别为空（暂停且无文字）时文字区显示「没听清，靠近一点再说」，用户重新开口（有新的部分结果）即自动消失；录音中若音量连续 3 秒处在「有声但偏小」区间（`voiceThreshold` 0.18 / `silentThreshold` 0.04 / `softAfter` 3s，均为常量），在波形下方淡入 13pt `.secondary` 的「声音有点小」，音量恢复或完全静音即淡出；小档把这一行放在波形区域里，不改变行高。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Voice/VoiceSheetView.swift`、`VoiceSession.swift`、`apps/ios/Views/HomeSourcesView.swift`、`Resources/Languages/zh-Hans.json`、`zh-Hant.json`（新增「声音有点小」「没听清，靠近一点再说」）。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过。本轮真机安装时设备连接隧道一直失败（`The tunnel connection failed`，手机锁屏/同一 Wi-Fi 未就绪），安装未完成；包已产出在 `build/dd-voice/Build/Products/DevDebug-iphoneos/`（2.36.0 / 156），解锁后一条 `devicectl device install app` 即可。
- 限制/待办：键盘「完成」依赖 `.toolbar(placement: .keyboard)`，若真机上没出现需要改为自绘键盘条；`.large` 仍复用半屏布局（二期连续通话）。
- 关联：C0155、C0156、C0157。
### C0159 · 2026-11-04 · 首页去掉横向分页，改成单列表 + 顶部胶囊筛选

- 原因：C0139 起的首页是「置顶 + 每个来源一页」的横向分页，翻页找会话比筛选麻烦；顶部渐进模糊在深色模式下也会显出一条灰带。
- 变化：
  - 去掉分页：删掉横向分页 `ScrollView`（`scrollTargetBehavior(.paging)` / `containerRelativeFrame`）与 `pinnedPage`、`sourcePage`，首页改为一条竖向 `List`；`.plainRosterList` 的顶部内边距、行内边距、隐藏分隔线等样式沿用，列表仍可滚到导航栏下方。
  - 顶部胶囊筛选：作为列表第一行（随列表滚动，不悬浮），`HomeFilter`（全部/置顶/Coe/DSH Bot/DSH）可用项由设置里的来源开关决定——只开一个来源时只显示「全部」「置顶」；胶囊高 32、左右内边距 14、间距 8、字号 15，选中项 `.primary` 底色 + 反色文字，未选中 `secondarySystemFill`；选择存 `@AppStorage("homeFilter")`，切换时 0.2 秒淡入淡出 + 按档位震一下；设置里关掉当前来源时自动回到「全部」。
  - 列表内容：全部 = 置顶会话按钉的先后在最上面，其余按最后消息时间倒序混排（DSH 的 `updatedAt` 统一换算成毫秒比较），保留来源角标；置顶 = 只显示钉住的，空态仍是「长按会话，选『钉在首页』」；单来源 = 只显示该来源。长按菜单、DSH push 到二级页、`<bot-profile>` / `You keep the memory` / 未命名会话与系统时间消息的过滤规则都没动。
  - 顶部渐进模糊：`ProgressiveTopBlur` 改为跟聊天页同一套（叠加在列表上、`ignoresSafeArea(edges: .top)`），材质跟随 `colorScheme`（深色用 `.thickMaterial`、浅色 `.ultraThinMaterial`），上面再叠一层 `systemBackground` 渐变，深色模式下不再是一条灰带；`.toolbarBackground(.hidden, for: .navigationBar)` 保留。
- 文件：`apps/ios/Views/HomeSourcesView.swift`、`apps/ios/Views/HomeSource.swift`（新增 `HomeFilter`）、`apps/ios/Kit/Sources/CodyncUI/Thread/ChatTranscript.swift`（`ProgressiveTopBlur`）。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 157）并启动。按要求未自测、未截图。
- 限制/待办：列表切换用行级淡入淡出（List 的插入/移除动画），不是整页交叉淡变；若观感不够，可换成 `ScrollView` + `LazyVStack` 自己控透明度。
- 关联：C0139、C0156。
### C0160 · 2026-11-04 · 撤掉首页顶部胶囊筛选，只保留渐进模糊

- 原因：C0159 加的「全部 / 置顶 / COE / DSHB / DSHC」胶囊行不需要了；首页要回到一条不再分类的列表，顶部模糊则要做得更干净。
- 变化：
  - 撤掉胶囊：整行 `filterRow`、`HomeFilter` 模型、`@AppStorage("homeFilter")`、切换动画与「来源被关掉回退到全部」的逻辑全部删除；首页仍是一条竖向 `List`（不恢复横向分页、不加任何新分类入口），内容与排序维持 C0159 的「全部」形态——钉住的按钉的先后在最上面，其余按最后消息时间倒序混排；DSH 未连接的提示行、空态「没有会话」保留。
  - 顶部渐进模糊按聊天页那套重做：`ProgressiveTopBlur` 叠在列表上并 `ignoresSafeArea(edges: .top)`，从状态栏一直盖到头像和 + 那一行下面（默认 110pt），垂直渐变蒙版淡出，无硬边；材质跟随 `colorScheme`（深色 `.thickMaterial`、浅色 `.ultraThinMaterial`），上面再叠一层 `Color(.systemBackground)` 渐变（顶部 0.85 → 0，深浅色同一套），不再出现灰白雾；`.toolbarBackground(.hidden, for: .navigationBar)` 保留，导航栏不会盖住模糊上半段。
  - 设置里「首页来源」三个开关、长按菜单、DSH 二级页、来源角标均未改动。
- 文件：`apps/ios/Views/HomeSourcesView.swift`、`apps/ios/Views/HomeSource.swift`（删除 `HomeFilter`）、`apps/ios/Kit/Sources/CodyncUI/Thread/ChatTranscript.swift`（`ProgressiveTopBlur` 浅色也用 0.85 渐变）。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 158）并启动。按要求未自测、未截图。
- 限制/待办：模糊高度沿用 110pt 常量，换机型如觉得覆盖不够可调 `ProgressiveTopBlur(height:)`。
- 关联：C0159。
### C0161 · 2026-11-04 · 首页/聊天页顶部模糊改回系统原生（附排查清单）

- 原因：首页顶部这一块前后补丁叠了十几轮（自绘模糊、隐藏导航栏背景、手算顶部内边距、忽略安全区），互相打架。这次先把所有相关代码列清楚，再统一交还给系统。
- 排查清单（行号按改动前的 C0160 版本）：

  | 文件:行 | 代码 | 作用 | 处置 |
  |---|---|---|---|
  | `HomeSourcesView.swift:156` | `.navigationTitle("")` | 不显示标题文字 | 留 |
  | `HomeSourcesView.swift:157` | `.navigationBarTitleDisplayMode(.inline)` | 内联标题栏 | 留 |
  | `HomeSourcesView.swift:158` | `.toolbar(.visible, for: .navigationBar)` | 强行让导航栏可见 | **删**（系统默认） |
  | `HomeSourcesView.swift:160` | `.toolbarBackground(.hidden, for: .navigationBar)` | 让导航栏背景透明，给自绘模糊让位 | **删** |
  | `HomeSourcesView.swift:161` | `.toolbar { toolbarContent }` | 头像 + 「+」两个工具栏项 | 留（项本身已是标准 ToolbarItem） |
  | `HomeSourcesView.swift:178` | `.plainRosterList(topInset:)` | 列表样式集合 | 留，但去掉里面的顶部内边距 |
  | `HomeSourcesView.swift:702-708` | `plainRosterList` 实现 | `.listStyle(.plain)`、`scrollContentBackground(.hidden)`、`defaultMinListRowHeight`、`scrollDismissesKeyboard` | 留 |
  | `HomeSourcesView.swift:704` | `.contentMargins(.top, topInset + 12, …)` | 手算顶部内边距，绕过导航栏 | **删** |
  | `HomeSourcesView.swift:179` | `.background(Palette.background)` | 页面底色 | 留 |
  | `HomeSourcesView.swift:180` | `.ignoresSafeArea(edges: .top)` | 让列表钻到导航栏下面（为自绘模糊服务） | **删** |
  | `HomeSourcesView.swift:183` | `.overlay(alignment: .top) { ProgressiveTopBlur() }` | 自绘顶部模糊 | **删**，换成 `.scrollEdgeEffectStyle(.soft, for: .top)` |
  | `HomeSourcesView.swift:184` | `.safeAreaInset(edge: .bottom) { bottomBar }` | 底部搜索/相机/麦克风栏 | 留 |
  | `HomeSourcesView.swift:226-231` | `topBarInset` | 状态栏 + 44pt 的手算高度，只为上面的 `contentMargins` 服务 | **删** |
  | `HomeSourcesView.swift:289-292` | iOS 27 分支 + `.contentMarginsRemoved()` | 去掉头像在工具栏里的默认边距 | **删**（改成一个标准 ToolbarItem） |
  | `HomeSourcesView.swift:294` | `ToolbarItem(.topBarTrailing) { newBotMenu }` | 「+」 | 留 |
  | `ChatTranscript.swift:55` | `.overlay(alignment: .top) { ProgressiveTopBlur() }` | 聊天页同样的自绘模糊 | **删**（`ConversationList` 已设 `topEdgeEffect.style = .soft`） |
  | `ChatTranscript.swift:180` 起 | `ProgressiveTopBlur` 结构体 | 自绘模糊本体（材质 + 渐变蒙版） | **删**（整个结构体） |
  | `ConversationList.swift:106` | `view.topEdgeEffect.style = .soft` | 聊天页真正的系统软边效果 | 留 |
  | `CodyncApp.swift` / `AppDelegate` | 无 `UINavigationBarAppearance` | 全局外观没有被改过 | 无需改 |
  | 全仓 | 无 `TabView(.page)`、无横向分页、无胶囊筛选残留 | C0159/C0160 已清掉 | 无需改 |
  | `CodyncApp.swift` | `AppearanceWindow(appearance:)`（用户设置的外观） | 全局深浅色 | 留（与本问题无关） |

- 变化：
  - 首页：删掉自绘模糊、额外材质与渐变、`.ignoresSafeArea(edges: .top)`、手算 `contentMargins(.top)` 与 `topBarInset`，以及强制的 `toolbar(.visible)` / `toolbarBackground(.hidden)`；列表改加 `.scrollEdgeEffectStyle(.soft, for: .top)`，顶部渐隐、深浅色适配全部交给系统；工具栏只留两个标准 ToolbarItem（头像、+），去掉 iOS 27 的 `contentMarginsRemoved()` 分支。
  - 聊天页：删掉 `ProgressiveTopBlur` 覆盖层（其集合视图本来就设了 `topEdgeEffect.style = .soft`），`ProgressiveTopBlur` 结构体整体删除。
  - 首页仍是固定单页列表：不恢复分页、不加胶囊筛选，列表内容与顺序不变；设置里的三个来源开关、长按菜单、DSH 二级页、来源角标未动。
- 文件：`apps/ios/Views/HomeSourcesView.swift`、`apps/ios/Kit/Sources/CodyncUI/Thread/ChatTranscript.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 159）并启动。按要求未自测、未截图。
- 限制/待办：顶部效果完全由系统决定，若系统行为不如预期只能调整内容内边距，不再自绘。
- 关联：C0156、C0159、C0160。
### C0162 · 2026-11-04 · 修 C0161 把导航栏头像改宽的问题

- 原因：C0161 按「工具栏只用标准项、去掉多余修饰」把 `ToolbarItem` 上的 iOS 27 分支连同 `.contentMarginsRemoved()` 一起删了。而这台手机是 iOS 27.3，正走那个分支：iOS 27 会给工具栏项一个图标尺寸的内边距，照片放进导航栏胶囊里就会被横向拉开——原注释写的就是这件事，删掉即回归。
- 变化：恢复 `toolbarContent` 里的 `#available(iOS 27.0, *)` 分支，仅对头像项应用 `.contentMarginsRemoved()`；iOS 26 及以下仍用标准 `ToolbarItem`。C0161 的其它改动（首页/聊天页改系统 `.scrollEdgeEffectStyle(.soft, for: .top)`、删自绘模糊与 `ProgressiveTopBlur`、不再强制 `toolbarBackground`）保持不变。
- 文件：`apps/ios/Views/HomeSourcesView.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 160，iOS 27.3）并启动。按要求未自测、未截图。
- 限制/待办：这是 iOS 27 工具栏布局的适配，属于系统 API 用法，不是顶部模糊的新补丁。
- 关联：C0161。
### C0163 · 2026-11-04 · 首页底栏换成 iOS 26 原生 TabView（4 tab + 底部附属栏 + 搜索）

- 存档：改动前的布局已在 tag **`layout-before-tabbar`**（= 分支 `backup/layout-before-tabbar`）上留档，提交 `58f6f7c7`。
  回退命令：`git checkout layout-before-tabbar`（或 `git switch backup/layout-before-tabbar`），看回来用 `git switch ui/native-tabbar`。
  本次功能都在新分支 `ui/native-tabbar` 上，C0109–C0114 那批未提交改动全程未 stash、未提交、原样保留。
- 原因：自绘的悬浮底栏（搜索框 + 麦克风 + 相机）要换成系统原生 tab bar，并要吃到 iOS 26 的「滚动缩小」「底部附属栏」能力。
- 变化：
  - 首页根视图改为 `TabView`（`Tab` API）：置顶、Coe、DS Bot、DSH 四个普通 tab，另加右侧 `Tab(role: .search)`。置顶 tab = 原首页内容与排序（置顶会话按钉的先后在前，其余按最后消息时间倒序混排）；其余三个 tab 只显示对应来源。图标用 SF Symbols（pin / bubble.left.and.bubble.right / cpu / terminal / magnifyingglass），标题中文（置顶、Coe、DS Bot、DSH、搜索）。
  - 每个 tab 各自一个 `NavigationStack`（共用 `accounts.selection` 作为 path），二级页 push、长按菜单、来源角标、隐藏规则（`<bot-profile>`、`You keep the memory`、未命名会话）都保持原样；`ChatScreen` 由 private 改为模块内复用。
  - 设置里的三个来源开关控制对应 tab 是否出现（置顶 tab 永远在第一位）；当前 tab 被关掉时自动切回置顶。
  - 底部附属栏：`.tabViewBottomAccessory` 放一条原生栏——左语音（点击弹出原语音 sheet，三档 detent 原样复用）、右相机（沿用原相机 sheet）；按 `@Environment(\.tabViewBottomAccessoryPlacement)` 区分 inline（只两个图标）与 expanded（语音按钮多一行「说点什么…」）；系统默认样式，未叠任何玻璃或背景。
  - 删除自绘底栏在首页的用法（搜索框、麦克风、相机的悬浮玻璃栏，以及 `barAway` 下移淡出逻辑）；`HomeBottomBar.swift` 仍留在仓库里，只因为已废弃的 `BotListView` 还引用它——那个文件带着另一会话的未提交改动，本轮不动。
  - 缩放：`.tabBarMinimizeBehavior(.onScrollDown)`，下滚缩成当前 tab 并把附属栏并进同一行，上滚恢复。
  - 顶部：头像（左）/ +（右）仍是标准 `ToolbarItem`，保留 iOS 27 的 `contentMarginsRemoved()`（C0162）；顶部模糊沿用系统 `.scrollEdgeEffectStyle(.soft, for: .top)`，每个 tab 的列表都加了。
  - `RootView` 去掉外层的 `NavigationStack`（首页自带每 tab 的栈），保留 `AccessBanners` 与 selection 的观察逻辑。
- 文件：`apps/ios/Views/HomeSourcesView.swift`、`apps/ios/Views/HomeSource.swift`（新增 `HomeTab`）、`apps/ios/Views/RootView.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 161）并启动。按要求未自测、未截图。
- 限制/待办：搜索 tab 只做标题的本地过滤（不含消息内容）；附属栏未做长按/更多操作；`HomeBottomBar` 待 `BotListView` 处理后再删。
- 关联：C0161、C0162。
### C0164 · 2026-11-04 · 置顶 tab 只显示钉住的会话，搜索用 role: .search 单独浮在右侧

- 原因：C0163 的置顶 tab 复用了原来的「钉住 + 其余混排」列表，但 tab 化之后置顶应该就是「钉住的」；另外 tab 图标里 DSH 用的 `terminal` 不是要求的线条版。
- 变化：
  - 置顶 tab 只列出 `pinnedEntries`——长按「钉在首页」钉住的会话（三种来源都可钉），顺序仍是钉的先后（沿用 `@AppStorage` 里原有的钉住列表）；空时显示「长按会话，选『钉在首页』」；不再混入其他会话。混排用的 `rows` / `stamp` 计算随之删除。
  - Coe、DS Bot、DSH 三个 tab 内容维持原状（各自来源的会话）。
  - 搜索仍由 `Tab(value: HomeTab.search, role: .search) { … }` 声明并放在 `TabView` 最后一项，系统画成右侧独立的圆形玻璃钮；左边只留四个普通 tab，且受设置里三个开关控制。
  - 图标统一 SF Symbols：`pin`、`bubble.left.and.bubble.right`、`cpu`、`apple.terminal`（DSH 由 `terminal` 改为线条版 `apple.terminal`）；搜索钮图标由系统提供。
  - 底部附属栏未改：左麦克风 + 「说点什么」，右相机，系统默认样式。
- 文件：`apps/ios/Views/HomeSourcesView.swift`、`apps/ios/Views/HomeSource.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 162）并启动。按要求未自测、未截图。
- 限制/待办：无。
- 关联：C0163。
### C0165 · 2026-11-04 · 搜索 tab 改成系统默认写法，单独浮在右侧

- 原因：C0164 的搜索 tab 虽然用了 `Tab(value:, role: .search)`，但额外传了自定义 `label:`（`Label("搜索", systemImage: "magnifyingglass")`）。一旦给了自定义 label，系统就把它当普通 tab 画，不进入「右侧独立圆形玻璃钮」的形态。
- 排查结论（逐项）：
  1. `HomeSourcesView.swift:170-174`（改动前）：`Tab(value: HomeTab.search, role: .search)` 确实直接写在 `TabView` 第一层，没有包在 `TabSection`/`ForEach`/自定义 wrapper 里——**但带了自定义 `label:`**，命中第 5 项的问题。
  2. `apps/ios/Resources/Info.plist`、`apps/project.yml`、`apps/shared/Config/*.plist`：**没有** `UIDesignRequiresCompatibility`，不存在退回旧版样式的可能。
  3. 全仓无 `UITabBar.appearance()`、`UITabBarAppearance`、`.tabViewStyle(...)`、`.toolbarBackground(for: .tabBar)`；只有 `HomeSourcesView.swift:177` 的 `.tabBarMinimizeBehavior(.onScrollDown)`（本轮保留）。
  4. `xcodebuild -showsdks` → `iphoneos27.1`；`apps/project.yml` 的 `deploymentTarget.iOS = 26.0`，满足 iOS 26 要求。
  5. **问题就在这里**：给了 `Label` 自定义 label。改为系统默认写法 `Tab(value: HomeTab.search, role: .search) { … }`，不传 label。
- 变化：删除搜索 tab 的自定义 `label:`，改用默认 label（标题由系统提供和本地化）；左侧四个普通 tab（置顶、Coe、DS Bot、DSH）仍作为一组玻璃 tab，搜索由系统画成右侧独立的圆形玻璃钮。附属栏、置顶 tab 内容以及其余功能未改动。
- 文件：`apps/ios/Views/HomeSourcesView.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 163）并启动。按要求未自测、未截图。
- 限制/待办：搜索 tab 的标题取自系统本地化（跟随设备/App 语言），不再是 App 自己的文案。
- 关联：C0163、C0164。
### C0166 · 2026-11-04 · 加「TabBar 对照」调试页（只查不改首页），并记录视图链

- 环境：真机 **iPhone 16 Pro，iOS 27.3**（对照页顶部用 `UIDevice.current.systemVersion` 实时打印）；编译 SDK **iPhoneOS 27.1**（`xcodebuild -showsdks` → `iphoneos27.1`），Deployment Target 26.0。
- 原因：搜索 tab 在首页没有单独浮到右侧，需要最小对照定位是哪一层导致的——按要求本轮只查不改首页。
- 变化：
  - 新增调试页 `TabBarProbeView`（`apps/ios/Kit/Sources/CodyncUI/Debug/TabBarProbeView.swift`），从设置里「连点版本号 10 次」展开的高级区进入（新增一行「TabBar 对照」），以 `fullScreenCover` 全屏弹出。
  - 四个变体用分段 Picker 切换：**最小版** = 三个 Tab（A、B、`Tab(role: .search)`），无任何修饰符；**V1** = 最小版 + `.tabBarMinimizeBehavior(.onScrollDown)`；**V2** = 最小版 + `.tabViewBottomAccessory { Text("accessory") }`；**V3** = 两个都加，并照抄首页 TabView 的全部修饰符（`selection`、每个 tab 内 `NavigationStack(path:)` + `navigationTitle("")` + `.inline` + 工具栏头像/＋、`.tint`）。
  - 顶部显示系统版本、构建号和 SDK。
- 首页 TabView 外层视图链（文件:行号，TabView 是根，外面没有 NavigationStack）：
  1. `CodyncApp.swift:37-38` — `WindowGroup { RootView() }`
  2. `RootView.swift:20-44` — `Group { … home … }` + `.background(Palette.background)` 等
  3. `RootView.swift:80-85` — `HomeSourcesView()` + `.safeAreaInset(edge: .bottom, spacing: 0) { AccessBanners() }`
  4. `HomeSourcesView.swift:60-61` — `body` 直接返回 `tabs`，外层再挂 `.task`、`.onChange`×5、`.sheet`(相机/语音/DSH 连接)、`.codyncSheet`×4、`.alert`、`.sectionNameDialog`、`.glassToast`、`.onAppear`
  5. `HomeSourcesView.swift:150-186` — `TabView(selection:)` + `.tabBarMinimizeBehavior(.onScrollDown)` + `.tabViewBottomAccessory { HomeVoiceAccessory(…) }` + `.tint(Palette.text)` + `.onChange(of: enabledSources)`
  6. `HomeSourcesView.swift:189-198` — 每个 Tab 内部才是 `NavigationStack(path: path) { … }`
  结论：TabView 本身是根视图，外层**没有** NavigationStack / ZStack / overlay / ignoresSafeArea / 自定义 frame；首页与最小版的差别只有「每个 tab 里多一层 NavigationStack + 工具栏」以及 V3 里照抄的那些修饰符。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Debug/TabBarProbeView.swift`（新）、`apps/ios/Views/SettingsView.swift`、`apps/ios/Views/AccountSwitcherView.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 164）并启动。按要求未自测、未截图。
- 限制/待办：首页本轮未做任何改动，等对照结果后再定方案。
- 关联：C0165。
### C0167 · 2026-11-04 · 方案 B：附属栏只留语音胶囊，相机与键盘收进语音 sheet，+ 只负责新建

- 原因：底部附属栏里再放相机，和「语音 + 相机」两个入口各有去处；相机其实属于「给这条消息配一张图」，键盘属于「不想说就打字」，都该在语音 sheet 里；+ 原来还是「新建 Bot / 新建群聊」，没有按来源分。
- 变化：
  - 附属栏：`.tabViewBottomAccessory` 只放一整条语音胶囊——左麦克风、右「跟 <主 Bot 名> 说点什么…」，整条可点，点开现有语音 sheet；相机按钮删除。只在置顶与 Coe 两个 tab 挂载（`selectedTab` 条件，用 `VoiceBar` 这个 ViewModifier 做条件挂载：`tabViewBottomAccessory(isEnabled:)` 需要 iOS 26.1，本工程 target 是 26.0），DS Bot / DSH / 搜索不显示。`inline`（滚动缩小后并入 tab 行）只显示麦克风 +「说点什么」，`expanded` 显示完整文字；系统默认样式，没叠玻璃。
  - 语音 sheet：76pt 小档不变（头像 36、波形、设置 44、暂停 44）。半屏/全屏底部一行改为 **相机 44 / 键盘 44 / 设置 44 / 暂停 44**，图标均为 Remix line 24pt、玻璃按钮沿用 `VoiceGlass`：相机走 App 现有的 `\.capturePhoto` 拍照/选图，附图挂到本次消息；键盘调用新增的 `VoiceSession.startTyping()`（暂停录音、把已识别文字放进可编辑输入框并弹键盘，可继续打字）。
  - 附了图片时标题下显示 64pt、圆角 12 的缩略图，右上角 ✕ 可删除；发送时文字与图片一起发给主 bot（`BotStore.sendAndConfirm(_:to:files:)` 新增 files 参数，走与会话打字相同的 `send` 入口）。
  - v3.4 的既有行为保持不变：标题栏左 ✕、中间头像 24 + 名字、右侧发送按钮（无内容时留空占位）、有内容时关闭二次确认（现在「有内容」包含图片）、键盘「完成」、点空白收起键盘。
  - +：改成原生 `Menu`，按设置里开着的来源列出「新建 Coe 会话 / 新建 DS Bot 会话 / 新建 DSH 会话」；Coe 与 DS Bot 都进同一个新建表单（DS Bot 即在该表单里填 `command`），DSH 直接 `dsh.newSession()`；菜单里没有任何相机/拍照入口。首页自己的相机 sheet 与 `attachCapturedPhoto` 随之删除（相机只在语音 sheet 里）。
- 文件：`apps/ios/Views/HomeSourcesView.swift`、`apps/ios/Kit/Sources/CodyncUI/Voice/VoiceSheetView.swift`、`VoiceSession.swift`、`VoiceSend.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 165）并启动。按要求未自测、未截图。
- 限制/待办：`tabViewBottomAccessory(isEnabled:)` 需 iOS 26.1，这里用 ViewModifier 条件挂载；DSH 新建依赖网关已连接。
- 关联：C0163、C0164、C0165、C0166。
### C0168 · 2026-11-04 · 附属栏与语音 sheet 返工：会话页隐藏底栏、头像对齐、原地展开、相机翻转

- 原因：C0167 之后有四处不合用——push 进会话页底栏还在；附属栏左边是图标而不是主 bot 头像、间距不对；点附属栏直接弹 sheet 太重；相机跳去 App 另一个独立拍照页。
- 变化：
  - **二级页隐藏底栏（最高优先级）**：每个 tab 的 `navigationDestination` 里，`ChatScreen` 与 `DSHConversationView` 都加 `.toolbar(.hidden, for: .tabBar)`；附属栏改成「只在当前 tab 的根页面挂载」——`isTabRoot`（`accounts.selection == nil && openDSHSession == nil`）与 tab 条件一起判断。返回一级页由系统动画恢复。会话页自己的输入框未动。
  - **+ 菜单汉化**：`New Coe chat / New DS Bot chat / New DSH chat` 三条补进 zh-Hans / zh-Hant（新建 Coe 会话 / 新建 DS Bot 会话 / 新建 DSH 会话），不再显示英文。
  - **附属栏样式**：左边换成主 bot 头像 24pt（`CharacterAvatar`，Circle 裁切），文字「跟 <主 Bot 名> 说点什么…」17pt `.secondary`；左右各 12pt、头像与文字间距 8，与 tab bar 边缘对齐；`inline` 只留头像，`expanded` 显示完整一行。整条可点。
  - **原地展开成 76pt 胶囊**：点附属栏不再弹 sheet，而是附属栏自己展开成 76pt 玻璃胶囊（`VoiceMiniBar`：头像 36 / 一条线波形 / 设置 44 / 暂停 44），spring 动画，并立刻开始录音；下方五个 tab 位置不动、始终可点。
    - 往上拖超过 40pt：弹出现有语音 sheet 并直接到 `.medium`，录音状态与已识别文字无缝带过去。
    - 收起：往下拖，或点页面空白处（展开期间 TabView 内容上盖一层透明点击层）；有文字时弹「丢弃这段语音？」沿用既有确认。
    - 实现方式：**先用原生 `.tabViewBottomAccessory`**（内容在展开态给到 76pt），没有退到 overlay 玻璃胶囊——若真机上系统把附属栏压矮，再改用 overlay 方案。
    - 展开期间再打开 sheet 时，sheet 关闭会一并把胶囊收起。
  - **半屏相机的翻转页**：语音 sheet 内置相机页 `VoiceCameraPage`（AVCaptureSession 实时取景、左上返回 `arrow-left-line` 44 玻璃钮、下方中间快门、右下切换前后摄 `camera-switch-line`、左下相册 `PhotosPicker`）；按下相机按钮用 `rotation3DEffect` 绕 Y 轴翻转 0.45s、中途（225ms）切换内容，返回时反向翻回，录音与文字保留；拍照或选图后自动翻回语音页并在标题下显示 64pt 缩略图。不再跳 App 原有的 `\.capturePhoto` 独立页面；相机权限沿用 AVCaptureDevice 授权流程。
- 文件：`apps/ios/Views/HomeSourcesView.swift`、`apps/ios/Kit/Sources/CodyncUI/Voice/VoiceSheetView.swift`、`VoiceCamera.swift`（新）、`VoiceMiniBar.swift`（新）、`Resources/Languages/zh-Hans.json`、`zh-Hant.json`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 166）并启动。按要求未自测、未截图。
- 限制/待办：附属栏展开高度依赖系统是否允许 76pt（真机确认，不行改 overlay）；相机页取景方向未做旋转适配；`.large` 仍复用半屏布局。
- 关联：C0166、C0167。
### C0169 · 2026-11-04 · 撤掉附属栏原地展开，改回原生语音 sheet

- 原因：C0168 的「原地展开成 76pt 胶囊」在真机上不成立——**系统会压低 `.tabViewBottomAccessory` 的高度**，76pt 的胶囊放不进去；附属栏里再加拖动手势也和系统 tab bar / 附属栏自己的手势**冲突**。所以整套撤掉，回到弹原生 sheet 的做法。
- 变化：
  - 删除原地展开的整套逻辑：`voiceBarOpen`、`confirmBarDiscard` / `showVoiceSettings` 状态，`expandVoiceBar` / `collapseVoiceBar` / `raiseVoiceBar` 三个动作，展开期间盖在 TabView 内容上的透明点击层，以及那条「丢弃这段语音？」的 confirmationDialog；`VoiceMiniBar.swift` 一并删除。
  - 附属栏保留 C0168 第 2 条的样式（主 bot 头像 24pt Circle 裁切 +「跟 <主 Bot 名> 说点什么…」17pt `.secondary`，左右 12 / 头像与文字间距 8 / 与 tab bar 对齐，inline 只留头像），点击后**直接弹原生语音 sheet**：`.presentationDetents([.height(76), .medium, .large])` 打开停在 76pt、`.presentationBackgroundInteraction(.enabled(upThrough: .height(76)))`、系统拖动指示条、`interactiveDismissDisabled(voice.hasWords)`，并立刻开始录音。小档 / 半屏 / 全屏的布局、玻璃按钮、一条线波形、v3.4 标题栏与关闭确认，全部与 C0153–C0167 已定的样式一致。
  - 保留：C0168 第 1 条（二级页 `.toolbar(.hidden, for: .tabBar)` + 附属栏只在 tab 根页面挂载）、+ 菜单的中文翻译、C0168 第 4 条的半屏相机 3D 翻转页。
  - sheet 盖住 tab bar 属预期行为，未做处理；sheet 关闭后 tab bar 与附属栏照常显示。
- 文件：`apps/ios/Views/HomeSourcesView.swift`；删除 `apps/ios/Kit/Sources/CodyncUI/Voice/VoiceMiniBar.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 167）并启动。按要求未自测、未截图。
- 限制/待办：附属栏不再有原地录音态，录音一律在 sheet 里进行。
- 关联：C0168、C0167、C0153。
### C0170 · 2026-11-04 · 语音 sheet 打开时隐藏 tab bar 与附属栏

- 原因：语音 sheet 弹出后 tab bar 与附属栏仍留在下面，和 sheet 争屏幕；打开语音时它们应该让位。
- 变化：在 `TabView` 上按 `showVoice` 切换 `.toolbar(showVoice ? .hidden : .visible, for: .tabBar)`；附属栏的挂载条件加上 `!showVoice`，两个都在 sheet 打开期间消失、关闭后由系统动画恢复。没有加额外的自定义动画，其它内容未动。
- 文件：`apps/ios/Views/HomeSourcesView.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 168）并启动。按要求未自测、未截图。
- 限制/待办：无。
- 关联：C0169、C0168。
### C0171 · 2026-11-04 · 相机页：翻转后正回、只有两个顶部按钮、底部统一玻璃按钮

- 原因：C0168 的相机页是 sheet 翻过去的第二面，方向是反的；顶部按钮布局和 sheet 不一致（只有返回，字号/材质也不统一）；底部快门还是白圈样式。
- 变化：
  - 镜像：相机页在原有翻转之外再加一层 `.rotation3DEffect(.degrees(180), axis: (0,1,0))`，翻过来后是正的（`180 + 翻转角`，静止时合 360°）。
  - 顶部只有两个 44pt 圆形玻璃钮、图标 24pt、离边缘 16pt：左 `arrow-left-line` 返回（反向翻转回语音页，录音与文字保留），右 `more-line`（⋯，菜单里只放了「打开设置」，相机权限在那里）；相机页上不再有关闭按钮或其它按钮。
  - 底部同样统一成玻璃按钮：中间快门（`record-circle-line`，白色 tint 玻璃）、左下相册（`image-line`，`photosPicker` 打开系统相册）、右下切换前后摄（`camera-switch-line`），尺寸与顶部一致。
  - 玻璃按钮复用语音 sheet 现成的 `VoiceGlass`（由 `private` 提升为模块内共用），相机页与 sheet 的圆钮完全同一套。
  - 其余逻辑（拍照/选图后自动翻回、缩略图、权限请求）未改。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Voice/VoiceCamera.swift`、`VoiceSheetView.swift`（`VoiceGlass` 可见性 + 相机面镜像）。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 169）并启动。按要求未自测、未截图。
- 限制/待办：⋯ 目前只提供「打开设置」一项。
- 关联：C0168、C0169。
### C0172 · 2026-11-04 · 语音 sheet 打开时隐藏 tab bar（改在每个 tab 的根视图上）

- 原因：C0170 把 `.toolbar(.hidden, for: .tabBar)` 加在 `TabView` 外层，系统不认（这类工具栏可见性只对被包在 `NavigationStack` 里的内容生效），所以 sheet 打开时 tab bar 仍然在。
- 变化：把规则挪进每个 tab 的 `NavigationStack` 根视图——`stack(voiceSheet:)` 里对内容加 `.toolbar(voiceSheet ? .hidden : .visible, for: .tabBar)`，五个 tab（置顶、Coe、DS Bot、DSH、搜索）的调用处都传 `voiceSheet: showVoice`（从首页把状态传下去）；`showVoice` 的所有赋值（打开、sheet onDismiss、发送/取消后面板清空、退到后台）都用 `withAnimation(.spring(response: 0.35, dampingFraction: 0.9))` 包住，让 tab bar 与附属栏一起退下去、一起回来。其他内容未动。
- 文件：`apps/ios/Views/HomeSourcesView.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 170）并启动。按要求未自测、未截图。
- 限制/待办：无。
- 关联：C0170。
### C0173 · 2026-11-04 · 相机页按设计稿重做布局（替换此前相机页的所有补充修复）

- 原因：前几版相机页是「顶部两个按钮 + 底部三个按钮」的临时排法，和设计稿不一致。
- 变化：
  - 镜像：保留 C0171 的做法——相机面在 sheet 的翻转之外再加一层 `.rotation3DEffect(.degrees(180), axis: (0,1,0))`，翻过来方向正常。
  - 取景：实时预览铺满整个相机页（`ignoresSafeArea`），四角用 `RoundedRectangle(cornerRadius: 32)` 裁切，跟着 sheet 的圆角走。
  - 顶部：**不放任何按钮**，只有系统自带的拖动指示条。
  - 底部：一排三个按钮，垂直居中对齐、离底边 16pt、离左右各 16pt——左「返回」44 圆形深色玻璃钮（黑 35% tint）+ 白色 `arrow-left-s-line` 24pt，点了反向翻转回语音输入页（录音与文字保留）；中「快门」72pt 玻璃环内嵌 60pt 实心白圆，按下缩到 0.9 并有触感；右「更多」44 圆形深色玻璃钮 + 白色 `more-line` 24pt，先只占位、点了无操作。
  - 去掉相册按钮与切换前后摄像头按钮（`PhotosPicker` 相关代码一并删除，后续放进「更多」）。
  - 取景页其余逻辑（拍照后自动翻回、缩略图、权限请求）未改。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Voice/VoiceCamera.swift`（`VoiceSheetView.swift` 的镜像层沿用 C0171）。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 171）并启动。按要求未自测、未截图。
- 限制/待办：「更多」暂未接任何功能（相册、前后摄后续放这里）。
- 关联：C0168、C0169、C0171。
### C0174 · 2026-11-04 · 语音 sheet 的进出过渡：先下沉淡出，再弹 sheet；关闭反向对称

- 原因：C0172 直接用 `.toolbar(.hidden)` 触发的系统动画太生硬，tab bar 会「跳」一下。
- 变化：
  - 打开（点语音条）：先把 tab bar 与附属栏所在的外层用 `.offset(y: 40)` + `.opacity(0)` 在 `spring(response: 0.35, dampingFraction: 0.9)` 下沉淡出；约 150ms 后（位移动画过半）再设 `tabBarHidden = true`、弹出原生语音 sheet 停在 76 小档。系统 `.hidden` 只在已经看不见之后生效，因此不会跳。
  - 关闭：sheet 先按系统动画降下去；`onDismiss` 里先取消 `.hidden`（此时外层仍处于下沉+透明状态），再用**同一个 spring** 从 `offset 40 / opacity 0` 升回原位并淡入——进出方向与时长完全对称。
  - 过渡期间 `isTransitioning` 为真，附属栏点击被忽略，避免重复触发。
  - 其它关闭路径（发送成功、退到后台）只置 `showVoice = false`，由 `onDismiss` 统一负责让底栏回来。
- 文件：`apps/ios/Views/HomeSourcesView.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 172）并启动。按要求未自测、未截图。
- 限制/待办：`offset` / `opacity` 作用在 `TabView` 这一层（系统 tab bar 无法单独位移），因此过渡瞬间页面内容也会随之下移淡出约 0.35s——若观感不合适，可改成只对附属栏做动效。
- 关联：C0170、C0172。
### C0175 · 2026-11-04 · 相机页底部被裁：取景铺到底、按钮让开 Home 指示条

- 原因：相机页整层 `.ignoresSafeArea()` 之后，三个按钮也被推到了安全区外，被 Home 指示条压住；同时取景在底部留下一条页面背景。
- 变化：
  - 取景层（黑底 + 实时预览 + 权限提示）单独 `.ignoresSafeArea(edges: .bottom)` 并 `clipShape(RoundedRectangle(cornerRadius: 32))`，一直铺到 sheet 最底部、圆角跟随 sheet，不再露出灰色/页面背景。
  - 三个按钮改放在**遵守安全区**的那一层，`padding(.bottom, 16)`，因此离 Home 指示条 16pt，左右仍是 16pt。
  - 其它布局与逻辑未动。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Voice/VoiceCamera.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 173）并启动。按要求未自测、未截图。
- 限制/待办：无。
- 关联：C0173。
### C0176 · 2026-11-05 · 打开语音时只让底栏退场，页面内容原地不动

- 原因：C0174 把下移/淡出加在了 `TabView` 这一层，导致首页列表、头像和 + 也跟着往下移并淡出——不该动的动了。
- 变化：
  - 撤掉 `TabView` / 页面上所有 `offset`、`opacity` 和补间动画（`barLifted`、`barDrop`、`barSpring` 一并删除）；首页列表、头像和 + 全程保持原位、完全可见。
  - 打开：点语音条后直接设 `tabBarHidden = true`（`.toolbar(.hidden, for: .tabBar)` 在每个 tab 根视图上），由系统自带的下滑动画把 tab bar 与附属栏一起收走；约 0.15 秒后再弹原生语音 sheet 并停在 76 小档。
  - 关闭：sheet 先按系统动画降下，`onDismiss` 里恢复 `.visible`，系统把 tab bar 与附属栏一起滑回来。
  - `isTransitioning` 保留，过渡期间不响应重复点击。
- 文件：`apps/ios/Views/HomeSourcesView.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 174）并启动。按要求未自测、未截图。
- 限制/待办：底栏进出的具体手感完全由系统决定。
- 关联：C0172、C0174。
### C0177 · 2026-11-05 · 相机画面铺满整个 sheet（附逐层排查）

- 原因：相机页画面没铺满，底部/顶部露出 sheet 自己的背景（看起来像灰条）。
- 逐层排查（改动前的状态）：
  1. `HomeSourcesView.swift:89-110` —— `.sheet(isPresented: $showVoice, …)` 只挂了 `presentationDetents` / `presentationDragIndicator` / `presentationBackgroundInteraction` / `interactiveDismissDisabled`，**没有** `presentationBackground`。所以那层灰不是我们画的，而是 **sheet 的系统默认背景**，凡是内容没铺到的地方就露它。
  2. `VoiceSheetView.swift` 的 `body` 根 `Group` —— 有 `.frame(maxWidth: .infinity, maxHeight: .infinity)`，**没有 padding / safeAreaPadding**；但它**没有** `ignoresSafeArea`，因此内容被 sheet 的上下安全区内缩，相机页顶部（拖动条区域）与底部（Home 指示条区域）都会露出第 1 条的背景。
  3. 翻转容器 —— `VoiceCameraPage(...).rotation3DEffect(180).rotation3DEffect(flip)`，同样没有 `ignoresSafeArea`，继续沿用第 2 条的内缩。
  4. `VoiceCameraPage`（`VoiceCamera.swift`）—— 之前是 `ZStack { viewfinder.ignoresSafeArea(edges: .bottom).clipShape(32); controls }`：取景只忽略底部、且被 `clipShape` 裁在自己的矩形里，顶部仍内缩；`Color.black` 也在同一个 ZStack 里，所以边缘露出的就是第 1 条的 sheet 背景。
  5. `controls` —— `VStack` + `padding(.horizontal, 16)` + `padding(.bottom, 16)`，无 frame 限制；之前因为整层 ignore 安全区而贴到 Home 指示条上。
- 变化：
  - 相机预览改为**相机页最底层**：`.background { ZStack { Color.black; VoiceCameraPreview } .ignoresSafeArea() }`，由外到内都铺满，圆角 `RoundedRectangle(32)` 跟随 sheet。
  - `VoiceCameraPage` 的翻转容器与 `VoiceSheetView` 内容根视图都加上 `.ignoresSafeArea(edges: .bottom)`（根视图按 `showingCamera ? .bottom : []` 条件加，**语音页布局不受影响**）。
  - 按钮仍按安全区布局：`padding(.bottom, 16)`，离 Home 指示条 16pt，位置不变。
  - 权限提示（拒绝 / 询问中）仍画在取景之上，其余逻辑未动。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Voice/VoiceCamera.swift`、`VoiceSheetView.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 175）并启动。按要求未自测、未截图。
- 限制/待办：如果真机上顶部拖动条区域仍露出一点背景，说明是 sheet 自身的安全区不可越过，只能接受那条窄边。
- 关联：C0173、C0175。
### C0178 · 2026-11-05 · 语音条与 tab bar 的进出动画（不再瞬移）

- 原因：C0176 直接切换 `.toolbar(.hidden)` 与附属栏挂载，二者都是瞬时变化，tab bar 和语音条「啪」地消失/出现。
- 变化：
  - 新增 `accessoryLeaving`（下移 40pt + 透明度 0）与 `accessoryMounted`（是否挂载）两个状态：**退出时先动画、后卸载**，不再一上来就把附属栏从视图树里拿掉。
  - 进入：点语音条后 `withAnimation(.easeInOut(duration: 0.3))` 同时置 `accessoryLeaving = true` 与 `tabBarHidden = true`，语音条下滑淡出；动画放完约 0.3s 后才卸载附属栏、弹原生语音 sheet 并停在 76 小档。
  - 退出：`onDismiss` 里先把附属栏按「offset 40 / opacity 0」挂回，再用同一个 `withAnimation(.easeInOut(duration: 0.3))` 回到原位、透明度 1，tab bar 同步显示。
  - 首页内容（列表、头像、+）没有任何位移或透明度变化，只有 tab bar 与语音条两样在动。
  - `isTransitioning` 仍然挡住重复点击。
- 文件：`apps/ios/Views/HomeSourcesView.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 176）并启动。按要求未自测、未截图。
- 限制/待办：**系统 tab bar 的 .toolbar(.hidden) 是否真的吃 `withAnimation` 我这边无法自测**。若真机上 tab bar 仍是瞬间消失（语音条已有滑动淡出、tab bar 却是硬切），那就是系统的工具栏可见性不参与该事务——按你的要求我先停在这里，请把现象告诉我（是不是只有 tab bar 硬切、语音条正常），我再决定是否改用「保持挂载 + 只淡出附属栏」的方案。
- 关联：C0172、C0174、C0176。
### C0179 · 2026-11-05 · 键盘模式：删掉「完成」、按钮钉在键盘上方

- 原因：「完成」是 C0155 为了让键盘能收起加在 sheet 根视图上的键盘工具栏；同时键盘弹起时底部那排按钮会被键盘盖住（附图时更明显）。
- 「完成」位置：`apps/ios/Kit/Sources/CodyncUI/Voice/VoiceSheetView.swift:88-93`（改动前）——`body` 上的 `.toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button(L10n.tr("Done")) { typing = false } } }`，整段已删除，没有换成其它按钮；收起键盘仍靠「点空白处」（同文件 `.onTapGesture { if typing { typing = false } }`）。
- 变化：半屏/全屏的布局从「标题 + 附件行 + 文字区 + 按钮行」改为「标题 + 附件行 + 文字区（可伸缩）」+ **`.safeAreaInset(edge: .bottom)` 包住按钮行**（波形 + 相机/键盘/设置/暂停）。按钮行因此始终贴在安全区底部：键盘弹起时正好钉在键盘正上方（有没有附图都一样），键盘收起后回到屏幕底部；空间不够时只有可滚动的文字区被压缩，标题与附件行的位置不变，按钮不会被遮住。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Voice/VoiceSheetView.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 177）并启动。按要求未自测、未截图。
- 限制/待办：无。
- 关联：C0155、C0167。
### C0180 · 2026-11-05 · 语音条进出动画去掉形变联动，退出改为下一帧起播

- 排查结论（形变联动）：活动路径上**没有**任何 glassEffectID / matchedGeometryEffect / Namespace 把语音条和 sheet 连起来——`apps/ios/Views/HomeSourcesView.swift`、`apps/ios/Kit/Sources/CodyncUI/Voice/VoiceSheetView.swift`、`VoiceCamera.swift`、`VoiceMiniBar.swift`(已删) 均无；唯一命中是 `apps/ios/Views/HomeBottomBar.swift:19/26/57/68/77`（`@Namespace`、`GlassEffectContainer`、`glassEffectID`），那是**已不再使用**的旧悬浮底栏（仅被同样废弃的 `BotListView` 引用），与本路径无关，未改动。
- 变化：
  - 进入保持：`withAnimation(.easeInOut(duration: 0.3))` 同时置「语音条下移 40pt + 渐隐」与 `tabBarHidden = true`；动画放完（300ms）才卸载语音条并由系统上滑弹出 sheet。
  - 退出改为：`onDismiss` 先把语音条按初始状态（offset 40 / opacity 0）挂回，**用 `DispatchQueue.main.async` 等到下一帧**，再用同一个 `withAnimation(.easeInOut(duration: 0.3))` 回到原位、透明度 1，tab bar 同步显示——首帧布局不再被并进动画，避免卡顿。
  - 页面内容仍然没有任何位移或透明度变化。
- 文件：`apps/ios/Views/HomeSourcesView.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 178）并启动。按要求未自测、未截图。
- 限制/待办：**系统 tab bar 的 `.toolbar(.hidden)` 是否参与该 `withAnimation` 事务我无法自测**。若真机上仍出现「语音条有滑动淡出、tab bar 却瞬间消失」，说明系统工具栏可见性不吃这个事务——按你的要求我先停在这里，请告诉我这个现象，我不再自己换方案。
- 关联：C0174、C0176、C0178。
### C0181 · 2026-11-05 · 点语音条后不再留下空白玻璃条：整条附属栏随动画卸掉

- 现象：C0180 只对附属栏**内容**做 offset/opacity，内容淡没了，系统给附属栏的玻璃胶囊外壳还在原地，留下一条空白玻璃条，直到 sheet 弹出才消失。
- 变化：
  - 点击时不再只淡出内容，而是在 `withAnimation(.easeInOut(duration: 0.3))` 里把整个附属栏卸掉（`.tabViewBottomAccessory` 不再挂载，`accessoryMounted = false`），同一个事务里 `tabBarHidden = true`，交给系统动画一起退场；0.3s 后再弹 sheet。
  - 关闭：`onDismiss` 里用同一个 `withAnimation(.easeInOut(duration: 0.3))` 把附属栏与 tab bar 一起挂回。
  - `VoiceBar` 去掉了 `leaving` 参数与那层 offset/opacity；页面内容仍然没有任何位移或透明度变化。
- 文件：`apps/ios/Views/HomeSourcesView.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 179）并启动。按要求未自测、未截图。
- 限制/待办：**系统卸载/挂载附属栏是否自带动画、是否吃这个 `withAnimation` 事务，我无法自测**。若真机上变成「瞬间消失/出现」（没有过渡），说明系统这部分不参与动画——按你的要求我先停在这里，请告知现象（「卸掉是瞬时的」即可），我不再自行改用 overlay 或其它方案。
- 关联：C0178、C0180。
### C0182 · 2026-11-05 · 关闭 sheet 后两个 bar 闪一下、没有入场动画：附属栏常驻、只换内容

- 原因（排查结论）：
  - 关闭链「直接出现、突然亮」：C0181 把 `accessoryLeaving`（offset 40 / opacity 0 → 0 / 1）整块删掉了，`onDismiss` 只在 `withAnimation` 里置 `accessoryMounted = true`，而 `HomeVoiceAccessory` 身上没有任何 offset / opacity，挂载那一帧初始值就等于终值，没有可插值的属性差 → 没有动画可播。
  - 进场链「看着正常」：点语音条那一帧就把附属栏从视图树里删掉（`withAnimation` 里 `accessoryMounted = false`），0.3s 后 sheet 从底部升起把这一帧盖住了。
  - 「闪一下」主因：`VoiceBar` 的 `body` 用 `if shown { content.tabViewBottomAccessory { … } } else { content }` 返回**两种不同的视图类型**，`shown` 一翻 SwiftUI 就把这个位置整棵子树销毁重建——重建的是整个 `TabView`（5 个 NavigationStack + 全部列表），不只是附属栏；重建那一帧没有旧视图可过渡，全屏重排就闪一下。
- 变化（方案 2）：
  - `VoiceBar` 改为**始终**对 `content` 应用 `.tabViewBottomAccessory { … }`：`shown` 时放 `HomeVoiceAccessory`，否则放 `EmptyView()`。视图类型不再变化 → `TabView` 不再重建。
  - `VoiceBar` 恢复 `leaving` 参数；`HomeVoiceAccessory` 上重新加 `.offset(y: leaving ? 40 : 0)` 与 `.opacity(leaving ? 0 : 1)`。
  - 进场：`beginVoice()` 里 `withAnimation(.easeInOut(duration: 0.3))` 同时置 `accessoryLeaving = true`（内容下移 40pt + 渐隐）与 `tabBarHidden = true`；300ms 后才 `accessoryMounted = false`（此时已不可见、且马上被 sheet 盖住）并弹 sheet——时序与 C0181 一致。
  - 关闭：`onDismiss` 先 `accessoryMounted = true; accessoryLeaving = true`（内容以 offset 40 / opacity 0 挂上），下一帧 `DispatchQueue.main.async` 再在同一个 `withAnimation(.easeInOut(duration: 0.3))` 里 `accessoryLeaving = false`（回到 0 / 1）与 `tabBarHidden = false`。
  - 页面内容仍然没有任何位移或透明度变化。
- 文件：`apps/ios/Views/HomeSourcesView.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过；已装到 iPhone 16 Pro（2.36.0 / 180）并启动。按要求未自测、未截图。
- 限制/待办（按你的要求先停在这里，等你报现象）：**附属栏常驻后、内容为 `EmptyView` 时系统是否仍留一条空白玻璃胶囊，我无法自测**。需要看三种静止状态：① 置顶 / Coe 正常显示；② DS Bot / DSH / 搜索 tab（这三处原本完全不挂 accessory）；③ 会话页、设置页等二级页。任一处仍留空玻璃条，就说明空内容不塌缩——请告诉我，我不自行换方案（overlay / 隐藏 slot 等）。
- 另一处按你的要求未动：状态变量仍叫 `accessoryMounted`，语义已变成「附属栏是否画内容」；要不要改名成 `accessoryShown`，你说了我再改。
- 关联：C0178、C0180、C0181。
### C0183 · 2026-11-05 · 语音条从系统附属栏改成自绘 overlay 玻璃胶囊

- 原因：`.tabViewBottomAccessory` 两个方向都做不出动画——它只能整条挂载/卸载，且挂载即终值。C0182 虽然消掉了闪（不再重建 TabView）、把内容 offset/opacity 加回来了，但那层内容仍活在系统槽位里，入场依旧被系统接管。
- 变化：
  - 删掉 `VoiceBar` 条件修饰符与 `.tabViewBottomAccessory`：`TabView` 不再挂系统附属栏。
  - `tabs` 改为 `.overlay(alignment: .bottom) { voiceCapsule }`；新增 `VoiceCapsule`：`GlassEffectContainer(spacing: 12)` 包住 `HomeVoiceAccessory` + `.padding(.vertical, 10)`，外面 `.glassEffect(.regular.interactive(), in: Capsule())`。内容与样式照搬原 `HomeVoiceAccessory`（主 bot 头像 24pt、`跟 xx 说点什么…` 17pt `Palette.secondary`、左 12、间距 8）。
  - `HomeVoiceAccessory` 去掉 `@Environment(\.tabViewBottomAccessoryPlacement)` 和 `placement == .expanded` 判断——没有系统附属栏了，文字改为常显（否则读到空 placement，文字会整段消失）。
  - 位置：横向 `.padding(.horizontal, 16)`（与列表行/工具栏同一侧距）；纵向 `.padding(.bottom, tabBarInset + 8)`，`tabBarInset` 是新增 `@State`，由每个 tab 的 `stack(...)` 里 `.onGeometryChange` 读自身 `safeAreaInsets.bottom` 得到（只保留更大值，tab bar 隐藏时不跟着缩），`ignoresSafeArea(.container, edges: .bottom)` 让它从屏幕底边量起——胶囊因此落在 tab bar 正上方 8pt。
  - 显隐：`capsuleShown = (selection == .pinned || selection == .coe) && isTabRoot`，规则与原来一致（DS Bot / DSH / 搜索 tab 与二级页不显示）。胶囊**始终挂载**，只改 `.offset(y: capsuleLeaving ? 40 : 0)` 与 `.opacity(capsuleShown && !capsuleLeaving ? 1 : 0)`，加 `.allowsHitTesting(...)` 关掉隐藏时的点击。
  - 进场：`withAnimation(.easeInOut(duration: 0.3))` 里 `capsuleLeaving = true`（下移 40 + 渐隐）与 `tabBarHidden = true`；300ms 后弹 sheet，时序与之前一致。
  - 关闭：`onDismiss` 里同一个 `withAnimation(.easeInOut(duration: 0.3))` 把 `capsuleLeaving` 归零、`tabBarHidden = false`。胶囊没卸载过，所以不再需要 C0182 那套「先挂成 40/0、下一帧再起播」。
  - 滚动：`.tabBarMinimizeBehavior(.onScrollDown)` 保留（系统 tab bar 仍会缩），胶囊不再跟着缩——`HomeVoiceAccessory` 里对 placement 的依赖已删，胶囊只做 offset/opacity。
  - 页面内容仍然没有任何位移。
- 文件：`apps/ios/Views/HomeSourcesView.swift`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug -destination 'generic/platform=iOS'` 通过（2.36.0 / 181）。**未装到 iPhone 16 Pro**：按设备 UDID 的构建在设备掉线后失败（`xcodebuild` 报 "Unable to find a destination matching the provided destination specifier"，`devicectl` 显示该机 `unavailable`，USB 也未枚举到），先停在编译通过这一步。按要求未自测、未截图。
- 限制/待办：
  - **装机待补**：手机重新连上后需再跑一次设备构建并安装启动（2.36.0 / 181）。
  - `.toolbar(.hidden, for: .tabBar)` 是否吃这个 `withAnimation` 事务仍未验证（C0180、C0181 就挂着这条）。若真机上 tab bar 是硬切、只有胶囊在下移渐隐，按你的要求我先停下报给你，不自行换方案。
  - 胶囊几何是按 app 现有约定推的，没有真机核对：横向 16pt（与列表行/工具栏同一侧距）、纵向 `tabBarInset + 8`、胶囊高 44（24pt 头像 + 上下各 10）。
  - `tabBarInset` 取自 tab 内容自身的 `safeAreaInsets.bottom`（应为 tab bar 总高，含 Home 指示条）。若它读到 0 或偏小，胶囊会贴到屏幕底边甚至压住 tab bar——真机上位置一偏就报我，我不自己调这个数。
- 关联：C0178、C0180、C0181、C0182。

### C0184 · 2026-11-05 · 清理确定死代码、移除 TabBar 对照页

- 原因：`ui/native-tabbar` 的底部栏改造完成后，仓库里留下一批“编译了没人调”的死代码（依据本轮只读审计，全仓约 4%）；其中 `TabBarProbeView` 仍会编进 Release，真机上“版本号十连击 → TabBar 对照”十二次点击即可打开。
- 变化（只删不改，共 22 个文件、748 行删除、1 行新增）：
  - 整文件删 7 个 Swift 文件 + 1 个图片集（411 行）：`Views/TestTabView.swift`(32)、`Views/RowLabel.swift`(51)、`Thread/RecordingPill.swift`(44)、`Thread/DictationEngineMenu.swift`(27)、`Routines/TimeZonePicker.swift`(60)、`AnalyticsSheet.swift`(64)、`Debug/TabBarProbeView.swift`(127)、`Resources/Assets.xcassets/github.imageset`(6；全仓无 `Image("github")` 引用)。`TimeZones.swift` 按清单保留（测试在用）。
  - 文件内删符号（285 行）：`Dialog.swift` 的 `DialogCard` + `DialogButtonStyle`(91，`codyncDialog` 早已改成原生 alert)；`Bots/ComputerFilterHeader.swift` 的 `ComputerFilterHeader`(88，同文件 `BotStore.connectionLabel` 保留)；`Views/LanguageSettings.swift` 的 `LanguageSettings`(24，`LanguageRow`/`LanguagePage` 保留)；`Views/QuickCapture.swift` 的 `QuickCaptureOverlay` 与 `endPull()`(82)。
  - 零引用函数 6 个（36 行）：`AccountSession.sessionToken()`(5)、`AccountStore.joinAccount(claimId:signed:cloud:)`(12)、`Composer.pasteFiles()`(6)、`CloudClient.createClaim()`(4)、`Market.composioApps(search:)`(5)、`VoiceSession.dismissNotice()`(4)。
  - 移除 TabBar 对照页入口（净 8 行）：`Views/SettingsView.swift` 的 `showTabBarProbe` 绑定与“TabBar 对照”按钮(5)、`Views/AccountSwitcherView.swift` 的状态/传参/`.fullScreenCover`(−3/+1)。版本号十连击、`showAdvanced` 及其下的 Sign out / Delete account / Start over 全部保留不动。
  - `apps/Codync.xcodeproj/project.pbxproj` 由 `xcodegen generate --spec apps/project.yml` 重新生成，只减少 8 行（两个 Views 文件的 PBXFileReference/PBXBuildFile/group/Sources 条目），没有其它改动。
- 文件：上列 21 个，加 `apps/Codync.xcodeproj/project.pbxproj`。
- 验证：`xcodebuild build -scheme iOS -configuration Release -destination 'platform=iOS,id=<iPhone 16 Pro>' CODE_SIGNING_ALLOWED=NO` 通过（0 error）。签名步骤在环境层面受限：Release 配置用 `ios/Resources/iOS.entitlements`（含 `aps-environment`、`com.apple.developer.usernotifications.communication`），而当前签名身份“穗 许”是 Personal Team，不支持这两个能力，故 iOS scheme 的签名构建失败，与本次改动无关。改用可签名的 `iOS Dev`/`DevDebug`（`UIPreview.entitlements`）构建通过，已装到 iPhone 16 Pro（2.36.0 / build 24）并启动成功。按要求未自测、未截图。
- 限制/待办：清单外的一律没动——`BotListView` 死岛（连带 `HomeBottomBar`/`RosterSectionHeader`/`ComputerSection`/`EmptyRoster`/`CardMenuOverlay`，约 1 千行）、`AppTab.test`、`CODYNC_QUICKCAPTURE`、L10n json 与孤儿 key、`ChoiceList`/`CardForm`、DSHKit 的 `DSHHomeSection`、Analytics 明文 key、`relayDisabled`/`relayTasks`/`canEditKey` 均留待后续。
- 关联：C0183。

### C0186 · 2026-11-05 · iOS 移除 App 内更新：清掉只为那个按钮存在的残渣

- 原因：C0111 撤掉 App 内更新入口后，模型层与埋点里还留着只为那个按钮服务的分支和事件，测试也仍在断言已经不存在的 `.button` 配件——"删了 UI 没删底层"。
- 变化：
  - `Kit/Sources/CodyncUI/Store/BotStore+HostUpdate.swift`：删掉 `HostVersionLine.Accessory.button(String)`（两处生产者都已在 C0111 移除），`Accessory` 只剩 `.updating`；删掉 `requestHostUpdate()`（生产代码零调用，唯一调用方是测试）。
  - `Views/ComputersView.swift`：版本行的 `switch` 去掉 `case .button: EmptyView()` 占位分支。
  - `Kit/Sources/CodyncKit/Analytics/AnalyticsEvent.swift`：删掉 `Link.appStore`（撤掉 App Store 跳转后全仓 0 引用）。
  - `Kit/Tests/CodyncUITests/HostUpdateTests.swift`：删掉两个由 `requestHostUpdate()` 驱动的用例（更新请求、行内 `.updating`→`.button` 轮回）；剩下两个 `HostVersionLine.make` 用例改为断言新行为——没有按钮，只给一句 "Update Codync on that computer."。
  - `how(os:)` 保持固定一句，不恢复 macOS/Linux 专属指引；`Views/BotListView.swift` 里 C0111 的 −3 行原样保留。
  - 同批已处理：`apps/desktop/package.json` 被误删的 `scripts` 与 `devDependencies` 已按 HEAD 还原，不产生提交。
- 文件：上列 4 个 iOS 文件。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过（0 error / 0 warning）。按要求未跑测试、未截图。
- 限制/待办：`UpdateNeededText.notUpdated(.requested)` 的文案仍写「Try again, or update Codync on that computer.」，而"再试一次"的按钮已不存在；这句属清单外，未改，留待后续。
- 关联：C0110、C0111。

### C0187 · 2026-11-05 · 思考状态行：与 Live Activity 合成一套文字，phase 改用结构化字段

- 原因：C0109–C0113 的状态行只改了聊天页，Live Activity 仍走 `BotActivityPresentation.caption` 直接显示原始 `activity`（`bash`）——同一个 bot 在锁屏说「bash」、在聊天说「跑一下命令」；状态行区分「思考/工作」也还是靠 `activity` 的英文前缀（`Thinking`/`Starting`/`Typing`/`Writing a reply`）在猜，host 一发中文就永远判成「正在工作」。
- 变化：
  - `Kit/Sources/CodyncKit/Models/ThinkingStatusText.swift`（新）：`ThinkingStatusText` 从 CodyncUI 上移到 CodyncKit，成为这一行文字的**唯一来源**；顺带把「10 秒后才显示耗时」「60 秒算久」「耗时标签格式」收成这里的常量与函数。
  - `Kit/Sources/CodyncKit/Models/BotActivityPresentation.swift`：`caption` 的 `working`/`needsInput` 分支改走 `ThinkingStatusText.text(...)`，Live Activity 与聊天页从此同一句话。
  - `Kit/Sources/CodyncUI/Thread/ThinkingStatus.swift`：删掉本地文字映射（已上移）；`ThinkingStatusRow` 的 phase 只看结构化字段 `bot.needsInput`（host `status` = `working`/`needsInput`），不再对 `activity` 做英文前缀匹配；耗时统一走 `ThinkingStatusText.elapsed(_:)` / `.suffix(seconds:)`。
  - `Kit/Tests/CodyncKitTests/ActivityPresentationTests.swift`：`caption` 断言改成新措辞（`needsInput`→`Waiting for your OK`、空 activity→`Typing…`、`bash`→`Running a command`）。
- 计时选了哪一套：聊天页那套「按 `startedAt` 算秒数 + 1s 时钟」。理由：只有它能同时表达「10 秒前不显示」和「60 秒后加一句」，`Text(style: .timer)` 是系统自走的文本、取不到秒数，判断不了这两个阈值。Live Activity 仍保留 `Text(style: .timer)`——ActivityKit 的卡片不能跑 1s 的 `TimelineView`，只能靠系统 timer 文本或推送刷新；但它的**文字**已与聊天页同源。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过（0 error / 0 warning）。按要求未跑测试、未截图。
- 限制/待办：
  - host 的 `Bot` 只有 `status`（idle/working/needsInput/error）、`activity`（自由文本）、`startedAt`，**没有**能区分「思考中 / 正在跑某一步」的结构化字段。原来的两种动效（思考时呼吸、工作时扫光）因此合成一种：工作时扫光、等你点同意时静止加黄点。要把呼吸找回来需要 host 增加阶段字段，属 host 改动，本次不做。
  - `de/es/fr/ja/ko` 五个语言包只带上了 C0109 已有的 9 条文案改动，未新增 key。
- 关联：C0109、C0112、C0113。

### C0188 · 2026-11-05 · 长按菜单汉化：切回「跟随系统」时清掉 AppleLanguages，并提示需重启

- 原因：C0114 让 `AppleLanguages` 跟着 App 内选择走，但 `.system` 分支直接 `return`——只要选过中文再切回「跟随系统」，这条覆盖永远清不掉，UIKit 的编辑菜单会一直停在中文，只有重装才恢复。
- 变化：
  - `Kit/Sources/CodyncKit/L10n.swift`：`applyToSystemMenus(in:)` 的 `.system` 分支改为 `removeObject(forKey: "AppleLanguages")`，让 `CFBundleLocalizations` 与设备语言重新决定。
  - `Views/LanguageSettings.swift`：语言页底部加一行小字 `Restart the app for the new language to take effect`——`AppleLanguages` 是启动时读一次的，切换后要重启才生效。
  - `Resources/Languages/zh-Hans.json`：新增该 key 一条（「切换后重启 App 生效」）。英文侧不建 json、key 本身即英文；zh-Hant 缺 key 时回落 zh-Hans。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过（0 error / 0 warning）。按要求未跑测试、未截图。
- 限制/待办：iOS 不允许 App 自行重启，"重启生效"只能靠这行提示，没有其它手段。
- 关联：C0114。

### C0189 · 2026-11-05 · 删掉整个死岛：旧的自绘 roster 与它的底部栏

- 原因：C0184 只清了“确定死、零引用”的单文件，最大的一块还留着——`ui/native-tabbar` 用 `HomeSourcesView` 重写首页后，旧的自绘 roster（拖拽分组、底部浮动栏、卡片长按菜单）整套仍在编译，却没有任何挂载点；986 行，而且 C0111 还在改它。
- 变化：
  - 整文件删除 6 个（986 行）：`Views/BotListView.swift`(534)、`Views/HomeBottomBar.swift`(118)、`Views/RosterSectionHeader.swift`(85)、`Views/ComputerSection.swift`(88)、`Views/EmptyRoster.swift`(32)、`Kit/Sources/CodyncUI/Bots/CardMenuOverlay.swift`(129)。删前逐个确认只互相引用：`BotListView` / `HomeBottomBar` / `RosterSectionHeader` / `RosterBotsLabel` / `ComputerSection` / `EmptyRoster` / `CardMenuOverlay` / `CardMenuState` / `PluginGlyph` 在死岛以外均 0 命中。
  - `Views/BotListView.swift:222` 的 `CODYNC_QUICKCAPTURE` 环境开关随文件消失（全仓唯一读取点）；`QuickCaptureOverlay` C0184 已删，活的 `QuickCaptureSheet` 不受影响。
  - `App/CodyncApp.swift`：`AppTab` 去掉 `test`（全仓没有任何 `switch` 为它分支，只有这一处枚举声明）。
  - 死岛删除后新产生的 Swift 孤儿（确认零引用后删）：`Views/ComputerStatus.swift` 的 `RouteIcon`（17 行）、`Views/BotRosterLine.swift` 的 `LiftItem` 与 `RosterLine`（56 行）。同文件的 `NewTarget` / `GroupTarget` / `EditTarget` 仍被 `HomeSourcesView` 使用，保留。
  - `apps/Codync.xcodeproj/project.pbxproj` 由 `xcodegen generate --spec apps/project.yml` 重新生成，减少 20 行（5 个 Views 文件各自的 FileReference/BuildFile/group/Sources 条目），无其它改动。
  - 合计：10 个文件，+1 / −1080。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过（0 error）。按要求未跑测试、未截图。
- 未删，只登记（等你决定）：
  - L10n 孤儿 key（本次不动 json，全仓已无任何字符串引用）：`Create your first bot`、`Double-tap to fold or expand.`、`Double-tap to fold or expand. Touch and hold to rename or remove the section.`、`{name}, 1 bot`、`{name}, 1 bot, {unread} unread`、`{name}, {count} bots`、`{name}, {count} bots, {unread} unread` —— 共 7 条。
  - asset：无。死岛只用 Remix 字体图标（`RemixIcon` / `RemixImage` 的字形名），不涉及 xcassets。
  - 只被死岛调用、但仍被**测试**引用的 Swift 符号（删了会破测试，保留）：`Store/ComputerSelection.swift`（`ComputerSelection` / `ConnectionSummary`，测试 17 处）、`Store/RosterSectionOrder.swift`（测试 3 处）、`Store/RosterSection.swift` 的 `RosterSection.lines` 与 `RosterSectionLine`（测试 5 处）。
  - 与本次无关的孤儿（清单外，未动）：`Views/QuickCapture.swift` 的 `QuickCaptureModel`（C0184 删 `QuickCaptureOverlay` 后零引用）、`CodyncKit/Models/Cloud.swift` 的 `CloudClaim`（C0186 删 `createClaim()` 后零引用）、`Controls.swift` 的 `CardForm` / `ChoiceList`。
- 关联：C0111、C0184、C0186。

### C0190 · 2026-11-05 · 玻璃收口第 1 步：`GlassSurface` 取代 `glass(in:)` 的两分支写法

- 原因：全 App 的玻璃有 4 套写法（`glass(in:)` 7 处、`VoiceGlass` 6 处、裸 `glassEffect` 5 处、裸 material 5 处）。其中通用的 `glass(in:)` 既没有 `interactive()` 也没有 tint；而 iOS 26 以下的 material 回退在本工程（deployment target 26.0）里不可达。
- 变化（`Kit/Sources/CodyncUI/Platform.swift`）：
  - 新增 `GlassSurface<S: Shape>` 修饰器：`glassEffect` + `interactive`（布尔）+ `tint`（可选），内部按 `tint.map { Glass.regular.tint($0) } ?? .regular` 再叠 `.interactive()`。
  - `glass(in:)` 改成它的薄封装，并加 `interactive:` / `tint:` 两个带默认值的参数——7 个现有调用点（GlassToast、CallView ×2、CommandList、Composer ×2、ConversationList）一行未改，观感不变。
  - 删掉 `#available(iOS 26, *)` 分支与 `ultraThinMaterial` 回退：target 是 26.0，else 不可达。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过（0 error / 0 warning）。按要求未跑测试、未截图。
- 关联：C0191、C0192、C0193。

### C0191 · 2026-11-05 · 玻璃收口第 2 步：语音链路并入 `GlassSurface`，删掉 `VoiceGlass` / `VoicePress`

- 原因：`VoiceGlass`（6 处）和 `GlassSurface` 是同一件事的两份实现——参数一一对应（`tint` 可选、`interactive()` 恒开）；`VoicePress`（5 处）也只是 `PressScale` 的 0.92 变体。
- 变化：
  - `Kit/Sources/CodyncKit/Design/Motion.swift`：`PressScale` 增加 `scale: CGFloat = Motion.pressScale` 参数——「更深的按压」从此有正规出口，不必每处手写 ButtonStyle。
  - `Kit/Sources/CodyncUI/Voice/VoiceSheetView.swift`：4 处 `VoiceGlass(tint:shape:)` → `.glass(in:interactive: true, tint:)`；5 处 `.buttonStyle(VoicePress())` → `.buttonStyle(PressScale(scale: 0.92))`；删除 `VoiceGlass` 与 `VoicePress` 两个类型（24 行）。
  - `Kit/Sources/CodyncUI/Voice/VoiceCamera.swift`：2 处 `VoiceGlass` → `.glass(in: Circle(), interactive: true, tint:)`——快门 `white 0.18`、返回/更多 `black 0.35`。
  - 观感不变的理由：`VoiceGlass` 的 iOS 26 分支本来就是 `glassEffect(tint?.regular.tint(...).interactive() ?? .regular.interactive())`，与 `GlassSurface(interactive: true, tint:)` 逐项等价；0.92 的缩放只是搬进 `PressScale(scale:)`。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过（0 error / 0 warning）。按要求未跑测试、未截图。
- 关联：C0190、C0192、C0193。

### C0192 · 2026-11-05 · 玻璃收口第 3 步：`GlassButton` 接管手搓圆钮，裸 material 并入 `GlassSurface`

- 原因：手搓的玻璃/材质圆钮散在 6 个文件（相机页 2、远屏页 6+2、输入框“+”、跳到最新、头像铅笔角标）；远屏页 5 处还是 `.ultraThinMaterial`，在 iOS 26 上永远拿不到 Liquid Glass；“跳到最新”同一处并存系统 `.glass` 与自绘两套写法。
- 变化：
  - 新增 `Kit/Sources/CodyncUI/GlassButton.swift`：`GlassButton`（圆形图标钮，`.glass(tint:)` / `.filled(fill, ink:)`，`press` 传 nil 即不给按压反馈）+ `GlassGlyph`（同一个圆的“仅图形”版，给自带 `Button`/`Menu` 的调用方）。
  - `Platform.swift`：`glass(in:)` 改为 `public`——app target 的相机快门要自绘这一个面。
  - 迁移：
    - `Views/QuickCapture.swift`：返回 → `GlassButton(press: nil)`；“更多”（`Menu` 标签）→ `GlassGlyph`；快门玻璃环 → `.glass(in: Circle(), interactive: true)`。
    - `Kit/Sources/CodyncUI/Screen/ScreenView.swift`：`OverlayButton`（6 个）→ `GlassButton`；`IconLabel`（2 个标签）→ `GlassGlyph`；另 3 处 material（Capsule、圆角 12、圆角 8）→ `.glass`。
    - `Kit/Sources/CodyncUI/Bots/BotProfileEditView.swift`：头像铅笔角标 → `GlassGlyph`（material → 玻璃）。
    - `Kit/Sources/CodyncUI/Thread/Composer.swift`：输入框“+” → `GlassGlyph`。
    - `Views/HomeSourcesView.swift` 语音胶囊、`Thread/ThreadView.swift` 顶部胶囊：裸 `glassEffect` → `.glass(in:interactive: true)`（`GlassEffectContainer` 保留）。
    - `Thread/ConversationList.swift`：“跳到最新”两套写法合成一个 `GlassButton`，删掉 `#available(iOS 26)` 分支。
  - 结果：裸 `.glassEffect` 与裸 material 现在各 **0 处**（只剩 `GlassSurface` 内部那一次）。
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过（0 error）。按要求未跑测试、未截图。
- 本次唯一的可见变化（其余尺寸全部保持原值，收档放在 C0193）：① 远屏页 5 处 material 首次变成 Liquid Glass；② “跳到最新”从系统 `.glass` 按钮（controlSize large）改为自绘 44pt 玻璃圆钮。
- 关联：C0190、C0191、C0193。

### C0193 · 2026-11-05 · 玻璃收口第 4 步：尺寸与形状收档（7 档 → 4 档），图标钮一律正圆

- 原因：圆钮的尺寸散成 7 档（22/28/36/38/44/46/48，另有相机快门 64/72），形状也不统一——`IconButton` 是 44pt 圆角方形（r≈12.3），玻璃/实心圆钮却是正圆；改一个尺寸要满仓库找。
- 变化：
  - `Kit/Sources/CodyncUI/GlassButton.swift` 新增 `ControlMetrics`：`Size`（micro 24 / compact 36 / icon 44 / large 64，各带 `glyph` 默认图标尺寸与 `hitTarget` 命中区）、`Shape`（只有 `.circle`，全局常量 `ControlMetrics.shape`）、`Press`（standard 0.98 / deep 0.92 / none）。形状、尺寸、按压**只在这一个地方定义**。
  - `GlassButton` / `GlassGlyph` 的 API 从 `side: CGFloat` 改成 `size: ControlMetrics.Size`，`press` 从 `CGFloat?` 改成 `ControlMetrics.Press`。
  - `IconButton`（`Chrome.swift`）改用 `ControlMetrics.Size.icon.side` + `ControlMetrics.shape` → **32 处图标钮从圆角方形变成正圆**（穗已拍板）。
- 逐条：旧尺寸 → 新尺寸（可见变化用 **加粗**）
  | 位置 | 旧 | 新 |
  |---|---|---|
  | `IconButton`（32 处） | 44pt **圆角方形**（r≈12.3），图标 24 | `.icon` 44pt **正圆**，图标 24 |
  | 语音 sheet `circle()` / `circleLabel` / 发送 / 占位 | 44 | `.icon` 44（不变） |
  | 语音 sheet 附件 ✕ | 22 | `.micro` **24** |
  | 语音相机 返回 / 更多 | 44 | `.icon` 44（不变） |
  | 语音相机 快门 | 72 | `.large` **64** |
  | 相机页 返回 / 更多 | 44 | `.icon` 44（不变） |
  | 相机页 快门（玻璃环 64 / 白盘 54） | 64 / 54 | `.large` 64 / `side-10` 54（不变） |
  | 远屏页 `OverlayButton`（6）/ `IconLabel`（2） | 36 | `.compact` 36（不变） |
  | 「跳到最新」 | 44 | `.icon` 44（不变） |
  | 输入框「＋」 | 48 圆 | `.compact` **36**（外层 48 命中区不变） |
  | 输入框 发送 / 停止 | 36 可见 + 48 命中 | `.compact` 36 + `hitTarget` 48（不变） |
  | 通话条 圆钮（设置 / 静音 / 挂断） | 46 | `.icon` **44** |
  | 输入框附件 ✕ | 28 | `.micro` **24** |
  | Bot 头像 铅笔角标 | 38 | `.compact` **36** |
- 验证：`xcodebuild build -scheme 'iOS Dev' -configuration DevDebug` 通过（0 error）。按要求未跑测试、未截图。
- 按你的要求**本次没有补按压反馈**的 5 处（维持原样，仅登记）：输入框「＋」、Bot 头像铅笔角标、相机页 返回、相机页 更多、相机页 快门（都是 `press: .none` / `.buttonStyle(.plain)`）。其余圆钮是 standard 0.98，语音 sheet 保持 deep 0.92。
- 关联：C0190、C0191、C0192。

### C0194 · 2026-11-04 · 首页删掉原生 TabView，底部改成搜索框 + 语音圆钮

- 原因：原生 `TabView` 的底部导航栏（置顶 / Coe / DS Bot / DSH + 系统搜索页）在首页占掉整整一条，
  语音胶囊只能挂在它上面，为把它藏起来还写了每 tab 一个 `stack(voiceSheet:)`、3 处
  `.toolbar(…, for: .tabBar)`、一段量 tab bar 高度的 `onGeometryChange` 和一套 40pt 下滑淡出动画。
  现在底部只留一行：左边搜索框、右边圆钮；拍照已并入语音输入，不再有单独的照片按钮。
- 变化：
  - `Views/HomeSourcesView.swift` 删掉整套 tab 结构：`tabs`（`TabView` / `Tab` / `Tab(role: .search)`）、
    每 tab 的一份 `stack(voiceSheet:)`、`.tabBarMinimizeBehavior(.onScrollDown)`、3 处
    `.toolbar(…, for: .tabBar)`、量 tab bar 高度的 `onGeometryChange`，以及只服务它的
    `selection` / `tabBarHidden` / `capsuleLeaving` / `tabBarInset` / `isTransitioning` / `barFade` /
    `isTabRoot` / `capsuleShown`。首页改成一个 `NavigationStack`，根页面是「置顶」列表；会话仍按原来的
    `path` 绑定推入同一栈。
  - 删掉语音胶囊：`voiceCapsule` 的 `.overlay(alignment: .bottom)` 挂载、`VoiceCapsule` 与
    `HomeVoiceAccessory` 两个类型、`beginVoice()` 里「胶囊下滑 40pt + 淡出、等 300ms 再抬 sheet」的过渡、
    sheet `onDismiss` 里把胶囊和 tab bar 拉回的那段动画。语音 sheet 本身（`VoiceSheetView`、
    `voice` / `showVoice` / `voiceDetent`、`sendToLeadBot`、`raiseSheet`、`voice.phase` 与 detent 处理）
    一行未改。
  - 新底部栏（同文件，就放在被删的胶囊段）：`HStack(spacing: 12)` + 左右 `.padding(.horizontal, 16)`
    与 `.padding(.top, 8)`，作为首页根的 `.safeAreaInset(edge: .bottom, spacing: 0)` —— 只有根页面有，
    push 进二级页就没有；键盘弹出时随安全区被顶到键盘上方（与聊天页 Composer 同一套做法）。
  - 搜索框：`TextField`（`Search chats`）+ `search-line` 图标 + 内边距 14 + 高度 `ControlMetrics.Size.icon.side`
    (44，与右侧圆钮同高) + `.glass(in: Capsule(), interactive: true)`；整颗胶囊 `.contentShape(Capsule())`
    加点击即 `@FocusState` 聚焦。不跳页、不弹 sheet，键盘就地出现。
  - 过滤：复用原搜索 tab 的 `searchEntries`——所有已启用来源的会话按标题 `localizedStandardContains` 匹配
    （与搜索范围一致：不限于置顶）；空结果显示 `No matches`。原独立搜索页 `searchList` 换成就地显示的
    `searchResults`（同样的行、同样的空状态，去掉 `.searchable`）。
  - 右侧圆钮：`GlassButton(size: .icon)`，两个状态同位置叠加、`.animation(Motion.fade)` 淡入淡出；
    未聚焦显示 `mic-line`（`beginVoice()` 打开现有语音 sheet，含「先设置主 Bot」的 toast 校验），
    聚焦时显示 `close-line`（清空 `searchText`、取消聚焦收键盘、列表复原、圆钮变回麦克风）。
  - `Views/HomeSource.swift`：删除只服务 tabs 的 `enum HomeTab`（含 `title` / `symbol` / `source`）。
- 文件：`apps/ios/Views/HomeSourcesView.swift`、`apps/ios/Views/HomeSource.swift`。
  未改 `VoiceSheetView` / `VoiceCamera` / Kit 任意文件，未新建文件，`apps/Codync.xcodeproj` 未重新生成
  （`project.yml` 无新文件可加）。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`（真机 destination、
  ui-preview 覆盖、构建号 182）**编译通过，0 error**，改动的两个文件 0 warning；`xcrun devicectl device install app`
  装到 iPhone 16 Pro（`com.suiyikou.codync.uipreview` 2.36.0 / 182）成功。按你的要求**不自测**：
  不跑测试、不截图、不用 CDP，界面与交互均未实测。
- 限制/待办：
  - 暂时没有入口、但代码保留的视图：Coe 来源列表 `rosterList(botEntries(for: .coe))`、
    DS Bot 来源列表 `rosterList(botEntries(for: .dsBot))`、DSH 对话列表 `rosterList(dshEntries, hint: dshHint)`
    （含 `dshHintRow` 的未连接提示）；「首页来源」开关仍在 `Views/SettingsView.swift` 的
    `ForEach(HomeSource.allCases)` 三行里可切，当前只影响搜索范围与 DSH 连接，不影响首页主体。
  - 底部栏贴键盘、✕ 清空收键盘、进会话页隐藏等交互只按代码实现，尚未真机确认。
  - `Views/RootView.swift`（第 81–83 行）与 `Views/SettingsView.swift`（第 47 行）各有一句提到
    tab bar / 语音胶囊的注释已过时；按「清单外一律不动」本次未改。
- 关联：C0192、C0193。

### C0195 · 2026-11-04 · 首页底部栏改用会话页输入栏的数值，并补上中文文案

- 原因：C0194 的底部栏按「上 8 / 下 0、圆钮 44、间距 12」自行定的数，结果比会话页输入栏偏上、
  圆钮比输入栏的「＋」大一号、胶囊是正圆端而不是输入框的圆角，中文界面里 placeholder 和空结果
  还落在英文（`Search chats` / `No matches` 两条词条根本没进 zh-Hans）。
- 核验（会话页 `Kit/Sources/CodyncUI/Thread/Composer.swift` 的实际数值）：
  - 输入栏底边：键盘收起时 `padding(.bottom, 28)` + `ignoresSafeArea(.container, .bottom)`，
    即距屏幕物理底边 28pt；键盘弹起时 `padding(.bottom, 12)`，即距键盘顶部 12pt；顶部 `padding(.top, 6)`。
  - 「＋」与输入框水平间距：外层 `HStack(spacing: 8)`；「＋」是 `.compact` 36pt 圆放在
    `ControlMetrics.Size.compact.hitTarget`(44) 命中框内，左右各 4pt 不可见留白，**视觉间距 8 + 4 = 12pt**。
    因此「键盘顶部间距 12 = ＋号与输入框间距 12」在视觉上成立（原始 spacing 是 8，差在命中框那 4pt）。
  - 输入框：最小高度 44（= `compact.hitTarget`），圆角 `RoundedRectangle(cornerRadius: 24, style: .continuous)`，
    胶囊内左内边距 14，整行左右外边距 16；输入框右侧是 36pt 圆、44pt 命中框的发送/停止按钮。
- 变化（`Views/HomeSourcesView.swift`）：
  - 底部栏 `HStack(spacing: 12)` → `spacing: 8`；`.padding(.top, 8)` → `.padding(.top, 6)`；
    新增 `.padding(.bottom, keyboardUp ? 12 : 28)` 与 `.ignoresSafeArea(.container, edges: keyboardUp ? [] : .bottom)`，
    与会话页逐项相同；新增 `keyboardUp` 状态，由 `keyboardWillShow/WillHide` 通知驱动（会话页同款）。
    键盘弹起时栏底距键盘 12pt，不再贴着键盘。
  - 右侧圆钮 `GlassButton(size: .icon)`(44) → `size: .compact`(36)，外面套
    `.frame(compact.hitTarget)` 44pt 命中框，与会话页「＋」一致；`HStack` 8 + 命中框 4 = 视觉 12。
  - 搜索框：`Capsule` 正圆端 → `RoundedRectangle(cornerRadius: 24, style: .continuous)`，
    高度用 `ControlMetrics.Size.compact.hitTarget`(44)，内边距 14、外层 16 不变。
- 变化（`Kit/Sources/CodyncKit/Resources/Languages/zh-Hans.json`）：
  - 新增 `"Search chats": "搜索"`、`"No matches": "没有找到"`（两条之前都不存在，所以中文界面显示英文）。
  - 英文仍是键本身（无 en 表）；zh-Hant 沿用既有的「缺词回退简体」行为，日/韩/法/德/西五个表未动。
- 文件：`apps/ios/Views/HomeSourcesView.swift`、`apps/ios/Kit/Sources/CodyncKit/Resources/Languages/zh-Hans.json`。
  `Composer.swift` 只读核验，未改；未新建文件，`apps/Codync.xcodeproj` 未重新生成。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`（真机 destination、
  ui-preview 覆盖、构建号 183）**编译通过，0 error**；`xcrun devicectl device install app` 装到 iPhone 16 Pro
  （`com.suiyikou.codync.uipreview` 2.36.0 / 183）成功。按你的要求**不自测**：不跑测试、不截图、不用 CDP，
  首页与会话页对齐、键盘间距、中文文案都未实测。
- 限制/待办：
  - 其他语言表未加这两条词条，五个目录与 zh-Hans 的键本来就不完全一致（各比 zh-Hans 少 75 条）；
    未运行桌面端的 catalog 对拍测试（按要求不跑测试）。
  - zh-Hant 没有这两条，会按既有规则回退到简体的「搜索」/「没有找到」；要繁体需另加。
- 关联：C0194。

### C0196 · 2026-11-04 · 首页底部栏的圆钮改回 44pt 图标圆（内 24）

- 原因：C0195 为了让首页底部栏与会话页输入栏逐项一致，把右侧圆钮改成会话页「＋」的 `.compact`
  36pt 圆（套 44pt 命中框），中间间距也随之按 8 + 命中框 4 算。穗要圆钮回到 App 的图标圆规格：
  **外 44、内 24**，不再参照会话页的「＋」。
- 变化（`Views/HomeSourcesView.swift`）：
  - `circleButton`：两个状态的 `GlassButton` 从 `size: .compact`(36) 改回 `size: .icon`(44，图标 24)；
    去掉外面那层 `.frame(compact.hitTarget)` 命中框（44 本身已达最小命中区）。
  - `bottomBar`：`HStack(spacing: 8)` → `spacing: 12`——圆钮恢复 44 后，原来「8 + 命中框 4 = 视觉 12」
    的算法不再适用，直接给 12，视觉间距与 C0194 一致。
- 保持不变（C0195 的其余部分）：顶部 6pt、底部 28pt / 键盘弹起 12pt 的垂直数值与
  `ignoresSafeArea`、`keyboardUp` 通知驱动、搜索框 44 高 / 24 圆角 / 内边距 14、外边距 16，
  以及 zh-Hans 的「搜索」「没有找到」两条词条。
- 文件：`apps/ios/Views/HomeSourcesView.swift`。未新建文件，`apps/Codync.xcodeproj` 未重新生成。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`（真机 destination、
  ui-preview 覆盖、构建号 184）**编译通过，0 error**；`xcrun devicectl device install app` 装到 iPhone 16 Pro
  （`com.suiyikou.codync.uipreview` 2.36.0 / 184）成功。按要求**不自测**：不跑测试、不截图、不用 CDP。
- 限制/待办：圆钮 44 比会话页「＋」的 36 大一号，两边不再等大——这是本次明确要的效果；
  首页栏高度 44 仍与输入栏一致，只有右侧圆钮比会话页的大。
- 关联：C0194、C0195。

### C0197 · 2026-11-04 · 首页底部栏：语音钮变形为 76pt 语音胶囊（自绘，不再用 sheet 的小档）

- 原因：76pt 小档一直是系统 sheet 的一档，语音钮和它之间隔着一次 sheet 弹出，形不成「按钮把搜索栏挤掉、
  自己长成输入条」的连续动作。穗要的是：点语音钮，搜索栏原地收窄让位，语音钮自己长成 76pt 胶囊；
  再从胶囊上推进入系统半屏 sheet。评估见 `/tmp/codync-audit/voice-morph.md`，按评估推荐的
  「frame 动画 + `GlassEffectContainer(spacing:)` 融合」实现，没有用 `glassEffectID`。
- 变化（`Kit/Sources/CodyncUI/Voice/VoicePill.swift`，新增）：
  - `VoicePill`：76pt 高的自绘胶囊，内容与顺序与原来的 76pt 档逐项相同——36pt 头像、波形、
    44pt 设置圆钮、44pt 麦克风圆钮，44pt 行 + 上下各 16pt 空白；没有发送、没有关闭。
  - 从 `VoiceSheetView` 抽出两档共用的件并改为模块内共享：`VoiceAvatar`（呼吸由 `recording` 派生，
    Reduce Motion 不呼吸）、`VoiceWaveColumn`、`VoiceSettingsButton`、`VoiceMicButton`。
- 变化（`Kit/Sources/CodyncUI/Voice/VoiceSheetView.swift`）：
  - 删掉 76pt 那一档：`small` 常量、`isSmall`、`pill`、body 里的 `isSmall` 分支与居中判断，
    以及它的 `breathing` / `showSettings` 两个状态和设置 sheet。
  - `settle` 改为 `public`（首页的胶囊用同一条曲线）；`detent` 绑定不再需要，从 init 去掉；
    新增 `openSettings` 回调（语音设置交给当前页面的 presenter）。
  - `avatar` / `waveColumn` / `settingsButton` / `micButton` / `micGlyph` 删除，改用共用的四个件。
- 变化（`Views/HomeSourcesView.swift`）：
  - 底部栏重写：`GlassEffectContainer(spacing: 12)` 里一个 `HStack`，间距在变形时 12 → 0，搜索框宽度
    自适应为「行宽 − 44 − 12」→ 0、透明度 → 0，圆钮的 frame 从 44×44 → 行宽×76，内容用 `Capsule()`
    裁剪；行宽用 `onGeometryChange` 量（`barWidth`），两边宽度之和始终等于行宽，右边缘与搜索框左边缘
    都不动。变形完成后搜索框整体移出视图树（`searchCollapsed`），零宽度不留玻璃残线。
  - 圆钮的玻璃上移到槽位（`.glass(in: Capsule())`），两个图标改成不带自身玻璃的 24pt 字形按钮，
    这样形状可以从圆长成胶囊；关闭时行为与 C0196 相同（44pt 圆、24pt 图标、两态淡入淡出）。
  - 手势：胶囊上短上推（< −30pt）→ `voiceDetent = .medium; showVoice = true`（方案 A）；短下推
    （> +30pt）→ 反向收回，有词/有照片时先用现有文案「Discard this voice message?」确认。
  - 语音流程：`beginVoice()` 先把搜索框键盘收起，再 `withAnimation` 展开胶囊，然后 `voice.begin()`
    （`VoiceSession` 在首页，变形与 sheet 之间录音不中断）；`raiseSheet()` 删除——最小的档就是半屏，
    改为 `openVoiceSheet()`，`.confirming` / `.notice` / `.paused 且没听到` 时从胶囊升到半屏。
  - 语音设置：胶囊里的设置打开首页这一层的 `VoiceLanguageSheet`；半屏/全屏里的设置仍由 sheet 自己弹
    （一个页面同时只能弹一个 sheet，从首页弹会在 sheet 已呈现时被拒），两条路径不会同时出现。
  - 动画曲线：选 `VoiceSheetView.settle`（`.spring(response: 0.35, dampingFraction: 0.9)`），因为
    sheet 自己的档位变化就是这条曲线，胶囊长出来和 sheet 变化读起来是一次动作；它不是过冲型弹簧，
    末尾稳定、不会把胶囊撑过行宽。Reduce Motion 时 `Motion.reduced(...)` 退化为 `Motion.fade`。
- 76pt 档原来的 6 处引用，逐条改掉：
  1. `voiceDetent` 初值 `VoiceSheetView.small` → `.medium`
  2. sheet `onDismiss` 里的复位 → `.medium`
  3. `presentationDetents([small, .medium, .large])` → `([.medium, .large])`
  4. `presentationBackgroundInteraction(.enabled(upThrough: small))` → 删除（最小档已是半屏，背景应锁住）
  5. `beginVoice()` 里的 `voiceDetent = VoiceSheetView.small` → 不再设档，改成展开胶囊；
     开 sheet 时由 `openVoiceSheet()` 设 `.medium`
  6. `raiseSheet()` 里 `voiceDetent == VoiceSheetView.small` 的前置判断 → 整个函数删除，
     由 `openVoiceSheet()` 取代
- 文件：`apps/ios/Kit/Sources/CodyncUI/Voice/VoicePill.swift`（新）、
  `apps/ios/Kit/Sources/CodyncUI/Voice/VoiceSheetView.swift`、`apps/ios/Views/HomeSourcesView.swift`。
  新文件在本地 Swift package `apps/ios/Kit` 里，已按要求执行 `xcodegen generate --spec apps/project.yml`；
  该 package 是目录型 target，`project.pbxproj` 因此没有变化（没有手改生成文件）。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`
  （真机 destination、ui-preview 覆盖、构建号 185）**编译通过，0 error**；`xcrun devicectl device install app`
  装到 iPhone 16 Pro（`com.suiyikou.codync.uipreview` 2.36.0 / 185）成功。按你的要求**不自测**：
  不跑测试、不截图、不用 CDP，变形、反向、上推衔接、设置、减弱动态均未实测。
- 限制/待办：
  - 从胶囊上推到半屏是「松手后弹 sheet」（方案 A），系统 sheet 的进场无法从 76pt 起，切换瞬间会有
    一次「胶囊 → sheet」的交接；录音不中断，但视觉衔接未实测。
  - 76pt 已不是 sheet 的一档，`presentationBackgroundInteraction` 随之去掉：半屏时首页不可交互（原来
    在 76pt 时可交互）。
  - 语音设置仍有两个 presenter：胶囊的在首页、半屏的在 sheet 内。这是「一个页面一次只能弹一个 sheet」
    的限制；若要求严格单一 presenter，只能把语音设置改成 sheet 内的一页（push）而不是第二个 sheet。
  - 变形期间栏高 44 → 76，首页列表会随安全区上移 32pt（`safeAreaInset` 的正常行为）。
- 关联：C0194、C0195、C0196；评估：`/tmp/codync-audit/voice-morph.md`。

### C0198 · 2026-11-04 · 语音胶囊「展开」时的轻微卡顿：录音启动挪到下一帧、阶段变化不再重建列表

- 原因：C0197 的展开动画在真机上比收起多一点卡顿，且冷启动第一次最明显。只读排查（没有 profile，按代码路径判断）
  找到三处只在「开启」时发生、且都落在动画首帧同一/相邻 runloop 的主线程工作：
  1. `VoiceSession.begin()`（`Kit/Sources/CodyncUI/Voice/VoiceSession.swift:122`）在动画开始后的同一轮里同步跑
     `phase = .recording` → `await transcriber.permission()`（其中又新建一个 `SFSpeechRecognizer`，
     `SpeechTranscriber.swift:126`）→ `transcriber.start()`：再建一个 `SFSpeechRecognizer`（`:144`）、
     `recognizer.recognitionTask(...)`（`:233`）、`AVAudioSession.setCategory/setActive(true)`、
     `AVAudioEngine`（首次 lazy 创建）、`installTap`、`engine.prepare()/start()`
     （`SpeechTranscriber.swift:404-427`）。这一串是几十毫秒量级（冷启动更久）的主 actor 同步工作。
  2. `Haptics.impact()`（`VoiceSession.swift:145`）每次现建 `UIImpactFeedbackGenerator`，从不 `prepare()`，
     而且排在音频启动之后，同一帧再叠一次唤起触感引擎的成本。
  3. `HomeSourcesView` 的根视图用 `.onChange(of: voice.phase)` 观察录音阶段（改前 `Views/HomeSourcesView.swift:129`），
     `phase = .recording` 会让整个首页 body（包含会话 `List`）重算一次——正好压在这次变形的第一帧上。
     「关闭」不碰 `voice.phase`，所以没有这一下。
- 变化（`Views/HomeSourcesView.swift`）：
  - `beginVoice()`：`withAnimation` 之后把 `voice.begin()` 推迟一帧（`Task { sleep(16ms); await voice.begin() }`，
    第 435-440 行）。先让栏的第一帧画出来，再去开麦克风/识别器。
  - 录音阶段的观察从首页根移到栏自己身上：`.background { VoicePhaseWatcher(...) }`（第 315 行），
    `VoicePhaseWatcher`（第 893 行）自己 body 里 `.onChange(of: voice.phase)`；回调
    `handleVoicePhase(_:)`（第 446 行，逻辑与原来逐条相同：`.confirming`/`.notice`/`.paused 且没听到` → 升半屏，
    `.idle` → 收 sheet）。阶段变化现在只让这个小视图重算，首页列表不再跟着刷新。
  - 动画本身一行未改：高度 76、时长/曲线（`VoiceSheetView.settle`）、上推开半屏、下拉收起、
    有文字时确认丢弃、Reduce Motion 的淡入淡出，全部保持 C0197 的样子。
- 未改动：`SpeechTranscriber.swift`、`VoiceSession.swift`、`Haptics.swift`、`VoicePill.swift`、`VoiceSheetView.swift`。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`
  （真机 destination、ui-preview 覆盖、构建号 186）**编译通过，0 error**，改动文件 0 warning；
  `xcrun devicectl device install app` 装到 iPhone 16 Pro（`com.suiyikou.codync.uipreview` 2.36.0 / 186）成功。
  按要求**不自测**：不跑测试、不截图、不用 CDP，改后的顺滑度未实测。
- 限制/待办：
  - 剩下的最大一块是 `SpeechTranscriber.start()` 里的音频/识别启动本身：`SFSpeechRecognizer` 建两次、
    `recognitionTask`、`setActive(true)`、`AVAudioEngine` 首次创建，全在主 actor 上同步执行；推迟一帧只是
    让它们不再压住动画第一帧，仍会在动画中段吃掉 2–3 帧。要彻底消除，得把这段挪出主线程（或提前预热
    引擎/识别器），那会把 `SpeechTranscriber.start` 改成 async 并牵动 `VoiceSession`/按钮回调，属于换实现方案，
    已按约定先停在这里等确认，未实施。
  - 冷启动第一次仍会比后续几次慢（识别服务/音频会话首次初始化），这一点只能在主线程外解决。
- 关联：C0197。

### C0200 · 2026-11-04 · 语音胶囊开启卡顿（方案 A）：音频会话与引擎挪到后台队列

- 原因：C0198 把录音推迟一帧后，开启前段已顺，但动画末段（右边设置/暂停钮出现那一下）仍卡。原因是
  `SpeechTranscriber.start()` 里剩下的重活仍在主 actor 上同步跑：`AVAudioSession.setCategory` +
  `setActive(true)`、`AVAudioEngine` 首次创建、`installTap`、`engine.prepare()/start()`，外加
  `permission()` 与 `start()` 各自新建一个 `SFSpeechRecognizer`。它们正好压在动画末段那一帧上。
- 变化（`Kit/Sources/CodyncUI/Voice/SpeechTranscriber.swift`）：
  - 新增 `MicStack`（私有，`@unchecked Sendable`，约 507-612 行）：一条串行队列独占音频会话 +
    `AVAudioEngine` + tap + format。`open(tap:) async -> Bool`、`retap(_:)`、`close()` 都在该队列上执行，
    引擎在同一队列里首次创建；**创建、改 tap、停止因此永远只在这一个线程上**，主线程只等结果。
  - 新增 `TapBox`（约 507 行）：把 `AVAudioNodeTapBlock` 跨线程传递时包装成 Sendable。
  - 删掉主 actor 上的 `engine` / `format` / `tapped` 三个属性与原来的 `openMic`、`installTap` 实现；
    `openMic(with:) async -> Bool` 现在只 `await mic.open(...)`（约 430 行），换 tap 走 `retap(on:)`
    （约 435 行），`closeMic()` 走 `mic.close()`（约 454 行）。
  - `SpeechTranscriber` 协议与 `OnDeviceSpeechTranscriber`：`start` 改为 `async throws`（43、144 行），
    `resume` 改为 `async -> Bool`（47、189 行）；`start()` 在 `await openMic` 之后加了 generation 校验，
    避免「打开途中被取消/暂停」时把 `isRecording` 设成 true。
  - `permission()` 建好的 `SFSpeechRecognizer` 现在留着给 `start()` 用（`recognizer(for:)`，约 145 行），
    一次开启只建一个（原来建两个）。`release()` 仍会清空，所以下次开启还是重新建一个——没有做预热（方案 B）。
- 变化（`Kit/Sources/CodyncUI/Voice/VoiceSession.swift`）：`begin()` 用 `try await transcriber.start`
  （录音启动整体异步）；`toggleMicrophone()` 改为 `async`，内部 `await transcriber.resume()`。
- 变化（`Kit/Sources/CodyncUI/Voice/VoicePill.swift`）：麦克风按钮改成 `Task { await session.toggleMicrophone() }`，
  继续录音不再阻塞按钮回调。
- 线程与顺序：会话激活/引擎启动/换 tap/停止全部在 `MicStack` 的串行队列上，FIFO 顺序保证
  「先关后开」「先开再换 tap」不会交错；tap 回调本身仍在音频线程（原样），只把电平 hop 回主线程。
- 开头的话不会丢：识别任务仍在麦克风打开之前建好（顺序未变），`engine.start()` 的墙钟时刻与改动前
  基本一致——同一份工作换到后台线程执行，且主线程不再被占用，实际只会更早而不是更晚。
- 现在还在主线程上的活：`SFSpeechRecognizer.recognitionTask(...)`（`startTask()`）、结果回调处理、
  `VoiceSession` 的状态更新与波形电平；未改动。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`
  先以 `-destination 'generic/platform=iOS'` 检编译，设备重新连上后再按真机 destination 构建，均
  **编译通过，0 error**（ui-preview 覆盖、构建号 187），改动文件 0 warning；`xcrun devicectl device install app`
  装到 iPhone 16 Pro（`com.suiyikou.codync.uipreview` 2.36.0 / 187）成功（期间设备曾 `unavailable`、
  报 `CoreDeviceError 4016`，重新连接后安装完成）。按要求**不自测**：不跑测试、不截图、不用 CDP；
  改后的顺滑度与录音是否照常均未实测。
- 限制/待办：
  - `recognitionTask(...)` 仍在主线程，属于本次未涵盖的范围（约几毫秒到十几毫秒），若末段仍能感觉到，
    下一步把它也交到 `MicStack` 队列（同样要处理 task 的创建/取消线程归属）。
  - 线程归属改动未在真机上验证录音是否照常；`MicStack.close()` 采用队列异步执行（不阻塞主线程），
    因此 `pause()` 后引擎停止与下一次 `open()` 之间靠队列 FIFO 保序，极端情况下若硬件迟迟不停，
    重新打开的等待会排在后面。
- 关联：C0198、C0197。

### C0201 · 2026-11-04 · 底部输入栏统一 48pt，会话页顶部资料按钮的头像/昵称放大

- 原因：会话页 composer 与首页搜索栏是两套尺寸（44 输入框 + 36 圆钮），比视觉上该有的小一档；会话页顶部
  资料玻璃胶囊里的头像（22）和昵称（13pt）也偏小。穗要底部统一 48、图标 24，顶部头像 24、昵称 16pt。
- 变化（`Kit/Sources/CodyncUI/GlassButton.swift`）：`ControlMetrics.Size` 新增一档 **`bar`：side 48、
  glyph 24**（`hitTarget` 自动为 48）。原有 icon 44 / compact 36 / large 64 / micro 24 全部保持原值，
  顶部导航头像与「+」仍是 44/24。枚举注释同步说明 bar 用于底部输入栏。
- 变化（`Kit/Sources/CodyncUI/Thread/Composer.swift`）：
  - `buttonSize` → `ControlMetrics.Size.bar.side`（48，原来是 compact 36），`buttonHitSize` →
    `ControlMetrics.Size.bar.hitTarget`（48，原来 44）——输入框与两侧按钮同高 48。
  - 「+」`addLabel`：`GlassGlyph(size: .compact, glyphSize: 24)` → `GlassGlyph(size: .bar)`，命中框
    `compact.hitTarget` → `bar.hitTarget`；图标取 `bar.glyph`(24)。
  - 发送/停止/打断：原来图标 14/14/20 三个数写死，统一取 `ControlMetrics.Size.bar.glyph`(24)
    （元组里的第三个元素因此删掉）。
- 变化（`Kit/Sources/CodyncUI/Thread/ThreadView.swift:156-165`）：顶部资料胶囊里的头像 22 → **24**，
  昵称 `13pt .semibold` → **`16pt .semibold`**；胶囊自身的 44 高与 14 内边距不变。
- 变化（`Views/HomeSourcesView.swift`）：底部栏改用同一个 token——搜索框 `minHeight` 44 → `bar.hitTarget`(48)
  （342 行）、收起态圆钮 44 → **`bar.side`(48)**（361-362 行）、圆钮图标 44→`bar.glyph`(24)（385-387 行）、
  搜索框宽度扣减从 44 改 48（323 行，行宽仍然「搜索框 + 12 + 圆钮」= 行宽）。左右边距 16、中间间距 12、
  上 6 / 下 28（键盘 12）全部不变，与会话页保持同一套规则。
- 未动：语音胶囊展开后的 76 高度、内容（44 行 + 上下 16）以及整个变形动画结构——圆钮收起态从 44 变 48，
  只是动画起点的 frame 数值跟着变，终点（行宽 × 76）与曲线、时长都不变。
- 文件：`Kit/Sources/CodyncUI/GlassButton.swift`、`Kit/Sources/CodyncUI/Thread/Composer.swift`、
  `Kit/Sources/CodyncUI/Thread/ThreadView.swift`、`apps/ios/Views/HomeSourcesView.swift`。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`
  （真机 destination、ui-preview 覆盖、构建号 188）**编译通过，0 error**，改动文件 0 warning；
  `xcrun devicectl device install app` 装到 iPhone 16 Pro（`com.suiyikou.codync.uipreview` 2.36.0 / 188）成功。
  按要求**不自测**：不跑测试、不截图、不用 CDP，尺寸与观感未实测。
- 限制/待办：语音胶囊**展开后**内部的设置/麦克风圆钮仍是 44（`icon`），因为胶囊内容行高就是 76-16-16=44；
  本次只按需求改了收起态与底部栏。会话页顶部胶囊宽了一点点（头像 +2、字号 +3），若在窄机型上挤压标题，
  需要再调内边距——未实测。
- 关联：C0197、C0198、C0200。

### C0199 · 2026-11-04 · 语音发送吐司改成 44pt 高，与顶部头像 / ＋ 同排居中

- 原因：语音转文字发送后的吐司（「✓ 已发送给 XXX」，以及「先设置主 Bot」那一条）原来是 46 高、距顶部
  安全区 6pt，跟顶部左边 44pt 头像按钮、右边 44pt「＋」按钮既不同高也不同排，看着发飘。
- 先确认共用范围：吐司是 CodyncUI 里的共用组件（`Toast/GlassToast.swift`，`public struct GlassToast` +
  `.glassToast(...)`），全仓库当时**只有首页在用**（`Views/HomeSourcesView.swift:128`，消息源 `:422`、`:486`）。
  按穗确认，直接改共用组件，因此以后别处再用也是 44 高 / 正胶囊。
- 变化（`Kit/Sources/CodyncUI/Toast/GlassToast.swift`）：
  - `GlassToast` 高度 `.frame(height: 46)` → **`ControlMetrics.Size.icon.side`（44）**，与顶部两个导航栏按钮
    同高；圆角原本就是 `Capsule()`（= 高度一半），未改；图标 20、字号 subheadline、玻璃、阴影、
    出现/消失动画、2 秒停留全部未动。
  - 定位基准：`.glassToast` 的 `topPadding` 默认值 10 → **0**，首页调用改为 `.glassToast($toast)`。0 表示
    「贴顶部安全区上沿」——导航栏正是从这条线开始排它那一行 44pt 按钮的，所以吐司与头像、「＋」自动
    落在同一行并垂直居中；**没有任何写死的 y 值**，灵动岛/刘海机型都跟着安全区走。
  - 横向：新增 `@State width`（`onGeometryChange` 量容器宽度）与 `maxPillWidth =
    容器宽 − 2 × (16 边距 + 44 按钮 + 8 间隙)`，套在胶囊上 `.frame(maxWidth:)`。文字仍然
    `lineLimit(1)` + `truncationMode(.tail)`，所以文字过长是省略号截断，胶囊本身宽度随文字自适应，
    左右永远压不到头像和「＋」。
- 变化（`Views/HomeSourcesView.swift:128`）：`.glassToast($toast, topPadding: 6)` → `.glassToast($toast)`，
  并在旁边注明它落在导航栏那一行。
- 未动：顶部按钮、底部语音栏、语音胶囊与变形动画、吐司的转场动画与停留时长。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Toast/GlassToast.swift`、`apps/ios/Views/HomeSourcesView.swift`。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`
  （真机 destination、ui-preview 覆盖、构建号 189）**编译通过，0 error**，改动文件 0 warning；
  `xcrun devicectl device install app` 装到 iPhone 16 Pro（`com.suiyikou.codync.uipreview` 2.36.0 / 189）成功。
  按要求**不自测**：不跑测试、不截图、不用 CDP，对齐与截断效果未实测。
- 限制/待办：吐司与导航栏按钮同排的前提是导航栏从顶部安全区上沿开始（标准 inline 工具栏），首页当前
  就是这个形态；若以后首页改成大标题或自定义导航栏，这个基准需要跟着调整。极窄机型上
  `maxPillWidth` 会很小，长文字会更早截断（这是设计要求，未实测具体宽度）。
- 关联：C0197（语音发送链路）、C0201（底部 48pt token）。

### C0202 · 2026-11-05 · 首页双指捏合进入来源切换（仿锁屏壁纸页）

- 原因：首页有三个会话来源（Coe / DS Bot / DSH 对话，由设置里的「首页来源」决定开哪几个），C0194 起首页主体
  固定显示「置顶」，来源列表一直有代码但没有入口。穗要仿 iOS 锁屏长按的壁纸切换，入口换成**双指捏合**。
  按确认的两个决定实现：① 切换态里顶部头像/「＋」与底部搜索栏/语音钮**淡出**并禁止交互；② **置顶也算一张卡片**
  （卡片 = 置顶 + 开着的来源），选定后首页主体换成那一张。
- 新增（`apps/ios/Views/HomeSourceSwitcher.swift`，XcodeGen 已重新生成工程）：
  - `HomeFace`：`.pinned` 或 `.source(HomeSource)`，带 `stored`/`init(stored:)` 与显示名（置顶 / Coe / DS Bot / DSH 对话）。
  - `SourceSwitcher`：切换态。上方来源名（`.title3.semibold`）+ 中间横向分页卡片 + 下方分页点（当前项 18×7 胶囊，
    其余 7×7 圆点）。卡片宽 = 屏宽 × `miniScale`(0.86)，高 = min(屏高 × 0.62, 卡宽 × 1.5)，间距 12，
    `contentMargins` 让首尾卡片也能居中。
  - 分页：`ScrollView(.horizontal)` + `.scrollTargetBehavior(.viewAligned)` + `.scrollPosition(id:)`，
    `onChange` 时更新居中卡片并 `Haptics.selection()`（沿用现有档位，关掉不震）。
  - `SourceCard`（`mini(_:)`）：**真实列表**（由首页传入的 `faceList`）按整屏尺寸布局后 `.scaleEffect(0.86, anchor: .topLeading)`
    缩到卡片大小，圆角 28 裁剪 + 1pt 描边 + 阴影；内容 `allowsHitTesting(false)`，只有卡片本身的点按生效。
- 变化（`Views/HomeSourcesView.swift`）：
  - 新增 `@AppStorage(HomeSourcePrefs.faceKey)`（`homeFace`）、`switcherShown` / `switcherFace` / `pinchScale` 三个状态；
    `face`（当前面，来源被关掉时回落置顶）、`faces`（= 置顶 + `enabledOrdered`）、`faceList(_:)`。
  - 首页主体从「固定置顶」改为 `faceList(face)`；搜索过滤逻辑不变。
  - 手势：列表上 `.simultaneousGesture(MagnifyGesture(minimumScaleDelta: 0.04))`（不抢单指滚动）——`onChanged`
    把 `magnification` 夹到 `[0.86, 1]` 实时缩放页面（顺带收起搜索键盘）；`onEnded` 时 `magnification < 0.93`
    吸附进入切换态，否则弹回。只有首页根页（`accounts.selection == nil && openDSHSession == nil`）且没有语音/设置
    sheet 打开时才响应。切换态里再挂一个 `MagnifyGesture`，`magnification > 1.08`（向外张开）按当前卡片退出。
  - chrome：`chromeOpacity = 切换态 ? 0 : 1 − shrink`（`shrink` 由 `pinchScale` 换算），套在底部栏与两个
    toolbar 按钮上；切换态时底部栏 `allowsHitTesting(false)`、两个菜单 `.disabled(true)`。
  - 退出：点卡片 → `pick(face)`：写入 `faceRaw`、把 `pinchScale` 置为 0.86 再动画回 1（卡片放大回整页），
    同时收起切换态。
- 手势冲突核查：单指纵向滚动不冲突（捏合两指、且用 simultaneousGesture）；行长按菜单是单指长按，不冲突；
  返回手势只存在于二级页，切换态只在根页；底部语音胶囊的上/下推在另一区域，且切换态时整条栏禁用交互；
  搜索框聚焦时捏合会先收键盘。
- 未做（按需求排除）：底部「自定义」与 + 按钮、卡片上的编辑/删除/长按菜单。
- 文件：`apps/ios/Views/HomeSourceSwitcher.swift`（新）、`apps/ios/Views/HomeSourcesView.swift`、
  `apps/ios/Views/HomeSource.swift`（`HomeSourcePrefs.faceKey`）、`apps/Codync.xcodeproj/project.pbxproj`（XcodeGen 生成）。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`
  （真机 destination、ui-preview 覆盖、构建号 190）**编译通过，0 error**，改动文件 0 warning；
  `xcrun devicectl device install app` 装到 iPhone 16 Pro（`com.suiyikou.codync.uipreview` 2.36.0 / 190）成功。
  按要求**不自测**：不跑测试、不截图、不用 CDP，捏合手感、翻页吸附、卡片缩放观感均未实测。
- 限制/待办：
  - 捏合过程中只缩放列表本身（导航栏与底部栏按比例淡出），列表在缩放时没有同步变圆角；进入切换态是一次
    交叉淡入，不是 matchedGeometry 的连续变形，手感需要真机确认。
  - 卡片里同时挂着 N 个真实 `List`（每个都 `.scrollDisabled`），数量等于开着的来源 + 置顶；来源很多时开销会上去。
  - 双指按住不动时，首根手指仍可能唤起行的长按预览（未在真机确认），若碍事可再加 `minimumScaleDelta` 门槛。
  - 切换态背景用 `Palette.background` 纯色，不是当前页的模糊快照。
- 关联：C0194（首页只显示置顶、来源列表保留）、C0199、C0201。备份 tag：`backup/before-source-pinch`（`dde7eb62`）。

### C0203 · 2026-11-05 · 捏合切换卡片细节：整屏等比、原生分页点、玻璃边框

- 原因：C0202 的卡片只裁了中间的会话列表，比例和手机屏不一样（不是等比），分页点是自绘的，卡片也不够玻璃化。
  目标：卡片 = 整个首页屏幕等比缩小，含顶部导航与底部栏；圆角按屏幕圆角等比缩；分页点换系统原生；
  边框/底用现有 `glass(in:)`（GlassSurface）；进出用同一条缩放过渡、不裁切。
- 备份：`backup/before-pinch-polish` → `37e1da1d`。
- 变化（`apps/ios/Views/HomeSourceSwitcher.swift`）：
  - **卡片等比**：`SourceSwitcher.cardScale = 0.70`（屏宽的 70%，左右各露出相邻卡片约 15%）；
    卡片高 = `卡宽 × 屏高 / 屏宽`，即严格等于屏幕宽高比；原来「卡宽 × 1.5 / 屏高 × 0.62」的裁切式尺寸删除。
  - **圆角**：新增 `SourceSwitcher.screenCorner = 55`（当前 iPhone 屏幕圆角；iOS 没有公开数值），
    卡片圆角 = `screenCorner × cardScale` ≈ **38.5pt**，`RoundedRectangle(..., style: .continuous)`。
  - **分页点**：自绘的 Capsule 圆点删除，改为 `private struct PageControl: UIViewRepresentable` 包 **`UIPageControl`**
    （`backgroundStyle = .minimal`、`allowsContinuousInteraction = false`、`isUserInteractionEnabled = false`），
    只由 `numberOfPages` / `currentPage` 驱动——系统原生指示器，翻页仍由 ScrollView 负责。
  - **玻璃化**：卡片内容外套 4pt `padding`，再 `.glass(in: RoundedRectangle(圆角 + 4, .continuous))`（项目现有
    `glass(in:)` / `GlassSurface`），形成一圈 Liquid Glass 边框；原来 1pt 的实色描边改为 0.5pt 极细线压在屏幕边上，
    阴影保留。
- 变化（`Views/HomeSourcesView.swift`）：
  - 新增 `screenSize` / `screenInsets`（`onGeometryChange` 量窗口尺寸与安全区）。
  - 新增 `miniHome(_:)`：**卡片内容 = 整个首页**——顶部安全区 + `miniNavRow`（头像 +「+」，同一批组件）+
    `faceList(face)`（真实列表）+ `miniBar`（`miniSearchField` / `miniVoiceButton`，与底部栏同尺寸同 `glass`），
    按窗口尺寸布局，整块 `allowsHitTesting(false)`。卡片里只是展示，不可点。
  - 页面缩放范围改为 `.scaleEffect(pinchScale)` 作用在**包含底部栏**的整页上（挂在 `.safeAreaInset` 之后），
    捏合时列表和底部栏一起缩；`pinchScale` 夹在 `[cardScale, 1]`。
  - `chromeOpacity` 只留给系统 toolbar 的两个按钮：导航栏不属于我们的视图树、无法缩进卡片，所以只在切换态淡出，
    卡片里用 `miniNavRow` 顶上；底部栏不再单独淡出（它跟着页面一起缩）。
  - `pick(_:)` 把 `pinchScale` 置为 `cardScale`(0.70) 再动画回 1，与卡片的缩放比例对齐，视觉上是卡片放大回整屏。
- 保持不变：4 张卡片（置顶 + 三个来源）、左右滑切换与吸附、翻页轻触感、点卡片进入、向外张开退出、
  记住上次选择（`homeFace`）。
- 文件：`apps/ios/Views/HomeSourceSwitcher.swift`、`apps/ios/Views/HomeSourcesView.swift`。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`
  （真机 destination、ui-preview 覆盖、构建号 191）**编译通过，0 error**，改动文件 0 warning；
  `xcrun devicectl device install app` 装到 iPhone 16 Pro（`com.suiyikou.codync.uipreview` 2.36.0 / 191）成功。
  按要求**不自测**：不跑测试、不截图、不用 CDP，卡片等比观感、原生分页点样式、玻璃边框与过渡均未实测。
- 限制/待办：
  - `screenCorner = 55` 是按当前 iPhone 屏幕圆角取的常数（iOS 无公开 API），换机型若要严格等比需要另测数值。
  - 系统 toolbar 的两个按钮只能在切换态淡出，卡片里的导航行是 `miniNavRow` 复刻（同一批组件、同位置同尺寸），
    不是把系统导航栏缩进卡片。
  - 卡片里仍是 N 个真实 `List`（每个 `.scrollDisabled`），来源多时开销随之增加；卡片背景为纯色 `Palette.background`。
  - 捏合过程中页面整体缩放，圆角不变形；圆角只在卡片态呈现（`clipShape` 在卡片上）。
- 关联：C0202、C0199、C0201。

### C0204 · 2026-11-05 · 捏合卡片显示 bug：灰条、内容偏移、双层边框、露边过窄

- 原因（真机截图）：四个现象都源自「卡片内容与卡片的几何来自两处不同的测量」，加上玻璃边框太厚。
  1. 卡片顶部/底部灰带：卡片的页面按 `screenSize/screenInsets`（在首页 `navigationStack` 上量）布局，
     而卡片尺寸按切换态自己的 `GeometryReader`（`.ignoresSafeArea()` 下的整屏）计算；两者如果对不上，
     缩放后的页面填不满卡片的矩形，露出的就是卡片的玻璃底（深色底上的 Liquid Glass 呈灰），
     于是状态栏区和 home 指示条区各出现一条灰带。
  2. 内容整体下偏：卡片里用 `Color.clear.frame(height: screenInsets.top)` 顶出状态栏高度，但量到的
     `safeAreaInsets` 与真实窗口安全区不一致（多算了导航栏那一行），头像/「+」被推低、底部栏位置随之错。
  3. 双层边框：卡片是 `padding(4)` + `.glass(...)`（4pt 玻璃带）+ 内侧 0.5pt 实色描边，读起来是
     「粗灰框 + 里面一条边」两层。
  4. 右邻卡片露太少且错位：卡宽 = 屏宽 × 0.70 且卡片间距 12，实际可见的邻卡只有约 48pt（先被 16pt 页边距
     吃掉），加上几何不一致导致邻卡内容和卡片框没对齐，看起来只剩一列头像；首尾卡片的 `contentMargins`
     也是按另一处量到的宽度算的，左右不对称。
- 变化（`apps/ios/Views/HomeSourceSwitcher.swift`）：
  - **一处几何来源**：新增 `@State window` / `insets`，`onAppear` 用 `windowMetrics()` 直接读 key window 的
    `bounds.size` 与 `safeAreaInsets`（只读窗口几何，不新建样式）；分页器、卡片尺寸、`contentMargins`、
    卡片页面布局**全部**用这同一份数值。`card` 闭包改为 `(HomeFace, CGSize, EdgeInsets) -> AnyView`。
  - `cardScale` 0.70 → **0.66**，卡片间距 12 → **10**：左右露边从约 48pt 提到约 **58pt** 且严格对称
    （`contentMargins` 按同一窗口宽度算），邻卡能看出是完整的一张缩小首页。
  - 玻璃边：`rim` 4 → **1.5**，去掉内侧 0.5pt 实色描边，只留 `.glass(in: RoundedRectangle(圆角 + 1.5))` 一层细边
    （仍是项目现有 `glass(in:)` / `GlassSurface`）。
- 变化（`Views/HomeSourcesView.swift`）：
  - 删掉 `screenSize` / `screenInsets` 两个状态与对应的 `onGeometryChange`（不再重复测量）。
  - `miniHome(_:window:insets:)`：顶部状态栏条用 **`Palette.background`**（页面本来的底色，不再用透明占位），
    底部栏之下补一条同样颜色的 **28pt** 条（与真实页面「栏底距屏幕底 28」一致），页面 `VStack` 的高度
    正好等于窗口高度，整块 `background(Palette.background)`——卡片从上到下都是首页背景色，安全区不再单独上色。
  - 卡片页面 = 窗口尺寸的完整首页（`insets.top` + 导航行 + 列表 + 底栏 + 28），按 `cardWidth / window.width`
    等比缩放，因此缩放后的宽高与卡片矩形**严格相等**，不再有填空/裁切。
- 保持不变：4 张卡片（置顶 + 三个来源）、捏合进入、左右滑与吸附、翻页轻触感、点卡片进入、向外张开退出、
  记住上次选择、`UIPageControl` 原生分页点。
- 文件：`apps/ios/Views/HomeSourceSwitcher.swift`、`apps/ios/Views/HomeSourcesView.swift`。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`
  （真机 destination、ui-preview 覆盖、构建号 192）**编译通过，0 error**，改动文件 0 warning；
  `xcrun devicectl device install app` 装到 iPhone 16 Pro（`com.suiyikou.codync.uipreview` 2.36.0 / 192）成功。
  按要求**不自测**：不跑测试、不截图、不用 CDP，四个现象是否消失未在真机确认。
- 限制/待办：窗口几何改为读 key window，多窗口/外接屏场景未考虑（本 App 单窗口）；`screenCorner = 55` 仍是
  当前 iPhone 屏幕圆角的常数；卡片里依旧是 N 个真实 `List`。
- 关联：C0203、C0202。

### C0205 · 2026-11-05 · 捏合卡片：放大不再「闪一下」，卡片背景一色到底

- 原因（真机录屏）：
  1. **放大时闪一下**：`pick(_:)` 一开始就把 `switcherShown = false`，切换态被撤掉、真实的系统导航栏和底部栏
     立刻回到全屏位置，而中间页面还在用 `pinchScale` 从 0.66 放到 1 —— 两者不同步，第一帧就闪。
     缩小方向没问题，因为缩小时切换态是**新盖上去**的，页面和 chrome 一起缩在卡片里。
  2. **两截底色**：卡片里的列表用的是真实 `List`，`List` 自带一层背景（`scrollContentBackground(.hidden)`
     在卡片这种被缩放、脱离列表容器的上下文里没有完全生效），于是列表区域露出一块深灰底，且只覆盖到列表
     自己的框、到不了底部搜索栏，形成「上面灰下面黑」。
- 变化（`apps/ios/Views/HomeSourceSwitcher.swift`）：
  - 新增 `growing` / `growProgress` 两个状态与 `growingCard(_:window:cardWidth:cardHeight:)`：点卡片（或双指张开）
    时**不再立刻关闭切换态**，而是让这张卡片自己从「卡宽 × 卡高」长到「窗口宽 × 窗口高」——同一个 `mini` 视图、
    同一份几何，圆角随比例从屏幕圆角×0.66 变回屏幕圆角，被点的侧卡会一边长大一边滑到中间（`slide`）。
    分页器、来源名、分页点用 `.opacity(growing == nil ? 1 : 0)` 同步淡出。
  - `pick(_:)`（切换态内）：`withAnimation(.spring(0.36, 0.9))` 把 `growProgress` 推到 1，约 380ms 后才调用
    `commit(face)` 把控制权交回首页。
- 变化（`Views/HomeSourcesView.swift`）：
  - `pick(_:)`（首页侧）：不再做任何缩放动画，只把 `pinchScale` 置 1、`homeFace` 写入，并用 0.12s 的
    `easeOut` 让切换态淡出。因为卡片此刻已经长到整屏、内容与真实页面同尺寸同位置，交接时导航栏与底部栏
    「换回来」看不出跳变。
  - 卡片里的列表换成 `miniList(_:)`：不再挂 `List`，直接用 `VStack` 渲染同一批 `entryRow`（真实行视图），
    背景只有卡片页面自己的 `Palette.background`，从上到下一个颜色；因为没有 List，`rosterRow()` 的
    `listRowInsets` 会失效，补了 `miniRowInsets()`（左右各 16）保持与全屏一致；空态与 DSH 提示行同样处理。
  - 新增 `entries(for:)`：按面取行数据（置顶 / 某来源 / DSH）。
- 保持不变：4 张卡片、捏合进入、左右滑与吸附、翻页轻触感、点卡片进入、向外张开退出、记住上次选择、
  `UIPageControl` 分页点、卡片比例 0.66、间距 10、1.5pt 玻璃边。
- 文件：`apps/ios/Views/HomeSourceSwitcher.swift`、`apps/ios/Views/HomeSourcesView.swift`。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`
  （真机 destination、ui-preview 覆盖、构建号 193）**编译通过，0 error**，改动文件 0 warning；
  `xcrun devicectl device install app` 装到 iPhone 16 Pro（`com.suiyikou.codync.uipreview` 2.36.0 / 193）成功。
  按要求**不自测**：不跑测试、不截图、不用 CDP，放大过渡与背景色是否一致未在真机确认。
- 限制/待办：卡片里的行不再是 `List`，因此卡片内的滚动、下拉刷新、行高自动测量都不生效（卡片本来也不需要）；
  卡片长到整屏的最后几帧仍带 1.5pt 玻璃边，随即被交接盖掉。
- 关联：C0204、C0203、C0202。

### C0206 · 2026-11-05 · 捏合卡片：顶部按钮同帧交接、卡片按真实安全区排版

- 原因（真机录屏）：
  1. **缩小时顶部按钮不跟着缩**：头像和「+」是系统 `ToolbarItem`，缩放只作用在页面内容上，所以它们待在全屏位置被淡出，
     同时卡片顶部淡入一份复刻——看起来像消失再出现。底部栏是我方视图、在 `safeAreaInset` 里，所以能正常跟着缩。
  2. **卡片内间距偏紧**：卡片页面此前按 `window.safeAreaInsets` 排版，那个读数不是真实安全区（状态栏高度拿错），
     顶部条与导航行的相对位置不对，整体显得比全屏紧。
  3. **放大结束跳一下**：交接时真实页面（真实安全区）与卡片（错误的假设值）不是同一套坐标，换回来的那一帧
     头像上跳、列表下移、底栏也跟着动。
- 决策：按穗确认**保留系统工具栏**（不改成自绘），用运行时测量 + 复刻做同帧交接，接受交接帧玻璃的轻微变化。
- 变化（`Views/HomeSourcesView.swift`）：
  - 新增 `accountFrame` / `plusFrame` / `pageOrigin` 三个测量值：
    - 两个 `ToolbarItem` 内部各挂 `.onGeometryChange { $0.frame(in: .global) }`，量出**系统实际摆放**的矩形；
    - 页面根内容挂同样的测量拿到自身 global 原点（切换态/捏合中不更新）。
  - 新增 `navReplica`：把 `AccountSwitcherButton(avatarSize: 36)` 和 `RemixImage("add-line", size: 24)` 这两份**同一批视图**
    按 `系统矩形 − 页面原点` 的偏移摆进页面，作为 `.overlay(alignment: .topLeading)` 挂在被缩放的内容上——于是它
    跟列表、底部栏一起被 `scaleEffect` 缩小，并且在缩放比为 1 时与系统按钮**逐像素重合**。
  - `chromeOpacity` 从「仅切换态」改为 **`switcherShown || pinchScale < 0.999 ? 0 : 1`**：捏合的第一帧系统按钮就隐藏、
    复刻（`1 - chromeOpacity`）同帧出现，两者位置重合，肉眼看不出切换；放大结束时反过来。
  - 卡片页面 `miniHome(_:)` 改为**用测量值排版**，不再假设安全区：状态栏条高 = `accountFrame.minY`（系统按钮的上沿），
    导航行高 = `max(accountFrame.height, plusFrame.height)`，行内两枚按钮直接摆在 `accountFrame.minX` 与
    `plusFrame.minX`（「+」的 y 取它与头像的实测差值），列表、底部栏、底部 28pt 依次与全屏一致。
    卡片仍按窗口尺寸排版后整体 `scaleEffect` 到卡片大小（见 `HomeSourceSwitcher.mini`）。
- 变化（`Views/HomeSourceSwitcher.swift`）：`card` 闭包回到 `(HomeFace) -> AnyView`，删除 `insets` 状态与
  `windowMetrics()` 里的安全区读取，只保留 `windowSize()` 给卡片矩形用。
- 保持不变：4 张卡片、捏合进入、左右滑与吸附、翻页轻触感、点卡片进入、向外张开退出、记住上次选择、
  `UIPageControl` 分页点、0.66 卡片比例 / 10 间距 / 1.5pt 玻璃边、卡片放大路径。
- 文件：`apps/ios/Views/HomeSourcesView.swift`、`apps/ios/Views/HomeSourceSwitcher.swift`。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`
  （真机 destination、ui-preview 覆盖、构建号 194）**编译通过，0 error**，改动文件 0 warning；
  `xcrun devicectl device install app` 装到 iPhone 16 Pro（`com.suiyikou.codync.uipreview` 2.36.0 / 194）成功。
  按要求**不自测**：不跑测试、不截图、不用 CDP，交接帧与卡片排版是否逐像素一致未在真机确认。
- 限制/待办：
  - 复刻用的是同一批视图但**没有系统工具栏的玻璃胶囊**（那是系统渲染的），交接那一帧按钮底会有轻微变化——已确认接受。
  - 依赖 `.frame(in: .global)` 的测量：测量在切换态/捏合期间冻结，若系统在运行中改变工具栏布局（旋转、动态字号）
    需要重新展开一次首页才会更新。
  - 卡片尾部仍带 1.5pt 玻璃边，放大到整屏的最后几帧可见，随即被交接盖掉。
- 关联：C0205、C0204、C0203、C0202。备份 tag：`backup/before-pinch-sync`（`060d7c25`）。

### C0207 · 2026-11-05 · 消息正文换成 MarkdownUI：表格可横滚、代码块高亮 + 复制

- 原因：消息正文一直是自研的 `MarkdownBlocks` 解析 + 手写视图，表格没有明显表头、代码块无高亮/无复制、
  公式和复杂 GFM 都不支持。盘点（C0206 前那份只读报告）里 dsh-mobile 的 Markdown 这套是最容易变现的一块。
- 依赖：新增 **MarkdownUI 官方正式版**（`https://github.com/gonzalezreal/swift-markdown-ui`，`from: "2.0.0"`，
  解析结果 **2.4.1**），连带 `swift-cmark 0.9.0`、`NetworkImage 6.0.1`；**没有**用 dsh-mobile 里那份改过的 fork，
  也**没有**引入 SwiftMath（不做公式）。
- 变化：
  - `Kit/Sources/CodyncUI/Thread/MarkdownText.swift`：正文改为 `Markdown(source).markdownTheme(.codync(...))`，
    保留 `Equatable`（只比 `source`，`nonisolated`）、保留 `.textSelection(.enabled)`；正文字号与代码字号改用
    `@ScaledMetric`（body 17 / footnote 13），标题与代码块都从它们派生，继续跟随动态字体。
  - 新增 `Kit/Sources/CodyncUI/Thread/MarkdownTheme.swift`：`Theme.codync(body:code:)` 用**现有 token** 定制
    —— 正文/标题字号与 `Palette.text` 取自原渲染器同一套（h1 ≈ 20 粗、h2 = 正文 semibold、h3 ≈ 15 粗）；
    行内代码 monospaced 0.9em + `Palette.text.opacity(0.08)` 底（与原实现同值）；链接保持单色 + 下划线；
    引用 `Palette.secondary` + 左侧 3pt `Palette.border`；分隔线 1pt `Palette.border`；无序列表统一 `.disc`。
    - 表格：`ScrollView(.horizontal)` + 内容 `fixedSize`，表头行铺 `Palette.surface`、行间 1pt `Palette.border` 细线，
      单元格内边距 12/7、表头 semibold。
    - 代码块：自定义 `MarkdownCodeBlock`——横向滚动不换行、`Palette.codeBackground` + 圆角 8、右上角复制按钮
      （`ControlMetrics.Size.micro` 24 + 14pt 图标，`PressScale` 反馈，复制后 `Palette.added` 勾 1.2 秒）。
  - 新增 `Kit/Sources/CodyncUI/Thread/CodeHighlighter.swift`：无依赖的小型高亮器，按语言（swift/json/js/ts/python/
    shell/sql/go/rust/yaml）着色注释、字符串、数字、关键字；**颜色全部映射到现有 token**（关键字 `Palette.text`
    semibold、字符串 `Palette.added`、数字 `Palette.warning`、注释 `Palette.tertiary`）；未知语言保持纯色。
    流式半截文本安全：未闭合的字符串/注释只会把剩余部分着色，不崩不闪。
  - Swift 6 严格并发：`BlockStyle` 的 body 是非 isolated 的逃逸闭包，而 SwiftUI 只在主 actor 渲染时调用它，
    因此用 `@preconcurrency import MarkdownUI` + `rendered { }`（`MainActor.assumeIsolated` + `@unchecked Sendable`
    的 `AnyView` 盒子）把「这一定在主线程渲染」告诉类型系统，没有用 `nonisolated(unsafe)` 硬关检查。
- 未动：气泡、列表行、输入框、顶部栏、`DSHConversationView`/`ThreadView` 的结构；Coe 与 DSH 共用同一份
  `MarkdownText`，所以两边自动一起换。
- 文件：`apps/ios/Kit/Package.swift`、`apps/Codync.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`、
  `Kit/Sources/CodyncUI/Thread/MarkdownText.swift`、`…/Thread/MarkdownTheme.swift`（新）、
  `…/Thread/CodeHighlighter.swift`（新）。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`
  （真机 destination、ui-preview 覆盖、构建号 195）**编译通过，0 error**，新增/改动文件 0 warning；
  `xcrun devicectl device install app` 装到 iPhone 16 Pro（`com.suiyikou.codync.uipreview` 2.36.0 / 195）成功。
  按要求**不自测**：不写测试、不截图、不用 CDP；表格/代码块/流式表现均未在真机确认。
- 限制/待办（本次**没做**、需要你定的）：
  - `MarkdownBlocks`（自研块解析）现在只有测试还在用，正文已不经过它；建议单独一单删掉解析器与它的测试。
  - **图片**：MarkdownUI 默认会渲染 `![](...)`（走 NetworkImage 拉远端图），而旧渲染器把图片语法当纯文本显示。
    这是一处未点名的行为变化；若要保持旧行为，需要把 `Theme.image` 置空。
  - 语法高亮**没有专用 token**：用的是语义色（added/warning/tertiary/text）映射；若要真正的代码配色，需要新增
    `Palette.syntax*` 一组 token。
  - 项目里没有**圆角 token**：代码块沿用旧渲染器的 8pt，表格不加圆角。
  - `Copy code` / `Copied` 两条 a11y 文案没有 zh-Hans 词条（回退英文）；块间距改用 MarkdownUI 默认，
    与旧实现的 VStack spacing 8 不完全一致。
- 关联：C0206（只读盘点报告 `/tmp/codync-audit/dsh-mobile-inventory.md`）。备份 tag：`backup/before-markdown-c0207`。

### C0208 · 2026-11-05 · 会话页搬迁第 1 步：共用行/输入框骨架 + 流式只重绘变化行，DSH 页先接上

- 背景：穗要求把 dsh-mobile 的「输入框 / 消息气泡与行 / 时间线 / 顶部栏与页骨架」四块搬过来，Coe 与 DSH 共用。
  按确认的三条做：**保留 SwiftUI 列表**（不引入 ChatLayout/UIKit 视口）、**只搬骨架**（旧 App 的折叠胶囊、队列 dock、
  附件菜单、语音、slash/@ 弹层、引用、长按菜单、重试、跳到底部等一律不带）、**新建共用行模型 + 适配器**。
  为避免一次性改坏 Coe，按允许的拆单方式分两次：本条 C0208 落共用件与 DSH 页，C0209 再把 Coe 的 `ThreadView` 接上。
- 对照表（已落地部分）：
  | dsh-mobile | Sully Coe | 方式 |
  |---|---|---|
  | `Core/ConversationTimeline.swift` 的「只重绘变化行」思路 | `Thread/ConversationList.swift`：`ConversationRow` 新增 `revision`，列表只对 revision 变化的行 `reconfigureItems` | **改着搬**（我们的列表已经是 UIKit collection，缺的正是这一层） |
  | `Views/ConversationView.swift:1077-1760` 的 composer 骨架 | 新增 `Thread/ConversationComposer.swift`（48 高输入框 + 48×48 按钮 + 24 图标，`ControlMetrics.bar` / `GlassButton` / `glass(in:)`） | **改着搬**（尺寸/字体/玻璃全换 token，功能只留文字 + 发送） |
  | `Views/ConversationView.swift` 顶部资料胶囊 | `Views/DSHConversationView.swift` 的 `profile`（24 图标 + 16pt semibold 名称 + 玻璃胶囊，标准 `ToolbarItem(.principal)`） | **改着搬**（不搬旧 App 的模糊/导航栏补丁，顶部仍用系统 `.scrollEdgeEffectStyle(.soft, for: .top)`） |
  | 行/气泡 | DSH 页继续用既有 `ChatTranscriptView` 的行（`ChatEntryRow`：用户右侧气泡、助手 Markdown、时间分隔），并接上 revision | **沿用 + 接 revision**；Coe 的 `ChatRows` 换行放 C0209 |
- 变化：
  - `Kit/Sources/CodyncUI/Thread/ConversationList.swift`：`ConversationRow` 加 `revision`（默认 0）；协调器记 `revisions[id]`，
    只把 revision 变了的行放进 `reconfigureItems`，其余行不再每帧重配 —— 这是「流式输出不整页重算」在我们的
    UIKit 列表里的落点（原来每帧对**所有**可见行 `reconfigureItems`）。
  - `Kit/Sources/CodyncUI/Thread/ChatTranscript.swift`：行 revision = `text.hashValue &* 31 &+ entry.rev`，流式增长的字只让
    自己那一行重绘。
  - 新增 `Kit/Sources/CodyncUI/Thread/ConversationComposer.swift`：`public struct ConversationComposer`，输入框 `bar.hitTarget`
    (48) 高 + 圆角 24 玻璃，右侧发送 `GlassButton(size: .bar)`（不可发送时用 `Palette.accentDim`），可选左侧按钮
    `leading`（Coe 的附件入口留给 C0209）；`.safeAreaInset(edge: .bottom)` 挂载，键盘弹起跟着走；行内边距 16 / 上 6 / 下 12。
  - `Views/DSHConversationView.swift`：删掉自带的 `TextField` + `Image(systemName:)` 组合，改用 `ConversationComposer`；
    顶部加 `profile` 玻璃胶囊（DSH 会话没有资料页，只展示）；`navigationTitle` 改空 + inline，标题挪到 principal。
- 未做（C0209）：Coe 的 `ThreadView` 换成同一套行与 `ConversationComposer`；`ChatRows`/旧 `Composer` 的清理；
  附件/语音/命令/引用/长按菜单是否回到新输入框与行上（按本轮答复：暂不带）。
- 未接上的数据：DSH 侧 `jsonTool` / `toolResult` / `status` / `context` / `system` 这几类旧行在本项目没有对应数据；
  DSH 会话也没有"资料页"可点，顶部胶囊只展示。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Thread/ConversationList.swift`、`…/Thread/ChatTranscript.swift`、
  `…/Thread/ConversationComposer.swift`（新）、`apps/ios/Views/DSHConversationView.swift`。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`（真机 destination、
  ui-preview 覆盖、构建号 196）**编译通过，0 error**，改动文件 0 warning；`xcrun devicectl device install app`
  装到 iPhone 16 Pro（`com.suiyikou.codync.uipreview` 2.36.0 / 196）成功。按要求**不自测**。
- 关联：C0207（Markdown）、备份 tag `backup/before-chat-port-c0208`（`99a6937b`）、盘点报告 `/tmp/codync-audit/dsh-mobile-inventory.md`。

### C0209 · 2026-11-05 · 会话页搬迁第 2 步：Coe 的 ThreadView 接上共用输入框，流式只重绘变化行

- 背景：C0208 落下共用件与 DSH 页；本条把 Coe 的 `ThreadView` 接上同一套输入框形态，并保留 Coe 现有的全部能力。
  dsh-mobile 旧的 composer 里没有、我们也没有的东西（消息队列、滚动折叠胶囊）一律不新增。
- 能力对照表（原能力 → 现在挂在哪）：
  | 原能力（`Composer.swift`） | 现在 | 状态 |
  |---|---|---|
  | 「+」菜单（照片或视频 / 拍照 / 选择文件） | `ConversationComposer(leading:)` 槽位，`DropdownMenu` 原样 | 挂上 |
  | 照片选择 / 文件导入 / 拖拽文件 / 相机 | 仍挂在 `Composer.field` 的修饰链（`photosPicker`/`fileImporter`/`dropDestination`/`capturePhoto`） | 保留 |
  | 附件 chips、附件预览与移除 | 移到输入框上方的 `accessoryBar` | 保留（从卡片内改为上方） |
  | 引用回复（`quoteBar` + 取消引用） | 同一 `accessoryBar`（在 chips 之上） | 保留 |
  | 发送 / 停止 / 打断（通话中） | `ConversationComposer(trailing:)` 槽位，`trailingButton` 原样 | 挂上 |
  | 输入框（`ComposerText`：selection + IME 修复） | 作为 `field:` 槽位传入，**没有换成普通 Binding**，IME 行为不变 | 保留 |
  | slash 命令列表（`CommandList`）、@ 提及（`SuggestionChip`） | 仍在 `Composer.body` 的 VStack 里（输入框上方） | 保留 |
  | 键盘避让（收起 28 / 弹起 12、`ignoresSafeArea`） | `ConversationComposer(bottomPadding:)` + 外层 `ignoresSafeArea` | 保留 |
  | 消息长按菜单（复制、重发、钉住、编辑、删除、分组…） | 未动，仍在 `ChatRows` 的 `contextActions` | 保留 |
  | 语音入口 | **原本就没有**（Coe 的 composer 从来没有麦克风按钮；语音在本 App 是首页底部胶囊） | 无处可挂，需要确认是否新增 |
- 变化：
  - `Kit/Sources/CodyncUI/Thread/ConversationComposer.swift`：新增**槽位形态**初始化
    `init(accessory:leading:field:trailing:bottomPadding:)`；行几何（48 高、16 边距、12 间距、上 6）仍由组件给；
    DSH 继续用简式初始化，外观不变。
  - `Kit/Sources/CodyncUI/Thread/Composer.swift`：`field` 从「HStack（+ 号｜圆角卡片里塞引用/chips/输入框｜发送）」改为
    `ConversationComposer(accessory:leading:field:trailing:)`；引用与附件 chips 提升到输入框上方；输入框自身承担 48pt 高、
    14pt 内边距与 24 圆角玻璃；`ComposerText`（selection/IME）原样保留。
  - `Kit/Sources/CodyncUI/Thread/ThreadView.swift`：消息行与「working」行开始带 `revision`（文本 hash、`entry.rev`、`updatedAt`、
    步骤数），配合 C0208 的列表改动，**流式输出只重绘变化的那一行**。
- 未做 / 需要确认：
  - **语音入口不存在**：Coe 的输入框历史上就没有麦克风按钮，本条没有新增（新增=新功能）。
  - 气泡与消息行：Coe 的 `ChatRows` 本来就用 `Palette.bubbleUser/bubbleAgent` + 18 圆角 + 16 内边距，与 C0208 的 DSH 行同构，
    因此没有拆掉重写 `ChatRows`（拆了只会丢能力）；两条路径的差异只在输入框与 revision。
  - 引用与 chips 从输入框内部移到输入框上方（新布局的统一形态），这是可见的位置变化。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Thread/ConversationComposer.swift`、`…/Thread/Composer.swift`、`…/Thread/ThreadView.swift`。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`（真机 destination、
  ui-preview 覆盖、构建号 197）**编译通过，0 error**，改动文件 0 warning；`xcrun devicectl device install app`
  装到 iPhone 16 Pro（`com.suiyikou.codync.uipreview` 2.36.0 / 197）成功。按要求**不自测**。
- 关联：C0208（共用件）、C0207（Markdown）、备份 tag `backup/before-chat-port-c0209`（`2fb92685`）。

### C0210 · 2026-11-05 · 会话页只留一行扫光状态行，步骤行全部不显示

- 原因：跑到一半时消息列表底部会堆出「思考了 xx 秒」「运行了 x 个命令」这类步骤行，还能展开；
  穗要求只留一行状态（bot 头像 + 一句会扫光的短标题），步骤行既不显示也不留展开入口，运行结束即消失。
- 类型对照表（数据来自两页现有的行数据，不新增取数）：
  | 数据源 | 值 | 状态行短标题 |
  |---|---|---|
  | Coe `Entry.kind` | `thought` | 在想 |
  | Coe `Entry.kind == "tool"` + `toolKind` | `think` | 在想 |
  | 同上 | `execute` | 在跑命令 |
  | 同上 | `read` | 在看文件 |
  | 同上 | `edit` / `move` / `delete` | 在改代码 |
  | 同上 | `search` / `fetch` / 其他 / nil | 在处理 |
  | Coe `Entry.kind` | `plan` | 在处理 |
  | Coe `Entry.kind` | `agent`（含非 final 的叙述） | 不映射到状态行——那是 bot 说的话，仍作为消息显示 |
  | DSH 运行中的步骤 | **没有实时数据**（`DSHGateway` 只在完成的消息里带 `tools`，运行中只有 `isStreaming`） | 一律「在处理」 |
  | DSH 的 `DSHSummary`（思考了 X 秒 · 运行了 X 个命令） | 有，但整行不再显示 | — |
- 变化：
  - 新增 `Kit/Sources/CodyncUI/Thread/ConversationStatusLine.swift`：`ConversationStatusLine`（头像 24 正圆 + footnote 标题、
    `Palette.secondary`、固定 24 高 + 上下 6 / 左右 16，`ShimmeringText` 的 1.6s 扫光、Reduce Motion 时静止），
    以及 `WorkingPhrase`（类型 → 中文短语的固定映射，与 `isStepOnly`）。
  - `Thread/ChatTranscript.swift`：DSH 的折叠摘要行（`TurnSummaryRow`）不再加入列表（数据没删，只是不画，也没有展开入口）；
    运行中原来的三点 typing 行换成 `ConversationStatusLine`（DSH 无 bot，用 `chat-ai-line` 的 24pt 圆脸）。
  - `Thread/ThreadView.swift`：Coe 的 transcript 过滤掉 `thought`/`tool`/`plan` 三类只属于步骤的条目；
    底部原来可展开的 `WorkingIndicator` 换成一行 `ConversationStatusLine`，标题由当前步骤类型映射。
  - `Thread/ThinkingStatus.swift`：`ShimmeringText` 由 private 改为模块内可见并支持传入字体（状态行用 footnote 复用同一段扫光）。
- 未做 / 需要你定：
  - DSH 的细分短语（在想 / 在跑命令 / 在看文件 / 在改代码）**拿不到实时类型**，目前一律「在处理」。要细分必须让 `DSHGateway`
    把运行中的当前 step 暴露出来（新增取数，未做）。
  - `WorkingIndicator` / `WorkingSteps` / `ThinkingStatusRow` / `TurnSummaryRow` 现在没有任何入口调用（展开入口随之消失），
    属于死代码；建议单独一单清理，本条没有删。
  - 状态行作为列表里的一行出现/消失，所以它下面**不会有输入框跳动**（输入框是 safeAreaInset，独立于列表），
    但列表内容会随行的增删整体位移一次；淡入淡出用 `.transition(.opacity)` + 列表自身动画。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Thread/ConversationStatusLine.swift`（新）、`…/Thread/ChatTranscript.swift`、
  `…/Thread/ThreadView.swift`、`…/Thread/ThinkingStatus.swift`。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`（真机 destination、
  ui-preview 覆盖、构建号 198）**编译通过，0 error**，改动文件 0 warning；`xcrun devicectl device install app`
  装到 iPhone 16 Pro（`com.suiyikou.codync.uipreview` 2.36.0 / 198）成功。按要求**不自测**。
- 关联：C0208/C0209（会话页搬迁）、备份 tag `backup/before-status-line-c0210`（`191d5fbf`）。

### C0211 · 2026-11-05 · 共用「头像 + 来源点」：Coe 无点 / DSHC 蓝点 / DSHB 橙点

- 原因：会话行的来源一直靠头像角上的**来源徽章**（dsBot 绿、dsh 橙、coe 蓝）表示，颜色与新要求的点不一致；
  DSH 会话用的是临时占位图标（`sparkles` 方块 / C0210 的 `chat-ai-line` 圆脸），也没有"每个来源一张脸"的概念。
- 拍板后落地的四条决定：① 新增两个 Palette 来源色 token；② **来源徽章全部去掉，只留点**；③ 设置入口用方案 A
  （Settings →「首页来源」下面一行「来源外观」→ 一个页面管两个来源）；④ 允许 `DSHGateway` 记录每个会话的首条用户消息。
- 变化：
  - `Kit/Sources/CodyncKit/Design/Theme.swift`：`Palette` 新增 `sourceBlue`（浅色 0x3D6DF2 / 深色 0x4C7DFF）与
    `sourceOrange`（浅色 0xD97A12 / 深色 0xF0A030）两个 token。
  - 新增 `Kit/Sources/CodyncUI/Bots/SourceAvatar.swift`：`SourceKind`（coe/dsBot/dsh，各自 `dot` 颜色与
    `dotSize(beside:)`——24pt 脸旁 6pt、列表 48pt 脸旁 8pt）、`SourceAppearance`（每来源的 shape/color 本地键与默认值，
    复用 `AvatarPalette`）、`SourceAvatar`（`CharacterAvatar(shape:color:)` + 右下角 `SourceDot`）、`SourceDot`
    （8/6pt 圆点，`Palette.background` 1.5pt 描边）。
  - `Kit/Sources/CodyncKit/Design/CharacterAvatar.swift`：`AvatarWithStatus` 增加可选 `sourceDot: Color?`；
    有点时把领队星标从右下挪到右上，避免与点重叠。
  - `Kit/Sources/CodyncUI/Bots/BotRow.swift`：新增 `source: SourceKind`（默认 `.coe`），把 `source.dot` 传给头像。
  - `apps/ios/Views/HomeSource.swift`：删除 `badge` / `badgeColor` / `HomeBadge`，改为 `kind: SourceKind`。
  - `apps/ios/Views/HomeSourcesView.swift`：会话行去掉 `SourceBadge` 叠加层、`BotRow` 传 `source:`；`DSHSessionRow`
    的占位图标换成 `SourceAvatar(.dsh, size: 48)`，`SourceBadge` 与 `sourceBadge` 参数删除，行标题改由
    `gateway.displayTitle(for:)` 传入。
  - `Kit/Sources/CodyncUI/Thread/ThreadView.swift`：会话页顶部胶囊的头像改用 `AvatarWithStatus(size: 24)`（Coe 无点）。
  - `apps/ios/Views/DSHConversationView.swift`：顶部胶囊头像 → `SourceAvatar(.dsh, size: 24)`；标题 → `displayTitle(for:)`。
  - `Kit/Sources/CodyncUI/Thread/ChatTranscript.swift`：C0210 的临时 `chat-ai-line` 圆脸 → `SourceAvatar(.dsh, size: 24)`（点 6pt）。
  - `apps/ios/DSHKit/Sources/DSHKit/DSHGateway.swift`：新增 `firstUserMessages`（每个会话首条用户消息，事件与历史两条路径都记录）
    与 `displayTitle(for:)`——会话自己的标题优先，没有则取首条用户消息前 16 字，再没有显示「未命名会话」。
  - 新增 `apps/ios/Views/SourceAppearanceView.swift`：「来源外观」页，两组（DSH 编程 / DS Bot），每组 `AvatarPicker`
    （形状 + 颜色，复用现有色板）并带预览；`AccountRoute` 加 `.sourceAppearance`，Settings 里「首页来源」组下加一行入口。
  - `Kit/Sources/CodyncUI/Bots/AvatarPicker.swift`：改为 `public`（供 app target 的来源外观页复用）。
  - `apps/Codync.xcodeproj/project.pbxproj`：XcodeGen 重新生成（新增 app target 文件）。
- 未做 / 需要你注意：
  - 来源点与"未读/需要你"小点的位置冲突：有点时点占右下角、领队星标改到右上；未读/需要你仍在右下一侧（多数行不显示）。
  - DSH 会话名只在**打开过该会话**（或收到过它的用户消息）之后才知道；纯列表、从未打开且网关没给标题的会话显示「未命名会话」。
  - 头像与颜色存在 `UserDefaults`（`sourceShape.*` / `sourceColor.*`），不做 App Group 同步（widget 用不到来源头像）。
- 文件：见上（`Palette`/`SourceAvatar`/`AvatarPicker`/`AvatarWithStatus`/`BotRow`/`ThreadView`/`ChatTranscript`/
  `DSHGateway`/`HomeSource`/`HomeSourcesView`/`DSHConversationView`/`SourceAppearanceView`/`AccountSwitcherView`/`SettingsView`）。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`（真机 destination、
  ui-preview 覆盖、构建号 199）**编译通过，0 error**，改动文件 0 warning；`xcrun devicectl device install app`
  装到 iPhone 16 Pro（`com.suiyikou.codync.uipreview` 2.36.0 / 199）成功。按要求**不自测**。
- 关联：C0210（状态行头像）、C0208/C0209（会话页搬迁）、备份 tag `backup/before-avatar-dot-c0211`（`ab462079`）。

### C0212 · 2026-11-05 · DSH 运行中按当前步骤显示四句状态行

- 原因：C0210 把会话页统一成一行扫光状态行，但 DSH 页只有 `isStreaming` 一个信号，运行中一律「在处理」，
  拿不到「在想 / 在跑命令 / 在看文件 / 在改代码」；而且 `assistant/message` 与 attempt 结束都会把
  `isStreaming` 置回 false，工具执行期间状态行反而会消失。穗要求按当前步骤显示，turn/end 后消失。
  四方已定 Q1=A：App 用结构化事件＋工具白名单，认不出的降级「在处理」，网关不改、WS 线上格式不变。
- 行为（用户可见）：
  - DSH 会话运行中，底部状态行按当前步骤显示：turn/step 开始、模型 attempt、reasoning-delta →「在想」；
    bash / pwsh / shell / exec / exec_command / terminal →「在跑命令」；read / read_file / readfile →「在看文件」；
    write / write_file / writefile / edit / edit_file / editfile / apply_patch →「在改代码」；
    其余（run_code、search / glob / grep / fetch、命名空间工具、缺 callId 的调用、未知工具）→「在处理」。
  - 同时有多个未完成工具时显示最近发起的那个；一个工具返回后回到「在处理」，等下个 step/attempt。
  - turn/end 后整行消失；assistant/message、attempt end、step/end 都不再隐藏它，工具在跑时不会闪没。
  - 新开会话、关闭会话、断线、连接失败、`session-stream-reset` 都会清掉当前活动：切会话再切回、
    断网再连上都不残留上一个工具名，也不会卡着不消失。旧 socket、旧 subscriptionId、旧 streamId 的帧一律丢弃；
    seq 重放忽略，seq 出现缺口时降级为「在处理」，不跨缺口拼工具。
  - Coe 的会话页不受影响：仍走 `WorkingPhrase.title(for:)`，四个短语抽成常量后字符串与行为不变。
- 分类与状态机（只在前端；网关未改，WS 字段未增）：
  | 输入 | running / 状态行 |
  |---|---|
  | turn/start、step/start、attempt start、reasoning-delta | 运行中 →「在想」 |
  | text-delta | 运行中 →「在处理」（有未完成工具时显示该工具） |
  | tool/call | 按白名单分类；最近一个未完成的调用优先 |
  | tool/result | 只移除匹配的 callId；还有别的 pending 显示最近那个，否则「在处理」 |
  | assistant/message、attempt end、step/end | 保持运行中，不隐藏 |
  | turn/end | 消失，清该轮全部 pending/attempt |
  | session-status、sessions[].running | 仅在没有可信基线时兜底；`false` 清细分状态，不作完成通知 |
  | session-snapshot | 完整窗口才折叠未结束 turn 与 pending call；裁剪窗口只保留 running →「在处理」 |
  | session-stream-reset | 当前 stream 作废、清细分；仍在跑就显示「在处理」，等新基线 |
- 变化：
  - `DSHKit/Sources/DSHKit/DSHModels.swift`：新增 `DSHActivityKind`（thinking/executing/reading/editing/processing，
    `forTool(named:)` 走小写精确别名，不用 contains、不读 arguments）、输入 DTO
    （`DSHActivityEnvelope` / `DSHActivityEvent` / `DSHActivityFrame` / `DSHActivityAttempt` / `DSHActivitySnapshot`），
    以及纯 reducer `DSHActivityState`：session/subscription/stream 代际、seq 水位、pending 调用（最近激活顺序）、
    attempt 的 revision/index、running 与 kind。DSHKit 不依赖 CodyncUI，不放颜色或 SwiftUI token，
    `DSHMessage` 正文结构未改。
  - `DSHKit/Sources/DSHKit/DSHGateway.swift`：发布 `currentActivity: DSHActivityKind?` 与 `isRunning`；
    `handleFrame` 新增 `subscribed`、`session-status` 两个分支，`sessions` 之后给打开会话做兜底；
    `event` / `assistant-stream` / `session-snapshot` 在正文处理之外先喂 reducer；`session-stream-reset` 清细分；
    `open` / `closeConversation` / `disconnect` / `handleDrop` / `requirePairingAgain` / `fail` 清空当前活动。
    tool/call 的 `arguments` 按 JSON 取值（字符串、数字、结构化 JSON 都收），不再只认 String。
    `send(text:)`、`upsertFinishedAssistant` 与正文处理分支未改。
  - `Kit/Sources/CodyncUI/Thread/ConversationStatusLine.swift`：`WorkingPhrase` 新增 `thinking` / `executing` /
    `reading` / `editing` 四个常量，`title(for:)` 改为引用它们（返回的字符串不变）。
  - `Kit/Sources/CodyncUI/Thread/ChatTranscript.swift`：`ChatTranscriptView` 新增
    `workingTitle: String = WorkingPhrase.generic`，状态行用它当标题；working 行的 revision 计入
    `workingTitle.hashValue`，列表复用时标题变化会重绘该行。
  - `apps/ios/Views/DSHConversationView.swift`：`working: gateway.isRunning`，`workingTitle` 由
    `gateway.currentActivity` 映射到 `WorkingPhrase`；头像仍是 `SourceAvatar(.dsh, size: 24)`，
    toolbar、composer、summary sheet、`onDisappear` 均未动。
- 未做 / 需要你注意：
  - 按你的要求没加测试 target、没写测试、没跑测试、没截图、没用 CDP；验证只有编译和安装。
  - 正文里的 `turnTools`（summary sheet 里工具参数）仍用 `as? String`，结构化 arguments 在**正文**仍会丢；
    按「不动正文处理分支」没改，要不要下一刀一起修由你定。
  - 工具白名单按旧 M / KMP 的别名定，没有做命名空间（`ns.tool` 一律「在处理」），run_code 也不猜。
  - 快照里的 `activeAttempt` 恢复依赖 `assistantStream.activeAttempt` 的字段形状（`attemptId` / `nextIndex` /
    `stream` 紧凑记录）；网关若改字段名会静默降级成「在想 / 在处理」，不会崩。
  - 改动文件里剩 1 个既有 warning（`DSHGateway.swift` 的 `if let openSessionId`），基线 C0211 就存在，
    不是本刀引入的，按「不顺手改」留着。
  - DSH 页的 `isStreaming` 语义保持原样（下一刀做正文归并）；`DSHViews.swift` 里还有一处旧的
    `isStreaming` typing 指示器，不在本刀范围。
- 文件：`apps/ios/DSHKit/Sources/DSHKit/DSHModels.swift`、`apps/ios/DSHKit/Sources/DSHKit/DSHGateway.swift`、
  `apps/ios/Kit/Sources/CodyncUI/Thread/ConversationStatusLine.swift`、
  `apps/ios/Kit/Sources/CodyncUI/Thread/ChatTranscript.swift`、`apps/ios/Views/DSHConversationView.swift`、
  `CHANGELOG.md`。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`（真机 destination、
  ui-preview 覆盖、构建号 200）**编译通过，0 error**，改动文件 0 新增 warning；`xcrun devicectl device install app`
  装到 iPhone 16 Pro（`com.suiyikou.codync.uipreview` 2.36.0 / 200）成功。按要求**不自测**。
- 关联：C0210（状态行）、C0211（头像与来源点）、设计 `streaming-step1.md`（Q1=A）、
  备份 tag `backup/before-dsh-activity-c0212`（`b5e25c39`）。

### C0213 · 2026-11-05 · 会话页状态行尺寸与文案、DSH 页底部透明、回到底部按钮位置

- 原因：C0210/C0212 之后状态行只有一句短语（「在想 / 在处理」），没有名字，尺寸也是临时值（footnote 13pt、
  左右 16、上下 6）；DSH 页输入框后面还垫了一层不透明底色，消息滑不过去；回到底部的 ↓ 按钮离输入框只有 10。
  穗要求两个会话页统一成「名字 + 状态」的 16pt 一行，并给出具体尺寸。
- 行为（两个会话页一致，pt 为一倍图）：
  | 项 | 值 |
  |---|---|
  | 头像 | 24×24（来源点照旧：DSH 右下 6pt，Coe bot 无点） |
  | 头像左边缘到屏幕左边框 | 24（列表 cell 的 16 + 状态行自身 8） |
  | 状态行顶部到上一条消息气泡底部 | 12 |
  | 状态行底部到输入框（玻璃框）顶部 | 24（行下 10 + 列表 section 下 8 + 输入框自身顶部 6） |
  | 头像与标题文字之间 | 10 |
  | 标题 | 16pt 常规字重，扫光保留（1.6s 扫 + 0.3s 停不变） |
  | 回到底部按钮底边到输入框顶部 | 36（按钮下 30 + 输入框顶部 6） |
- 文案改成「名字 + 状态」：
  | 短语 | Coe 来源 | DSH 来源 |
  |---|---|---|
  | 思考中 | `thought`；`tool` 且 `toolKind=think` | turn/step 开始、attempt start、reasoning-delta |
  | 正在输入中 | 非 final 的 `agent`（模型正在写正文） | `text-delta` |
  | 处理会话中 | `plan`、`tool` 的 search/fetch/其他/未知 | 认不出的工具、assistant/message、attempt end 等 |
  | 正在跑命令（**建议，待穗确认**） | `toolKind=execute` | bash / pwsh / shell / exec / exec_command / terminal |
  | 正在看文件（**建议，待穗确认**） | `toolKind=read` | read / read_file / readfile |
  | 正在改代码（**建议，待穗确认**） | `toolKind=edit` / `move` / `delete` | write / edit / apply_patch 等 |
  - Coe 用该 bot 的名字（「<bot 名> 思考中」）；DSH 没有 bot 名字，固定用「DeepSeek」（「DeepSeek 正在输入中」）。
  - Coe 对不上的状态一律「处理会话中」。
- 变化：
  - `Kit/Sources/CodyncUI/Thread/ConversationStatusLine.swift`：`HStack` 间距 8→10；标题字体 `.footnote`→
    `.system(size: 16, weight: .regular)`；左右内边距 16→8、去掉上下 6（改由两个页面按 12 / 10 给）。
    `WorkingPhrase` 改成「名字 + 短语」：新增 `typing`（正在输入中）与 `processing`（处理会话中，替换原 `generic`）、
    `line(name:phrase:)`、`title(for:name:)`；原 `title(for:)` 拆出 `phrase(for:)`；Coe 的 `agent` 步骤映射到「正在输入中」。
  - `Kit/Sources/CodyncUI/Thread/ThreadView.swift`：状态行标题改成 `WorkingPhrase.title(for:name:)`；
    行加 `.padding(.top, 12)` / `.padding(.bottom, 10)`；working 行的 revision 改为「启动时间 + 标题哈希」，
    标题一变就重绘。
  - `Kit/Sources/CodyncUI/Thread/ChatTranscript.swift`：working 行同样加 12 / 10；`workingTitle` 默认值
    `WorkingPhrase.generic` → `WorkingPhrase.processing`。
  - `Kit/Sources/CodyncUI/Thread/ConversationList.swift`：`JumpToLatest` 底边距 10 → 30（到玻璃框 36）。
  - `Kit/Sources/CodyncUI/Thread/ThinkingStatus.swift`：`ShimmeringText.font` 的注释同步为 16pt 常规（只改注释）。
  - `apps/ios/Views/DSHConversationView.swift`：状态行标题 = 「DeepSeek + 短语」；去掉输入框那层
    `.background(Palette.background)`，底部与 Coe 一样只留输入框自己的玻璃效果。
  - `apps/ios/DSHKit/Sources/DSHKit/DSHModels.swift`：`DSHActivityKind` 增加 `typing`；`text-delta`
    （以及快照恢复时的最后一段正文）映射到它。
- 未做 / 需要你注意：
  - 三条建议短语（正在跑命令 / 正在看文件 / 正在改代码）已按建议写，穗确认前随时可改字符串。
  - 「输入框顶部」按**可见的玻璃输入框上边缘**算：输入框组件自己还有 6pt 顶部内边距，所以布局上的数字是
    状态行下 10、按钮下 30。若你要按输入框外框（含那 6pt）算，应改成 16 / 36。
  - Coe 的「正在输入中」来自非 final 的 `agent` 步骤；若某一轮 host 不产生 `agent` 步骤，那一轮只会看到
    「思考中」或「处理会话中」。
  - 按你的要求没跑测试、没截图、没用 CDP；只编译和安装。
- 文件：`apps/ios/Kit/Sources/CodyncUI/Thread/ConversationStatusLine.swift`、
  `apps/ios/Kit/Sources/CodyncUI/Thread/ThreadView.swift`、`apps/ios/Kit/Sources/CodyncUI/Thread/ChatTranscript.swift`、
  `apps/ios/Kit/Sources/CodyncUI/Thread/ConversationList.swift`、`apps/ios/Kit/Sources/CodyncUI/Thread/ThinkingStatus.swift`、
  `apps/ios/Views/DSHConversationView.swift`、`apps/ios/DSHKit/Sources/DSHKit/DSHModels.swift`、`CHANGELOG.md`。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`（真机 destination、
  ui-preview 覆盖、构建号 201）**编译通过，0 error**，0 warning；`xcrun devicectl device install app` 装到
  iPhone 16 Pro（`com.suiyikou.codync.uipreview` 2.36.0 / 201）成功。按要求**不自测**。
- 关联：C0210（状态行）、C0212（DSH 当前步骤）、备份 tag `backup/before-status-line-c0213`（`95fb3af9`）。

### C0214 · 2026-11-05 · 状态行动态标题 + 思考内容误进气泡的修复

- 原因：① C0213 的标题是固定短语，同一轮里从「思考中」到「正在看文件」之外没有更多信息；
  穗要求改成「名字 + 根据上下文动态生成的短描述」。② DSH 会话运行中，思考过程会被当成回复正文
  显示在气泡里，提交后又消失。
- **Bug 根因（DSH）**：`DSHGateway.text(ofChunk:)` 只对 `text-delta` 取正文，其余 chunk 落到兜底
  `chunk["text"]`；而 `reasoning-delta` 的 payload 正好也是 `{"type":"reasoning-delta","text":…}`，
  于是思考的每一段都被 `appendStreaming` 追加进了那条运行中的 assistant 气泡。等本轮
  `assistant/message` 提交时，`upsertFinishedAssistant` 用正式正文覆盖同一个气泡，所以那段思考
  「输出完又消失」。修法：只有 `text-delta`（以及没有 `type` 的旧式纯文本 chunk）算正文，
  `reasoning-delta` / `tool-call-delta` / `usage` / `finish` 一律返回 nil；思考改由活动 reducer 单独累积，
  只用于状态行标题。**Coe 无此问题**：Coe 的思考是 `thought` 步骤，在 `ThreadView.transcript` 里被
  `WorkingPhrase.isStepOnly` 过滤掉，从不画成气泡；`agent` 步骤才是正文。
- 行为（动态标题，**建议方案，穗尚未确认**）：
  | 状态 | 标题里的描述 | 数据来源（Coe / DSH） |
  |---|---|---|
  | 思考 | 当前思考内容的第一句，去 Markdown，截到 16 字加省略号；拿不到写「思考中」 | Coe：`thought` / `tool(think)` 的 `data.text`；DSH：本轮 `reasoning-delta` 累积文本 |
  | 输出正文 | 正在输入中 | Coe：非 final 的 `agent`；DSH：`text-delta` |
  | 调用工具 | 「正在看 README.md」「正在跑 xcodebuild」「正在改 ChatTranscript.swift」；认不出的写「正在用 工具名」；拿不到参数用「正在看文件 / 正在跑命令 / 正在改代码」 | Coe：`locations[0].path` / `command` / `diffs[0].path` / `title`；DSH：tool/call 的 JSON 里 `path|file_path|filename|file|target_file` 或 `command|cmd|script` |
  | 其它 | 处理会话中 | — |
  - 名字规则不变：Coe 用该 bot 的名字，DSH 固定「DeepSeek」。
  - 最多每秒换一次（`StatusTitle` 里按最后一次变更时间节流），换的时候 0.18s 淡入淡出，扫光从新文字重新开始。
  - 不额外调用模型，只用已经收到的实时数据。
- 变化：
  - `DSHKit/Sources/DSHKit/DSHModels.swift`：新增 `DSHActivityDetail`（kind + toolName + toolArgument + reasoning）；
    `DSHActivityEvent.arguments`（原样 JSON 文本）改为 `toolArgument`（调用里的关键参数）；
    `DSHActivityFrame` 增加 `text`（只收 reasoning-delta 的文字）；reducer 累积本轮思考（上限 400 字，
    在新 turn / 新 attempt / 断线 / 重置 / gap / 快照时清空），`activity` 由 `DSHActivityKind?` 改为
    `DSHActivityDetail?`。
  - `DSHKit/Sources/DSHKit/DSHGateway.swift`：发布 `currentActivity: DSHActivityDetail?`；新增
    `toolArgument(_:toolName:)` 从 tool/call 的 JSON 取 path 或 command（字符串形式的 JSON 也会解析）；
    reasoning-delta 的文字交给 reducer；**`text(ofChunk:)` 修掉把思考当正文的兜底**。
  - `Kit/Sources/CodyncUI/Thread/ConversationStatusLine.swift`：`WorkingPhrase` 新增 `Verb`（看/跑/改/用）与
    `tool(_:subject:)`（只取文件名或命令第一个词，缺参数回落到固定短语）、`summary(of:)`（第一句 + 去 Markdown +
    16 字截断）；Coe 的 `phrase(for:)` 改为按最后一个步骤的 `toolKind`/`locations`/`command`/`diffs`/`title` 取描述。
    状态行文字抽成 `StatusTitle`：每秒最多换一次 + 淡入淡出 + 扫光重启；其余尺寸不变。
  - `apps/ios/Views/DSHConversationView.swift`：标题由 `DSHActivityDetail` 生成（思考用 `summary(of:)`，
    工具用 `WorkingPhrase.tool(...)`）。
- 未做 / 需要你注意：
  - 动态标题是**建议方案**，穗确认前随时可调（截断字数、动词措辞、是否保留「正在用」）。
  - Coe 的「正在输入中」仍依赖非 final 的 `agent` 步骤；没有该步骤的轮次只会看到「思考中 / 处理会话中」。
  - DSH 断线重连后，snapshot 里没有「思考正文」的句子，标题会先回到「思考中」，等下一段 reasoning-delta 再变。
  - 状态行每秒最多变一次是**显示层节流**：数据本身仍按实时更新，气泡与正文不受影响。
  - 按你的要求没跑测试、没截图、没用 CDP；只编译和安装。
- 文件：`apps/ios/DSHKit/Sources/DSHKit/DSHModels.swift`、`apps/ios/DSHKit/Sources/DSHKit/DSHGateway.swift`、
  `apps/ios/Kit/Sources/CodyncUI/Thread/ConversationStatusLine.swift`、`apps/ios/Views/DSHConversationView.swift`、
  `CHANGELOG.md`。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`（真机 destination、
  ui-preview 覆盖、构建号 202）**编译通过，0 error**，改动文件 0 新增 warning；`xcrun devicectl device install app`
  装到 iPhone 16 Pro（`com.suiyikou.codync.uipreview` 2.36.0 / 202）成功。按要求**不自测**。
- 关联：C0210（状态行）、C0212（DSH 当前步骤与工具白名单）、C0213（尺寸与「名字 + 状态」）、
  备份 tag `backup/before-dynamic-title-c0214`（`d226f98d`）。

### C0215 · 2026-11-05 · 去掉主 bot 的五角星徽标（iOS 所有位置）

- 原因：穗要求五角星所有地方都去掉，包括详情页。
- 变化：
  - `Kit/Sources/CodyncKit/Design/CharacterAvatar.swift`：`AvatarWithStatus` 删掉主 bot 的星标 overlay
    （原在 `sourceDot == nil ? .bottomTrailing : .topTrailing` 上画 `LeadAgentBadge(size: max(12, size * 0.34))`）。
    头像本体、来源点、未读/需要输入标记都没动。
  - `Kit/Sources/CodyncUI/Bots/BotDetailsView.swift`（`identity` 里）：详情页 88pt 大头像由 `LeadAgentAvatar`
    换成 `CharacterAvatar`，尺寸仍 88；那颗可点的星（点开是「主 bot 说明」sheet）随之消失。
  - 删除 `Kit/Sources/CodyncKit/Design/LeadAgentBadge.swift` 与 `Kit/Sources/CodyncUI/Bots/LeadAgentAvatar.swift`：
    全仓库 rg 后 iOS 侧已无任何引用（`apps/android` 与 `apps/desktop` 各有一份同名实现，属别的 App，未在本次范围）。
- 未改（按你的要求）：`bot.lead` 字段，以及主 bot 的选择、排序、语音入口、发送给主 bot、菜单显示规则、Host 逻辑；
  C0211 的来源点（`SourceKind.dot` / `SourceAvatar`）；首页长按菜单里「设为主 Bot」的 star-line 图标；`Palette.warning`。
- 待穗确认（按「别自己发明新排布」保守处理）：
  - 状态标记（未读点 / 需要输入的感叹号）位置仍是 `bot.lead ? .topTrailing : .bottomTrailing`：列表行右下角是
    来源点（`BotRow` 会传 `sourceDot`），主 bot 的标记如果统一挪到右下会和它重叠；按「重叠就先保持现状」没有改。
    要统一成右下是一行改动（顺带说明：非主 bot 现在本来就和来源点重叠，C0211 已记录）。
  - 详情页去掉那颗星以后，「主 bot 说明」sheet 没有入口了；按要求没有另加入口。
- 文件：`apps/ios/Kit/Sources/CodyncKit/Design/CharacterAvatar.swift`、
  `apps/ios/Kit/Sources/CodyncUI/Bots/BotDetailsView.swift`；删除
  `apps/ios/Kit/Sources/CodyncKit/Design/LeadAgentBadge.swift`、
  `apps/ios/Kit/Sources/CodyncUI/Bots/LeadAgentAvatar.swift`；`CHANGELOG.md`。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`（真机 destination、
  ui-preview 覆盖、构建号 203）**编译通过，0 error**，改动文件 0 warning；`xcrun devicectl device install app` 装到
  iPhone 16 Pro（`com.suiyikou.codync.uipreview` 2.36.0 / 203）成功。按要求**不自测**。
  另：C0212–C0214 的构建命令多传了 `CODYNC_APP_NAME=Codync UI 测试`（抄自 `docs/guides/ios-ui-preview.md` 的示例），
  它覆盖了 `DevDebug` 配置里的 App 名；这次起不再传，安装后的显示名回到 `project.yml` 里 `DevDebug` 的名字。
- 关联：C0211（来源点）、备份 tag `backup/before-remove-lead-star-c0215`（`485f865f`）。

### C0216 · 2026-11-05 · DSH 串流第二步：消息正文

- 原因：正文使用随机消息 ID、按相同文字去重、回填最后一条 assistant，以及 history 整体替换列表，
  会合并合法的相同消息、覆盖上一轮回复，或在重进会话时冲掉实时内容。
- 变化：
  - 新增 `apps/ios/DSHKit/Sources/DSHKit/DSHWireEvent.swift`：区分 live 与 history 的数据结构，保留原始
    JSON、完整度、真实 seq/turn/step，归一时间；正式身份编码为 `[gatewayId, sessionId, seq]`。
    紧凑 snapshot 前缀和实时 chunk 分开解析，reasoning 永远不进入正文。
  - 新增 `apps/ios/DSHKit/Sources/DSHKit/DSHConversationState.swift`：每个网关/会话/历史格式独立保存内存
    canonical events、实时游标、分页覆盖范围、请求登记和冻结的发送意图；history 只合并，不能改实时游标或清理 attempt。
    临时回复只按 `end.outcome.seq` 结算；显示别名和起始游标锚点保住当前行的位置，不按 turn 或数组末尾覆盖。
    同 seq 幂等补齐，两个相同文字但不同 seq 的消息各自保留；矛盾事件或时钟缺口重新订阅基线。
  - `apps/ios/DSHKit/Sources/DSHKit/DSHModels.swift`：消息 ID 改为必须明确传入；桥接真实 seq/turn/step、
    displayRowId 和 revision，保留 C0212 的活动类型和 reducer。
  - `apps/ios/DSHKit/Sources/DSHKit/DSHGateway.swift`：校验 hello 的 gatewayId/历史格式；连接和会话切换退休
    旧 stream/请求；订阅单飞，正文与活动共用 session/subscription/stream 准入链。首屏使用原子 snapshot；
    history 使用唯一请求 ID，按 hasMore/nextBeforeSeq 向前补页，空页最多连续读取三页。
    已知离线和本地编码失败保留明确失败状态；socket 错误、断线或回执超时标为「送达待核对」。
    sent 仅表示已接收；未知送达先查历史并展示已有服务端队列提示，再由用户确认是否重发，绝不自动重发。
    退休的旧请求 ID 留存以吸收迟到回执，accepted 不倒退。
  - `apps/ios/Views/DSHConversationView.swift`：连接分页、刷新和本地发送状态行；正式用户气泡只来自服务端
    user/message。点发送冻结内容，失败可人工重试或恢复编辑；已有新草稿时追加旧内容，不覆盖新输入。
    不生成工具/思考展开与 summary sheet；C0213/C0214 的状态行标题和尺寸不变。
  - `apps/ios/Kit/Sources/CodyncUI/Thread/ChatTranscript.swift`：新增带默认值的分页/刷新/发送状态桥接参数，
    支持显示行别名与是否跟随新增用户消息；复用原 ConversationList 的 applyKeepingPlace，DSH 服务端新增消息
    不触发强制跟随。Coe 继续使用原默认行为。
- 删除旧逻辑：最后相同文字去重、随机正式消息 UUID、upsertFinishedAssistant/最后 assistant 回填、
  旧流式 append/finalize 与 turnTools 聚合、history 整体覆盖、打开会话并行拉 history、乐观复制用户气泡。
- 与设计的差异：无功能范围差异。内部采用单个活动 attempt（对应当前协议的 activeAttempt），保留行别名并以
  startedAfterSeq 作显示锚点；缓存正文投影与排序索引，避免每个 token 重解整段历史。发送状态独立于正式气泡，
  因而不在 canonical 消息上增加 delivery 字段；这些是设计所述职责的具体实现。
- 边界：ConversationList、ConversationStatusLine、Coe Host、网关协议、Package.swift、pbxproj 均未改；
  无新依赖、测试 target、磁盘聊天缓存、离线队列。发送状态仅存内存，进程退出后不恢复，也不自动补发。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`（真机
  destination、ui-preview 覆盖、构建号 205）编译通过；最终增量构建 0 error、0 warning，前一次构建仅有
  未改文件 BotShortcuts.swift 的既有弃用警告。先关闭设备上的旧 App，再用 `xcrun devicectl device install app`
  装到 iPhone 16 Pro（`00008140-000A31311AE3001C`，`com.suiyikou.codync.uipreview`，2.36.0 / 205）成功。
  执行正确性、完整性和结构三项只读代码审查并修复发现的问题；按穗要求不运行测试、不启动 App 自测，
  七项真机场景留给穗操作。构建和安装记录位于 `/tmp/codync-audit/c0216-build-final.log`、`c0216-install.json`。
- 关联：详细设计 `/tmp/codync-audit/streaming-step2.md`；备份 tag
  `backup/before-dsh-transcript-c0216`（`bfaa83df`，包含 C0212–C0215）。回滚可 revert 本次提交，
  不回退状态行和 C0215；无协议或数据库迁移。回滚正文实现会恢复旧覆盖风险。

### C0217 · 2026-11-05 · DSH 串流第三步：事件类型显示正确

- 原因：第二步把正文保真以后，其余事件类型仍不对。工具调用与结果没有准确配对（一条结果会清掉整轮的
  工具状态；历史先读到结果、往前翻才补到调用时无法回填），非用户来源塞进来的上下文被画成「我发的」
  气泡，本轮出错/取消/中断在会话里没有任何说明，而正常的轮次反而可能被误报成结束。
- 变化：
  - `apps/ios/DSHKit/Sources/DSHKit/DSHWireEvent.swift`：新增工具调用地址 `DSHToolKey`
    （gatewayId/sessionId/turn/step/callId，turn/step 可空）与松索引 `DSHToolLooseKey`
    （gatewayId/sessionId/callId）；`DSHToolRecord` 保存参数原样（对象/数组/数字/布尔/null 不转字符串，
    本身就是 JSON 的字符串保留原字符串）、name、callSeq、按 seq 去重的 resultSeqs、output/preview/
    isError/error/outputTruncated 与 matchState；`DSHUnmatchedResult` 记孤立与歧义结果；
    `DSHMessageOrigin`（user/context/legacy + 原样 rawSource + 受控来源名 + confidence）；
    `DSHTurnTermination`/`DSHTerminationError`。`DSHJSON` 改为 Hashable 并补 `bool`/`number` 取值。
    tool-result 正文同时接受当前会话格式的扁平 text 块与旧 `tool-result` 包装块。
  - `apps/ios/DSHKit/Sources/DSHKit/DSHModels.swift`：`DSHTool` 增加 preview、`outputTruncated`、
    可空 `isError`（不再把「未声明」当成退出码 0）与 `matchState`；`DSHMessage.Role` 增加 `.notice`，
    新增 `DSHNotice`（info/error/context + 受控来源名 + 标题）与 `DSHMessage.notice`；
    `DSHTranscriptItem.Kind` 增加 `.notice` 并带 `notice`。正文角色不再被强迫成 user/assistant。
    C0212 的 `DSHActivityKind`/`DSHActivityState`/白名单定义原样保留。
  - `apps/ios/DSHKit/Sources/DSHKit/DSHConversationState.swift`：工具配对先按精确 ToolKey；结果缺
    turn/step 时只接受**唯一**兼容候选，零候选记孤立、多候选记歧义，绝不挑最近一条。历史先读到结果、
    往前翻才补到调用时只补关系、不追加第二条结果；同一结果 seq 幂等。多个并发工具互不影响，结果只结束
    它自己那一次调用。新增 context 与 turn/end 投影：只有 `source.kind == user` 画成用户气泡，其他显式
    来源画成「上下文 · 来源名」中性说明；`turn/end` 按出错/取消/中断/未知各给一条说明，正常结束不加任何
    说明。同一结束事件按 seq 幂等只显示一条；下一轮开始不删上一轮的说明。上下文/终止说明行 id 由原事件
    地址派生（context 加固定后缀，终止用 `termination` + endSeq）。
  - `apps/ios/DSHKit/Sources/DSHKit/DSHGateway.swift`：状态行改为读取与正文同一份解析后的
    `DSHWireEvent`（callId/toolName/toolArgument 单一来源），不再有第二套字段解析；活动仍只接结构化
    事件，不接生成的说明文字，白名单未改。`activityEvent` 与 `toolArgument` 改为委托 DSHWireEvent，
    快照路径与实时路径命名一致。
  - `apps/ios/Views/DSHConversationView.swift`：三路映射 user/agent/notice；notice 复用既有
    `NoticeRow`，出错用 `style "error"`（`Palette.danger`），取消/中断/未知用默认次要文字颜色，上下文
    画成标题 + 原文的中性行，受控来源名放进 `data.title`。不加工具气泡，不恢复展开/summary sheet/轨迹入口。
  - `apps/ios/Kit/Sources/CodyncUI/Thread/ChatTranscript.swift`：行 revision 从只哈希正文改为把说明
    文字、来源（`data.title`）、样式（`data.style`）与 `entry.rev` 都计入，来源或样式变化会单独重画该行。
    CodyncUI 未引入 DSHKit 依赖。
- 与设计的差异（均为实现取舍，功能范围无差异）：
  - 终止说明的行身份用 `(gateway, session, "termination", endSeq)`，没有再拼 turn。endSeq 本身唯一且
    稳定；turn 在真实协议里可选，拼进去反而会让「不知轮号」的说明拿不到稳定 id。
  - 上下文来源名走**受控映射表**（22 个已知 kind + `plugin:*` → 中文名，未知回退「上下文」），不直接显示
    raw `source.kind`。源码证据显示真实取值包含 `ptc-mode`、`cordis-host-runner`、
    `dsh-session-title-llm` 这类不能上屏的内部名；设计原话也是「受控来源名」。映射表本身是本次新增内容。
  - `aborted` 按 `reasonDetails.reason.kind` 再分：等于 `user` 才是「本轮已取消」，`parent`/`disposed`/
    `hook` 记「本轮已中断」。设计表格把 aborted/cancelled/canceled 都归取消；源码里网关/DSH 只产出
    `aborted`，且它同时表示用户取消和宿主中止，所以必须用 cause 区分，否则主动取消与被动中断会混为一谈。
  - 只有 `reason` **完全缺失**才写「本轮已结束，原因未提供」；`reason` 存在但本版不认识的值按「其他非错误
    终止」处理，不加说明。真实 reason 全集为 `completed`/`blocked`/`max-tokens`/`aborted`/`error`/
    `interrupted`/`forked`，其中非 error/取消/中断的三种按设计表格「正常或其他非错误终止」静默。
  - 真实协议里 `turn/end` 不带 `step`，因此终止说明行的 step 为 nil，不影响排序（按 seq）。
  - 无 source 字段的老数据仍走旧的「Time sampled…」前缀兼容路径并画成用户气泡；这类行只是「来源未知」，
    不宣称已确认是用户本人输入。前缀规则**只**用于老数据，来源确认为 user 的消息不再被它隐藏。
  - `DSHTool` 已按设计补齐结果元信息，但不再挂到每条 assistant 消息上（`DSHWireEvent.tools` 返回空），
    因此不可能再出现工具气泡或 summary 行。设计要求的「typed arguments」放在 `DSHToolRecord.arguments`
    上（参数原样、对象不转字符串），没有再在 `DSHTool` 里留一份拷贝：工具已不随消息下发，多一份只会
    成为永不赋值或与权威记录漂移的死字段。
  - 当前 iOS 订阅的是 `view: conversation`，网关对 `request/context`、`request/header`、
    `system/message`、`assistant/chunk` 整体返回 null，这几类在客户端**永远收不到**，所以没有为它们加
    DTO 或 UI 分支，只在投影里按未知类型忽略。
- 边界：不改网关、不改 Coe Host、不改协议；不删旧 summary 代码（留给 Q9）；不加测试 target、不加依赖、
  不改 `Package.swift`/`project.yml`/pbxproj；C0212–C0216 的成果（状态行、正文身份、发送状态）未改动。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`
  （真机 destination、ui-preview 覆盖、构建号 209）编译通过，0 error；仅剩未改文件 `BotShortcuts.swift`
  的既有弃用警告。`xcrun devicectl device install app` 装到 iPhone 16 Pro（`00008140-000A31311AE3001C`，
  `com.suiyikou.codync.uipreview`，2.36.0 / 209）成功。按穗要求**只编译不自测**，七项真机场景留给穗操作。
  构建与安装记录在 `/tmp/codync-audit/c0217-build-final.log`、`c0217-install.json`。
- 关联：详细设计 `/tmp/codync-audit/streaming-step3.md`；wire 形状以网关源码与 DSH 源码核对（结论见
  `/tmp/codync-audit/ws-mobile-protocol.md`）；备份 tag `backup/before-dsh-events-c0217`（`c1f0c529`，
  含 C0212–C0216）。回滚可 revert 本次提交，只撤事件类型投影与 notice 适配，保留第二步的消息 store 和
  C0212 状态行；无协议或数据 schema 迁移，原 JSON 事实可保留。

### C0218 · 2026-11-05 · DSH 图片：后台部分（不含输入框界面）

- 原因：DSH 会话里既发不了图片，也看不到别人发的图片。要先把「图片怎么处理、怎么发、怎么按需取回」
  做成不依赖界面的后台能力，等新输入框做好后直接接上，不必再动这一层。
- 变化：
  - 新增 `apps/ios/DSHKit/Sources/DSHKit/DSHImageProcessor.swift`：纯逻辑图片处理器，不依赖界面、
    不依赖网关。用 ImageIO 读**真实格式**（不看扩展名）；合规的 JPEG/PNG/GIF/WebP 原样发；HEIC/TIFF/BMP、
    EXIF 不正向、或超限的图转成**方向正确**的 JPEG（透明底转白，缩略图 API 不放大小图）；JPEG 质量
    0.9→0.3 递减，仍超则长边 ×0.8 重新从 0.9 试，最多 12 轮，压不下来就报错而不是发超限图；批内最多
    2 张并行解码；整条消息超 16 MiB 直接报错，不自动拆条。
  - `apps/ios/DSHKit/Sources/DSHKit/DSHModels.swift`：新增 `DSHImageRef`（attachmentId/mediaType/
    bytes/width/height/name，不含字节）、`DSHOutgoingImage`（待发图片的 mediaType/name/data）；
    `DSHMessage` 与 `DSHTranscriptItem` 增加 `images`。保留 C0212–C0217 全部类型。
  - `apps/ios/DSHKit/Sources/DSHKit/DSHWireEvent.swift`：`images` 同时解析 live 的 `event.images` 与
    history 的 `data.content[].attachment`，按 attachmentId 去重。
  - `apps/ios/DSHKit/Sources/DSHKit/DSHConversationState.swift`：纯图片（text 为空、images 非空）也生成
    一行（user 气泡 / assistant / context notice 不变）；`DSHSubmission.images` 与文字一起冻结，重试/重发
    用同一份字节，不重新压缩成另一份 payload。
  - `apps/ios/DSHKit/Sources/DSHKit/DSHGateway.swift`：保存 hello 的 `capabilities` 并发布，断线清空；
    `send(text:images:)` 支持只发图不带字，未宣告 `images` 的网关拒绝发图，超 16 MiB 在发送前拦下并给出
    `imageSendProblem`；新增按需取图 `imageData(attachmentId:)`——缓存键 (gatewayId, sessionId,
    attachmentId)、只放内存、有界（32MiB / 24 张，超出按最早淘汰）、同时最多 3 个请求、去重排队，并按
    sessionId+attachmentId 匹配 `attachment` 回包（网关不回显 requestId）；断线把所有在途取图请求以 nil
    收尾（这是读取重试，不是重发消息）。
  - `apps/ios/Kit/Sources/CodyncUI/Thread/Attachments.swift`：把 Coe 的图片视图抽出「谁来加载」的通用层
    `LoadedImage`/`LoadedImageViewer`/`TranscriptImageList` 与中性类型 `TranscriptImageRef`；
    `AttachmentImage` 改为薄包装，公开 API 与行为不变（Coe 的 LibraryView / FileDownloadCard /
    AttachmentList 照旧）。DSH 不伪造 botId 走 Coe 下载地址。
  - `apps/ios/Kit/Sources/CodyncUI/Thread/ChatTranscript.swift`：`TranscriptItem` 可带图片，
    `ChatTranscriptView` 新增 `loadImage`/`imageReloadKey`（都有默认值，Coe 调用点不改）；用户/助手行在
    文字上方显示图片，纯图不画空气泡；notice 行的图片（上下文图）显示在中性行上方；行 revision 把图片 id
    计入，图片晚到只重画该行。
  - `apps/ios/Views/DSHConversationView.swift`：去掉「纯图消息丢弃」的判断，映射图片并接网关 loader。
- **图片处理器对外接口（新输入框直接接它）**：
  ```swift
  // 输入一张或一批「原始字节 + 名字」，返回处理好的图片或抛错；批量顺序保持、最多 2 张并行。
  public static func DSHImageProcessor.prepare(_ input: DSHImageInput) async throws -> DSHPreparedImage
  public static func DSHImageProcessor.prepare(_ inputs: [DSHImageInput]) async throws -> [DSHPreparedImage]
  // 发送前算整帧字节（Base64 膨胀 + 16 MiB 判定都走这里）。
  public static func DSHImageProcessor.messageByteCount(text: String, images: [DSHPreparedImage]) -> Int
  public static func DSHImageProcessor.messageByteCount(text: String, images: [DSHOutgoingImage]) -> Int
  ```
  `DSHImageInput(data:name:)`；`DSHPreparedImage(mediaType:name:data:pixelWidth:pixelHeight:)`，可直接
  `DSHOutgoingImage(prepared)` 交给 `gateway.send(text:images:)`。错误类型 `DSHImageError`
  （notAnImage/tooManyImages/cannotCompress/messageTooLarge/unsupportedByGateway），都有中文
  `errorDescription`，输入框可以直接显示。发送前还可用 `gateway.imageSendProblem(text:images:)` 预检
  能力与体积。
- **实际压缩参数**：长边上限 2000px；像素积 40,000,000；单张字节上限 3,670,016；整帧 16 MiB；一批最多
  20 张、2 张并行；JPEG 质量从 0.9 每轮 −0.1 到 0.3，再长边 ×0.8 从 0.9 重来，最多 12 轮，最小长边 256，
  达不到上限报 `cannotCompress`；透明图铺白底。
- 与设计的差异（实现取舍）：
  - 设计把「加号/附件条/相机/共享 Composer 控件」也列在本轮文件计划里；穗明确本轮**只做后台**，输入框
    另做，所以 `ComposerAttachments.swift`、`Composer.swift`、`ConversationComposer.swift` 一律未改，
    DSH 页没有加号或菜单。附件选择的界面接线留到新输入框那一步。
  - 取图缓存的「请求状态」放在 `DSHGateway`（它本来就负责 I/O、且按 gateway+session 天然隔离），没有放进
    `DSHConversationState`（设计写了 State/WireEvent 二选一）。
  - 取图请求**加了 20 秒超时**（设计未写）。没有它，一次丢包会让该图永远停在占位；超时后按 nil 收尾，行
    保留占位，重连可再取。
  - 缓存上限取 32 MiB / 24 张（设计只说「有界内存」，未给数值）。
  - 新增 `gateway.imageSendProblem(text:images:)` 让输入框在发送前拿到明确错误（设计只要求「超限提示减少
    图片数量」，没用它的接口形态）。
  - `context` 来源的图片仍按第三步的中性说明行显示（图片放在说明行上方），不是用户气泡；这与设计的
    「context 图片沿中性来源显示」一致。
- 边界：不改网关、不改 Coe Host、不改协议；不做视频/普通文件；不加测试 target、不加依赖、不改
  `Package.swift`/`project.yml`/pbxproj；C0212–C0217 的状态行/正文身份/事件投影未改动；CodyncUI 未
  import DSHKit。手机上暂无发图入口，符合本轮范围。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`
  （真机 destination、ui-preview 覆盖、构建号 212）编译通过，0 error；仅未改文件 `BotShortcuts.swift`、
  `QuickCapture.swift` 的既有警告。`xcrun devicectl device install app` 装到 iPhone 16 Pro
  （`00008140-000A31311AE3001C`，`com.suiyikou.codync.uipreview`，2.36.0 / 212）成功。按穗要求**只编译
  不自测**，四项真机场景留给穗操作。构建与安装记录在 `/tmp/codync-audit/c0218-build-final.log`、
  `c0218-install.json`。另做了一轮独立只读复核，修掉三处：JPEG 2000 曾被误当基线 JPEG 原样透传（已改
  为转码）、取图 base64 解码从主线程挪到后台、`attachment` 回包只接受本连接仍在等的请求且 bytes 不符时
  立即释放（不再空等 20 秒超时）。
- 关联：设计 `/tmp/codync-audit/attachment-images.md`；备份 tag `backup/before-dsh-images-c0218`
  （`2fb2c54a`，含 C0217）。回滚可 revert 本次提交，回到「纯图消息不显示、DSH 无图片能力」的状态，
  不改协议、无数据迁移，DSH 原消息与历史不受影响。

### C0219 · 2026-11-05 · 新输入框：bot 页胶囊 + chat 页可展开

- 原因：输入框原来分在三处（加号、玻璃输入框、发送），bot 页和 chat 页是两套；穗要的是「一个框」：
  bot 页永远一条胶囊，chat 页没获焦是胶囊、获焦后展开成上下两行。
- 变化：
  - `apps/ios/Kit/Sources/CodyncUI/Thread/ConversationComposer.swift`：重写成**单一玻璃框**。两种形态
    `Mode.capsule` / `.expanded`：胶囊一行（框内左侧 +、中间输入、右侧发送，底对齐），展开两行（上面
    整行打字、下面 48pt 按钮行）。框内的按钮不再自带玻璃（玻璃叠玻璃）。所有几何收在一个 `private
    enum Layout` 里：外边距 16、最小高 48、圆角 24、按钮离边 6、间隙 6、展开打字区内边距 12；胶囊→方框
    用 `Motion.layout` 系统 spring 过渡，不硬切。
  - `apps/ios/Kit/Sources/CodyncUI/GlassButton.swift`：`Style` 新增 `.plain`（只画图标、不画圆底），给框内
    按钮用；原 `.glass` / `.filled` 完全不变。
  - `apps/ios/Kit/Sources/CodyncUI/Thread/Composer.swift`（Coe bot 页）：改成新单框；`+` 仍是原来的照片/
    视频、拍照、选择文件菜单（行为一字未改），label 改成无玻璃的 `GlassGlyph`（compact 36、图标 24）；
    输入区改成裸 TextField（去掉自己的玻璃、1…6 行）；发送/停止/中断保留原逻辑，几何由 48 玻璃圆改成
    compact 36 实心圆、箭头 20。引用条、附件条仍放在框上方，与改动前一致。**没有模型按钮、没有语音按钮。**
  - `apps/ios/Views/DSHConversationView.swift`（chat 页）：输入框改用新的 `DSHComposer`（与 `DSHConversationView`
    同文件，避免改生成式 pbxproj）：未获焦 = 胶囊（+ 左、发送右，无模型按钮）；`@FocusState` 获焦 = 展开
    （上打字、下 + 模型 发送），收起键盘/失焦变回胶囊、草稿保留。运行中且输入为空，发送位变停止
    （`stop-fill`，调 `gateway.cancelTurn()`）；未连接时 +、模型、发送都变灰不可点。`+`、模型各弹一个
    `.medium/.large` 半屏 sheet，只有标题「添加」/「模型」和「即将上线」占位。键盘弹起时输入框底距键盘 8。
  - `apps/ios/DSHKit/Sources/DSHKit/DSHGateway.swift`：新增 `cancelTurn()`，发 `session-cancel`（协议 #18）。
    （**说明**：任务说「接现有的取消逻辑」，但 DSHGateway 原本没有任何取消实现，`session-cancel` 全仓从未
    发送过；停止按钮要能用（验收第 7 条）就必须补这一条最小发送。只发请求，收尾仍以 `turn/end` 为准，
    不新增其它功能。）
  - `CHANGELOG.md`：本节。
- **实际用的尺寸（一倍图 pt）**：外边距 16；胶囊高/按钮行高 48（`Size.bar.hitTarget`）；圆角 24；框内按钮
  compact 36（`Size.compact.side`）、离框边 6、间距 6；`+`/模型图标 24（`Size.bar.glyph`）、发送实心圆箭头 20；
  展开打字区内边距 12；文字 `.body` 17pt、1…6 行后框内滚动；键盘弹起底距 8、否则 12。所有能用的尺寸/玻璃/
  字号都走现有 token；圆角 24 与箭头 20 本仓没有对应 token，收在上述 `Layout` 与 `sendGlyph` 两个单点常量。
- **与方案不一样的地方**：
  - **胶囊态不显示模型按钮**。方案线框图 `01` 的空胶囊里画了模型按钮，但穗本轮原话是「chat 页没获焦时跟 bot
    页一样：左边加号、右边发送」，所以模型按钮只在**展开**后出现。若你要胶囊里也一直有模型按钮，告诉我，改动很小。
  - **状态行到输入框顶约 16pt，不是 24pt**。按「不改状态行」，我没动 `ConversationStatusLine` 的下边距（10），
    加上输入框自身的上边距 6 = 16。要做到 24，需要动状态行下边距或输入框上边距（后者会把回到底部按钮从 36
    顶到 44）。请拍板是否要调。
  - **附件条、引用条仍在框外上方**，没有搬进框内（方案把「附件行进框内」列为【建议】，本轮只做写到的建议，且穗说
    「照旧能用」，所以保持原位置）。
  - `DSHComposer` 放在 `DSHConversationView.swift` 里而不是新文件，因为 app target 的 pbxproj 是 XcodeGen 生成的，
    新文件要重新生成工程；挪进已有文件避免工程文件的无关 diff。
  - 模型按钮图标用 Remix `robot-2-line`（通用模型图标；本仓没有更贴切的提供方图标来源）。
  - `ConversationComposer` 的胶囊/展开切换用现有 `Motion.layout`（`spring(duration:0.3,bounce:0)`）作为「系统
    spring」，没有另造动画曲线。
- 边界：不改消息气泡、状态行、顶部栏、右上角「更多」；不填加号/模型 sheet 内容、不接模型切换；不加语音；不加
  依赖、测试 target；不改 Package.swift/project.yml/pbxproj；C0212–C0218 的发送状态、草稿冻结、事件投影、图片
  显示均未动。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`（真机
  destination、ui-preview 覆盖、构建号 213）编译通过，0 error；仅未改文件的既有警告。`xcrun devicectl device
  install app` 装到 iPhone 16 Pro（`00008140-000A31311AE3001C`，`com.suiyikou.codync.uipreview`，2.36.0 / 213）
  成功。按穗要求**只编译不自测**，八项真机场景留给穗操作。构建与安装记录在 `/tmp/codync-audit/c0219-build.log`、
  `c0219-install.json`。
- 关联：布局方案 `~/Downloads/布局方案.md` 及线框图（`00` 结构、`01`–`03`、`10` 机器人页）；备份 tag
  `backup/before-new-composer-c0219`（`3bc3e9a6`，含 C0218）。回滚可 revert 本次提交，回到三处分离的旧输入框与
  无展开的 DSH 输入；不改协议、无数据迁移，`cancelTurn` 属新增但可随本次一并撤掉。

### C0220 · 2026-11-05 · 修 chat 会话页点输入框卡死

- 原因（已定位到具体代码）：`apps/ios/Kit/Sources/CodyncUI/Thread/ConversationComposer.swift` 的
  `frame`（C0219 写的）用 `Group { switch mode { case .capsule: capsule; case .expanded: expanded } }`
  在两种形态间切换，而 `capsule`（`HStack`）和 `expanded`（`VStack`）两个分支**各自引用了同一个 `field`
  （即 TextField 的 `AnyView`）**。同一个 View 值放在条件编译的两个不同分支里，就是 SwiftUI 眼里的
  **两个不同结构位置**，也就有两个不同的身份。于是点输入框获焦 → `mode` 变 `.expanded` → 分支切换，旧的
  TextField 被销毁、新的被重建 → 焦点丢失（`@FocusState focused` 被置回 false）→ `mode` 变回 `.capsule`
  → 又切分支、再重建 → 重建出来的 TextField 因为绑定仍要求获焦而再次拿到焦点……`focused` 每帧在
  true/false 之间来回，`frame` 又对 `mode` 挂了 `.animation(Motion.layout, value: mode)`，展开/收起动画
  永远播不完，SwiftUI 一直重排，App 就卡死。bot 页 `mode` 恒为 `.capsule`，从不切分支，所以正常——和
  「bot 页没事、只有 chat 页卡」的现象完全对上。
- 变化：只改 `ConversationComposer.swift` 的 `frame`。把输入框固定成**同一个实例**：`VStack` 里始终是
  同一个 `HStack { leading; field; trailing }`，`field` 永远是它中间那个孩子、位置不变（身份不变）。切换
  形态只改外层几何：
  - 胶囊：`leading`/`trailing` 在 `field` 两侧正常显示，`HStack` 内边距 6、最小高 48。
  - 展开：`leading`/`trailing` 的宽度收到 0（`opacity 0` + `clipped`，但仍留在树里，保证 `field` 位置不动），
    `field` 变整行（上内边距 12、左右 12），并在 `HStack` **之后**追加一行 48 高的按钮行（左加号、右模型+发送）。
  `mode` 变化只改修饰符数值和追加一个后置兄弟节点，不再换分支，所以 TextField 全程不销毁、不重建，焦点
  不再抖，循环消失。胶囊视觉与 C0219 保持一致（`frame(minHeight:48)` 把 36 的按钮/输入垂直居中=上下各 6）；
  展开视觉也与设计一致（打字区 12、按钮行 48、按钮离边 6）。
- 未改动：`DSHConversationView.swift` / `DSHComposer`（两态切换、按钮可用性、两个 sheet、停止/未连接逻辑
  原样）、bot 页 `Composer.swift`、`GlassButton`、`DSHKit`。没有改设计：未获焦是胶囊（左加号、右发送，空
  输入发送置灰），点输入框展开成方框（上打字、下左加号右模型+发送），收起键盘回胶囊、文字保留；bot 页仍
  一直是胶囊。
- 边界：只修这一处死循环，没有顺手改别的；不加依赖、测试 target，不改 Package.swift/project.yml/pbxproj。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`
  （`generic/platform=iOS` 与真机 destination）均 **BUILD SUCCEEDED，0 error**，构建号 214。装机时设备
  tunnel 多次失败（`The tunnel connection failed`，与 C0216 同款环境问题），已产出包在
  `build/dd/Build/Products/DevDebug-iphoneos/`；若后台重试仍未装上也只需手机解锁/同 Wi-Fi 后一条
  `devicectl device install app` 即可。按穗要求不跑测试、不截图、不自测。
- 关联：根因由 C0219（`a432069b`）引入；备份 tag `backup/before-composer-hang-c0220`（`7ffd963b`，含
  C0219）。回滚可 revert 本次提交，回到 C0219 的两分支结构（会重新出现卡死），不建议。

### C0221 · 2026-11-05 · bot 页和 chat 页底部统一成一套组件

- 原因：穗定了两个会话页共用一套底部组件，chat 页只在这套组件上扩展。但现在两个页面还是各写一套：输入框
  各自包一层、键盘/底部间距各写一份、状态行的上下内边距在两个文件里各写一遍、回到底部箭头的间距是个散落的
  字面量。尤其两边的「输入框下面的底部间距」不一致（bot 页 28、chat 页 12），bot 页还对输入框用了
  `.ignoresSafeArea(.bottom)`，导致 bot 页的回到底部箭头顶得比 chat 页高，两页看起来不一样。
- 改动前两页底部各用了什么（文件:行号，均为改动前 HEAD `8ff39487`）：
  - **bot 页（Coe）**
    - 输入框：`Composer.swift:122-129` 包 `ConversationComposer(... mode:.capsule, bottomPadding: keyboardUp ? 12 : 28)`；
      键盘状态 `Composer.swift:34`、监听 `:132-137`；`Composer.swift:155` `.ignoresSafeArea(.container, edges: keyboardUp ? [] : .bottom)`。
    - 回到底部箭头：`ConversationList.swift:405-420` 的 `JumpToLatest`，`.padding(.bottom, 30)`（`:409`）。
    - 状态行：`ThreadView.swift:356-358` `ConversationStatusLine(bot:title:)` + `.padding(.top,12).padding(.bottom,10)`。
    - 列表：`ThreadView.swift:326-364` `ChatTranscriptList`→`ConversationList`。
  - **chat 页（DSH）**
    - 输入框：`DSHConversationView.swift:230-236` 包 `ConversationComposer(... mode: focused ? .expanded : .capsule,
      bottomPadding: keyboardUp ? 8 : 12)`；键盘状态 `:215`、监听 `:237-242`；**没有** `ignoresSafeArea`。
    - 回到底部箭头：同 `ConversationList.swift:409` 的 `JumpToLatest`（两页本来就用同一个箭头组件、同一个 30）。
    - 状态行：`ChatTranscript.swift:148-155` `ConversationStatusLine(title:){SourceAvatar}` + `.padding(.top,12).padding(.bottom,10)`。
    - 列表：`ChatTranscript.swift:57-61` `ChatTranscriptList`→`ConversationList`。
  - **两边共用的**：`ConversationComposer`（C0219/C0220）的 `Layout.side=16`、`minHeight=48`、`cornerRadius=24`；
    `ConversationList` 里的 `JumpToLatest`；`ConversationStatusLine`。
- 哪些重复 / 数值不一致：① 底部间距 28 vs 12、键盘间距 12 vs 8、`ignoresSafeArea` 只有 bot 页有 → 箭头到输入框
  顶的距离两页不一样（bot 更高）；② 状态行的 `.padding(.top,12).padding(.bottom,10)` 在 `ThreadView` 和
  `ChatTranscript` 各写一份；③ 箭头的 `30`、输入框的 16/48 都是散落字面量，没有一组共享常量。
- 变化：
  - 新增 `apps/ios/Kit/Sources/CodyncUI/Thread/ConversationBottomBar.swift`：
    - `ConversationBottomMetrics`：一整套共有常量——`sideMargin 16`、`inputHeight 48`、`composerTopPadding 6`、
      `restingBottomPadding 12`、`keyboardBottomPadding 8`、`jumpGap 36`（+ 派生 `jumpPadding = 36−6 = 30`）、
      `statusTopPadding 12`、`statusInputGap 24`（+ 派生 `statusBottomPadding = 24−6 = 18`）。
    - `ConversationBottomBar`：**共用的底部组件**。它包住 `ConversationComposer`，统一负责底部间距策略与键盘观察
      （弹起 8 / 收起 12），两页只通过参数传自己的 `mode`、`leading`/`field`/`trailing` 和一个可选 `accessory`。
  - `Composer.swift`（bot 页）：改用 `ConversationBottomBar(mode:.capsule, accessory:…, leading:…, field:…, trailing:…)`；
    删掉自己的 `keyboardUp`、键盘监听、`bottomPadding` 和 `.ignoresSafeArea` 那行。加号菜单、引用、附件、发送/停止、
    草稿、IME 等全部原样。
  - `DSHConversationView.swift`（chat 页的 `DSHComposer`）：改用 `ConversationBottomBar(mode: focused ? .expanded : .capsule,
    …)`；删掉自己的键盘状态与监听。两态切换、按钮可用性、停止/未连接、两个占位 sheet 全部原样；模型按钮仍只出现在
    展开态的 `trailing` 里（扩展点），bot 页不传。
  - `ConversationComposer.swift`：`Layout.side/minHeight/buttonRowHeight` 改为读 `ConversationBottomMetrics`（同一组常量的
    源头）；C0220 的「单一 TextField、不在布局里改状态」写法一行未动。
  - `ConversationList.swift`：箭头的 `.padding(.bottom, 30)` 改成 `ConversationBottomMetrics.jumpPadding`。
  - `ThreadView.swift` / `ChatTranscript.swift`：状态行的上下内边距改用 `ConversationBottomMetrics.statusTopPadding` /
    `statusBottomPadding`（两页同一处常量）。
- 与设计的差异 / 可见变化（都是按「统一 + 已定数值」的结果，请确认观感）：
  - bot 页输入框下方的底部间距从 28 改成 12、并去掉了 `.ignoresSafeArea(.bottom)`，与 chat 页一致 → bot 页
    回到底部箭头从原来的「偏高」降到与 chat 页相同的 **离输入框顶 36**。
  - 状态行到输入框顶从原来的 16 统一到 **24**（穗在 C0219 已定为 24）：两页状态行都会比原来高约 8pt。
  - 底部仍然透明（输入框无底色、只有玻璃），消息照旧从后面透出；输入框高 48、左右边距 16 不变。
  - chat 页展开仍是「上打字、下左加号右模型+发送」，收起回胶囊；bot 页只有加号+发送，没有模型/语音。
- 边界：只做统一，没加新功能；加号/模型 sheet 内容仍是占位、未改；不改消息气泡、顶部栏、加号行为；不加依赖、
  测试 target；不改 Package.swift/project.yml/pbxproj（新文件在 SPM 的 `Kit/` 下自动纳入）。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`（`generic/platform=iOS`
  与真机 destination）均 **BUILD SUCCEEDED，0 error**，构建号 215；`xcrun devicectl device install app` 装到
  iPhone 16 Pro（`00008140-000A31311AE3001C`，`com.suiyikou.codync.uipreview`，2.36.0 / 215）成功。按穗要求
  **不跑测试、不截图、不自测**，观感留穗验收。
- 关联：组件源头 C0219（`a432069b`）、C0220（`8ff39487`）；备份 tag `backup/before-unified-bottom-c0221`（`e7d10fec`，
  含 C0219/C0220）。回滚可 revert 本次提交，两页恢复各自一套底部间距（箭头高度会再次不一致）。

### C0222 · 2026-11-05 · 底部输入框位置改回和首页对齐

- 原因：C0221 为了统一两页把输入框下方的底部间距从 28 改成 12、并去掉了 bot 页的
  `.ignoresSafeArea(.bottom)`，输入框整体往上移，和首页底部搜索栏对不齐了。穗没要求移动输入框位置。
- 首页搜索栏的基准（改动前，`apps/ios/Views/HomeSourcesView.swift`）：底部栏 `bottomBar` 的修饰符在
  `:542-545`——`.padding(.horizontal,16)`、`.padding(.top,6)`、`.padding(.bottom, keyboardUp ? 12 : 28)`、
  `.ignoresSafeArea(.container, edges: keyboardUp ? [] : .bottom)`；键盘监听 `:550-556`。即：静止时玻璃底边
  距屏幕物理底边 **28**，键盘弹起时 12，且忽略底部安全区。
- 变化：
  - `ConversationBottomMetrics`：`restingBottomPadding` 由 12 改回 **28**（键盘态的 `keyboardBottomPadding`
    保持 **8**，按本轮要求不变）。首页底部栏改为读同一组常量——`sideMargin(16)`、`composerTopPadding(6)`、
    `restingBottomPadding(28)` 不再写字面量（首页键盘态的 12 保持原样）。两页输入框的静止位置因此与首页一致。
  - **底部安全区的写法**：把 `.ignoresSafeArea(.container, edges: .bottom)` 从「输入框自己」挪到「会话内容的
    容器」上——`ThreadView.swift` 的 `chat`（transcript）与 `DSHConversationView.swift` 的 body（`ChatTranscriptView`），
    在 `.safeAreaInset` 之前加这一行；`ConversationBottomBar` 自己的 `.ignoresSafeArea` 去掉。
    原因：若把 `.ignoresSafeArea(.bottom)` 放在 `safeAreaInset` 里的输入框上，安全区会被「撑大」一个 home
    indicator 的高度，内容底边被抬高，回到底部箭头和状态行就会离输入框顶过远（这正是 C0221 之前「bot 页箭头
    很高」的成因）。把忽略安全区放在内容容器上，输入框玻璃底边同样落在「物理底边 −28」，**和首页完全一致**，
    而内容底边不再被撑大，箭头和状态行按内容底边算就正好是 36 / 24。
  - 回到底部箭头、状态行不动：仍是 `ConversationBottomMetrics.jumpPadding`（=36−6=30 → 离输入框顶 36）与
    `statusBottomPadding`（=24−6=18 → 离输入框顶 24）。**没有靠挪输入框来对齐箭头。**
  - 共用组件结构、胶囊/展开两态、C0220 的单一 TextField 写法、透明底，全部未改。
- 与任务字面写法的差异：任务说「bot 页恢复 bottomPadding 28 + 在输入框上加 .ignoresSafeArea(.bottom)」。我保留了
  28 这个数值与「忽略底部安全区」的行为，但把忽略安全区放在**内容容器**而不是**输入框**上——两者得到相同的
  输入框静止位置（玻璃底边距物理底边 28，与首页重合），差别只在于后者会让 `safeAreaInset` 的保留高度被
  home indicator 撑大、把箭头/状态行顶高。这样同时满足「输入框和首页重合」「箭头 36」「状态行 24」三条。
- 边界：只改底部位置与这套常量；不改加号/模型 sheet 内容、不加新功能、不改消息气泡/顶栏；不加依赖、测试 target；
  不改 Package.swift/project.yml/pbxproj。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`（`generic/platform=iOS`
  与真机 destination）均 **BUILD SUCCEEDED，0 error**，构建号 **216**；`xcrun devicectl device install app` 装到
  iPhone 16 Pro（`00008140-000A31311AE3001C`，`com.suiyikou.codync.uipreview`，2.36.0 / 216）成功。按穗要求
  **不跑测试、不截图、不自测**，观感留穗验收（尤其「首页↔会话页重合」和「箭头 36」两项）。
- 关联：C0221（`69568869`）、C0219/C0220；备份 tag `backup/before-bottom-align-c0222`（`294b9a85`）。回滚可
  revert 本次提交，回到 C0221 的「输入偏上」状态。

### C0222b · 2026-11-05 · 回退 C0222 的错误改法，按首页写法重做底部对齐

- 现象（穗真机）：bot 页和 chat 页点输入框打字几下就闪退、发消息几秒后闪退；底部状态行和回到底部箭头掉到
  输入框下面、箭头比输入框还低；刚发出的气泡被输入框压住；bot 页输入框玻璃外框消失、发送位置多一个灰色圆圈、
  停止按钮和占位文字叠在一起。
- 崩溃原因（代码定位，非猜测）：C0222 把 `.ignoresSafeArea(.container, edges: .bottom)` 放在了
  **transcript（`safeAreaInset` 里面那一层）** 上——`ThreadView.swift` 的 `chat`、`DSHConversationView.swift` 的
  body。这样滚动内容与安全区 inset 每帧互相触发重新布局：打字时输入框高度每变一次就重排一次，形成布局自激，
  最终主线程被拖死 / 触发 watchdog 闪退；同时浮层（`JumpToLatest` 箭头、状态行）和 `safeAreaInset` 的定位被
  打乱，于是箭头/状态行掉到输入框下方、玻璃外框丢失（灰色圆圈是回到底部箭头被错位画到了发送位置）。bot 页
  `mode` 不变也照样闪退，因为问题在 transcript 层，与模式无关——与「两页都闪退」一致。
  **设备崩溃日志已核对**（`devicectl device copy from --domain-type systemCrashLogs` 拉取，机型
  Sully Coe / iOS 27.3）：事故时段共 4 份 `bug_type 309` 崩溃，`build_version` 都是 **216（即 C0222）**，
  同一堆栈：`EXC_BREAKPOINT / SIGTRAP`（`_assertionFailure`），**主线程**，`-[UICollectionView
  _updateVisibleCellsNow:]` 连续出现 **100 次**（`_invalidateLayoutWithContext` →
  `UICollectionViewCompositionalLayout _didPerformUpdateVisibleCellsPassWithLayoutOffset` → `_updateVisibleCellsNow`
  自递归），最终 UIKitCore 抛出 Swift 断言失败。即：transcript 的 collection view 在「更新可见 cell」过程中被
  反复 invalidate layout，递归 100 层后断言崩溃——正是 C0222 把 `.ignoresSafeArea` 放在 transcript 上、每帧
  触发布局重算导致的。崩溃 .ips 已拉存 `/tmp/crashlogs/Sully Coe-2026-11-05-1225*.ips`。
- 修复：按穗要求**回退 C0222 的改法**，改为和首页底部搜索栏**完全相同的写法**——把底部安全区逃逸放在**输入框
  （bar）自己**上，而不是 transcript 上：
  - `ConversationBottomMetrics.restingBottomPadding` = 28；`ConversationBottomBar` 自身加
    `.ignoresSafeArea(.container, edges: keyboardUp ? [] : .bottom)`（与 `HomeSourcesView.swift:542-545` 的首页
    底部栏逐字一致：`sideMargin 16 / composerTopPadding 6 / 静止 28 / 键盘忽略策略`）。
  - `ThreadView`、`DSHConversationView` 恢复 C0222 之前（无 transcript 级 `.ignoresSafeArea`）。
  - 首页底部栏改读同一组常量（`sideMargin`/`composerTopPadding`/`restingBottomPadding`），不再写字面量。
  - 层级恢复：消息列表（`safeAreaInset` 预留输入框高度，最后一条不被压住）→ 回到底部箭头（离输入框顶 36）→
    状态行（离输入框顶 24）→ 输入框 → 与首页底部搜索栏对齐的底边。输入框外观回到 C0221：玻璃外框、左加号、
    右发送/停止，无多余灰圆。
  - 不动：共用组件结构、胶囊/展开两态、C0220 单一 TextField、C0216/C0217 串流、bot 页功能；不加任何新功能。
- 边界：本次只修 C0222 引入的崩溃/层级/外观/对齐，未动 C0223 的任何功能（C0223 仍暂停）。
- 验证：`xcodebuild build -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug`
  （`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，构建号 **217**；`xcrun devicectl device install app`
  装到 iPhone 16 Pro（`00008140-000A31311AE3001C`，`com.suiyikou.codync.uipreview`，2.36.0 / 217）成功。按穗要求
  不跑测试、不截图。
- 关联：C0222（`0726b46b`，本次回退其代码改法）、C0221（`69568869`）、C0219/C0220；备份 tag
  `backup/before-bottom-align-c0222`（`294b9a85`，C0222 前）。回滚本次即回到 C0222 的崩溃状态，不建议。

### C0222c · 2026-11-05 · 输入框按钮间距回 6、置底箭头回 32

- 现象（穗真机核对）：① 输入框高 48、按钮 36，按理四边间距都是 6，但加号左侧、发送右侧实测是 10；② 回到底部
  箭头离输入框顶约 74，不是 32。
- 根因：
  1. **10 不是 6**：`Composer.swift` 里给 Coe 的加号/发送套了一个 `ControlMetrics.Size.compact.hitTarget = 44`
     宽的点击框，36 的圆在 44 的框里居中，左右各多出 (44−36)/2 = 4pt，再叠加胶囊的 6pt 内边距 → 10。间距应只由
     内边距决定，点击框不该占布局宽度。
  2. **74 不是 32**：输入框为对齐首页用了 `.ignoresSafeArea(.bottom)`，`safeAreaInset` 预留的高度因此包含
     home indicator 那一段（约 34pt），内容底边被抬高；箭头是按「内容底边 − 常数」定位的，于是被顶到 ~74。这是
     和机型相关的 inset，不能用固定常数硬减。
- 变化（只改这三处，不动层级/外观/其他）：
  - `Composer.swift`：加号与发送/停止按钮的**布局宽度**从 44 改为 36（`compact.side`），点击响应区仍用
    `.contentShape` 覆盖圆本身。胶囊四边间距回到 **6**。删掉不再用的 `buttonHitSize`。
  - `ConversationBottomMetrics.jumpGap` 改为 **32**。
  - `ConversationList.swift`：`JumpToLatest` 的定位改为按**实测底部 inset** 反算——
    `gapPadding = restingBottomPadding(28) + inputHeight(48) + jumpGap(32) − inset`，其中
    `inset = fullFrame.maxY − safeFrame.maxY`（列表已有的两处 GeometryReader 测量）。用 `.offset(y: -gapPadding)`
    （正负都能处理，inset 大时 gapPadding 为负，箭头落进那段空隙），保证箭头底边离输入框顶恰好 **32**，换机型也对。
- 已知未处理（本次穗只点了箭头与按钮间距）：**状态行**同样受这个 inset 影响（C0222b 让它从 24 变成约 58）。是否
  用同一个实测修正把状态行也调回 24，等穗确认（改法与箭头相同，一行参数）。
- 边界：不改层级、外观、共用组件结构、胶囊/展开两态、C0220 单一 TextField、串流；不加新功能。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，
  构建号 **218**；已装到 iPhone 16 Pro（2.36.0 / 218）。不跑测试、不截图。
- 关联：C0222b（`d930dd6d`）、C0221（`69568869`）。

### C0222d · 2026-11-05 · 状态行到输入框的间距改回 24（实测修正）

- 背景：穗确认「头像 + 正在处理/正在输入中」那一行就是状态行，它的间距和置底箭头同一个来源，C0222b 之后
  从设计的 24 变成约 58。
- 变化（只改状态行定位，不动别处）：
  - 状态行不再由 `ThreadView`/`ChatTranscriptView` 各自当普通列表行去画（那两处拿不到底部 inset，只能写死
    padding）。改为把状态行交给 `ConversationList`（用 `status:` 参数），由它作为最后一行渲染。
  - `ConversationList` 已有 `fullFrame`/`safeFrame` 实测，按与箭头相同的公式算状态行的下边距：
    `statusInputGap(24) + restingBottomPadding(28) + inputHeight(48) − inset`，保证状态行底边离输入框顶
    **24**，换机型也对。
  - `ChatTranscriptList` 增加 `status:` 透传；`ChatTranscriptView`、`ThreadView` 把状态行内容（`ConversationStatusLine`）
    作为 `status` 传入、不再塞进普通 rows。
- 边界：不改箭头（C0222c 已到 32）、按钮间距（已 6）、层级、外观、胶囊/展开两态、C0220 单一 TextField、串流；
  不加新功能。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，
  构建号 **219**；已装到 iPhone 16 Pro（2.36.0 / 219）。不跑测试、不截图。
- 关联：C0222c（`97bcfe26`）、C0222b（`d930dd6d`）。

### C0222e · 2026-11-05 · 状态行改为放在底部栏、输入框正上方（修正 C0222d）

- 现象（穗截图）：C0222d 之后，状态行（头像 + 「正在处理…」）被输入框盖住一大截，头像也丢了，「24 像 -24」。
- 原因：C0222d 把状态行做成列表最后一行、用一个**负的 bottom padding** 想把它推进「内容底边与玻璃之间的空隙」。
  负 padding 会压缩 cell 高度、让内容溢出并被裁掉，而且那段空隙（约 40pt）本来就不够放 24 高的状态行——于是
  被推进输入框、头像被裁。
- 修法（正确的位置）：状态行不再当列表行，而是放进 `ConversationBottomBar` 的 VStack、**输入框玻璃正上方**：
  - `ConversationBottomBar` 增加 `status:` 参数，body 变成 `VStack { status.padding(.bottom, statusInputGap −
    composerTopPadding).padding(.horizontal, sideMargin); ConversationComposer(...) }`。
  - 因为它是在 `safeAreaInset` 里、属于底部栏的一部分，列表会**为它预留高度**：最后一条消息停在状态行上方，
    状态行不可能被输入框盖住；状态行底边离玻璃顶 = (24−6) + 玻璃自身 topPadding(6) = **24**；头像完整不裁。
  - `Composer`（bot 页）与 `DSHComposer`（chat 页）各增加 `status:` 透传；`ThreadView`、`DSHConversationView`
    把 `ConversationStatusLine` 作为 status 传入（`working` 时才有）。
  - `ConversationList` / `ChatTranscriptList` / `ChatTranscriptView` 撤销 C0222d 那套「把状态行塞进列表」的
    临时改动（回到不渲染状态行）。
- 不变：箭头 32（C0222c）、按钮四边 6（C0222c）、层级、外观、胶囊/展开两态、C0220 单一 TextField、串流。
- 边界：只调整状态行的位置与归属，不加新功能。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，
  构建号 **220**；已装到 iPhone 16 Pro（2.36.0 / 220）。不跑测试、不截图。
- 关联：C0222d（`8ea744aa`，本次取代其做法）、C0222c（`97bcfe26`）。

### C0222f · 2026-11-05 · 未获焦时输入框缩窄（318），获焦展开到 358

- 需求：默认（未获焦 / 往下滑看历史）输入框窄一点，点输入框唤键盘时展开回满宽；bot 页与 chat 页手感一致。
- 变化：
  - `ConversationBottomMetrics` 增 `collapsedExtraSideInset = 20`：未获焦时左右各多缩 20（边距 16→36，宽 358→318，
    居中）；获焦时回到 16（358）。
  - `ConversationComposer` 增 `focused` 输入，玻璃框左右边距按 `focused ? 16 : 36` 取值，并对 `focused` 挂
    `Motion.layout` 动画（键盘弹起/收起时平滑变宽变窄）。附件/引用条仍按 16（不跟着缩）。
  - `ConversationBottomBar`、`Composer`（bot 页）、`DSHComposer`（chat 页）逐层透传 `focused`。两页都用同一条
    规则：未获焦窄、获焦宽。bot 页形状仍是胶囊，只是宽度随焦点变。
- 不变：胶囊/展开两态、按钮四边 6、箭头 32、状态行 24、层级、外观、C0220 单一 TextField、串流。
- 边界：只改输入框在未获焦/获焦时的宽度，不加新功能。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，
  构建号 **221**；已装到 iPhone 16 Pro（2.36.0 / 221）。不跑测试、不截图。
- 关联：C0222e（`f5a96dad`）、C0221 共用底部组件。

### C0223a · 2026-11-05 · chat 页加号 sheet：照片/拍照 → 发图

- 说明：C0223 继续。本组只做**图片附件**（复用 C0218 已有的 `DSHImageProcessor` 与 `message.images` 后端），
  分块文件上传、命令/技能菜单等放后续提交（C0223a2 起）。
- 变化（只动 chat 页的加号 sheet 与输入区附件，不碰底部布局/宽度/按钮/箭头/状态行/串流）：
  - 加号 sheet（`DSHAddSheet`）：把原来的占位换成「照片」「拍照」两个入口；网关 `hello` 没有 `images`
    capability 时两个入口置灰并提示"不支持发图片"。照片用 `PhotosPicker`（仅图片，最多 20 张），拍照走
    `\.capturePhoto`。选/拍完的图经 `DSHImageProcessor.prepare`（长边 2000/40MP/3.67MB，HEIC 转 JPEG 等）
    处理后进入待发。
  - 待发缩略条：选好的图片在输入框上方显示 64×64 缩略图，每张右上角 ✕ 可移除，准备/压缩中显示进度。它是
    共用底部组件的 `accessory` 槽（在玻璃上方、属于底部栏，列表为其预留高度，不遮消息）。
  - 发送：`send()` 改为 `gateway.send(text:images:)`，图片与文字一起发（纯图也可发）；成功后清空草稿与待发图。
    `canSend`/`showsStop` 已把"有待发图片"计入。
- 能力开关：无 `images` → 加号 sheet 的图片入口置灰、不报错。
- 「未确认」/未做：分块文件上传（`file-upload-*`）、视频、命令/技能、模型面板、更多菜单、会话内目标/任务/排队/
  审批/提问/文件卡/工具结果图/重试/压缩提示——均按后续 C0223 子提交继续。
- 边界：不改 bot 页；不改底部输入框设计（胶囊/展开、318↔358、按钮 6、箭头 32、状态行 24、C0220 单一
  TextField）；不改串流。不加依赖/测试 target。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，
  构建号 **222**；已装到 iPhone 16 Pro（2.36.0 / 222）。不跑测试、不截图。
- 关联：C0218（图片后端 `DSHImageProcessor`/`message.images`）、C0221 共用底部组件 `accessory` 槽。

### C0223b · 2026-11-05 · chat 页命令与技能（加号 sheet + `/` 过滤菜单）

- 说明：C0223 第二组。命令数据完全按网关 `commands{sessionId, locale:"zh-CN"}` 返回动态渲染，不写死。
- 变化（只动 chat 页加号 sheet、输入区的 `/` 菜单与命令处理；不碰底部布局/宽度/按钮/箭头/状态行/串流）：
  - `DSHGateway`：新增 `supportsCommands`（capability `commands`）、`commandGroups`（发布）、`loadCommands()`
    （发 `commands` 请求，等 `commands` 回复，按 `groups[].items[]` 解出 `{id,name,description,ui.kind,
    ui.insertText,ui.submitText,ui.images}`）；`executeCommand(line)`（`command-execute`）；`commandOptions(for:)`
    （`command-options`）与 `selectCommandOption`（`command-select`）。加了一套「发请求→等对应回复帧」的挂起机制
    （`requestFrame`，一次一个、UI 串行），断线时以 error 收尾避免悬挂。
  - `DSHModels`：新增 `DSHCommand` / `DSHCommandGroup` / `DSHCommandOption`。
  - 加号 sheet（`DSHAddSheet`）：在图片两项下面按 `groups` 渲染「命令」「技能」两组（`/plan /goal /compact`
    若存在则置顶，其余保持原顺序；`select` 类带 `›`）。点按按 `ui.kind` 处理：`immediate` 直接 `command-execute`；
    `input` 把 `insertText` 填进输入框让读者补全再发；`select` 打开二级选项（`command-options` → `command-select`）。
  - 输入框里打 `/`：输入框上方弹出同样的命令/技能列表，按已输入内容过滤（去重、最多 12 条）。
  - 能力开关：网关没有 `commands` capability 时不显示命令区、也不弹 `/` 菜单。
- 边界：不改 bot 页；不改底部输入框设计；不改串流。不加依赖/测试 target。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，
  构建号 **223**；已装到 iPhone 16 Pro（2.36.0 / 223）。不跑测试、不截图。
- 关联：C0223a（图片附件同属加号 sheet）、C0221 共用底部组件 `accessory` 槽。

### C0223a2 · 2026-11-05 · chat 页文件附件（分块上传）

- 说明：C0223 第三组，把加号 sheet 的文件附件补齐，走网关分块上传。
- 变化（只动 chat 页加号 sheet、输入区附件卡与发送；不碰底部布局/宽度/按钮/箭头/状态行/串流）：
  - `DSHGateway`：新增 `supportsFileUpload`（capability `file-upload-v1`）与 `fileUploads`（发布，进度卡数据）。
    `uploadFile(data:name:)` 依次 `file-upload-open`（带 sha256/size）→ 循环 `file-upload-chunk`（按响应
    `chunkBytes` 分块、按 `nextOffset` 更新进度）→ `file-upload-finish` 拿 `receiptId`；失败置 failed 可重试。
    `retryFileUpload`/`removeFileUpload`。断线把在途上传标失败、并让挂起请求以 error 收尾。
    `send(text:images:files:)` 支持 `files:[DSHOutgoingFile]` → `message.files:[{receiptId}]`（`requestId` 始终带）；
    `DSHSubmission` 冻结 files，重试/重发沿用同一批 receiptId。上传与命令共用「发请求→等回复帧」机制（一次一个）。
  - `DSHModels`：新增 `DSHOutgoingFile`（name+receiptId）、`DSHFileUpload`（progress/status/receiptId/error）。
  - 加号 sheet 增「文件」入口（`fileImporter`，可多选）；`file-upload-v1` 缺省时置灰。
  - 输入框上方文件卡：文件名、大小、上传进度条；失败显示原因+重试；每张可移除（✕）。与图片缩略条共处同一
    `accessory` 槽。
  - 发送：仅把**上传完成（ready）**的文件随消息发出，`canSend/showsStop` 已计入；发送成功后清掉用掉的卡片。
- 能力开关：无 `file-upload-v1` → 文件入口置灰。
- 边界：不改 bot 页、底部输入框设计、串流。不加依赖/测试 target。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，
  构建号 **224**；已装到 iPhone 16 Pro（2.36.0 / 224）。不跑测试、不截图。
- 关联：C0223a（图片）、C0223b（命令）、`message.files`/`file-upload-*` 协议见 `/tmp/codync-audit/c0223-protocol.md` #24/#25。

### C0223c · 2026-11-05 · chat 页模型 sheet（模型/思考等级/Agent 模式/权限/设为默认）

- 说明：C0223 第四组，把「模型」占位 sheet 填成真面板。数据全部来自网关。
- 变化（只动 chat 页模型 sheet 与网关请求；不碰底部布局/宽度/按钮/箭头/状态行/串流）：
  - `DSHGateway`：新增会话控制请求——
    - 模型：`loadModels()`（`models{sessionId}` 解析 `current{provider,model,reasoningEffort?}` 与
      `groups[].models[]`，含每个模型的 `reasoning.efforts[]`）；`selectModel(provider:model:reasoningEffort:)`
      （`select-model`，字段名 `reasoningEffort`）；`saveDefaultModel(...)`（`save-default-model`）。
    - Agent 模式：`loadAgentPresets()`（`agent-presets`→`presets[]{id,name,description,isDefault,broken}`）、
      `loadSessionAgentPreset()`（`session-agent-preset`→`agentPreset/locked`）、`selectAgentPreset(_:)`
      （`select-agent-preset`）；并接 `session-agent-preset-updated` 推送里的 `locked`/`agentPreset`（首轮
      `turn/start` 后锁定）。注意：`agent-preset/locked` 是**错误码**不是事件，锁定靠这个 `-updated` 推送。
    - 权限：`loadPermissionOptions()`（`permission-options`→`options[]{value,name,description}`）、
      `setPermission(_:)`（`permission`，`name`=选项 value）。
  - 上述 capability：Agent 模式用 `session-agent-preset`；`models`/`select-model`/`permission*`/`save-default-model`
    在源码里**无独立 capability**（属 hello 基线不宣告），照常请求、失败静默。
  - `DSHModels`：新增 `DSHModel/DSHModelGroup/DSHReasoningEffort/DSHCurrentModel/DSHAgentPreset/DSHPermissionOption`。
  - `DSHModelSheet`：思考等级分段（取当前模型 `reasoning.efforts`）、按 provider 分组的模型列表（当前打勾）、
    Agent 模式（`session-agent-preset` 能力有才显示，锁定/坏项置灰并写「已锁定」）、权限档位、以及「设为新会话
    默认」按钮（**二次确认** alert 后再发 `save-default-model`）。
- 边界：不改 bot 页、底部输入框设计、串流。不加依赖/测试 target。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，
  构建号 **225**；已装到 iPhone 16 Pro（2.36.0 / 225）。不跑测试、不截图。
- 关联：C0223a/a2/b、协议见 `/tmp/codync-audit/c0223-protocol.md` #4–#8。

### C0223d1 · 2026-11-05 · chat 页右上角「更多」：上下文用量 / Token 统计 / 重命名 / 归档 / 分叉

- 说明：C0223 第五组（「更多」第一批）。加号/模型之外的会话级操作入口。
- 变化（只动 chat 页右上角工具栏与相应面板/请求；不碰底部布局/宽度/按钮/箭头/状态行/串流）：
  - `DSHGateway`：新增 `loadContextUsage()`（`context-usage`）、`loadSessionStats()`（`session-stats`，返回原始
    json 供面板渲染 `sessionStats`/`tokenUsage`/`contextPressure`）、`forkSession()`（`fork`，成功返回新
    sessionId；`fork-unavailable` 提示稍后再试）、`renameSession(_:)`（`session-rename`）、`archiveSession()`
    （`session-archive`）。
  - chat 页右上角新增「更多」（省略号 `Menu`）：上下文用量、Token 统计、重命名（capability `session-rename`）、
    分叉、归档（capability `session-archive`，红色项 + 二次确认，文案「归档」）。
  - `DSHContextUsageSheet`：展示 `context-usage` 的 `tokenUsage`/`contextPressure` 键值，并有「立即压缩」按钮
    （发 `/compact` 命令）。
  - `DSHStatsSheet`：展示 `session-stats` 的 `sessionStats`/`tokenUsage`/`contextPressure` 键值（只有 token 数，
    不编造金额）。
  - 重命名：带输入框的 alert；归档：二次确认后发 `session-archive` 并收起会话；分叉：成功 `open` 新会话，
    失败弹提示。
- 「未确认」：`tokenUsage`/`contextPressure` 的**具体字段结构**网关协议未文档化，面板按字典原样逐项显示（key 为
  英文原字段名），未做语义命名；如需中文标签，请在拿到一次真实返回后我再映射。
- 待后续（C0223d2）：步骤/轨迹页、轮次导航（turn-outline）、工作区文件（file-list/下载）、本会话定时任务、
  团队与子智能体（只读）。
- 边界：不改 bot 页、底部输入框设计、串流。不加依赖/测试 target。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，
  构建号 **226**；已装到 iPhone 16 Pro（2.36.0 / 226）。不跑测试、不截图。
- 关联：C0223a/a2/b/c、协议见 `/tmp/codync-audit/c0223-protocol.md` #10–#14。

### C0223d2 · 2026-11-05 · chat 页「更多」：工作区文件 / 定时任务 / 团队（只读）

- 说明：C0223 第六组，「更多」第二批。均为请求-响应型面板。
- 变化（只动 chat 页「更多」菜单与相应 sheet/请求；不碰底部布局/宽度/按钮/箭头/状态行/串流）：
  - `DSHGateway`：`supportsFiles`(`file-downloads`)/`supportsSchedule`(`schedule-management`)/
    `supportsTeam`(`agent-team-v1`)；`listFiles(path:)`（`file-list`，按 `entries[]{name,path,kind,bytes,mediaType}`）、
    `downloadFile(path:)`（`file-download-open`→循环 `file-download-read` 到 `eof`）、`listSchedules()`/`deleteSchedule(_:)`
    （`schedule-list`/`schedule-delete`）、`loadAgentTeam()`（`agent-team` → `agentTeam.members[]`）。
  - `DSHModels`：新增 `DSHFileEntry`/`DSHSchedule`/`DSHTeamMember`。
  - 「更多」增三入口（按能力显示）：工作区文件、定时任务、团队。
  - `DSHFilesSheet`：逐级浏览（目录进入/上一级），点文件下载后就地预览（图片显示；文本按 UTF-8 显示；其它显示字节数）。
  - `DSHScheduleSheet`：列出本会话定时任务，删除带**二次确认**（`schedule-delete`），成功后刷新。
  - `DSHTeamSheet`：只读成员列表（name/role/phase）。
- 「未确认」/未做：`schedule-*` 的 `items[]`/`change` 完整字段未在协议中展开，列表只显示 `title` 与一个 `kind`/时间字段
  摘要；**编辑（schedule-update）需完整 `expected` 记录，本轮未做**，留后续。团队只读列表完成，点成员进入其会话
  （需 `parentSessionId`+`subagentMode` 子地址订阅）留后续。步骤/轨迹页、轮次导航（turn-outline）仍留 C0223d3。
- 边界：不改 bot 页、底部输入框设计、串流。不加依赖/测试 target。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，
  构建号 **227**；已装到 iPhone 16 Pro（2.36.0 / 227）。不跑测试、不截图。
- 关联：C0223d1、协议见 `/tmp/codync-audit/c0223-protocol.md` #15–#17。

### C0223e1 · 2026-11-05 · chat 页会话内：目标面板 + 任务清单

- 说明：C0223 第七组。挂在输入框上方（共用底部组件的 accessory 槽，消息为其让位、不遮消息）。
- 变化（只动输入框上方面板与网关请求；不碰底部布局/宽度/按钮/箭头/状态行/串流）：
  - `DSHGateway`：`supportsGoals`(`goals`)/`supportsTasks`(`tasks`)；`loadGoal()`（`goal`→`{goal:{id,revision,
    objective,phase,maxGoalRounds},roundsStarted}`）、`loadTasks()`（`tasks`→`todos[]{content,status}`）；写操作
    `pauseGoal/resumeGoal/clearGoal/editGoal(objective:maxGoalRounds:)`，都带最新 `ref{id,revision}`。接
    `goal-updated` / `tasks-updated` 推送刷新。请求/响应复用「发请求→等回复帧」机制（新增 goal*/tasks 到 kinds）。
  - `DSHModels`：`DSHGoal`、`DSHTodo`。
  - `DSHComposer.aboveInput`：目标面板（目标/阶段/轮次；暂停/继续、编辑、删除）+ 任务清单（可折叠，按状态图标）
    + 原有的待发文件/图片/`/`菜单，统一排在输入框上方。
  - 删除目标、编辑目标均二次确认（编辑带输入框；删除红色确认）。
- 「未确认」：目标 `phase` 取值（源码未列全，按非 "paused" 视为进行中）；`roundsStarted/maxGoalRounds` 缺失时不显示轮次。
- 待后续（C0223e2）：排队消息（session-queues/session-queue + queue-update）、压缩/重试提示（compaction*/llm/retry
  在状态行/消息流）。审批/提问卡 C0223f，文件交付卡/工具图/长按复制 C0223g。
- 边界：不改 bot 页、底部输入框设计、串流。不加依赖/测试 target。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，
  构建号 **228**；已装到 iPhone 16 Pro（2.36.0 / 228）。不跑测试、不截图。
- 关联：C0223d2、协议见 `/tmp/codync-audit/c0223-protocol.md` #18/#19。

### C0223e2 · 2026-11-05 · chat 页会话内：排队消息（编辑/删除/插话）

- 说明：C0223 第八组。运行中发的消息进"排队消息"区，挂在输入框上方。
- 变化（只动输入框上方排队区与网关请求；不碰底部布局/宽度/按钮/箭头/状态行/串流）：
  - `DSHGateway`：新增 `queuedMessages`（发布，`[DSHQueueHint]`）。在既有的 `session-queues`/`session-queue`
    推送处理里同时刷新它（只取当前打开会话）；`queueUpdate(itemId:action:text:)` 发 `queue-update`
    （action = edit|remove|steer，edit 带 text），回执不是最终态、以随后的 `session-queue` 推送为准。capability
    `queue-control`。
  - `DSHComposer.aboveInput`：新增「排队消息 · N」区，每条显示内容 + 编辑/插话/删除。
  - 编辑带输入框 alert；删除二次确认；插话（steer）直接发。
- 「未确认」：`items[].message.content` 的文本由既有 `DSHQueueHint.decode` 取 text 块拼接（沿用 C0216 的实现）。
- 待后续（C0223e3）：压缩事件提示（compaction/start·summary·end）与重试提示（llm/retry）在消息流/状态行的展示；
  步骤/轨迹、轮次导航（C0223d3）；审批/提问卡（C0223f）；文件交付卡/工具图/长按复制（C0223g）。
- 边界：不改 bot 页、底部输入框设计、串流。不加依赖/测试 target。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，
  构建号 **229**；已装到 iPhone 16 Pro（2.36.0 / 229）。不跑测试、不截图。
- 关联：C0223e1、协议见 `/tmp/codync-audit/c0223-protocol.md` #20。

### C0223f · 2026-11-05 · chat 页审批卡 / 提问卡

- 说明：C0223 第九组。收到审批/提问请求时，卡片替换输入区（底部 inset）。
- 变化（只动底部输入区在有卡时的替换与网关应答；不碰输入框本身设计/宽度/箭头/状态行/串流）：
  - `DSHGateway`：新增 `pendingApproval`/`pendingQuestion`（发布）。接推送 `approval-requested`（解出
    rpcId/approvalId/toolName/reason，`displayReason` 取 `zh-CN` 或首个字符串）、`approval-resolved`（按
    approvalId 清）、`question-requested`（questions[]{id,header,question,detail,options[{label,description}],
    multiSelect}）、`question-resolved`（清）。`respondApproval(_:outcome:)`（`allowed-once`/`rejected`，
    `approval-response`）、`answerQuestion(_:answers:)`（`question-answer`，answers=`[{id,selected,custom?}]`）、
    `cancelQuestion`（`question-cancel`）。均按 `sessionId` 过滤。
  - `DSHModels`：`DSHApprovalRequest`、`DSHQuestion`/`DSHQuestionOption`/`DSHQuestionRequest`。
  - UI：`DSHApprovalCard`（工具名 + 原因 + 「允许一次 / 拒绝」）；`DSHQuestionCard`（多题、单选/多选、自定义
    回答、「提交 / 跳过」）。二者替换输入区，键盘收起时以卡片呈现。
- 「未确认」：`displayReason` 多语言对象的取键顺序（优先 zh-CN，否则首个字符串）；`question` 的 `intent` 结构未
  使用（按普通单选/多选处理）。
- 待后续（C0223e3）：压缩/重试提示；C0223d3：步骤/轨迹、轮次导航；C0223g：文件交付卡/本地路径/工具结果图/长按复制。
- 边界：不改 bot 页、底部输入框设计、串流。不加依赖/测试 target。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，
  构建号 **230**；已装到 iPhone 16 Pro（2.36.0 / 230）。不跑测试、不截图。
- 关联：C0223e1/e2、协议见 `/tmp/codync-audit/c0223-protocol.md` #21/#22。

### C0223e3 · 2026-11-05 · chat 页压缩事件与重试提示

- 说明：C0223 第十组。把压缩/重试这类"过程"事件投影成消息流里的中性提示行。
- 变化（只动 `DSHConversationState` 的投影；不碰布局/输入框/箭头/状态行/串流）：
  - `compact/*`：`compaction/start` → 「正在压缩上下文…」；`compaction/summary` → 「已压缩历史记录（N 条，
    约 T tokens）」（`shadowedItemCount`/`shadowedTokenCount`）；`compaction/end` 仅在有 `error` 时显示
    「压缩出错：…」。
  - `llm/retry` → 「正在重试模型请求（第 N/M 次）」（`retry`/`maxRetries`）；`llm/retry-started` 不显示。
  - 实现：`project()` 新增这些 type 的 `notice` 行（复用现有 NoticeRow 中性样式），按各自 seq 定位、随消息流滚动。
- 「未确认」/偏离：任务希望"重试"显示在**状态行**；但状态行属 C0212 已定实现（不改状态行），所以本轮把重试也做成
  消息流中性提示行。要改成状态行显示需单独动 C0212 的 reducer，届时再定。重复重试会按 seq 各显示一行。
- `tool/result` 的图片：协议第 28 节确认**网关实时不输出 images** → C0223g 的"工具结果图"标「未确认/不做」。
- 待后续：C0223d3（步骤/轨迹、轮次导航）、C0223g（文件交付卡/本地路径/长按复制；工具结果图不可做）。
- 边界：不改 bot 页、底部输入框设计、串流。不加依赖/测试 target。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，
  构建号 **231**；已装到 iPhone 16 Pro（2.36.0 / 231）。不跑测试、不截图。
- 关联：C0223e1/e2、协议见 `/tmp/codync-audit/c0223-protocol.md` #26/#27/#28。

### C0223g · 2026-11-05 · chat 页交付文件提示 + 复制能力核对

- 说明：C0223 第十一组。
- 变化：
  - `DSHConversationState.project()` 新增 `deliverables/presented` → 消息流中性提示行「交付文件：a.pdf、b.txt」
    （取 `files[].path` 的文件名）。source capability `file-references-v1`。
  - 复制：DSH 的 agent 行用 `MarkdownText`（`.textSelection(.enabled)`），长按可选中/复制文字；这是既有能力，
    本轮核对确认可用，未改。
- 「未确认」/未做（按协议或范围）：
  - **工具结果图**：协议第 28 节确认网关实时 `tool/result` **不输出 images**，无法展示 → 不做（若需，只能从历史
    原始 content 块自行解析，属另一项）。
  - **交付文件的卡片样式 + 点卡片预览**：本轮只做成提示行（列出文件名），未做可点卡片（需在消息行引入新的卡片
    行类型与点击下载，较大改动，留后续）。
  - **正文里的本地路径可点 → file-resolve → 下载预览**：未做（需在 Markdown 里识别路径并接 `file-resolve`，
    留后续，标「未确认 UI」）。
  - 代码块/表格「复制为文本」：依赖 `MarkdownText` 既有行为，未单独加按钮。
- 待后续：C0223d3（步骤/轨迹页、轮次导航 turn-outline）。
- 边界：不改 bot 页、底部输入框设计、串流。不加依赖/测试 target。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，
  构建号 **232**；已装到 iPhone 16 Pro（2.36.0 / 232）。不跑测试、不截图。
- 关联：C0223e3、协议见 `/tmp/codync-audit/c0223-protocol.md` #23/#28。

### C0223d3 · 2026-11-05 · chat 页轮次导航（turn-outline，只读）

- 说明：C0223 第十二组，收尾。
- 变化：
  - `DSHGateway`：`supportsTurnOutline`(`turn-outline-v1`)；在既有 `applyTurnOutline`（原用于首页副标题）里，
    当 `sessionId == openSessionId` 时把整份大纲存进 `turnOutline: [DSHTurnOutline]`（项 `{turn,seq,prompt,response}`，
    来自 `turn-outline-updated` 推送与 `projection-baseline.values.turnOutline`）。
  - `DSHModels`：`DSHTurnOutline`。
  - 「更多」增「轮次导航」（capability `turn-outline-v1`）→ `DSHTurnOutlineSheet`：只读列出每轮「第 N 轮」+ prompt/response 摘要。
- 「未确认」/未做：
  - **点一轮精确跳到消息流对应位置**：共用 transcript 没有 scroll-to-seq API，本轮只做只读列表，未接跳转（标未确认）。
  - **步骤/轨迹页**：网关**无 `turn-outline`/trajectory 专用请求**，逐步骤 LLM 请求/工具耗时需客户端自行从 history+流聚合，
    本轮未做（隐藏，未编造）。
- 边界：不改 bot 页、底部输入框设计、串流。不加依赖/测试 target。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，
  构建号 **233**；已装到 iPhone 16 Pro（2.36.0 / 233）。不跑测试、不截图。
- 关联：C0223d2、协议见 `/tmp/codync-audit/c0223-protocol.md` #9。

### C0223d2b · 2026-11-05 · chat 页定时任务：补上编辑（schedule-update）

- 说明：补 C0223d2 里"未做"的定时任务编辑。
- 变化：
  - `DSHGateway`：`listSchedules()` 同时在内存保留每条原始记录 `scheduleRaw`；新增 `updateSchedule(_:title:prompt:)`
    —— 按协议把 `expected` 设为**完整原记录**（白名单字段 id/kind/title/prompt/scheduledAt/afterSeconds/everySeconds/
    time/timeZone/weekdays/expression），带新 `title`/`prompt` 发 `schedule-update`，以 `updated:true` 判定成功。
  - `DSHScheduleSheet`：每行加「编辑」（标题+提示词两个输入框的 alert），保存后重新拉列表；删除仍二次确认。
- 边界：不改 bot 页、底部输入框设计、串流。不加依赖/测试 target。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，
  构建号 **234**；已装到 iPhone 16 Pro（2.36.0 / 234）。不跑测试、不截图。
- 关联：C0223d2、协议 `/tmp/codync-audit/c0223-protocol.md` #16。

### C0223g2 · 2026-11-05 · chat 页交付文件卡片（可点下载预览）

- 说明：把 C0223g 里"交付文件只做提示行"升级为可点卡片。
- 变化（跨 CodyncUI 与 DSHKit，均沿用 C0218 图片的"通用 ref + 回调"模式）：
  - `CodyncUI`：新增 `TranscriptFileRef{id,name}`；`TranscriptItem.files`；`ChatTranscriptView.onOpenFile` 回调；
    `ChatEntryRow` 在 user/agent/notice 行渲染文件 chip（图标+文件名+下载箭头，点按调用 `onOpenFile(id)`）；行
    revision 计入文件 id。
  - `DSHKit`：新增 `DSHFileRef{path,name}`；`DSHMessage.files`/`DSHTranscriptItem.files`；`deliverables/presented`
    投影为一条带 `files` 的 notice 行（标题「交付文件」）。
  - `DSHConversationView`：把行内 files 映射成 `TranscriptFileRef`，`onOpenFile` 走 `gateway.downloadFile(path:)`
    下载后用现有 `DSHFilePreviewSheet` 预览（图片/文本/字节）。
- 「未确认」：正文本地路径点击 → `file-resolve` 仍未做（需在 Markdown 里识别路径）。
- 边界：不改 bot 页、底部输入框设计、串流。不改 Coe 现有调用（`onOpenFile` 默认 nil）。不加依赖/测试 target。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，
  构建号 **235**；已装到 iPhone 16 Pro（2.36.0 / 235）。不跑测试、不截图。
- 关联：C0223g、C0218（图片通用层思路）、协议 `/tmp/codync-audit/c0223-protocol.md` #23/#15。

### C0223fix1 · 2026-11-05 · 修 A（命令/技能不显示）+ C（上下文/统计汉化排序）

- **A 命令/技能不显示**：根因是 `onAppear` 同时发起 `commands`/`goal`/`tasks` 三个「发请求→等回复」，共用一个
  等待槽，互相把对方的帧吃掉（网关回复按 kind 匹配、无 requestId）。改：
  - `DSHGateway.requestFrame` 改为**串行**（一次一个请求，`acquireRequestSlot`/`releaseRequestSlot` 排队），加
    15s 超时兜底（超时以 error 收尾，避免卡死后续请求）；`commandAwaiter` 带自增 id，超时只解自己的。
  - `DSHComposer`：把加载集中到 `loadSessionPanels()`；在 `onAppear`、`gateway.phase` 变为 `.ready` 时、以及
    **打开加号 sheet 时**（若命令为空）都会补拉；加号 sheet 若 `commands` 能力在但列表还空，显示「命令加载中…」。
- **C 上下文/Token 汉化 + 排序**：`DSHContextUsageSheet`/`DSHStatsSheet` 改用 `DSHMetrics`：
  - 已知 key 映射中文（总量/输入/输出/缓存读取/缓存写入/缓存命中/推理/未缓存输入/系统提示词/工具/对话消息/窗口上限/
    已用占比…），未知 key 回落原字段名（不编造）。
  - 主指标（已用占比/总量/输入/输出/缓存/推理）排最前；百分比按 `xx%`、token 计数加千分位 + ` tok`。
  - 分组：上下文面板「Token 用量 / 上下文压力」；统计面板「执行统计 / Token 用量 / 上下文」。
- 边界：不改输入框设计、串流、Coe 共享组件。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，
  构建号 **236**；已装 iPhone 16 Pro（2.36.0 / 236）。不跑测试、不截图。
- 说明：`tokenUsage` 的确切字段名网关未文档化，若个别 key 未命中映射仍会显示英文原名；把实际 key 给我可精修。

### C0223fix2 · 2026-11-05 · 附件（图片/文件/文档）与消息气泡间距改为 12

- 说明：用户反馈"带图发送时图片离附带的消息气泡太远（约55px@1x），改成12"。
- 变化（CodyncUI，DSH 与 Coe 共用）：
  - `ChatTranscript.ChatEntryRow`（DSH 的 user/agent/notice 三种行）：把「附件块（图片+文件）」与「文字气泡」之间的间距
    统一成 **12**（附件彼此之间仍 4）；无附件时保持 4。
  - `ChatRows.UserBubble`（Coe 用户气泡）：有附件时附件→文字气泡间距 **12**（无附件 4）。
  - `Attachments.swift`：图片框 `.frame(maxWidth:220, maxHeight:280)` 加 `alignment: .bottom`，避免图片在框内上下留白把气泡顶远。
- 覆盖：图片、文件、文档都走同一「附件块」，因此都是 12；视频本轮未做附件，未涉及。
- 边界：不改输入框结构/宽度/箭头/状态行/串流。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，
  构建号 **237**；已装 iPhone 16 Pro（2.36.0 / 237）。不跑测试、不截图。
- 若仍偏大/偏小：告诉我，我按你量到的实际像素再调（也可把 12 做成统一常量）。

### C0223fix3 · 2026-11-05 · 修加号 sheet 里点“照片/拍照/文件”没反应

- 现象：加号 sheet 打开时点「照片/拍照/文件」看似没反应，必须先把 sheet 关掉，全屏选择器才出来；文件夹还打不开。
- 根因：这三个 picker（`.photosPicker`/`.fileImporter`，以及从 `RootView` 弹的相机 `.sheet`）挂在**加号 sheet 后面的父视图/根视图**上。iOS 同一宿主同一时刻只能展示一个 sheet，所以新 picker 被排队，直到加号 sheet 关闭；文件选择器在父层被挡就表现为“打不开”。
- 修法：点这三项时**先自动关闭加号 sheet，再在 onDismiss 里立即弹对应 picker**（相机是根视图弹的，只能这样；照片/文件同法最稳）。
  - `DSHComposer` 新增 `pendingAttach`（photos/files/camera）+ `performPendingAttach()`：`DSHAddSheet` 的 `tile` 点按后先 `dismiss()`，sheet 的 `onDismiss` 里延时 120ms 再 `pickingPhotos/pickingFiles/capturePhoto`，避免同一帧二次展示冲突。
- 边界：不改输入框结构/宽度/箭头/状态行/串流。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，构建号 **238**；已装 iPhone 16 Pro（2.36.0 / 238）。不跑测试、不截图。
- 说明：体验上是“加号收起→选择器弹出”，不是两个 sheet 叠一起（相机根弹无法叠加）；若你更想要“选择器直接盖在加号上”，照片/文件可改成 sheet 内再弹，相机仍需先关。

### C0223fix4 · 2026-11-05 · 修加号 sheet 不会自动关闭（dismissModal 对标准 .sheet 是空操作）

- 复测：上一版点「照片/拍照/文件」仍不自动收，必须手动关，关了才弹 picker。说明 sheet 根本没被程序关闭，`onDismiss` 直到手动关才触发。
- 根因：`dismissModal` 的默认值是 `DismissModalAction {}`（空实现），只有 `codyncSheet/codyncOverlay` 才会注入真实关闭动作；
  而 DSH 这些面板用的是**标准 `.sheet`**，所以里面所有 `dismiss()`/「关闭」都是空操作（此前靠下滑手势关）。
- 修法：
  - `DSHAddSheet` 改为传入 `onClose`（父视图置 `showAddSheet=false`）关闭；三个媒体 tile 与命令行、关闭按钮都走 `onClose`。
  - 本文件其余 DSH sheet（模型/上下文/统计/文件/定时/团队/轮次/命令选项等）的 `@Environment(\.dismissModal)` 统一换成
    标准 `@Environment(\.dismiss)`，关闭/取消按钮从此真正生效。
- 效果：点「照片/拍照/文件」→ 加号自动收起 → `onDismiss` 里弹对应 picker（相机根弹也走这套）。
- 边界：不改输入框结构/宽度/箭头/状态行/串流。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，构建号 **240**；
  已装 iPhone 16 Pro（2.36.0 / 240）。不跑测试、不截图。

### C0223fix5 · 2026-11-05 · 命令/技能列表：图标 + 中文名 + 说明（类参考图）

- 说明：用户希望命令/技能不是光秃秃的 `/compact` 英文 token，而是像参考图那样「图标 + 中文名 + 一句说明」，点即执行。
- 变化（仅 UI 呈现，协议字段不变）：
  - `DSHCommandStyle`：常见命令→中文名+SF Symbol（compact 压缩、model 模型、export 下载日志、plan 计划、goal 目标、
    permission 权限、clear/rename/archive/fork/help…）；技能统一 `sparkles` 图标；未收录的回落原名 + `terminal`。
  - 加号 sheet 与 `/` 过滤菜单：每行改为「图标 + 中文名（+ 灰色 `/token`）+ 中文说明」。说明来自网关按 `locale=zh-CN`
    返回的 `description`（已本地化），我们不编造。
  - 分组标题：「命令」改为「指令」（对齐参考图），技能仍「技能」。
  - 去重：`file/attach/upload/photo/image…` 这类与已有「照片/文件」按钮重复的命令，在加号里**隐藏**；整组若全被隐藏则
    不显示该组标题。
- 「未确认」：命令的中文名是客户端映射（网关只给 token + 本地化 description）；未收录的新命令显示原名。
- 边界：不改输入框结构/宽度/箭头/状态行/串流。
- 验证：`xcodebuild build ... -configuration DevDebug`（`generic/platform=iOS`）**BUILD SUCCEEDED，0 error**，构建号 **241**；
  已装 iPhone 16 Pro（2.36.0 / 241）。不跑测试、不截图。

### C0224 · 2026-11-05 · 收尾：DSH 会话级功能（C0223）与修复汇总

- 原因：按用户要求把本轮 DSH（chat 页）会话级功能与修复做一次收尾记录并本地提交（不推送）。
- 变化：本轮在 `ui/voice-morph` 上完成、并已分别本地提交的改动汇总（详见各自记录）：
  - 功能：C0223a 加号发图；C0223b 命令/技能；C0223a2 文件分块上传；C0223c 模型 sheet；
    C0223d1 更多·用量/统计/重命名/分叉/归档；C0223d2 更多·工作区文件/定时任务/团队；C0223d2b 定时任务编辑；
    C0223e1 目标面板+任务清单；C0223e2 排队消息；C0223f 审批/提问卡；C0223e3 压缩/重试提示；
    C0223g 交付文件提示；C0223g2 交付文件可点卡片；C0223d3 轮次导航（只读）。
  - 修复：C0223fix1 命令请求串行化+上下文/统计汉化；C0223fix2 附件↔气泡间距 12；
    C0223fix3/fix4 加号 sheet 关闭与照片/拍照/文件 picker；C0223fix5 命令/技能图标+中文名+说明。
  - 本提交本身**只更新本文件**（无代码 diff）；代码改动均已在上述提交中。
- 文件：`CHANGELOG.md`（本记录）；功能代码见
  `apps/ios/DSHKit/Sources/DSHKit/{DSHModels,DSHGateway,DSHConversationState}.swift`、
  `apps/ios/Views/DSHConversationView.swift`、
  `apps/ios/Kit/Sources/CodyncUI/Thread/{ChatTranscript,ChatRows,Attachments}.swift`。
- 验证：`xcodebuild build -configuration DevDebug -destination generic/platform=iOS` **BUILD SUCCEEDED，0 error**；
  已装 iPhone 16 Pro（2.36.0 / 242）。未跑测试、未截图（按要求）。
- 限制/待办：未确认/未做——工具结果图（网关无数据）、步骤/轨迹（网关无专用请求）、轮次导航精确跳转（无 scroll API）、
  团队进子会话、正文本地路径预览、重试放状态行（受“不改状态行”约束）；命令中文名为客户端映射，未知命令回落原名。
- 关联：C0223 系列（C0223a/a2/b/c/d1/d2/d2b/e1/e2/e3/f/g/g2/d3/fix1–fix5）。

## 2026-11-05

### C0225 · 2026-11-05 · 合并上游 upstream/main e34b319a（保留我方 DSH 与全部定制）

- 原因：上游 `upstream/main` 更新到 `e34b319a`（自共同祖先 `5e6b1c93` 起 81 个提交）。在保留我方全部定制（DSH、界面、交互、Google 登录）的前提下同步；冲突文件保留我方，非冲突的上游改动照常合入。
- 变化：
  - 从 `ui/voice-morph` 新建 `sync/upstream-20261105-voice-morph`，`git merge upstream/main e34b319a`（merge 提交，未 push）。
  - 31 个冲突：21 个取我方版本（`AGENTS.md`、`README.md`、桌面 `SettingsView.tsx`、`AnalyticsEvent.swift`、`CharacterAvatar.swift`、iOS `BotRow`/`CallRows`/`CustomConnectorSheet`/`InstallConnectorSheet`/`InstalledView`/`MarketplaceView`/`AccountStore`/`ChatRows`/`Composer`/`RoutineNoticeRow`/`ThreadView`/`TraceView`/`AccessRequestView`/`RootView`、host 两个测试文件）。
  - 语言 `de/es/fr/ja/ko/zh-Hans/zh-Hant` 按 key 并集（我方值优先）：并入上游新 key（de/es/fr/ja/ko 各 301，zh-Hans 278、zh-Hant 278）；双方都改过的 key 保留我方：zh-Hans 14 个、zh-Hant 15 个（如 `Delete {name}?`、`Friday`、`Schedule`、`Send now`、`Webhook` 等，详见合并日志）。
  - `apps/Codync.xcodeproj/project.pbxproj` 由 `xcodegen generate` 按并集重新生成：保留我方 bundle id/app group/keychain/`DEVELOPMENT_TEAM=KQQ6SD2P4C`/GoogleSignIn/DSHKit/Remix；并入上游 `ChooseComputerView.swift` 等新文件引用；`MARKETING_VERSION=2.39.1`。
  - 接口适配（只改我方文件，不改上游文件）：
    - `ConnectorSignInFlow` 改无参并补 `.signInCodeDialog`：`CustomConnectorSheet.swift`、`InstallConnectorSheet.swift`、`InstalledView.swift`。
    - 上游移除评审打断/阅读（基线代码、非我方定制）：采用删除，移除我方调用处 `Composer.swift`、`ThreadView.swift`、`RootView.swift`。
    - `AnalyticsEvent.swift`：`reviewRequested(completed:)` 改为 `reviewRequested(prompts:)`（上游新版 `ReviewInvitation.swift` 需要）；补 `OnboardingStep.choose`（上游新文件 `ChooseComputerView.swift` 需要）、`Link.installLink`（上游新版 `PairingView.swift` 需要）；保留我方移除 `Link.appStore` 的定制。
  - 规则 7（modify/delete，保留我方删除）：
    - `apps/ios/Kit/Sources/CodyncUI/Thread/RecordingPill.swift`：上游把 `LevelDots(... color: Palette.text ...)` 改为不带 `color` 参数（随通话条改动）；按规则保留我方删除，未采纳。
    - `apps/ios/Views/BotListView.swift`：上游新增 agent logo（`AgentLogos.storageKey`、`bot.runningAgent`、`BotRow(bot:agent:)`）、移除 `.reviewInvitation(blocked:)`、无障碍标签改用 agent 名；按规则保留我方删除，未采纳。
  - 锁文件：`host/Cargo.lock` 为 2.39.1 且含 `jsonwebtoken`；`apps/desktop/package-lock.json` 含 `@playwright/test`；`cargo metadata --locked`、`npm ci` 通过。
- 文件：`apps/project.yml`、`apps/Codync.xcodeproj/project.pbxproj`、`apps/ios/Kit/Sources/CodyncKit/Analytics/AnalyticsEvent.swift`、`apps/ios/Kit/Sources/CodyncUI/Marketplace/*`、`apps/ios/Kit/Sources/CodyncUI/Thread/{Composer,ThreadView}.swift`、`apps/ios/Views/RootView.swift`、`apps/ios/Kit/Sources/CodyncKit/Resources/Languages/*.json`、`CHANGELOG.md`。
- 验证：iOS `iOS Dev`/`DevDebug`（模拟器）编译通过；桌面 `npm run typecheck`、`npm run build` 通过；`Screen Dev`（macOS，`CODE_SIGNING_ALLOWED=NO`）编译通过；真机构建/安装/启动结果见下。
- 特别保护（已核对）：
  - `apps/ios/DSHKit/` 整个目录、`apps/ios/Views/DSHConversationView.swift`、DSH 资源（`agent-dsh.imageset`、`agent_dsh.xml`、`dsh.svg` 等）在合并前后**逐字节一致**：`git diff --cached HEAD -- <DSH 路径>` 为空、blob 列表与合并前完全相同、工作区无改动。
  - Google 登录链路保留：`apps/project.yml` 仍为 `GoogleSignIn`，无 Clerk。
- 限制/待办：
  - 冲突文件里放弃的上游功能：每 bot 的 agent logo、通话条/通话会话改进、connector 验证码登录入口（共享类型已合入）、手机设置选账户电脑、消息排队入口、GitHub 点星/App Store 评分邀请、routine/trace 的 i18n、settings 的 tr 翻译、host 账户离开/加入配对测试。
  - 上游新增文件里因入口被放弃而未接线的代码（仅列出，未删未接）：`apps/ios/Kit/Sources/CodyncKit/Models/Entry+Queue.swift`、`apps/ios/Kit/Sources/CodyncUI/Thread/QueuedMessages.swift`、`apps/ios/Kit/Sources/CodyncUI/Bots/AgentBadge.swift`、`apps/ios/Views/ChooseComputerView.swift`。
  - 未 push；未做功能自测（按约定只编译 + 安装）。
- 关联：C0122、C0091（同批上游同步）。
