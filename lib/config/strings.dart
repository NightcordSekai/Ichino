class AppStrings {
  AppStrings._();

  // Tab
  static const tabHome = '主页';
  static const tabTickets = '票据';
  static const tabBest50 = 'B50';
  static const tabRisk = '风险';
  static const tabSettings = '设置';
  static const tabAbout = '关于';

  // Login
  static const appTitle = 'Ichino';
  static const qrCodeToken = 'QR Code 令牌';
  static const qrHint = '粘贴二维码解析内容... / 粘贴连接信息';
  static const uploadQR = '上传二维码';
  static const login = '登录';
  static const loggingIn = '登录中...';
  static const qrScanSuccess = '二维码解析成功';
  static const qrScanFailed = '未能识别二维码，请手动粘贴内容';
  static const qrScanError = '解析失败';
  static const forcePreviewApi = '强制使用 Preview API';
  static const loginFailed = '登录失败';
  static const qrTokenUnrecognized = '没认出 QR 令牌（内容里应当含 SGWCMAID），也可以粘贴「连接信息」。';
  static const requestFailed = '请求失败';
  static const settingsTooltip = '设置';

  // 连接信息（实验性）：uid + JSESSIONID + token 的 Base64 快照
  static const experimentalBadge = '实验性';
  static const connectionShareTitle = '导出连接信息';
  static const connectionShareDesc =
      '把用户 ID、JSESSIONID Cookie 与登录令牌打包成 Base64，'
      '在其他设备的登录页粘贴即可恢复会话。';
  static const connectionShareSecurity = '内容未加密，拿到这串字符的人可以直接操作该账号。';
  static const connectionShareCopy = '复制到剪贴板';
  static const connectionShareCopied = '连接信息已复制到剪贴板';
  static const connectionShareEmpty = '当前会话既没有 Cookie 也没有令牌，无法导出。';
  static const restoreSession = '恢复会话';
  static const restoringSession = '恢复中...';
  static const sessionShareDetected = '已识别为连接信息（实验性功能），点击「恢复会话」直接续上这次登录。';
  static const sessionRestoreFailed = '会话恢复失败';
  static const sessionRestoreCookie = '已复用连接信息里的 JSESSIONID，没有重新登录';
  static const sessionRestoreToken = 'Cookie 不可用，已用令牌重新登录';
  static const sessionRestoredNotice =
      '这是用连接信息恢复的会话：JSESSIONID 只用于读取数据，'
      '票据与风险页的写入操作需要先重新登录。';

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
  static const ticketStockNotEmpty = '该功能票已有库存，出于安全考虑不会继续发票。';
  static const selectedTicket = '已选票';
  static const ticketUsed = '功能票使用完成';
  static const ticketCooldownSeconds = 60;
  static String ticketCooldownCountdown(int remaining) => '冷却中，剩余 $remaining 秒';
  static String ticketCooldownNotice(int remaining) =>
      '登录后需冷却 $ticketCooldownSeconds 秒，剩余 $remaining 秒后可使用功能票。';

  // Settings
  static const titleServerSettings = '参数设置';
  static const titleServerSection = 'Title Server';
  static const authServerSettings = 'Auth Server';
  static const machineSettings = '机器信息';
  static const save = '保存';
  static const labelTitleServerUrl = 'Title Server URL';
  static const hintTitleServerUrl = '';
  static const labelAesKey = 'AES Key';
  static const hintAesKey = 'your aes key string';
  static const labelAesIv = 'AES IV';
  static const hintAesIv = 'your aes iv string';
  static const labelClientId = 'Client ID';
  static const hintClientId = 'A63E01C2805';
  static const labelRegionId = 'Region ID';
  static const hintRegionId = '1';
  static const labelPlaceId = 'Place ID';
  static const hintPlaceId = '1403';
  static const labelObfuscateParam = 'Obfuscate Param';
  static const hintObfuscateParam = 'LatuAa81';
  static const labelApiVersion = 'API Version (Mai-Encoding)';
  static const hintApiVersion = '1.53';
  static const labelRegionName = 'Region 名称';
  static const hintRegionName = '北京';
  static const labelPlaceName = 'Place 名称';
  static const hintPlaceName = 'Place name';
  static const labelKeychipId = 'Keychip ID';
  static const hintKeychipId = 'ID';
  static const labelAimeUrl = 'Aime URL';
  static const hintAimeUrl = '';
  static const labelAimeSalt = 'Aime Salt';
  static const hintAimeSalt = 'API Key 派生用 Salt';
  static String fieldRequired(String label) => '$label 不能为空';

  // Config Export/Import
  static const configExportImport = '配置导入/导出';
  static const exportConfig = '导出当前配置';
  static const importConfig = '从剪贴板导入配置';
  static const exportSuccess = '配置已导出到剪贴板 (Base64)';
  static const importSuccess = '配置已导入并保存';
  static const importFailed = '导入失败：剪贴板内容无效';
  static const noConfigToExport = '没有可导出的配置';

  // UnlockMusic (解锁歌曲 / UpsertUserAll 上传解锁道具)
  static const unlockFeatureTitle = '歌曲解锁';
  static const unlockFeatureDesc = '通过上传 itemKind 5/6/7 道具解锁歌曲与谱面。';
  static const unlockMusicIdLabel = '解锁歌曲 ID';
  static const unlockMusicIdHint = '例如 834';
  static const unlockMusicOption = '解锁歌曲 (itemKind 5)';
  static const unlockMasterOption = '解锁 Master (itemKind 6)';
  static const unlockRemasterOption = '解锁 Re:Master (itemKind 7)';
  static const unlockNeedMusicId = '请填写要解锁的歌曲 ID。';
  static const unlockNeedOption = '请至少勾选一项解锁内容。';
  static const unlockNotLoggedIn = '尚未登录游戏服务器，无法执行解锁操作。';

  // 待提交列表 (userItemList 可累加多行)
  static const listAddButton = '添加到列表';
  static const listRemoveTooltip = '从列表移除';
  static const listDuplicate = '该内容已在列表中。';
  static const unlockPendingTitle = '待解锁列表';
  static const collectiblesPendingTitle = '待获取列表';
  static const unlockPendingEmpty = '列表为空，可在上方填写歌曲 ID 并勾选难度后添加。';
  static const collectiblesPendingEmpty = '列表为空，可在上方选择类型与 ID 后添加。';
  static const unlockNeedList = '请至少添加一首要解锁的歌曲。';
  static const collectiblesNeedList = '请至少添加一项收藏品。';
  static const autoLogoutAndExit = '完成后自动退出登录并返回标题页';
  static const exitingToTitle = '正在退出登录并返回标题页...';
  static String unlockCooldownNotice(int remaining) =>
      '登录后需冷却 $ticketCooldownSeconds 秒，剩余 $remaining 秒后可执行解锁操作。';
  static const unlockFetchData = '拉取数据';
  static const unlockFetching = '拉取中...';
  static const unlockRefetch = '重新拉取';
  static const unlockNoData = '⚠️ 未拉取到用户数据，请先点「拉取数据」按钮获取。';
  static const unlockFetched = '数据已拉取';
  static const unlockMusicRun = '执行解锁';
  static const unlockRunning = '执行中...';
  static const unlockStepFetch = '拉取用户数据';
  static const unlockStepUpload = '上传解锁数据';
  static const unlockMusicSuccess = '解锁数据上传完成';

  // Collectibles (收藏品获取 / UpsertUserAll 上传收藏品道具)
  // itemKind: 1=姓名框 2=称号 3=头像 10=搭档 11=背景板 12=功能票
  static const collectiblesFeatureTitle = '收藏品获取';
  static const collectiblesFeatureDesc =
      '通过上传 itemKind 道具获取收藏品（姓名框/称号/头像/搭档/背景板/功能票）。';
  static const collectiblesItemKindLabel = '收藏品类型 (itemKind)';
  static const collectiblesItemIdLabel = '收藏品 ID';
  static const collectiblesItemIdHint = '例如 250103';
  static const collectiblesNeedItemId = '请填写要获取的收藏品 ID。';
  static const collectiblesNotLoggedIn = '尚未登录游戏服务器，无法执行获取操作。';
  static String collectiblesCooldownNotice(int remaining) =>
      '登录后需冷却 $ticketCooldownSeconds 秒，剩余 $remaining 秒后可执行获取操作。';
  static const collectiblesRun = '执行获取';
  static const collectiblesStepUpload = '上传获取数据';
  static const collectiblesSuccess = '收藏品获取数据上传完成';

  static const List<int> collectiblesItemKinds = [1, 2, 3, 10, 11, 12];

  static String collectiblesItemKindName(int kind) {
    switch (kind) {
      case 1:
        return '姓名框';
      case 2:
        return '称号';
      case 3:
        return '头像';
      case 10:
        return '搭档';
      case 11:
        return '背景板';
      case 12:
        return '功能票';
      default:
        return '$kind';
    }
  }

  // TravelPartner 旅行伙伴 (ItemKind.Character = 9，走 userCharacterList)
  static const travelPartnerFeatureTitle = '旅行伙伴';
  static const travelPartnerFeatureDesc =
      '发放旅行伙伴并编组出战槽位。角色走 userCharacterList（不是搭档 Partner=10，也不走 userItemList）。';
  static const travelPartnerNotLoggedIn = '尚未登录游戏服务器，无法操作旅行伙伴。';
  static String travelPartnerCooldownNotice(int remaining) =>
      '登录后需冷却 $ticketCooldownSeconds 秒，剩余 $remaining 秒后可操作旅行伙伴。';
  static const travelPartnerFetchData = '拉取角色数据';
  static const travelPartnerFetching = '拉取中...';
  static const travelPartnerRefetch = '重新拉取';
  static const travelPartnerFetched = '角色数据已拉取';
  static const travelPartnerNoData = '⚠️ 尚未拉取，请先获取角色与用户数据。';
  static const travelPartnerOwnedTitle = '已拥有旅行伙伴';
  static const travelPartnerOwnedEmpty = '还没有任何旅行伙伴。';
  static const travelPartnerGrantTitle = '发放新的旅行伙伴';
  static const travelPartnerGrantEmpty = '未添加待发放角色。';
  static const travelPartnerCharacterIdLabel = '旅行伙伴 ID';
  static const travelPartnerCharacterIdHint = '例如 101';
  static const travelPartnerNeedCharacterId = '请填写旅行伙伴 ID。';
  static const travelPartnerAlreadyOwned = '该旅行伙伴已拥有，无需重复发放。';

  static const travelPartnerIdRangeTitle = '角色 ID 对照';
  static const travelPartnerIdRangeBody =
      '101-105 · 201-205 · 301-306 · 392-395 · 401-405 · 501-505 · 601-605\n'
      '编号按颜色分段，每段内递增。这个表取自客户端内置的默认发放清单，机台的 '
      'Chara.xml 可能更多。\n\n'
      'ID 不在机台表里时服务器照样保存，但客户端 CharacterSelectProces 会静默跳过，'
      '游戏里就是「加不上」。';
  static const travelPartnerIdUnknown = '该 ID 不在已知的默认角色清单里，机台表里也可能有，注意确认。';

  // 上传后复查 GetUserCharacterApi，用来区分「服务器没存」和「存了但游戏不显示」
  static String travelPartnerVerified(int count) =>
      '旅行伙伴数据上传完成，复查 GetUserCharacterApi 已确认服务器保存了 $count 个角色。'
      '若游戏里仍看不到，说明这些 ID 不在机台的 Chara 表里。';
  static String travelPartnerNotSaved(String ids) =>
      '数据包已被接受，但复查时服务器上没有 #$ids —— '
      '服务器没有写入 upsertUserAll.userCharacterList。';
  static String travelPartnerVerifyFailed(String error) =>
      '旅行伙伴数据上传完成，但复查角色列表失败，无法确认是否写入：$error';

  static const travelPartnerSlotTitle = '编组出战槽位';
  static const travelPartnerSlotNone = '空';
  static String travelPartnerSlotLabel(int index) =>
      index == 0 ? '槽 0（队长）' : '槽 $index';
  static const travelPartnerLevelLabel = '等级（留空不改）';
  static const travelPartnerLevelHint = '1 ~ 999999';
  static const travelPartnerLevelInvalid = '旅行伙伴等级需要在 1 ~ 999999 之间。';
  static String travelPartnerLevelConverted(int realLevel) =>
      '真实等级 $realLevel = ${realLevel ~/ 10000} 转生 + ${realLevel % 10000} 级';
  static const travelPartnerCopySlot0 = '把槽 0 复制到其他槽位';
  static const travelPartnerCopyNeedSlot0 = '槽 0 还没有选择旅行伙伴。';
  static const travelPartnerNotOwnedHint = '编组失败：你并不拥有该旅行伙伴。';
  static const travelPartnerRun = '执行旅行伙伴操作';
  static const travelPartnerRunning = '执行中...';
  static const travelPartnerSuccess = '旅行伙伴数据上传完成';
  static const travelPartnerStepFetch = '拉取角色与用户数据';
  static const travelPartnerStepUpload = '上传旅行伙伴数据';

  // MapTraveller 一键跑图（UserMap 走 userMapList，收藏品另走 userItemList）
  static const mapFeatureTitle = '一键跑图';
  static const mapFeatureDesc =
      '把区域标记为已完成。isClear / isComplete 在客户端是从 distance 派生的，'
      '所以这里把 distance 直接推到 999999999（UserMapData.MaxDistance），'
      '超过任何一张图的 End 里程针，状态才不会被下一次进区域选择页冲掉。';
  static const mapNotLoggedIn = '尚未登录游戏服务器，无法操作区域进度。';
  static String mapCooldownNotice(int remaining) =>
      '登录后需冷却 $ticketCooldownSeconds 秒，剩余 $remaining 秒后可操作区域进度。';
  static const mapIdLabel = '区域 ID';
  static const mapIdHint = '例如 550001';
  static const mapNeedMapId = '请填写要标记完成的区域 ID。';
  static const mapPendingEmpty = '列表为空，可在上方填写区域 ID 后添加。';
  static const mapRun = '标记区域已完成';
  static const mapRunning = '执行中...';
  static const mapStepFetch = '拉取区域进度';
  static const mapStepUpload = '上传区域进度';
  static const mapFetchData = '拉取区域数据';
  static const mapFetched = '区域数据已拉取';
  static const mapNoData = '⚠️ 尚未拉取区域进度。';
  static String mapCompleted(int mapId) => '区域 #$mapId 已标记为完成';
  static String mapVerified(int count) =>
      '上传完成，复查 GetUserMapApi 已确认 $count 个区域的进度被保存。'
      '若游戏里区域仍显示未解锁，多半是 distance 还不够或该 mapId 不在机台表里。';
  static String mapNotSaved(String ids) =>
      '数据包已被接受，但复查时服务器上没有 #$ids 的完成记录 —— '
      '服务器没有写入 upsertUserAll.userMapList。';
  static String mapVerifyFailed(String error) =>
      '上传完成，但复查区域进度失败，无法确认是否写入：$error';
  static const mapCollectiblesNotice =
      '只标记完成，不发放该区域的收藏品——对应关系在机台的 Map.xml / '
      'MapTreasure.xml 里，App 拿不到。要收藏品请用「收藏品获取」。';

  // Kaleidoscope 万花筒专区（UserKaleidxScope 走 userKaleidxScopeList）
  static const kaleidxFeatureTitle = '万花筒专区';
  static const kaleidxFeatureDesc =
      '发现新的宿命之门、获取门的钥匙。两者都是 userKaleidxScopeList 里同一行的 '
      'isGateFound / isKeyFound，钥匙不走 userItemList。每行是整行替换，'
      '所以上传前会先读回原行的成绩与日期再合并。';
  static const kaleidxNotLoggedIn = '尚未登录游戏服务器，无法操作万花筒。';
  static String kaleidxCooldownNotice(int remaining) =>
      '登录后需冷却 $ticketCooldownSeconds 秒，剩余 $remaining 秒后可操作万花筒。';
  static const kaleidxGateIdLabel = '门 ID (gateId)';
  static const kaleidxGateIdHint = '例如 3';
  static const kaleidxNeedGateId = '请填写门 ID。';
  static const kaleidxNeedAction = '请至少勾选一项：发现门或获取钥匙。';
  static const kaleidxPendingEmpty = '列表为空，可在上方填写门 ID 后添加。';
  static const kaleidxActionDiscover = '发现门 (isGateFound)';
  static const kaleidxActionKey = '获取钥匙 (isKeyFound)';
  static const kaleidxKeyNeedsGate =
      '只给钥匙不给门的话这扇门是隐形的（客户端状态机把 !found && key 判为 None），'
      '所以勾了钥匙会连带把门标为已发现。';
  static const kaleidxRun = '执行万花筒操作';
  static const kaleidxRunning = '执行中...';
  static const kaleidxStepFetch = '拉取万花筒进度';
  static const kaleidxStepUpload = '上传万花筒进度';
  static const kaleidxFetchData = '拉取门进度';
  static const kaleidxFetched = '门进度已拉取';
  static const kaleidxNoData = '⚠️ 尚未拉取门进度，无法合并原行字段。';
  static const kaleidxGateIdDuplicated = '同一扇门只能出现一次。';
  static String kaleidxVerified(int count) =>
      '上传完成，复查 GetUserKaleidxScopeApi 已确认 $count 扇门的状态被保存。'
      '若游戏里仍看不到，说明这个 gateId 不在机台的 KaleidxScopeGate.xml 里，'
      '或它绑定的活动没在开。';
  static String kaleidxNotSaved(String ids) =>
      '数据包已被接受，但复查时服务器上没有 #$ids 的行 —— '
      '服务器没有写入 upsertUserAll.userKaleidxScopeList。';
  static String kaleidxVerifyFailed(String error) =>
      '上传完成，但复查万花筒进度失败，无法确认是否写入：$error';

  static String kaleidxGateState(bool found, bool key, bool clear) {
    if (!found && key) return '隐形（有钥匙但没发现门）';
    if (!found) return '未见过';
    if (!key) return '已发现 · 未解锁';
    if (!clear) return '可挑战';
    return '已通关';
  }

  // NumberPatch 数值修改（修改 Rating / 添加舞里程），都走 UpsertUserAllApi
  static const numberPatchNotLoggedIn = '尚未登录游戏服务器，无法执行修改。';
  static const numberPatchRun = '执行修改';
  static const numberPatchStepUpload = '上传修改后的数据';
  static String numberPatchCooldownNotice(int remaining) =>
      '登录后需冷却 $ticketCooldownSeconds 秒，剩余 $remaining 秒后可执行修改。';
  static String numberPatchOutOfRange(int min, int max) =>
      '数值超出范围（$min ~ $max）。';
  static String numberPatchRangeHint(int min, int max) => '可填 $min ~ $max';
  static String numberPatchPreview(String label, int current, int target) =>
      '$label: $current → $target';

  // Rating 修改（只改总 Rating，不动每首歌的 Rating）
  static const ratingFeatureTitle = '修改 Rating';
  static const ratingFeatureDesc =
      '只写总 Rating（userData.playerRating 与 userRating.rating 两处），取值 0 ~ 99999。'
      'ratingList / newRatingList 里每首歌各自的 Rating 原样带回不动。'
      '包里带一条占位 playlog，before/after Rating 一并改成新旧值。';
  static const ratingValueLabel = '目标总 Rating';
  static const ratingValueHint = '例如 15000';
  static const ratingNeedValue = '请填写目标 Rating。';
  static const ratingSuccess = 'Rating 上传完成';
  static const ratingCurrentValue = '当前总 Rating';

  // MaiMile 舞里程（UserDetail.point 余额 / totalPoint 累计）
  static const maiMileFeatureTitle = '添加舞里程';
  static const maiMileFeatureDesc =
      '舞里程就是 UserDetail.point（余额），totalPoint 为累计获得量。'
      '客户端只在「获得」时把余额钳到 99999（UserDetail.AddMile），'
      '商店扣款走不带钳位的 Point -= cost，所以写更大的值不会被覆回。'
      '取值是整个 int32 区间，累加模式填负数即为扣减。';
  static const maiMileValueLabel = '舞里程数值';
  static const maiMileValueHint = '例如 10000';
  static const maiMileNeedValue = '请填写舞里程数值。';
  static const maiMileModeLabel = '写入方式';
  static const maiMileModeAdd = '累加（当前值 + N）';
  static const maiMileModeSet = '直接设定为 N';
  static const maiMileCurrentBalance = '当前舞里程';
  static const maiMileSuccess = '舞里程上传完成';

  // HighRiskFeature hub (中转页)
  static const musicRiskHubTitle = '高危功能';
  static const musicRiskHubDesc = '以下功能会向服务器发送伪造数据，属于高风险操作，请谨慎使用。';
  static const musicRiskHubNotLoggedIn = '尚未登录游戏服务器，无法执行高危操作。';
  static String musicRiskHubCooldownNotice(int remaining) =>
      '登录后需冷却 $ticketCooldownSeconds 秒，剩余 $remaining 秒后可执行高危操作。';

  // Best50 (Best 50 成绩图)
  static const best50FeatureTitle = 'Best 50';
  static const best35Label = 'BEST 35';
  static const best15Label = 'BEST 15';
  static const best50Empty = '没有 Rating 数据。';
  static const best50LoadingMusic = '正在加载乐曲数据...';
  static const best50Export = '导出图片';
  static const best50Exporting = '导出中...';
  static const best50NoMusicData = '乐曲数据未就绪，定数与曲名可能缺失。';
  static String best50RatingSum(int b35, int b15) =>
      'B35: $b35 + B15: $b15 = ${b35 + b15}';
  static String best50Exported(String? path) =>
      path == null ? '图片已导出' : '图片已导出到 $path';
  static String best50ExportFailed(String error) => '导出失败: $error';
  static const best50Footer =
      'Generated by Ichino. UI designed by chuxuehaocai.';

  // About
  static const aboutTitle = 'Ichino';
  static const aboutDesc = '基于 QR Code 的 maimai DX 街机网络登录客户端。';
  static const aboutBasics = '基本信息';
  static const aboutPlatforms = '支持平台';
  static const aboutPackageId = '应用标识';
  static const aboutRiskNotice =
      '「风险」页会向服务器发送伪造的 UpsertUserAllApi 数据包，属于高危操作，可能封号。';
  static const credits = '致谢';
  static const creditBuiltWith = '构建框架';
  static const creditQRDecode = 'QR 解码';
  static const creditB50 = 'B50 成绩图';
  static const creditProtocol = '协议实现参考';
  static const creditIconAssets = '图标资源';
  static const creditLicense = '许可证';
}
