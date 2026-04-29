import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:redis/redis.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const RedisClientApp());
}

class RedisClientApp extends StatelessWidget {
  const RedisClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0E7490),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Redis Client',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF4F7F7),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: colorScheme.inverseSurface,
          contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        ),
      ),
      home: const RedisWorkbenchPage(),
    );
  }
}

class RedisWorkbenchPage extends StatefulWidget {
  const RedisWorkbenchPage({super.key});

  @override
  State<RedisWorkbenchPage> createState() => _RedisWorkbenchPageState();
}

class _RedisWorkbenchPageState extends State<RedisWorkbenchPage> {
  final List<RedisServerConnection> _connections = [];
  String? _selectedConnectionId;

  final hostController = TextEditingController(text: '127.0.0.1');
  final portController = TextEditingController(text: '6379');
  final dbController = TextEditingController(text: '0');
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  final addKeyController = TextEditingController();
  final addKeyValueController = TextEditingController();
  final addKeyTtlController = TextEditingController();

  RedisServerConnection? get _selectedConnection {
    for (final connection in _connections) {
      if (connection.id == _selectedConnectionId) {
        return connection;
      }
    }
    return null;
  }

  @override
  void dispose() {
    for (final connection in _connections) {
      unawaited(connection.disconnect());
    }
    hostController.dispose();
    portController.dispose();
    dbController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    addKeyController.dispose();
    addKeyValueController.dispose();
    addKeyTtlController.dispose();
    super.dispose();
  }

  Future<void> _showAddConnectionDialog() async {
    final formKey = GlobalKey<FormState>();

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('新增 Redis 连接'),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: hostController,
                      decoration: const InputDecoration(
                        labelText: 'Host',
                        hintText: '127.0.0.1',
                        prefixIcon: Icon(Icons.dns_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入 Redis 地址';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: portController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              prefixIcon: Icon(Icons.settings_ethernet),
                            ),
                            validator: (value) {
                              final port = int.tryParse(value ?? '');
                              if (port == null || port <= 0 || port > 65535) {
                                return '端口无效';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: dbController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'DB',
                              prefixIcon: Icon(Icons.storage_outlined),
                            ),
                            validator: (value) {
                              final db = int.tryParse(value ?? '');
                              if (db == null || db < 0) {
                                return 'DB 无效';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: '可选',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        hintText: '可选',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }

                  final connection = RedisServerConnection(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    host: hostController.text.trim(),
                    port: int.parse(portController.text.trim()),
                    db: int.parse(dbController.text.trim()),
                    username: usernameController.text.trim(),
                    password: passwordController.text,
                  );

                  setState(() {
                    _connections.add(connection);
                    _selectedConnectionId = connection.id;
                  });

                  Navigator.of(dialogContext).pop();
                  await _refreshConnection(connection, showSuccess: true);
                },
                icon: const Icon(Icons.add_link),
                label: const Text('保存并连接'),
              ),
            ],
          );
        },
      );
    } finally {}
  }

  Future<void> _refreshConnection(
    RedisServerConnection connection, {
    bool showSuccess = false,
  }) async {
    setState(() {
      connection.isBusy = true;
      connection.lastError = null;
    });

    try {
      await connection.connectAndLoad();

      if (!mounted) {
        return;
      }

      setState(() {});

      if (showSuccess) {
        _showMessage(
          '已连接 ${connection.host}:${connection.port}，DB ${connection.db}',
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {});
      _showMessage('连接失败: $error', isError: true);
    }
  }

  Future<void> _disconnectConnection(RedisServerConnection connection) async {
    setState(() {
      connection.isBusy = true;
      connection.lastError = null;
    });

    await connection.disconnect();

    if (!mounted) {
      return;
    }

    setState(() {});
    _showMessage('已断开 ${connection.host}:${connection.port}');
  }

  Future<void> _deleteConnection(RedisServerConnection connection) async {
    if (_selectedConnectionId == connection.id) {
      _selectedConnectionId = null;
    }
    await connection.disconnect();
    setState(() {
      _connections.removeWhere((c) => c.id == connection.id);
    });
    _showMessage('已删除 ${connection.host}:${connection.port}');
  }

  Future<void> _selectKey(RedisServerConnection connection, String key) async {
    setState(() {
      connection.selectedKey = key;
      connection.isValueLoading = true;
      connection.lastError = null;
    });

    try {
      await connection.loadValue(key);
    } catch (error) {
      connection.lastError = error.toString();
      connection.selectedValue = null;
    }

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _deleteKey(RedisServerConnection connection, String key) async {
    try {
      await connection.deleteKey(key);
      _showMessage('已删除 Key: $key');
      await _refreshConnection(connection);
    } catch (error) {
      _showMessage('删除 Key 失败: $error', isError: true);
    }
  }

  // 目前只支持string，后续扩展
  Future<void> _addKey(RedisServerConnection connection) async {
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('添加 Key'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: addKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Key',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addKeyValueController,
                  decoration: const InputDecoration(
                    labelText: 'Value',
                    prefixIcon: Icon(Icons.edit_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  controller: addKeyTtlController,
                  decoration: const InputDecoration(
                    labelText: 'TTL (秒)',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => {
                  Navigator.of(dialogContext).pop(),
                  addKeyController.clear(),
                  addKeyValueController.clear(),
                  addKeyTtlController.clear(),
                },
                child: const Text('取消'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final newKey = addKeyController.text.trim();
                  final newValue = addKeyValueController.text;
                  final newTtl = int.tryParse(addKeyTtlController.text);
                  if (newKey.isEmpty) {
                    return;
                  }

                  try {
                    if (newTtl != null) {
                      await connection._command?.send_object([
                        'SET',
                        newKey,
                        newValue,
                        'EX',
                        newTtl,
                      ]);
                    } else {
                      await connection._command?.send_object([
                        'SET',
                        newKey,
                        newValue,
                      ]);
                    }
                    _showMessage('已添加 Key: $newKey');
                    await _refreshConnection(connection);

                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                      addKeyController.clear();
                      addKeyValueController.clear();
                      addKeyTtlController.clear();
                    }
                  } catch (error) {
                    _showMessage('添加 Key 失败: $error', isError: true);
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('添加'),
              ),
            ],
          );
        },
      );
    } finally {}
  }

  void _showMessage(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Theme.of(context).colorScheme.errorContainer
              : null,
          showCloseIcon: true,
          duration: Duration(milliseconds: 1000),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Redis Client'),
      //   centerTitle: false,
      //   actions: [
      //     Padding(
      //       padding: const EdgeInsets.only(right: 16),
      //       child: FilledButton.icon(
      //         onPressed: _showAddConnectionDialog,
      //         icon: const Icon(Icons.add),
      //         label: const Text('新增连接'),
      //       ),
      //     ),
      //   ],
      // ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1100;
          final leftPane = _buildConnectionPane(context);
          final rightPane = _buildWorkspacePane(context);

          if (isWide) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  SizedBox(width: 360, child: leftPane),
                  const SizedBox(width: 20),
                  Expanded(child: rightPane),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(height: 300, child: leftPane),
                const SizedBox(height: 16),
                Expanded(child: rightPane),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionPane(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _connections.isEmpty
                  ? _EmptyStateCard(
                      icon: Icons.hub_outlined,
                      title: '没有 Redis 连接',
                      message: '',
                      actionLabel: '新增连接',
                      onPressed: _showAddConnectionDialog,
                    )
                  : ListView.separated(
                      itemCount: _connections.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final connection = _connections[index];
                        final isSelected =
                            connection.id == _selectedConnectionId;
                        return _ConnectionCard(
                          connection: connection,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              _selectedConnectionId = connection.id;
                            });
                          },
                          onRefresh: () => _refreshConnection(connection),
                          onDisconnect: () => _disconnectConnection(connection),
                          onDelete: () => _deleteConnection(connection),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspacePane(BuildContext context) {
    final connection = _selectedConnection;
    final theme = Theme.of(context);

    if (connection == null) {
      return _EmptyStateCard(
        icon: Icons.view_sidebar_outlined,
        title: '请选择一个连接',
        message: '',
        actionLabel: '新增连接',
        onPressed: _showAddConnectionDialog,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${connection.host}:${connection.port}',
                  style: theme.textTheme.headlineSmall,
                ),
                Chip(
                  avatar: const Icon(Icons.storage, size: 18),
                  label: Text('DB ${connection.db}'),
                ),
                Chip(
                  avatar: Icon(
                    connection.isConnected
                        ? Icons.check_circle
                        : Icons.portable_wifi_off,
                    size: 18,
                  ),
                  label: Text(connection.isConnected ? '已连接' : '未连接'),
                ),
              ],
            ),
            if (connection.lastError != null) ...[
              const SizedBox(height: 12),
              Text(
                connection.lastError!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 760;
                  final keyPane = _buildKeyListPane(context, connection);
                  final valuePane = _buildValuePane(context, connection);

                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(flex: 2, child: keyPane),
                        const SizedBox(width: 16),
                        Expanded(flex: 3, child: valuePane),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      Expanded(child: keyPane),
                      const SizedBox(height: 16),
                      Expanded(child: valuePane),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyListPane(
    BuildContext context,
    RedisServerConnection connection,
  ) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: const Text('Key 列表'),
            subtitle: Text('共 ${connection.keys.length} 个'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '添加Key',
                  onPressed: () => _addKey(connection),
                  icon: const Icon(Icons.add),
                ),
                IconButton(
                  tooltip: '刷新',
                  onPressed: connection.isBusy
                      ? null
                      : () => _refreshConnection(connection),
                  icon: connection.isBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: !connection.isConnected && connection.keys.isEmpty
                ? _InlineHint(
                    icon: Icons.link_off,
                    message: '连接断开后无法读取 key。点击刷新可以重新连接。',
                  )
                : connection.keys.isEmpty
                ? _InlineHint(
                    icon: Icons.key_off_outlined,
                    message: '当前 DB 暂无 key，或还没有完成加载。',
                  )
                : ListView.builder(
                    itemCount: connection.keys.length,
                    itemBuilder: (context, index) {
                      final key = connection.keys[index];
                      final isSelected = key == connection.selectedKey;
                      return ListTile(
                        selected: isSelected,
                        leading: Icon(
                          isSelected ? Icons.vpn_key : Icons.vpn_key_outlined,
                        ),
                        title: Text(
                          key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18, // 图标缩小
                            color: Colors.redAccent,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          splashRadius: 18,
                          tooltip: "删除 Key",
                          onPressed: () {
                            _deleteKey(connection, key);
                          },
                        ),
                        onTap: () => _selectKey(connection, key),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildValuePane(
    BuildContext context,
    RedisServerConnection connection,
  ) {
    final theme = Theme.of(context);
    final selectedKey = connection.selectedKey;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: selectedKey == null
            ? const _InlineHint(
                icon: Icons.preview_outlined,
                message: '请选择一个 key 查看 value。',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            Text(
                              selectedKey,
                              style: theme.textTheme.titleLarge,
                            ),
                            if (connection.selectedValueType != null)
                              Chip(label: Text(connection.selectedValueType!)),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TTLWidget(
                          keyName: selectedKey,
                          loadTTL: connection.keyTtl,
                          showRefresh: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: connection.isValueLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF11212A),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                connection.selectedValue ?? '(empty)',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  color: Color(0xFFE7F6F8),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class TTLWidget extends StatefulWidget {
  final String keyName;

  final Future<int> Function(String keyName) loadTTL;

  final Duration syncInterval;

  final bool showRefresh;

  const TTLWidget({
    super.key,
    required this.keyName,
    required this.loadTTL,
    this.syncInterval = const Duration(seconds: 10),
    this.showRefresh = true,
  });

  @override
  State<TTLWidget> createState() => _TTLWidgetState();
}

class _TTLWidgetState extends State<TTLWidget> {
  int _ttl = -1;
  bool _loading = true;

  Timer? _countdownTimer;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _initTTL();
  }

  @override
  void didUpdateWidget(covariant TTLWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // key切换时重新加载
    if (oldWidget.keyName != widget.keyName) {
      _stopTimers();
      _initTTL();
    }
  }

  Future<void> _initTTL() async {
    setState(() {
      _loading = true;
    });

    await _fetchTTL();

    _startCountdown();
    _startSync();

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _fetchTTL() async {
    try {
      final value = await widget.loadTTL(widget.keyName);

      if (!mounted) return;

      setState(() {
        _ttl = value;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _ttl = -2;
      });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      if (_ttl > 0) {
        setState(() {
          _ttl--;
        });
      }
    });
  }

  void _startSync() {
    _syncTimer?.cancel();

    _syncTimer = Timer.periodic(widget.syncInterval, (_) async {
      await _fetchTTL();
    });
  }

  void _stopTimers() {
    _countdownTimer?.cancel();
    _syncTimer?.cancel();
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  Color _getColor(ThemeData theme) {
    if (_ttl == -2) return Colors.red;
    if (_ttl == -1) return Colors.blueGrey;
    if (_ttl <= 10) return Colors.red;
    if (_ttl <= 60) return Colors.orange;
    return Colors.green;
  }

  String _getText() {
    if (_loading) return "TTL...";
    if (_ttl == -1) return "永久";
    if (_ttl == -2) return "已过期";
    return "${_ttl}s";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getColor(theme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            _getText(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.showRefresh) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: _fetchTTL,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.refresh, size: 14, color: color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class RedisServerConnection {
  RedisServerConnection({
    required this.id,
    required this.host,
    required this.port,
    required this.db,
    required this.username,
    required this.password,
  });

  final String id;
  final String host;
  final int port;
  int db;
  final String username;
  final String password;

  RedisConnection? _client;
  Command? _command;

  bool isBusy = false;
  bool isConnected = false;
  bool isValueLoading = false;
  String? selectedKey;
  String? selectedValue;
  String? selectedValueType;
  int? selectedKeyTtl;
  String? lastError;
  List<String> keys = const [];

  Future<void> connectAndLoad() async {
    isBusy = true;

    try {
      await disconnect(clearState: false);

      final client = RedisConnection();
      final command = await client
          .connect(host, port)
          .timeout(const Duration(seconds: 5));

      if (password.trim().isNotEmpty) {
        if (username.trim().isNotEmpty) {
          await command.send_object(['AUTH', username.trim(), password]);
        } else {
          await command.send_object(['AUTH', password]);
        }
      }

      if (db != 0) {
        await command.send_object(['SELECT', db]);
      }

      _client = client;
      _command = command;
      isConnected = true;

      final loadedKeys = await _loadKeys();
      keys = loadedKeys;

      if (selectedKey != null && !keys.contains(selectedKey)) {
        selectedKey = null;
        selectedValue = null;
        selectedValueType = null;
      } else if (selectedKey != null) {
        await loadValue(selectedKey!);
      }
    } catch (error) {
      lastError = error.toString();
      isConnected = false;
      rethrow;
    } finally {
      isBusy = false;
      isValueLoading = false;
    }
  }

  Future<void> disconnect({bool clearState = true}) async {
    try {
      await _client?.close();
    } catch (_) {
      // Ignore close failures from already terminated sockets.
    } finally {
      _client = null;
      _command = null;
      isConnected = false;
      isBusy = false;
      isValueLoading = false;
      if (clearState) {
        keys = const [];
        selectedKey = null;
        selectedValue = null;
        selectedValueType = null;
      }
    }
  }

  Future<void> loadValue(String key) async {
    final command = _command;
    if (command == null) {
      throw StateError('当前连接不可用，请先刷新或重新连接。');
    }

    isValueLoading = true;

    try {
      final typeResponse = await command.send_object(['TYPE', key]);
      final type = typeResponse?.toString() ?? 'unknown';
      final valueResponse = await _readValueByType(command, key, type);

      selectedKey = key;
      selectedValueType = type;
      selectedKeyTtl = await keyTtl(key);
      selectedValue = _formatValue(type, valueResponse);
    } finally {
      isValueLoading = false;
    }
  }

  Future<List<String>> _loadKeys() async {
    final command = _command;
    if (command == null) {
      throw StateError('当前连接不可用，请先刷新或重新连接。');
    }

    final response = await command.send_object(['KEYS', '*']);
    final list = response is List ? response : const <dynamic>[];
    final loadedKeys = list.map((item) => item.toString()).toList()..sort();
    return loadedKeys;
  }

  Future<dynamic> _readValueByType(
    Command command,
    String key,
    String type,
  ) async {
    switch (type) {
      case 'string':
        return command.send_object(['GET', key]);
      case 'hash':
        return command.send_object(['HGETALL', key]);
      case 'list':
        return command.send_object(['LRANGE', key, '0', '-1']);
      case 'set':
        return command.send_object(['SMEMBERS', key]);
      case 'zset':
        return command.send_object(['ZRANGE', key, '0', '-1', 'WITHSCORES']);
      case 'stream':
        return command.send_object(['XRANGE', key, '-', '+']);
      case 'none':
        return null;
      default:
        return 'Unsupported Redis type: $type';
    }
  }

  String _formatValue(String type, dynamic rawValue) {
    if (rawValue == null) {
      return '(null)';
    }

    if (type == 'string') {
      return rawValue.toString();
    }

    final normalized = switch (type) {
      'hash' => _toMap(rawValue),
      'zset' => _toPairList(rawValue),
      'stream' => _toStreamList(rawValue),
      _ => _normalize(rawValue),
    };

    return const JsonEncoder.withIndent('  ').convert(normalized);
  }

  Map<String, dynamic> _toMap(dynamic rawValue) {
    final list = rawValue is List ? rawValue : const <dynamic>[];
    final result = <String, dynamic>{};
    for (var index = 0; index < list.length; index += 2) {
      final key = list[index].toString();
      final value = index + 1 < list.length
          ? _normalize(list[index + 1])
          : null;
      result[key] = value;
    }
    return result;
  }

  List<Map<String, dynamic>> _toPairList(dynamic rawValue) {
    final list = rawValue is List ? rawValue : const <dynamic>[];
    final result = <Map<String, dynamic>>[];
    for (var index = 0; index < list.length; index += 2) {
      result.add({
        'member': list[index].toString(),
        'score': index + 1 < list.length ? list[index + 1] : null,
      });
    }
    return result;
  }

  List<Map<String, dynamic>> _toStreamList(dynamic rawValue) {
    final list = rawValue is List ? rawValue : const <dynamic>[];
    final result = <Map<String, dynamic>>[];

    for (final entry in list) {
      if (entry is List && entry.length >= 2) {
        result.add({'id': entry[0].toString(), 'fields': _toMap(entry[1])});
      }
    }

    return result;
  }

  dynamic _normalize(dynamic value) {
    if (value is List) {
      return value.map(_normalize).toList();
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _normalize(item)),
      );
    }
    return value;
  }

  Future<void> deleteKey(String key) async {
    final command = _command;
    if (command == null) {
      throw StateError('当前连接不可用，请先刷新或重新连接。');
    }

    await command.send_object(['DEL', key]);
  }

  Future<int> keyTtl(String key) async {
    final command = _command;
    if (command == null) {
      throw StateError('当前连接不可用，请先刷新或重新连接。');
    }

    final ttlResponse = await command.send_object(['TTL', key]);
    return int.tryParse(ttlResponse?.toString() ?? '-1') ?? -1;
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.connection,
    required this.isSelected,
    required this.onTap,
    required this.onRefresh,
    required this.onDisconnect,
    required this.onDelete,
  });

  final RedisServerConnection connection;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRefresh;
  final VoidCallback onDisconnect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;

    return Card(
      elevation: isSelected ? 4 : 0,
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
          : theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor),
        borderRadius: BorderRadius.circular(22),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    connection.isConnected
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${connection.host}:${connection.port}',
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton.outlined(
                    iconSize: 12,
                    style: IconButton.styleFrom(minimumSize: Size(12, 12)),
                    onPressed: connection.isBusy ? null : onRefresh,
                    icon: connection.isBusy
                        ? const SizedBox(
                            width: 8,
                            height: 8,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    tooltip: '刷新',
                  ),
                  const SizedBox(width: 4),
                  IconButton.outlined(
                    iconSize: 12,
                    style: IconButton.styleFrom(minimumSize: Size(12, 12)),
                    onPressed: connection.isBusy || !connection.isConnected
                        ? null
                        : onDisconnect,
                    icon: const Icon(Icons.link_off),
                    tooltip: '断开连接',
                  ),
                  const SizedBox(width: 4),
                  IconButton.outlined(
                    iconSize: 12,
                    style: IconButton.styleFrom(minimumSize: Size(12, 12)),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete),
                    tooltip: '删除',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: connection.db,
                    icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                    borderRadius: BorderRadius.circular(12),
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    items: List.generate(16, (index) {
                      return DropdownMenuItem(
                        value: index,
                        child: Text("DB $index"),
                      );
                    }),
                    onChanged: (value) {
                      if (value != null) {
                        connection.db = value;
                        onRefresh();
                      }
                    },
                  ),
                ),
              ),
              // Wrap(
              //   spacing: 8,
              //   runSpacing: 8,
              //   children: [
              //     Chip(label: Text('DB ${connection.db}')),
              //     Chip(
              //       avatar: Icon(
              //         connection.isConnected
              //             ? Icons.check_circle_outline
              //             : Icons.pause_circle_outline,
              //         size: 18,
              //       ),
              //       label: Text(connection.isConnected ? '已连接' : '已断开'),
              //     ),
              //   ],
              // ),
              if (connection.lastError != null) ...[
                const SizedBox(height: 12),
                Text(
                  connection.lastError!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        // border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.add),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineHint extends StatelessWidget {
  const _InlineHint({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
