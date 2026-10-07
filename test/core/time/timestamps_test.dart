import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/timestamps.dart';

void main() {
  test('Q-018：创建使用显式输入的同一次取时，保留毫秒', () {
    expect(timestampsForCreation(now: 1720000000123), (
      createdAt: 1720000000123,
      updatedAt: 1720000000123,
    ));
  });

  const Timestamps previous = (createdAt: 1001, updatedAt: 2002);
  test('只有内容变化且保存成功才更新 updatedAt', () {
    for (final changed in [false, true]) {
      for (final succeeded in [false, true]) {
        final result = timestampsAfterSave(
          previous: previous,
          now: 3003,
          contentChanged: changed,
          saveSucceeded: succeeded,
        );
        expect(result.createdAt, 1001);
        expect(result.updatedAt, changed && succeeded ? 3003 : 2002);
        expect(previous, (createdAt: 1001, updatedAt: 2002));
      }
    }
    final saved = timestampsAfterSave(
      previous: previous,
      now: 3003,
      contentChanged: true,
      saveSucceeded: true,
    );
    expect(
      timestampsAfterSave(
        previous: saved,
        now: 4004,
        contentChanged: false,
        saveSucceeded: true,
      ),
      saved,
    );
  });
}
