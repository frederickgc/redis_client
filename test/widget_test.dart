import 'package:flutter_test/flutter_test.dart';

import 'package:redis_client/main.dart';

void main() {
  testWidgets('renders redis client shell', (tester) async {
    await tester.pumpWidget(const RedisClientApp());

    expect(find.text('Redis Client'), findsOneWidget);
    expect(find.text('连接列表'), findsOneWidget);
    expect(find.text('请选择一个连接'), findsOneWidget);
    expect(find.text('新增连接'), findsWidgets);
  });
}
