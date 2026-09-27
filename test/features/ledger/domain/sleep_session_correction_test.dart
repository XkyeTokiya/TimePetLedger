import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session_correction.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

const _id = '12345678-1234-4abc-8123-123456789abc';
const _otherId = '87654321-4321-4abc-9123-123456789abc';
SleepSession _sleep({
  String id = _id,
  int start = 1000,
  int end = 2000,
  SleepType type = SleepType.mainSleep,
}) => SleepSession(
  id: id,
  startedAt: start,
  endedAt: end,
  type: type,
  startPrecision: TimePrecision.approximate,
  endPrecision: TimePrecision.exact,
  note: '第一段\n\n第二段',
  createdAt: 100,
  updatedAt: 200,
);

SleepSessionCorrectionResult _correct(
  SleepSession? original, {
  Iterable<LedgerFactInterval> existing = const [],
  int now = 300,
  int? start,
  int? end,
  TimePrecision? startPrecision,
  TimePrecision? endPrecision,
  SleepType? type,
  ({String? value})? note,
}) => correctSleepSession(
  original: original,
  existing: existing,
  now: now,
  startedAt: start,
  endedAt: end,
  startPrecision: startPrecision,
  endPrecision: endPrecision,
  type: type,
  note: note,
);

void main() {
  test('Q-013：跨日更正保留一条完整事实、身份和创建时间', () {
    final original = _sleep();
    final start = DateTime.utc(2026, 9, 21, 23, 50).millisecondsSinceEpoch;
    final end = DateTime.utc(2026, 9, 22, 7, 40).millisecondsSinceEpoch;
    final result = _correct(
      original,
      start: start,
      end: end,
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.approximate,
      note: (value: '  更正说明\n\n第二段  '),
    );
    final corrected = result.sleepSession;
    expect(result.changed, isTrue);
    expect(
      (corrected.id, corrected.createdAt, corrected.updatedAt),
      (_id, 100, 300),
    );
    expect((corrected.startedAt, corrected.endedAt), (start, end));
    expect(
      (corrected.startPrecision, corrected.endPrecision),
      (TimePrecision.exact, TimePrecision.approximate),
    );
    expect(corrected.type, SleepType.mainSleep);
    expect(corrected.note, '更正说明\n\n第二段');
    expect(
      (original.startedAt, original.endedAt, original.updatedAt),
      (1000, 2000, 200),
    );
  });

  test('SL-003：两种睡眠类型可双向更正，不改变区间和精度', () {
    for (final type in SleepType.values) {
      final original = _sleep(type: type);
      final other = type == SleepType.mainSleep
          ? SleepType.nap
          : SleepType.mainSleep;
      final changed = _correct(original, type: other).sleepSession;
      expect(changed.type, other);
      expect((changed.startedAt, changed.endedAt), (1000, 2000));
      expect(
        (changed.startPrecision, changed.endPrecision),
        (original.startPrecision, original.endPrecision),
      );
      expect(_correct(changed, type: type).sleepSession.type, type);
    }
  });

  test('每个获准字段可独立更正，变化时更新时间', () {
    final original = _sleep();
    final results = [
      _correct(original, start: 999),
      _correct(original, end: 2001),
      _correct(original, startPrecision: TimePrecision.exact),
      _correct(original, endPrecision: TimePrecision.approximate),
      _correct(original, type: SleepType.nap),
      _correct(original, note: (value: '新备注')),
    ];
    for (final result in results) {
      expect(result.changed, isTrue);
      expect(result.sleepSession.updatedAt, 300);
      expect(result.sleepSession.id, original.id);
      expect(result.sleepSession.createdAt, original.createdAt);
    }
  });

  test('备注可保留或显式清空，空白归一为 null', () {
    final original = _sleep();
    expect(
      _correct(original, type: SleepType.nap).sleepSession.note,
      original.note,
    );
    for (final note in [null, '', ' \n\t ']) {
      final result = _correct(original, note: (value: note));
      expect(result.sleepSession.note, isNull);
      expect(result.changed, isTrue);
    }
  });

  test('无变化、规范化等值与重复请求不更新时间', () {
    final original = _sleep();
    expect(_correct(original).sleepSession, same(original));
    final normalized = _correct(original, note: (value: ' 第一段\n\n第二段 '));
    expect(normalized.changed, isFalse);
    expect(normalized.sleepSession, same(original));
    final changed = _correct(original, type: SleepType.nap).sleepSession;
    final repeated = _correct(changed, type: SleepType.nap, now: 999);
    expect(repeated.changed, isFalse);
    expect(repeated.sleepSession, same(changed));
    expect(repeated.sleepSession.updatedAt, 300);
  });

  test('缺失对象拒绝更正，不创建替代睡眠', () {
    expect(
      () => _correct(null),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('记录已不存在'),
        ),
      ),
    );
  });

  test('Q-016：两种类型与两端精度均拒绝零或反向区间', () {
    for (final type in SleepType.values) {
      for (final startPrecision in TimePrecision.values) {
        for (final endPrecision in TimePrecision.values) {
          for (final end in [1000, 999]) {
            expect(
              () => _correct(
                _sleep(),
                type: type,
                startPrecision: startPrecision,
                endPrecision: endPrecision,
                end: end,
              ),
              throwsArgumentError,
            );
          }
        }
      }
    }
  });

  test('Q-016：历史、未来、1 毫秒和长区间更正均合法', () {
    for (final (start, end) in [
      (-2208988800000, -2208988799999),
      (4102444800000, 4102444800001),
      (-2208988800000, 4102444800000),
    ]) {
      final result = _correct(_sleep(), start: start, end: end);
      expect(
        (result.sleepSession.startedAt, result.sleepSession.endedAt),
        (start, end),
      );
    }
  });

  test('Q-015：备注按 Unicode 码点计数，2000 接受、2001 拒绝', () {
    for (final text in ['😀' * 2000, 'e\u0301' * 1000]) {
      expect(
        _correct(_sleep(), note: (value: ' $text ')).sleepSession.note,
        text,
      );
      expect(
        () => _correct(_sleep(), note: (value: '${text}x')),
        throwsArgumentError,
      );
    }
  });

  test('更新排除旧睡眠自身，相接合法；同 id TimeBlock 和其他睡眠仍冲突', () {
    final original = _sleep();
    final old = LedgerFactInterval.fromSleepSession(original);
    final otherSleep = LedgerFactInterval.fromSleepSession(
      _sleep(id: _otherId, start: 2000, end: 3000),
    );
    final block = LedgerFactInterval.fromTimeBlock(
      TimeBlock(
        id: _id,
        startedAt: 2000,
        endedAt: 3000,
        startPrecision: TimePrecision.approximate,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.unknown,
        createdAt: 0,
        updatedAt: 0,
      ),
    );
    final existing = [old, otherSleep, block];
    expect(_correct(original, existing: existing).changed, isFalse);
    expect(
      () => _correct(original, end: 2001, existing: existing),
      throwsA(
        isA<SleepSessionCorrectionConflict>().having(
          (e) => e.conflicts,
          'conflicts',
          [otherSleep, block],
        ),
      ),
    );
    expect(original.endedAt, 2000);
    expect(original.updatedAt, 200);
  });

  test('无变化也检查冲突；注入回拨时间不改写原对象', () {
    final original = _sleep();
    final overlap = LedgerFactInterval.fromSleepSession(_sleep(id: _otherId));
    expect(
      () => _correct(original, existing: [overlap]),
      throwsA(isA<SleepSessionCorrectionConflict>()),
    );
    final result = _correct(original, type: SleepType.nap, now: -1);
    expect(result.sleepSession.updatedAt, -1);
    expect(result.sleepSession.createdAt, 100);
    expect(original.updatedAt, 200);
  });
}
