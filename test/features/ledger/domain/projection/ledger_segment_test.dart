import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_segment.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/reconciliation_window.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_annotation.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

const _id = '12345678-1234-4abc-8123-123456789abc';
const _otherId = '12345678-1234-4abc-8123-123456789abd';

TimeBlock _block(
  int start,
  int end, {
  String id = _id,
  TimePrecision startPrecision = TimePrecision.exact,
  TimePrecision endPrecision = TimePrecision.exact,
  BlockKnowledgeState knowledge = BlockKnowledgeState.known,
}) => TimeBlock(
  id: id,
  startedAt: start,
  endedAt: end,
  startPrecision: startPrecision,
  endPrecision: endPrecision,
  knowledgeState: knowledge,
  title: knowledge == BlockKnowledgeState.known ? '阅读论文' : null,
  goalId: _otherId,
  categoryId: 'reserved',
  note: '保留备注',
  createdAt: 1,
  updatedAt: 2,
);

SleepSession _sleep(
  int start,
  int end, {
  TimePrecision startPrecision = TimePrecision.exact,
  TimePrecision endPrecision = TimePrecision.exact,
}) => SleepSession(
  id: _id,
  startedAt: start,
  endedAt: end,
  startPrecision: startPrecision,
  endPrecision: endPrecision,
  type: SleepType.mainSleep,
  note: '完整跨日睡眠',
  createdAt: 3,
  updatedAt: 4,
);

ReconciliationWindow _window({
  int start = 100,
  int end = 200,
  LedgerDateRelation relation = LedgerDateRelation.historical,
  int? now,
}) => ReconciliationWindow.select(
  date: CivilDate(year: 2026, month: 9, day: 22),
  relation: relation,
  dayStartedAt: start,
  nextDayStartedAt: end,
  now: now ?? end,
);

RhythmAnnotation _annotation({String blockId = _id, String id = _otherId}) =>
    RhythmAnnotation(
      id: id,
      timeBlockId: blockId,
      state: RhythmState.progress,
      continuationHint: '下次继续读方法章节',
      createdAt: 5,
      updatedAt: 6,
    );

void main() {
  test('SL-002：23:50–07:40 保留一个原事实，两日分别贡献 10 分和 7h40m', () {
    final midnight = DateTime.utc(2026, 9, 22).millisecondsSinceEpoch;
    final sleep = _sleep(midnight - 600000, midnight + 27600000);
    final days = [
      (CivilDate(year: 2026, month: 9, day: 21), midnight - 86400000, midnight),
      (CivilDate(year: 2026, month: 9, day: 22), midnight, midnight + 86400000),
    ];
    final parts = [
      for (final (date, start, end) in days)
        projectLedgerSegments(
              window: ReconciliationWindow.select(
                date: date,
                relation: LedgerDateRelation.historical,
                dayStartedAt: start,
                nextDayStartedAt: end,
                now: midnight + 172800000,
              ),
              timeBlocks: [],
              sleepSessions: [sleep],
              annotations: [],
            ).single
            as SleepSessionSegment,
    ];
    expect(parts.map((part) => part.duration.milliseconds), [600000, 27600000]);
    expect(parts.map((part) => part.startedAt), [sleep.startedAt, midnight]);
    expect(parts.map((part) => part.endedAt), [midnight, sleep.endedAt]);
    for (final part in parts) {
      expect(part.source, same(sleep));
      expect(part.source.note, '完整跨日睡眠');
      expect(part.source.type, SleepType.mainSleep);
      expect(part.reference, (type: LedgerFactType.sleepSession, id: _id));
    }
    expect(sleep.startedAt, midnight - 600000);
    expect(sleep.endedAt, midnight + 27600000);
  });

  test('Q-017：两类事实窗口外与仅相接都不生成切片', () {
    for (final (start, end) in [(1, 99), (1, 100), (200, 250), (201, 250)]) {
      expect(
        projectLedgerSegments(
          window: _window(),
          timeBlocks: [_block(start, end)],
          sleepSessions: [],
          annotations: [_annotation()],
        ),
        isEmpty,
      );
      expect(
        projectLedgerSegments(
          window: _window(),
          timeBlocks: [],
          sleepSessions: [_sleep(start, end)],
          annotations: [],
        ),
        isEmpty,
      );
    }
  });

  test('Q-009：空窗口不生成切片，包括跨越零点的事实', () {
    for (final relation in [
      LedgerDateRelation.today,
      LedgerDateRelation.future,
    ]) {
      expect(
        projectLedgerSegments(
          window: _window(relation: relation, now: 100),
          timeBlocks: [_block(90, 120)],
          sleepSessions: [_sleep(130, 150)],
          annotations: [_annotation()],
        ),
        isEmpty,
      );
    }
  });

  test('Q-009 / Q-014：跨 now 只贡献已发生部分，裁掉的近似结束不传播', () {
    for (final isSleep in [false, true]) {
      final result = projectLedgerSegments(
        window: _window(relation: LedgerDateRelation.today, now: 150),
        timeBlocks: isSleep
            ? []
            : [_block(120, 180, endPrecision: TimePrecision.approximate)],
        sleepSessions: isSleep
            ? [_sleep(120, 180, endPrecision: TimePrecision.approximate)]
            : [],
        annotations: [],
      ).single;
      expect(result.startedAt, 120);
      expect(result.endedAt, 150);
      expect(result.duration.milliseconds, 30);
      expect(result.endPrecision, TimePrecision.exact);
      expect(result.duration.hasApproximation, isFalse);
    }
  });

  test('Q-014：两端独立，裁掉才消除近似，恰等于窗口边界仍保留', () {
    // 每类事实分别覆盖完整位于窗口、左裁、右裁、双裁及边界相等。
    for (final isSleep in [false, true]) {
      for (final start in [90, 100, 110]) {
        for (final end in [190, 200, 210]) {
          for (final startPrecision in TimePrecision.values) {
            for (final endPrecision in TimePrecision.values) {
              final result = projectLedgerSegments(
                window: _window(),
                timeBlocks: isSleep
                    ? []
                    : [
                        _block(
                          start,
                          end,
                          startPrecision: startPrecision,
                          endPrecision: endPrecision,
                        ),
                      ],
                sleepSessions: isSleep
                    ? [
                        _sleep(
                          start,
                          end,
                          startPrecision: startPrecision,
                          endPrecision: endPrecision,
                        ),
                      ]
                    : [],
                annotations: [],
              ).single;
              final expectedStart = start < 100
                  ? TimePrecision.exact
                  : startPrecision;
              final expectedEnd = end > 200
                  ? TimePrecision.exact
                  : endPrecision;
              expect(result.startPrecision, expectedStart);
              expect(result.endPrecision, expectedEnd);
              expect(
                result.duration.hasApproximation,
                expectedStart == TimePrecision.approximate ||
                    expectedEnd == TimePrecision.approximate,
              );
              switch (result) {
                case TimeBlockSegment(:final source):
                  expect(source.startPrecision, startPrecision);
                  expect(source.endPrecision, endPrecision);
                case SleepSessionSegment(:final source):
                  expect(source.startPrecision, startPrecision);
                  expect(source.endPrecision, endPrecision);
              }
            }
          }
        }
      }
    }
  });

  test('源类型和 id 共同标识：同 id 睡眠不接收 TimeBlock 的解释', () {
    final block = _block(150, 175);
    final sleep = _sleep(100, 140);
    final annotation = _annotation();
    final result = projectLedgerSegments(
      window: _window(),
      timeBlocks: [block],
      sleepSessions: [sleep],
      annotations: [annotation],
    );
    expect(result, hasLength(2));
    expect(result.first, isA<SleepSessionSegment>());
    expect((result.first as SleepSessionSegment).source, same(sleep));
    final blockPart = result.last as TimeBlockSegment;
    expect(blockPart.source, same(block));
    expect(blockPart.annotation, same(annotation));
    expect(blockPart.reference, (type: LedgerFactType.timeBlock, id: _id));
    expect(result.first.reference, isNot(blockPart.reference));
    expect(blockPart.source.title, '阅读论文');
    expect(blockPart.source.goalId, _otherId);
    expect(blockPart.source.note, '保留备注');
    expect(blockPart.source.categoryId, 'reserved');
    expect(blockPart.annotation?.continuationHint, '下次继续读方法章节');
  });

  test('未排序输入合并按时间排列，不修改输入或自动给其他记录解释', () {
    final first = _block(
      101,
      110,
      id: _otherId,
      knowledge: BlockKnowledgeState.unknown,
    );
    final last = _block(160, 180);
    final blocks = [last, first];
    final sleeps = [_sleep(120, 150)];
    final result = projectLedgerSegments(
      window: _window(),
      timeBlocks: blocks,
      sleepSessions: sleeps,
      annotations: [_annotation()],
    );
    expect(result.map((part) => part.startedAt), [101, 120, 160]);
    expect((result.first as TimeBlockSegment).source, same(first));
    expect((result.first as TimeBlockSegment).source.title, isNull);
    expect(
      (result.first as TimeBlockSegment).source.knowledgeState,
      BlockKnowledgeState.unknown,
    );
    expect((result.first as TimeBlockSegment).annotation, isNull);
    expect(result.first.duration.hasApproximation, isFalse);
    expect(blocks, [same(last), same(first)]);
    expect(sleeps.single.startedAt, 120);
    expect(() => result.clear(), throwsUnsupportedError);
  });

  test('Q-017：一毫秒正交集保留，内部时长不舍入', () {
    for (final isSleep in [false, true]) {
      final result = projectLedgerSegments(
        window: _window(),
        timeBlocks: isSleep ? [] : [_block(99, 101)],
        sleepSessions: isSleep ? [_sleep(199, 201)] : [],
        annotations: [],
      ).single;
      expect(result.duration.milliseconds, 1);
      expect(result.duration.roundedMinutes, 0);
    }
  });

  test('RH-001：重复解释引用拒绝，不静默选择或覆盖', () {
    expect(
      () => projectLedgerSegments(
        window: _window(),
        timeBlocks: [_block(110, 120)],
        sleepSessions: [],
        annotations: [
          _annotation(),
          _annotation(id: _id),
        ],
      ),
      throwsArgumentError,
    );
  });
}
