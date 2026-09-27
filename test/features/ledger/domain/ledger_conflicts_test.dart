import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

const _id = '12345678-1234-4abc-8123-123456789abc';
const _otherId = '87654321-4321-4abc-9123-123456789abc';

LedgerFactInterval _interval(
  LedgerFactType type,
  int start,
  int end, {
  String id = _id,
  TimePrecision startPrecision = TimePrecision.exact,
  TimePrecision endPrecision = TimePrecision.exact,
  BlockKnowledgeState knowledgeState = BlockKnowledgeState.known,
  SleepType sleepType = SleepType.mainSleep,
}) => switch (type) {
  LedgerFactType.timeBlock => LedgerFactInterval.fromTimeBlock(
    TimeBlock(
      id: id,
      startedAt: start,
      endedAt: end,
      startPrecision: startPrecision,
      endPrecision: endPrecision,
      knowledgeState: knowledgeState,
      title: knowledgeState == BlockKnowledgeState.known ? '活动' : null,
      createdAt: 0,
      updatedAt: 0,
    ),
  ),
  LedgerFactType.sleepSession => LedgerFactInterval.fromSleepSession(
    SleepSession(
      id: id,
      startedAt: start,
      endedAt: end,
      startPrecision: startPrecision,
      endPrecision: endPrecision,
      type: sleepType,
      createdAt: 0,
      updatedAt: 0,
    ),
  ),
};

void main() {
  for (final candidateType in LedgerFactType.values) {
    for (final existingType in LedgerFactType.values) {
      final label = '$candidateType / $existingType';
      test('LEDGER-004：$label 包含、被包含、相等、部分相交', () {
        final candidate = _interval(candidateType, 1000, 2000);
        for (final (start, end) in [
          (1200, 1800),
          (500, 2500),
          (1000, 2000),
          (500, 1500),
          (1500, 2500),
          (1000, 1500),
          (1500, 2000),
        ]) {
          final existing = _interval(existingType, start, end, id: _otherId);
          expect(
            findLedgerConflicts(candidate: candidate, existing: [existing]),
            [existing],
          );
          expect(
            findLedgerConflicts(candidate: existing, existing: [candidate]),
            [candidate],
          );
        }
      });

      test('Q-017：$label 双向相接与分离无冲突，1 毫秒交集不舍入', () {
        final candidate = _interval(candidateType, 1000, 2000);
        for (final (start, end, overlaps) in [
          (0, 1000, false),
          (2000, 3000, false),
          (0, 999, false),
          (2001, 3000, false),
          (0, 1001, true),
          (1999, 3000, true),
          (1000, 1001, true),
        ]) {
          final existing = _interval(existingType, start, end, id: _otherId);
          expect(
            findLedgerConflicts(candidate: candidate, existing: [existing]),
            overlaps ? [existing] : isEmpty,
          );
        }
      });

      test('LEDGER-004：$label 每种起止精度组合均不豁免冲突', () {
        for (final candidateStart in TimePrecision.values) {
          for (final candidateEnd in TimePrecision.values) {
            for (final existingStart in TimePrecision.values) {
              for (final existingEnd in TimePrecision.values) {
                final candidate = _interval(
                  candidateType,
                  1000,
                  2000,
                  startPrecision: candidateStart,
                  endPrecision: candidateEnd,
                );
                final existing = _interval(
                  existingType,
                  1500,
                  2500,
                  startPrecision: existingStart,
                  endPrecision: existingEnd,
                );
                expect(
                  findLedgerConflicts(
                    candidate: candidate,
                    existing: [existing],
                  ),
                  [existing],
                );
              }
            }
          }
        }
      });
    }

    test('$candidateType 更新只排除同类型同 id，另一类型同 id 仍冲突', () {
      final candidate = _interval(candidateType, 1000, 2000);
      final old = _interval(candidateType, 900, 1900);
      final otherType = candidateType == LedgerFactType.timeBlock
          ? LedgerFactType.sleepSession
          : LedgerFactType.timeBlock;
      final other = _interval(otherType, 1500, 2500);
      final sameTypeOtherId = _interval(
        candidateType,
        1600,
        2600,
        id: _otherId,
      );
      expect(
        findLedgerConflicts(
          candidate: candidate,
          existing: [old, other, sameTypeOtherId],
          replacing: candidate.reference,
        ),
        [other, sameTypeOtherId],
      );
      expect(findLedgerConflicts(candidate: candidate, existing: [old]), [old]);
      expect(
        findLedgerConflicts(
          candidate: candidate,
          existing: [old],
          replacing: candidate.reference,
        ),
        isEmpty,
      );
      for (final invalid in [other.reference, sameTypeOtherId.reference]) {
        expect(
          () => findLedgerConflicts(
            candidate: candidate,
            existing: [old],
            replacing: invalid,
          ),
          throwsArgumentError,
        );
      }
    });
  }

  test('完整跨日睡眠与前日或次日活动均检查，不按开始日期筛选', () {
    final start = DateTime.utc(2026, 9, 21, 23, 50).millisecondsSinceEpoch;
    final midnight = DateTime.utc(2026, 9, 22).millisecondsSinceEpoch;
    final end = DateTime.utc(2026, 9, 22, 7, 40).millisecondsSinceEpoch;
    final sleep = _interval(LedgerFactType.sleepSession, start, end);
    for (final (from, to) in [
      (start - 1, start + 1),
      (midnight, midnight + 1),
      (end - 1, end + 1),
    ]) {
      final block = _interval(LedgerFactType.timeBlock, from, to);
      expect(findLedgerConflicts(candidate: block, existing: [sleep]), [sleep]);
      expect(findLedgerConflicts(candidate: sleep, existing: [block]), [block]);
    }
    expect(sleep.startedAt, start);
    expect(sleep.endedAt, end);
  });

  test('Unknown、无 Goal 活动和两种睡眠均占据主要时间轴', () {
    for (final state in BlockKnowledgeState.values) {
      for (final type in SleepType.values) {
        final block = _interval(
          LedgerFactType.timeBlock,
          -1000,
          1000,
          knowledgeState: state,
        );
        final sleep = _interval(
          LedgerFactType.sleepSession,
          0,
          2000,
          sleepType: type,
        );
        expect(findLedgerConflicts(candidate: block, existing: [sleep]), [
          sleep,
        ]);
      }
    }
  });

  test('空输入无冲突，未排序输入返回全部冲突且不修改任何区间', () {
    final candidate = _interval(LedgerFactType.timeBlock, 1000, 4000);
    expect(findLedgerConflicts(candidate: candidate, existing: []), isEmpty);
    final late = _interval(LedgerFactType.sleepSession, 3000, 5000);
    final early = _interval(LedgerFactType.timeBlock, 0, 1500, id: _otherId);
    final adjacent = _interval(
      LedgerFactType.sleepSession,
      5000,
      6000,
      id: _otherId,
    );
    final existing = List<LedgerFactInterval>.unmodifiable([
      late,
      adjacent,
      early,
    ]);
    expect(findLedgerConflicts(candidate: candidate, existing: existing), [
      late,
      early,
    ]);
    expect(existing, [late, adjacent, early]);
    expect(
      [
        (late.startedAt, late.endedAt),
        (early.startedAt, early.endedAt),
        (candidate.startedAt, candidate.endedAt),
      ],
      [(3000, 5000), (0, 1500), (1000, 4000)],
    );
  });
}
