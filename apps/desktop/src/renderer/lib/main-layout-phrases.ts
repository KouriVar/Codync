// Phrases for the Mac main-layout revamp (C0096): the main bot's menu, the bot chips' message
// count card, the working strip and the docked conversation panel. Desktop-only, so they live here
// instead of the shared iPhone catalogs; languages without an entry fall back to English.
export const mainLayoutHans = {
  /** Group b: the bots on the user's computers, in the list the sidebar used to hold. */
  'Bots': 'Bot 列表',
  'Connection status': '连接状态',
  /** The bot the chat is with, in the chip's count card and the panel's placeholder. */
  '{count} messages': '{count} 条消息往来',
  'Message {name}': '给 {name} 发消息',
  /** A peer on another computer: nothing here can carry a message to it yet. */
  'Not on this computer: ask {name}’s own chat to reply.': '不在本机：暂时不能直接发消息给 {name}。',
  'Computers & connections': '电脑与连接',
  /** The docked panel's title and the heading over your messages to that peer. */
  'Conversation with {name}': '与 {name} 的对话',
  'You to {name}': '你发给 {name}',
  'Bots working now': '正在执行的 Bot',
  'Open menu': '打开菜单',
  '{name}, open menu': '{name}，打开菜单',
}

export const mainLayoutHant = {
  'Bots': 'Bot 列表',
  'Connection status': '連線狀態',
  '{count} messages': '{count} 條消息往來',
  'Message {name}': '給 {name} 傳訊息',
  'Not on this computer: ask {name}’s own chat to reply.': '不在本機：暫時不能直接傳訊息給 {name}。',
  'Computers & connections': '電腦與連線',
  'Conversation with {name}': '與 {name} 的對話',
  'You to {name}': '你發給 {name}',
  'Bots working now': '正在執行的 Bot',
  'Open menu': '打開選單',
  '{name}, open menu': '{name}，打開選單',
}
