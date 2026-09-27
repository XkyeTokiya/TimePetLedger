import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/identity/entity_id.dart';

void main() {
  test('接受调用方提供的 UUID v4，保留不透明原值', () {
    for (final variant in ['8', '9', 'a', 'b']) {
      final id = '12345678-1234-4abc-${variant}123-123456789abc';
      expect(requireUuidV4(id), id);
      expect(requireUuidV4(id.toUpperCase()), id.toUpperCase());
    }
  });

  test('拒绝缺失、格式错误、其他版本及错误变体，不生成替代身份', () {
    for (final id in [
      '',
      '1234567812344abc8123123456789abc',
      '12345678-1234-1abc-8123-123456789abc',
      '12345678-1234-4abc-7123-123456789abc',
      '12345678-1234-4abc-c123-123456789abc',
      '12345678-1234-4abc-8123-123456789abg',
      '12345678-1234-4abc-8123-123456789abc\n',
    ]) {
      expect(() => requireUuidV4(id), throwsArgumentError);
    }
  });
}
