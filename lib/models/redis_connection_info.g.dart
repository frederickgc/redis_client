// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'redis_connection_info.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RedisConnectionInfoAdapter extends TypeAdapter<RedisConnectionInfo> {
  @override
  final int typeId = 1;

  @override
  RedisConnectionInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RedisConnectionInfo(
      id: fields[0] as String,
      host: fields[1] as String,
      port: fields[2] as int,
      db: fields[3] as int,
      username: fields[4] as String?,
      password: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, RedisConnectionInfo obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.host)
      ..writeByte(2)
      ..write(obj.port)
      ..writeByte(3)
      ..write(obj.db)
      ..writeByte(4)
      ..write(obj.username)
      ..writeByte(5)
      ..write(obj.password);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RedisConnectionInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
