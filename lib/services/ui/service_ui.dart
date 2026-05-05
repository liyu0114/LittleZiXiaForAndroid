// 服务界面结构
//
// 按功能分组的UI组织

/// 服务分组
class ServiceGroup {
  final String name;
  final String icon;
  final List<ServiceItem> services;
  
  ServiceGroup({
    required this.name,
    required this.icon,
    required this.services,
  });
}

/// 服务项
class ServiceItem {
  final String id;
  final String name;
  final String description;
  final String file;
  
  ServiceItem({
    required this.id,
    required this.name,
    required this.description,
    required this.file,
  });
}

/// 界面结构
final serviceGroups = [
  // === 核心智能 ===
  ServiceGroup(
    name: '🤖 核心智能',
    icon: '🤖',
    services: [
      ServiceItem(
        id: 'task_decomposer',
        name: '任务分解',
        description: '智能分解任务 + 分布式执行',
        file: 'task_decomposer.dart',
      ),
      SkillAutoCreator(
        id: 'skill_auto_create',
        name: '技能自造',
        description: '自动创建新Skill',
        file: 'skill_auto_creator.dart',
      ),
      LocalModelManager(
        id: 'local_model',
        name: '本地模型',
        description: '加载运行本地LLM',
        file: 'local_model_service.dart',
      ),
      ContextManager(
        id: 'context',
        name: '超长上下文',
        description: '项目管理 + 对话压缩',
        file: 'context_manager.dart',
      ),
    ],
  ),
  
  // === 小程序平台 ===
  ServiceGroup(
    name: '📱 小程序平台',
    icon: '📱',
    services: [
      SandboxRuntime(
        id: 'sandbox',
        name: '沙盒运行',
        description: '隔离的代码执行环境',
        file: 'sandbox_runtime.dart',
      ),
      AppStore(
        id: 'app_store',
        name: '应用市场',
        description: '发布发现小程序',
        file: 'app_store.dart',
      ),
      CodeSandbox(
        id: 'code_sandbox',
        name: '代码沙盒',
        description: '安全执行用户代码',
        file: 'code_sandbox.dart',
      ),
    ],
  ),
  
  // === 网络通信 ===
  ServiceGroup(
    name: '🌐 网络通信',
    icon: '🌐',
    services: [
      NetworkMonitor(
        id: 'network_monitor',
        name: '断线重连',
        description: '网络状态 + 消息队列',
        file: 'network_recovery.dart',
      ),
      HybridNetworkManager(
        id: 'hybrid_network',
        name: 'P2P混合网络',
        description: '局域网 + Tailscale',
        file: 'hybrid_network_service.dart',
      ),
      HttpProxy(
        id: 'http_proxy',
        name: 'HTTP代理',
        description: '请求拦截替换',
        file: 'http_proxy.dart',
      ),
      WebSocketManager(
        id: 'websocket',
        name: 'WebSocket',
        description: 'WebSocket管理',
        file: 'websocket_manager.dart',
      ),
    ],
  ),
  
  // === 设备控制 ===
  ServiceGroup(
    name: '📲 设备控制',
    icon: '📲',
    services: [
      DeviceController(
        id: 'device_control',
        name: '设备控制',
        description: '截屏拍照执行命令',
        file: 'device_controller.dart',
      ),
      FileSync(
        id: 'file_sync',
        name: '文件同步',
        description: '多设备文件同步',
        file: 'file_sync.dart',
      ),
    ],
  ),
  
  // === 消息处理 ===
  ServiceGroup(
    name: '💬 消息处理',
    icon: '💬',
    services: [
      NotificationAggregator(
        id: 'notification',
        name: '通知聚合',
        description: '多渠道通知汇总',
        file: 'notification_aggregator.dart',
      ),
      TemplateManager(
        id: 'template',
        name: '消息模板',
        description: '常用消息模板',
        file: 'template_manager.dart',
      ),
      MessageQueue(
        id: 'message_queue',
        name: '消息队列',
        description: '异步消息处理',
        file: 'message_queue.dart',
      ),
    ],
  ),
  
  // === 任务调度 ===
  ServiceGroup(
    name: '⏰ 任务调度',
    icon: '⏰',
    services: [
      TaskScheduler(
        id: 'task_scheduler',
        name: '任务调度',
        description: '定时任务管理',
        file: 'task_scheduler.dart',
      ),
      CronManager(
        id: 'cron',
        name: '定时任务',
        description: 'Cron风格任务',
        file: 'cron_manager.dart',
      ),
      WorkflowEngine(
        id: 'workflow',
        name: '工作流引擎',
        description: '自动化工作流',
        file: 'workflow_engine.dart',
      ),
    ],
  ),
  
  // === 系统服务 ===
  ServiceGroup(
    name: '⚙️ 系统服务',
    icon: '⚙️',
    services: [
      PermissionManager(
        id: 'permission',
        name: '权限管理',
        description: '角色权限控制',
        file: 'permission_manager.dart',
      ),
      CacheManager(
        id: 'cache',
        name: '缓存管理',
        description: 'LRU缓存',
        file: 'cache_manager.dart',
      ),
      ConfigManager(
        id: 'config',
        name: '配置管理',
        description: '运行时配置',
        file: 'config_manager.dart',
      ),
      Database(
        id: 'database',
        name: '数据库',
        description: '轻量级数据库',
        file: 'database.dart',
      ),
    ],
  ),
  
  // === 监控运维 ===
  ServiceGroup(
    name: '📊 监控运维',
    icon: '📊',
    services: [
      LogAnalyzer(
        id: 'log_analyzer',
        name: '日志分析',
        description: '日志搜索统计',
        file: 'log_analyzer.dart',
      ),
      Analytics(
        id: 'analytics',
        name: '统计服务',
        description: '用户行为统计',
        file: 'analytics.dart',
      ),
      ServiceMonitor(
        id: 'service_monitor',
        name: '服务监控',
        description: '健康检查',
        file: 'service_monitor.dart',
      ),
    ],
  ),
  
  // === 扩展服务 ===
  ServiceGroup(
    name: '🔌 扩展服务',
    icon: '🔌',
    services: [
      PluginManager(
        id: 'plugin',
        name: '插件管理',
        description: '插件加载管理',
        file: 'plugin_manager.dart',
      ),
      ApiGateway(
        id: 'api_gateway',
        name: 'API网关',
        description: '路由+限流',
        file: 'api_gateway.dart',
      ),
      ShareManager(
        id: 'share',
        name: '分享服务',
        description: '多平台分享',
        file: 'share_manager.dart',
      ),
      BackupManager(
        id: 'backup',
        name: '备份服务',
        description: '数据备份恢复',
        file: 'backup_manager.dart',
      ),
    ],
  ),
];