import 'package:hive/hive.dart';
import '../models/redis_connection_info.dart';

class RedisStorage {
  static const String boxName = 'redis_connection_info';

  static Box<RedisConnectionInfo> get _box =>
      Hive.box<RedisConnectionInfo>(boxName);

  /// 获取所有连接
  static List<RedisConnectionInfo> getAll() {
    return _box.values.toList();
  }

  /// 添加连接
  static Future<void> add(RedisConnectionInfo conn) async {
    await _box.put(conn.id, conn);
  }

  /// 删除连接
  static Future<void> delete(String id) async {
    await _box.delete(id);
  }

  /// 更新连接
  static Future<void> update(RedisConnectionInfo conn) async {
    await _box.put(conn.id, conn);
  }

  static Future<void> updateDb(String id, int db) async {
    final conn = _box.get(id);

    if (conn == null) return;

    conn.db = db;
    await conn.save();
  }

  static Future<void> addAll(List<RedisConnectionInfo> list) async {
    final map = {for (var conn in list) conn.id: conn};

    await _box.putAll(map);
  }

  /// 清空
  static Future<void> clear() async {
    await _box.clear();
  }
}
