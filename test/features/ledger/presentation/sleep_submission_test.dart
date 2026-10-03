import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/identity/entity_id.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/time_contract.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_form.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_form_controller.dart';

import 'sleep_form_controller_test.dart'
    show FormSleepStore, sleepContext, fill;
import 'sleep_form_test.dart' show tapText;

class SubmissionRepository implements LedgerRepository {
  SubmissionRepository(this.inner);
  final LedgerRepository inner;
  Completer<void>? gate;
  int creates = 0;
  bool failCreate = false, failRecovery = false;
  @override
  Future<LedgerSnapshot> readWindow({
    required InstantMilliseconds startedAt,
    required InstantMilliseconds endedAt,
  }) {
    if (failRecovery) throw StateError('private recovery SQL');
    return inner.readWindow(startedAt: startedAt, endedAt: endedAt);
  }

  @override
  Future<SleepSession> createSleepSession({
    required EntityId id,
    required InstantMilliseconds startedAt,
    required InstantMilliseconds endedAt,
    required TimePrecision startPrecision,
    required TimePrecision endPrecision,
    required SleepType type,
    required InstantMilliseconds now,
    String? note,
  }) async {
    creates++;
    await gate?.future;
    if (failCreate) throw const LedgerStorageException('private SQL');
    return inner.createSleepSession(
      id: id,
      startedAt: startedAt,
      endedAt: endedAt,
      startPrecision: startPrecision,
      endPrecision: endPrecision,
      type: type,
      now: now,
      note: note,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SubmissionHarness {
  SubmissionHarness(this.db) {
    actual = DriftLedgerRepository(db);
    repository = SubmissionRepository(actual);
    loader = SleepLedgerLoader(
      repository: actual,
      resolveDate: resolveDeviceRecordingDate,
    );
    saver = SleepEntrySaver(
      repository: repository,
      drafts: store,
      newId: () => '00000000-0000-4000-8000-000000000001',
      now: () => DateTime(2026, 9, 29, 12).millisecondsSinceEpoch,
      refresh: ({required date, required now}) async {
        if (failRefresh) throw StateError('private read SQL');
        return loader.load(date: date, now: now);
      },
    );
  }
  final AppDatabase db;
  final store = FormSleepStore();
  late final DriftLedgerRepository actual;
  late final SubmissionRepository repository;
  late final SleepLedgerLoader loader;
  late final SleepEntrySaver saver;
  bool failRefresh = false;
  SleepFormController controller() => SleepFormController(
    context: sleepContext,
    store: store,
    entrySaver: saver,
  );
}

void main() {
  late SubmissionHarness h;
  setUp(() async {
    h = SubmissionHarness(await AppDatabase.open(NativeDatabase.memory()));
  });
  tearDown(() => h.db.close());

  test('submit waits for queued drafts; locks input, discard and duplicate taps until commit', () async {
    final c = h.controller();
    addTearDown(c.dispose);
    await c.initialize();
    h.store.writeGate = Completer<void>();
    fill(c);
    h.repository.gate = Completer<void>();
    final pending = c.submit();
    expect(c.submitting, isTrue);
    expect(c.editable, isFalse);
    expect(await c.submit(), isNull);
    expect(await c.discard(), isFalse);
    c.setType(SleepType.nap);
    expect(c.type, SleepType.mainSleep);
    await Future<void>.delayed(Duration.zero);
    expect(h.repository.creates, 0);
    h.store.writeGate!.complete();
    await c.flush();
    await Future<void>.delayed(Duration.zero);
    expect(h.repository.creates, 1);
    h.repository.gate!.complete();
    final result = await pending;
    expect(result!.coverage.accountedDuration.roundedMinutes, 460);
    expect(result.sleepSummary.mainSleep.records, hasLength(1));
    expect(c.committed!.complete, isTrue);
    expect(h.store.value, isNull);
    expect(await c.submit(), isNull);
    expect(await c.retryFinish(), isNull);
    expect(h.repository.creates, 1);
  });

  test('invalid input, draft failure and formal failure retain inputs without claiming commit', () async {
    final c = h.controller();
    addTearDown(c.dispose);
    await c.initialize();
    expect(await c.submit(), isNull);
    expect(h.repository.creates, 0);
    h.store.failSave = true;
    fill(c);
    expect(await c.submit(), isNull);
    expect(h.repository.creates, 0);
    expect(c.storageError, isNotNull);
    h.store.failSave = false;
    await c.retrySave();
    h.repository.failCreate = true;
    expect(await c.submit(), isNull);
    expect(c.committed, isNull);
    expect(c.submitError, contains('正式保存失败'));
    expect(c.submitError, isNot(contains('private')));
    expect(c.editable, isTrue);
    expect(h.store.value!.endedAt, c.endedAt);
  });

  test('reopening residual draft recognizes the committed fact; recovery read failure blocks input until retry', () async {
    h.store.failClear = true;
    final first = h.controller();
    await first.initialize();
    fill(first);
    expect(await first.submit(), isNull);
    expect(first.committed!.refreshed, isNotNull);
    first.dispose();
    h.repository.failRecovery = true;
    final second = h.controller();
    addTearDown(second.dispose);
    await second.initialize();
    expect(second.loadError, isNotNull);
    expect(second.editable, isFalse);
    expect(await second.submit(), isNull);
    h.repository.failRecovery = false;
    h.store.failClear = false;
    await second.initialize();
    expect(second.committed!.complete, isTrue);
    expect(second.editable, isFalse);
    expect(h.repository.creates, 1);
    expect(h.store.value, isNull);
  });

  for (final failure in ['clear', 'refresh', 'both']) {
    testWidgets(
      'widget distinguishes committed $failure failure and only finishes cleanup/read',
      (tester) async {
        final c = h.controller();
        await c.initialize();
        fill(c);
        await c.flush();
        h.store.failClear = failure != 'refresh';
        h.failRefresh = failure != 'clear';
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push<SleepLedger>(
                    MaterialPageRoute(builder: (_) => SleepForm(controller: c)),
                  ),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        await tapText(tester, '确认并保存到账本');
        expect(c.committed, isNotNull);
        expect(find.textContaining('睡眠已保存，但'), findsOneWidget);
        expect(find.text('确认并保存到账本'), findsNothing);
        expect(find.text('放弃草稿'), findsNothing);
        expect(find.textContaining('private'), findsNothing);
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('sleep-start')))
              .enabled,
          isFalse,
        );
        expect(h.repository.creates, 1);
        h.store.failClear = false;
        h.failRefresh = false;
        await tapText(tester, '继续清理并刷新');
        expect(find.text('打开'), findsOneWidget);
        expect(c.committed!.complete, isTrue);
        expect(
          c.committed!.refreshed!.sleepSummary.mainSleep.records,
          hasLength(1),
        );
        expect(
          c.committed!.refreshed!.coverage.accountedDuration.roundedMinutes,
          460,
        );
        expect(h.repository.creates, 1);
        expect(h.store.value, isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
      },
    );
  }

  testWidgets(
    'widget blocks a second click and back while submitting; write failure leaves editable draft',
    (tester) async {
      final c = h.controller();
      await c.initialize();
      fill(c);
      await c.flush();
      h.repository.gate = Completer<void>();
      h.repository.failCreate = true;
      await tester.pumpWidget(MaterialApp(home: SleepForm(controller: c)));
      await tester.pumpAndSettle();
      final button = find.text('确认并保存到账本');
      await tester.scrollUntilVisible(
        button,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button, warnIfMissed: false);
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      expect(c.submitting, isTrue);
      expect(h.repository.creates, 1);
      h.repository.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('正式保存失败'), findsOneWidget);
      expect(c.editable, isTrue);
      expect(h.store.value, isNotNull);
      expect(find.textContaining('睡眠已保存'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    },
  );

  testWidgets(
    'widget lists both conflict identities and full intervals and permits manual correction',
    (tester) async {
      final c = h.controller();
      await c.initialize();
      fill(c);
      await c.flush();
      const blockId = '00000000-0000-4000-8000-000000000002';
      const sleepId = '00000000-0000-4000-8000-000000000003';
      final start = c.startedAt!;
      await h.actual.createTimeBlock(
        id: blockId,
        startedAt: start,
        endedAt: start + 60000,
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.known,
        title: '夜间活动',
        now: 1,
      );
      await h.actual.createSleepSession(
        id: sleepId,
        startedAt: start + 60000,
        endedAt: c.endedAt!,
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        type: SleepType.nap,
        now: 1,
      );
      await tester.pumpWidget(MaterialApp(home: SleepForm(controller: c)));
      await tester.pumpAndSettle();
      await tapText(tester, '确认并保存到账本');
      expect(
        find.textContaining(
          '普通记录 $blockId：2026-09-28 23:50 → 2026-09-28 23:51',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          '睡眠记录 $sleepId：2026-09-28 23:51 → 2026-09-29 07:40',
        ),
        findsOneWidget,
      );
      expect(c.committed, isNull);
      expect(h.store.value, isNotNull);
      c.setStartedAtInput('2026-09-29 08:00');
      c.setEndedAtInput('2026-09-29 09:00');
      expect(c.conflicts, isEmpty);
      expect(c.submitError, isNull);
      await c.flush();
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    },
  );
}
