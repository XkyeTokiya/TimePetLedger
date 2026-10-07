import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/identity/entity_id.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/core/time/time_contract.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_entry_editor.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_form.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_form_controller.dart';

import '../application/sleep_entry_editor_test.dart' show sleepId, day, at;
import 'sleep_form_controller_test.dart' show FormSleepStore;
import 'sleep_form_test.dart' show tapText;

class EditRepository implements LedgerRepository {
  EditRepository(this.inner);
  final LedgerRepository inner;
  int updates = 0, deletes = 0;
  bool failRead = false, failWrite = false;
  Completer<void>? gate;
  @override
  Future<SleepSession?> readSleepSession(EntityId id) {
    if (failRead) throw const LedgerStorageException('private SQL');
    return inner.readSleepSession(id);
  }

  @override
  Future<SleepSession> updateSleepSession({
    required EntityId id,
    required InstantMilliseconds now,
    InstantMilliseconds? startedAt,
    InstantMilliseconds? endedAt,
    TimePrecision? startPrecision,
    TimePrecision? endPrecision,
    SleepType? type,
    ({String? value})? note,
  }) async {
    updates++;
    await gate?.future;
    if (failWrite) throw const LedgerStorageException('private SQL');
    return inner.updateSleepSession(
      id: id,
      now: now,
      startedAt: startedAt,
      endedAt: endedAt,
      startPrecision: startPrecision,
      endPrecision: endPrecision,
      type: type,
      note: note,
    );
  }

  @override
  Future<void> deleteSleepSession(EntityId id) async {
    deletes++;
    await gate?.future;
    if (failWrite) throw const LedgerStorageException('private SQL');
    await inner.deleteSleepSession(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class EditingHarness {
  EditingHarness(this.db) {
    actual = DriftLedgerRepository(db);
    repo = EditRepository(actual);
    loader = SleepLedgerLoader(
      repository: actual,
      resolveDate: resolveDeviceRecordingDate,
    );
    saver = SleepEntrySaver(
      repository: repo,
      drafts: store,
      newId: () => throw StateError('No create'),
      now: () => at(30, 12),
      refresh: ({required date, required now}) async {
        if (failDate == date) throw StateError('private refresh SQL');
        return loader.load(date: date, now: now);
      },
    );
    editor = SleepEntryEditor(
      repository: repo,
      drafts: store,
      saver: saver,
      dateOfInstant: deviceDateOfInstant,
    );
  }
  final AppDatabase db;
  final store = FormSleepStore();
  late final DriftLedgerRepository actual;
  late final EditRepository repo;
  late final SleepLedgerLoader loader;
  late final SleepEntrySaver saver;
  late final SleepEntryEditor editor;
  CivilDate? failDate;
  final context = SleepDraftContext.edit(
    date: day(28),
    sleepSessionId: sleepId,
  );
  SleepFormController model() =>
      SleepFormController(context: context, store: store, entryEditor: editor);
  Future<SleepSession> create() => actual.createSleepSession(
    id: sleepId,
    startedAt: at(28, 23, 50) + 123,
    endedAt: at(29, 7, 40) + 456,
    startPrecision: TimePrecision.approximate,
    endPrecision: TimePrecision.exact,
    type: SleepType.mainSleep,
    now: 1,
    note: '保留备注',
  );
}

void main() {
  late EditingHarness h;
  setUp(() async {
    h = EditingHarness(await AppDatabase.open(NativeDatabase.memory()));
  });
  tearDown(() => h.db.close());
  Future<void> show(WidgetTester tester, SleepFormController c) async {
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
  }

  test('loaded source keeps exact milliseconds; queued edit saves only after confirmation, duplicate edit/delete requests are locked', () async {
    final original = await h.create();
    final c = h.model();
    addTearDown(c.dispose);
    await c.initialize();
    expect(c.startedAt, original.startedAt);
    expect(c.endedAt, original.endedAt);
    c.setType(SleepType.nap);
    c.setPrecision(end: TimePrecision.approximate);
    await c.flush();
    expect(
      (await h.actual.readSleepSession(sleepId))!.type,
      SleepType.mainSleep,
    );
    h.repo.gate = Completer<void>();
    final pending = c.submit();
    expect(c.submitting, isTrue);
    expect(await c.submit(), isNull);
    expect(await c.delete(), isNull);
    expect(await c.discard(), isFalse);
    c.setType(SleepType.mainSleep);
    expect(c.type, SleepType.nap);
    await Future<void>.delayed(Duration.zero);
    expect(h.repo.updates, 1);
    h.repo.gate!.complete();
    expect(await pending, isNotNull);
    expect(c.committed!.sleepSession.note, original.note);
    expect(h.store.value, isNull);
    expect(c.committed!.sleepSession.id, original.id);
    expect(c.committed!.sleepSession.createdAt, 1);
    expect(await c.submit(), isNull);
    expect(h.repo.updates, 1);
  });

  test('source deletion during editing rejects update without recreating and keeps the draft', () async {
    await h.create();
    final c = h.model();
    addTearDown(c.dispose);
    await c.initialize();
    c.setType(SleepType.nap);
    await c.flush();
    await h.actual.deleteSleepSession(sleepId);
    expect(await c.submit(), isNull);
    expect(c.submitError, contains('记录已不存在'));
    expect(c.editable, isFalse);
    expect(h.store.value!.type, SleepType.nap);
    expect(await h.actual.readSleepSession(sleepId), isNull);
  });

  testWidgets(
    'restored edit with missing source reports not found, retains draft and cannot save or recreate',
    (tester) async {
      await h.create();
      final first = h.model();
      await first.initialize();
      first.setType(SleepType.nap);
      await first.flush();
      first.dispose();
      await h.actual.deleteSleepSession(sleepId);
      final c = h.model();
      await show(tester, c);
      expect(find.textContaining('记录已不存在'), findsOneWidget);
      expect(find.text('保存更正'), findsNothing);
      expect(h.store.value!.type, SleepType.nap);
      expect(h.repo.updates, 0);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('打开'), findsOneWidget);
      expect(h.store.value, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    },
  );

  testWidgets(
    'source read failure retries without replacing stored partial draft or exposing SQL',
    (tester) async {
      await h.create();
      final first = h.model();
      await first.initialize();
      first.setEndedAtInput('2026-');
      await first.flush();
      first.dispose();
      h.repo.failRead = true;
      final c = h.model();
      await show(tester, c);
      expect(find.text('无法读取睡眠记录或未完成输入，请重试。'), findsOneWidget);
      expect(find.textContaining('private'), findsNothing);
      expect(h.store.value!.endedAtInput, '2026-');
      h.repo.failRead = false;
      await tester.tap(find.text('重试读取'));
      await tester.pumpAndSettle();
      expect(c.restored, isTrue);
      expect(c.endedAt, isNull);
      expect(c.endedAtInput, '2026-');
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    },
  );

  for (final operation in ['update', 'delete']) {
    testWidgets(
      '$operation post-commit cleanup/other-day read failure locks mutations and retry does not repeat them',
      (tester) async {
        await h.create();
        final c = h.model();
        await c.initialize();
        c.setType(SleepType.nap);
        await c.flush();
        h.store.failClear = true;
        h.failDate = day(29);
        await show(tester, c);
        if (operation == 'update') {
          await tapText(tester, '保存更正');
        } else {
          await tapText(tester, '删除睡眠');
          await tester.tap(find.text('确认删除'));
          await tester.pumpAndSettle();
        }
        expect(c.postCommit, isTrue);
        expect(c.finishPending, isTrue);
        expect(find.textContaining('本地收尾和摘要 / 账本刷新失败'), findsOneWidget);
        expect(find.text('保存更正'), findsNothing);
        expect(find.text('删除睡眠'), findsNothing);
        expect(h.store.value, isNotNull);
        expect(await c.submit(), isNull);
        expect(await c.delete(), isNull);
        h.store.failClear = false;
        h.failDate = null;
        await tapText(tester, '继续清理并刷新');
        expect(find.text('打开'), findsOneWidget);
        expect(h.store.value, isNull);
        expect(h.repo.updates, operation == 'update' ? 1 : 0);
        expect(h.repo.deletes, operation == 'delete' ? 1 : 0);
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
      },
    );
  }

  testWidgets(
    'cancel deletion leaves fact and draft; formal failure is editable and preserves both',
    (tester) async {
      final original = await h.create();
      final c = h.model();
      await c.initialize();
      c.setType(SleepType.nap);
      await c.flush();
      await show(tester, c);
      await tapText(tester, '删除睡眠');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(h.repo.deletes, 0);
      expect(h.store.value, isNotNull);
      h.repo.failWrite = true;
      await tapText(tester, '删除睡眠');
      await tester.tap(find.text('确认删除'));
      await tester.pumpAndSettle();
      expect(find.text('删除失败，睡眠记录与当前输入仍保留，请重试。'), findsOneWidget);
      expect(c.editable, isTrue);
      expect(c.deleted, isNull);
      expect(
        (await h.actual.readSleepSession(sleepId))!.updatedAt,
        original.updatedAt,
      );
      await tapText(tester, '保存更正');
      expect(find.textContaining('正式保存失败'), findsOneWidget);
      expect(h.store.value, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    },
  );

  test('delete is locked during in-flight operation; reopened committed edit only finishes cleanup', () async {
    await h.create();
    final c = h.model();
    await c.initialize();
    c.setType(SleepType.nap);
    await c.flush();
    h.repo.gate = Completer<void>();
    final pending = c.delete();
    expect(await c.delete(), isNull);
    expect(await c.submit(), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(h.repo.deletes, 1);
    h.repo.gate!.complete();
    expect(await pending, isNotNull);
    expect(await c.delete(), isNull);
    c.dispose();
    await h.create();
    h.repo.gate = null;
    final first = h.model();
    await first.initialize();
    first.setType(SleepType.nap);
    await first.flush();
    h.store.failClear = true;
    expect(await first.submit(), isNull);
    first.dispose();
    h.store.failClear = false;
    final reopened = h.model();
    addTearDown(reopened.dispose);
    await reopened.initialize();
    expect(reopened.committed!.complete, isTrue);
    expect(reopened.editable, isFalse);
    expect(h.repo.updates, 1);
    expect(h.store.value, isNull);
  });
}
