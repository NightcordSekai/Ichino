class AppStrings {
  AppStrings._();

  // Tab
  static const tabHome = '主页';
  static const tabTickets = '票据';
  static const tabSettings = '设置';
  static const tabAbout = '关于';

  // Login
  static const appTitle = 'Project Ichino';
  static const loginSubtitle = '扫描或输入二维码进行登录';
  static const qrCodeToken = 'QR Code 令牌';
  static const qrHint = '粘贴二维码解析内容...';
  static const qrParsedResult = '解析结果（截取后 64 位）';
  static const uploadQR = '上传二维码';
  static const login = '登录';
  static const loggingIn = '登录中...';
  static const qrScanSuccess = '二维码解析成功';
  static const qrScanFailed = '未能识别二维码，请手动粘贴内容';
  static const qrScanError = '解析失败';
  static const forcePreviewApi = '强制使用 Preview API';
  static const loginFailed = '登录失败';
  static const requestFailed = '请求失败';
  static const settingsTooltip = '设置';

  // Home
  static const logoutTooltip = '退出登录';
  static const titleServerNotConfigured = '未配置 Title Server';
  static const titleServerNotConfiguredDesc = '请配置 Title Server 以获取用户数据。';
  static const openSettings = '打开设置';
  static const loadFailed = '数据加载失败';
  static const retry = '重试';
  static const unknownUser = '未知用户';
  static const online = '在线';
  static const offline = '离线';
  static const gameInfo = '游戏信息';
  static const lastGame = '最后游戏';
  static const lastPlay = '最后游玩';
  static const lastLogin = '最后登录';
  static const lastRegion = '最后地区';
  static const romVersion = 'Rom 版本';
  static const dataVersion = '数据版本';
  static const status = '状态';
  static const netMember = '联网会员';
  static const inherit = '继承';
  static const banState = '封禁状态';
  static const clean = '正常';
  static const dailyBonus = '每日奖励';
  static const notClaimed = '未领取';
  static const moreDetails = '更多详情';
  static const userId = '用户 ID';
  static const totalAwake = '总计 Awake';
  static const displayRate = '展示 Rate';
  static const iconId = '图标 ID';
  static const nameplateId = '名牌 ID';
  static const plateId = '姓名框 ID';
  static const frameId = '背景框 ID';
  static const titleId = '称号 ID';
  static const trophyId = '奖杯 ID';
  static const partnerId = '伙伴 ID';
  static const gradeRank = '段位';
  static const courseRank = '阶级';
  static const classRank = '段级';
  static const point = '当前 P';
  static const totalPoint = '累计 P';
  static const headphoneVol = '耳机音量';
  static const errorId = '错误 ID';
  static const rawApiResponse = '原始 API 响应 (调试)';

  // Ratings / breakdown
  static const ratingBreakdown = 'Rating 详情';
  static const musicRating = '乐曲 Rating';
  static const newChartRating = '新谱面 Rating';
  static const oldChartRating = '旧谱面 Rating';
  static const highestRating = '历史最高';

  // First play
  static const firstPlay = '入坑信息';
  static const joinDate = '入坑日期';
  static const firstGame = '首次游戏';
  static const firstRomVersion = '初始 Rom';
  static const firstDataVersion = '初始数据';

  // Play stats
  static const playStats = '游玩统计';
  static const playCount = '总游玩次数';
  static const currentPlayCount = '当期游玩';
  static const totalAchievement = '总达成率';
  static const totalDxScore = '总 DX 分';
  static const totalSync = '总同步数';

  // Notices
  static const inheritedAccountNotice = '此账号当前正在游玩, 仅显示 Preview 概要, 不执行登录。';

  static String rating(int r) => 'Rating: $r';

  // Tickets
  static const runTicket = '使用功能票';
  static const runningTicket = '执行中...';
  static const ticketNotConfigured = '请先配置 Title Server 设置。';
  static const ticketNotLoggedIn = '尚未登录游戏服务器，无法使用功能票。';
  static const ticketAutoLogout = '完成后自动退出登录';

  static const stepChargeTicket = '使用功能票';
  static const stepLogout = '退出游戏';

  static const myTickets = '功能票';
  static const refreshTickets = '刷新数据';
  static const loading = '加载中...';
  static const ticketNotSelected = '请先在功能票列表中选中一张票。';
  static const selectedTicket = '已选票';
  static const ticketUsed = '功能票使用完成';
  static const ticketCooldownSeconds = 60;
  static String ticketCooldownCountdown(int remaining) =>
      '冷却中，剩余 $remaining 秒';
  static String ticketCooldownNotice(int remaining) =>
      '登录后需冷却 $ticketCooldownSeconds 秒，剩余 $remaining 秒后可使用功能票。';

  // Settings
  static const titleServerSettings = 'Title Server 设置';
  static const required = '必填';
  static const optional = '可选 (有默认值)';
  static const save = '保存';
  static const labelTitleServerUrl = 'Title Server URL';
  static const hintTitleServerUrl = 'http://maimai-gm.wahlap.com:42081';
  static const labelAesKey = 'AES Key';
  static const hintAesKey = 'your aes key string';
  static const labelAesIv = 'AES IV';
  static const hintAesIv = 'your aes iv string';
  static const labelClientId = 'Client ID';
  static const hintClientId = 'your client id';
  static const labelRegionId = 'Region ID';
  static const hintRegionId = '1';
  static const labelPlaceId = 'Place ID';
  static const hintPlaceId = '1403';
  static const labelObfuscateParam = 'Obfuscate Param';
  static const hintObfuscateParam = 'LatuAa81';
  static const labelApiVersion = 'API Version (Mai-Encoding)';
  static const hintApiVersion = '1.53';
  static String fieldRequired(String label) => '$label 不能为空';

  // About
  static const aboutTitle = 'Project Ichino';
  static const aboutDesc = '基于 QR Code 的 maimai DX 街机网络登录客户端。';
  static const credits = '致谢';
  static const creditBuiltWith = '构建框架';
  static const creditQRDecode = 'QR 解码';
  static const creditIconAssets = '图标资源';
  static const creditLicense = '许可证';
}
