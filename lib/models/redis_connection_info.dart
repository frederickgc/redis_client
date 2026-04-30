import 'package:hive/hive.dart';

part 'redis_connection_info.g.dart';

@HiveType(typeId: 1)
class RedisConnectionInfo extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String host;
  @HiveField(2)
  int port;
  @HiveField(3)
  int db;
  @HiveField(4)
  String? username;
  @HiveField(5)
  String? password;

  RedisConnectionInfo({
    required this.id,
    required this.host,
    required this.port,
    required this.db,
    this.username,
    this.password,
  });
}
