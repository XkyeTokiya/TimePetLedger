import '../../../support/recording_fields.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_entry_editor.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_time_suggestion.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form.dart';

import 'recording_form_controller_test.dart' show FormDraftStore, formContext;

Widget app(
  RecordingDraftStore store, {
  RecordingTimeSuggestion suggestion = const ManualTimeEntry(),
  RecordingEntrySaver? saver,
  RecordingEntryEditor? editor,
  RecordingDraftContext? draftContext,
}) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => RecordingForm(
              context: draftContext ?? formContext,
              store: store,
              entrySaver: saver,
              entryEditor: editor,
              loadSuggestion: () async => suggestion,
            ),
          ),
        ),
        child: const Text('打开'),
      ),
    ),
  ),
);
Future<void> tap(WidgetTester tester, String text) async {
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  if (['保留草稿并返回', '放弃草稿'].contains(text) &&
      find.text(text).evaluate().isEmpty) {
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
  }
  final target = find.text(text);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(target.first), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

Future<void> enterTime(WidgetTester tester, String label, String value) async {
  if (find.text('调整记录时间').evaluate().isEmpty &&
      find.text(label).evaluate().isEmpty) {
    await tester.ensureVisible(
      find.byKey(const ValueKey('edit-recording-time')),
    );
    await tester.tap(find.byKey(const ValueKey('edit-recording-time')));
    await tester.pumpAndSettle();
  }
  if (find.text('调整记录时间').evaluate().isNotEmpty) {
    await tap(tester, '手动输入日期与时间');
    final field = find.byKey(
      ValueKey(label == '开始时间' ? 'time-start' : 'time-end'),
    );
    await tester.scrollUntilVisible(
      field,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
    await tap(tester, '应用时间');
    return;
  }
  await revealRecordingField(tester, label);
  await tap(tester, label);
  await tester.enterText(
    find.byKey(const ValueKey('time-dialog-input')),
    value,
  );
  await tap(tester, '确认');
}

void main() {
  testWidgets(
    'activity first, explicit Unknown, cross-date minute input and independent precision',
    (tester) async {
      final store = FormDraftStore();
      await tester.pumpWidget(app(store));
      await tap(tester, '打开');
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('activity'))).dy,
        lessThan(tester.getTopLeft(find.text('开始时间')).dy),
      );
      expect(find.text('请选择是否记得这段时间的内容。'), findsOneWidget);
      expect(find.byKey(const ValueKey('note')), findsNothing);
      await revealRecordingField(tester, 'note');
      await tester.enterText(find.byKey(const ValueKey('note')), '🐾' * 2001);
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('备注最多 2000 个字符。'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('note')), '🐾' * 2000);
      await tester.pumpAndSettle();
      expect(find.text('备注最多 2000 个字符。'), findsNothing);
      await tap(tester, '记得做了什么');
      await tester.tap(find.byKey(const ValueKey('activity')));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('请填写活动内容。'), findsOneWidget);
      await tap(tester, '想不起来');
      expect(find.text('请填写活动内容。'), findsNothing);
      await enterTime(tester, '开始时间', '2000-01-01 23:50');
      await tap(tester, '开始准确');
      await enterTime(tester, '结束时间', '2040-01-02 07:30');
      await enterTime(tester, '开始时间', '2000-01-01 23:40');
      expect(store.value!.startPrecision, TimePrecision.exact);
      expect(store.value!.endPrecision, TimePrecision.approximate);
      expect(store.value!.title, '');
      expect(
        store.value!.startedAt,
        DateTime(2000, 1, 1, 23, 40).millisecondsSinceEpoch,
      );
      expect(find.text('结束时间必须晚于开始时间。'), findsNothing);
      expect(find.text('Goal'), findsNothing);
    },
  );
  testWidgets('single candidate requires confirmation and remains editable', (
    tester,
  ) async {
    final store = FormDraftStore();
    final candidate = RecordingTimeInput(
      startedAt: DateTime(2026, 9, 27, 10).millisecondsSinceEpoch,
      endedAt: DateTime(2026, 9, 27, 11).millisecondsSinceEpoch,
    );
    await tester.pumpWidget(
      app(store, suggestion: TimeCandidates([candidate])),
    );
    await tap(tester, '打开');
    expect(find.widgetWithText(ListTile, '未填写'), findsNWidgets(2));
    await tap(
      tester,
      '${formatRecordingTime(candidate.startedAt)} → ${formatRecordingTime(candidate.endedAt)}',
    );
    expect(store.value!.startedAt, candidate.startedAt);
    expect(store.value!.startPrecision, TimePrecision.approximate);
    await enterTime(tester, '结束时间', '2026-09-28 12:10');
    expect(
      store.value!.endedAt,
      DateTime(2026, 9, 28, 12, 10).millisecondsSinceEpoch,
    );
  });
  testWidgets(
    'incomplete input survives leaving; restored draft ignores new suggestion; discard clears',
    (tester) async {
      final store = FormDraftStore();
      await tester.pumpWidget(app(store));
      await tap(tester, '打开');
      await tester.enterText(find.byKey(const ValueKey('activity')), '  一半输入');
      await revealRecordingField(tester, 'note');
      await tester.enterText(find.byKey(const ValueKey('note')), '  未完\n备注  ');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(store.value!.title, '  一半输入');
      expect(store.value!.note, '  未完\n备注  ');
      await tester.pumpWidget(
        app(
          store,
          suggestion: const DirectTimeSuggestion(
            RecordingTimeInput(startedAt: 10, endedAt: 20),
          ),
        ),
      );
      await tap(tester, '打开');
      expect(store.value, isNotNull);
      expect(find.text('  一半输入'), findsOneWidget);
      await revealRecordingField(tester, 'note');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('note')))
            .controller!
            .text,
        '  未完\n备注  ',
      );
      expect(find.widgetWithText(ListTile, '未填写'), findsNWidgets(2));
      await tap(tester, '放弃草稿');
      expect(store.value, isNull);
      expect(find.text('打开'), findsOneWidget);
    },
  );
  testWidgets('save and discard errors stay visible and preserve text', (
    tester,
  ) async {
    final store = FormDraftStore()..failSave = true;
    await tester.pumpWidget(app(store));
    await tap(tester, '打开');
    await tester.enterText(find.byKey(const ValueKey('activity')), '不能丢');
    await tester.pumpAndSettle();
    await tap(tester, '保留草稿并返回');
    expect(find.text('草稿保存失败，输入仍在此页，请重试。'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 900));
    await tester.pumpAndSettle();
    expect(find.text('不能丢'), findsOneWidget);
    store.failSave = false;
    await tap(tester, '重试保存草稿');
    store.failClear = true;
    await tap(tester, '放弃草稿');
    expect(find.text('无法放弃草稿，输入已保留，请重试。'), findsOneWidget);
    expect(store.value!.title, '不能丢');
    expect(find.textContaining('private SQL'), findsNothing);
  });
  testWidgets('read failure offers retry and cannot overwrite existing input', (
    tester,
  ) async {
    final store = FormDraftStore()..failRead = true;
    await tester.pumpWidget(app(store));
    await tap(tester, '打开');
    expect(find.text('无法读取草稿、时间建议或账本，请重试。'), findsOneWidget);
    expect(find.byKey(const ValueKey('activity')), findsNothing);
    expect(store.saves, 0);
    store.failRead = false;
    await tap(tester, '重试读取');
    expect(find.byKey(const ValueKey('activity')), findsOneWidget);
  });
  test(
    'minute parsing rejects invalid dates without limiting past or future',
    () {
      expect(parseRecordingTime('2026-02-30 10:00'), isNull);
      expect(parseRecordingTime('2026-09-28 24:00'), isNull);
      expect(parseRecordingTime('2026-09-28 12:30:20'), isNull);
      expect(parseRecordingTime('1900-01-01 00:00'), isNotNull);
      expect(parseRecordingTime('2200-01-01 00:00'), isNotNull);
    },
  );
  test('browsing dates are calendar values, independent of local midnight', () {
    expect(parseRecordingDate('2024-02-29')!.day, 29);
    expect(parseRecordingDate('2026-02-29'), isNull);
    expect(parseRecordingDate('2018-11-04')!.day, 4);
    final ancient = DateTime(-1, 1, 1).millisecondsSinceEpoch;
    expect(parseRecordingTime(formatRecordingTime(ancient)), ancient);
  });

  testWidgets('confirmed Unknown saves once, clears draft and leaves form', (
    tester,
  ) async {
    final db = (await tester.runAsync(
      () => AppDatabase.open(NativeDatabase.memory()),
    ))!;
    addTearDown(db.close);
    final repository = DriftLedgerRepository(db);
    final store = FormDraftStore();
    final loader = RecordingLedgerLoader(
      repository: repository,
      resolveDate: resolveDeviceRecordingDate,
    );
    final saver = RecordingEntrySaver(
      repository: repository,
      drafts: store,
      refresh: loader.load,
      newId: () => '00000000-0000-4000-8000-000000000001',
      now: () => DateTime(2026, 9, 29, 12).millisecondsSinceEpoch,
    );
    await tester.pumpWidget(app(store, saver: saver));
    await tap(tester, '打开');
    await tap(tester, '想不起来');
    await revealRecordingField(tester, 'note');
    await tester.enterText(find.byKey(const ValueKey('note')), '  补充\n第二行  ');
    await enterTime(tester, '开始时间', '2026-09-28 10:00');
    await enterTime(tester, '结束时间', '2026-09-28 11:00');
    await tap(tester, '保存到账本');
    expect(find.text('打开'), findsOneWidget);
    expect(store.value, isNull);
    final snapshot = await tester.runAsync(
      () => repository.readWindow(
        startedAt: DateTime(2026, 9, 28, 9).millisecondsSinceEpoch,
        endedAt: DateTime(2026, 9, 28, 12).millisecondsSinceEpoch,
      ),
    );
    expect(
      snapshot!.timeBlocks.single.knowledgeState,
      BlockKnowledgeState.unknown,
    );
    expect(snapshot.timeBlocks.single.note, '补充\n第二行');
  });

  testWidgets('conflict keeps input and names the related sleep record', (
    tester,
  ) async {
    final db = (await tester.runAsync(
      () => AppDatabase.open(NativeDatabase.memory()),
    ))!;
    addTearDown(db.close);
    final repository = DriftLedgerRepository(db);
    const sleepId = '00000000-0000-4000-8000-000000000002';
    await tester.runAsync(
      () => repository.createSleepSession(
        id: sleepId,
        startedAt: DateTime(2026, 9, 28, 10, 30).millisecondsSinceEpoch,
        endedAt: DateTime(2026, 9, 28, 11, 30).millisecondsSinceEpoch,
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        type: SleepType.nap,
        now: DateTime(2026, 9, 29, 12).millisecondsSinceEpoch,
      ),
    );
    final store = FormDraftStore();
    final loader = RecordingLedgerLoader(
      repository: repository,
      resolveDate: resolveDeviceRecordingDate,
    );
    await tester.pumpWidget(
      app(
        store,
        saver: RecordingEntrySaver(
          repository: repository,
          drafts: store,
          refresh: loader.load,
          newId: () => '00000000-0000-4000-8000-000000000001',
          now: () => DateTime(2026, 9, 29, 12).millisecondsSinceEpoch,
        ),
      ),
    );
    await tap(tester, '打开');
    await tap(tester, '记得做了什么');
    await tester.enterText(find.byKey(const ValueKey('activity')), '写作');
    await enterTime(tester, '开始时间', '2026-09-28 10:00');
    await enterTime(tester, '结束时间', '2026-09-28 11:00');
    await tap(tester, '保存到账本');
    expect(find.text('时间与已有记录冲突，请手动调整后再保存。'), findsOneWidget);
    expect(find.textContaining(sleepId), findsOneWidget);
    expect(store.value!.title, '写作');
    expect(find.text('已正式保存到账本，请不要再次提交。'), findsNothing);
  });

  testWidgets(
    'committed cleanup and refresh failures show only finish action',
    (tester) async {
      final db = (await tester.runAsync(
        () => AppDatabase.open(NativeDatabase.memory()),
      ))!;
      addTearDown(db.close);
      final repository = DriftLedgerRepository(db);
      final store = FormDraftStore()..failClear = true;
      final loader = RecordingLedgerLoader(
        repository: repository,
        resolveDate: resolveDeviceRecordingDate,
      );
      var failRefresh = true;
      final saver = RecordingEntrySaver(
        repository: repository,
        drafts: store,
        refresh: ({required date, required now}) {
          if (failRefresh) throw StateError('private read SQL');
          return loader.load(date: date, now: now);
        },
        newId: () => '00000000-0000-4000-8000-000000000001',
        now: () => DateTime(2026, 9, 29, 12).millisecondsSinceEpoch,
      );
      await tester.pumpWidget(app(store, saver: saver));
      await tap(tester, '打开');
      await tap(tester, '想不起来');
      await enterTime(tester, '开始时间', '2026-09-28 10:00');
      await enterTime(tester, '结束时间', '2026-09-28 11:00');
      await tap(tester, '保存到账本');
      expect(find.text('已正式保存到账本，请不要再次提交。'), findsOneWidget);
      expect(find.text('草稿清理失败，旧草稿仍可能显示；请重试清理。'), findsOneWidget);
      expect(find.text('账本刷新失败，记录已保存；请重试刷新。'), findsOneWidget);
      expect(find.text('保存到账本'), findsNothing);
      store.failClear = false;
      failRefresh = false;
      await tap(tester, '继续清理并刷新');
      expect(find.text('打开'), findsOneWidget);
      expect(store.value, isNull);
      final snapshot = await tester.runAsync(
        () => repository.readWindow(
          startedAt: DateTime(2026, 9, 28, 9).millisecondsSinceEpoch,
          endedAt: DateTime(2026, 9, 28, 12).millisecondsSinceEpoch,
        ),
      );
      expect(snapshot!.timeBlocks, hasLength(1));
    },
  );

  testWidgets(
    'edit restores draft, keeps source until save, and supports both directions',
    (tester) async {
      final db = (await tester.runAsync(
        () => AppDatabase.open(NativeDatabase.memory()),
      ))!;
      addTearDown(db.close);
      final repository = DriftLedgerRepository(db);
      const id = '00000000-0000-4000-8000-000000000001';
      final start = DateTime(2026, 9, 28, 23, 30).millisecondsSinceEpoch;
      final end = DateTime(2026, 9, 29, 0, 30).millisecondsSinceEpoch;
      await tester.runAsync(
        () => repository.createTimeBlock(
          id: id,
          startedAt: start,
          endedAt: end,
          startPrecision: TimePrecision.approximate,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.known,
          title: '写作',
          note: '原备注',
          now: 1,
        ),
      );
      final store = FormDraftStore();
      final loader = RecordingLedgerLoader(
        repository: repository,
        resolveDate: resolveDeviceRecordingDate,
      );
      final saver = RecordingEntrySaver(
        repository: repository,
        drafts: store,
        refresh: loader.load,
        newId: () => '00000000-0000-4000-8000-000000000002',
        now: () => DateTime(2026, 9, 30, 12).millisecondsSinceEpoch,
      );
      final editor = RecordingEntryEditor(
        repository: repository,
        drafts: store,
        saver: saver,
      );
      final draftContext = RecordingDraftContext.edit(
        date: formContext.date,
        timeBlockId: id,
      );
      await tester.pumpWidget(
        app(store, editor: editor, draftContext: draftContext),
      );
      await tap(tester, '打开');
      expect(find.text('更正记录'), findsOneWidget);
      expect(find.text('写作'), findsOneWidget);
      await revealRecordingField(tester, 'note');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('note')))
            .controller!
            .text,
        '原备注',
      );
      expect(
        find.byKey(const ValueKey('recording-time-summary')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('recording-time-summary')))
            .data,
        contains(formatRecordingTime(end)),
      );
      expect(store.value, isNull);
      await tap(tester, '想不起来');
      await tester.enterText(find.byKey(const ValueKey('note')), '  更正\n备注  ');
      await enterTime(tester, '结束时间', '2026-09-29 01:00');
      await tap(tester, '保留草稿并返回');
      expect(
        (await tester.runAsync(() => repository.readTimeBlock(id)))!
            .timeBlock
            .knowledgeState,
        BlockKnowledgeState.known,
      );
      expect(
        (await tester.runAsync(() => repository.readTimeBlock(id)))!
            .timeBlock
            .note,
        '原备注',
      );
      await tap(tester, '打开');
      expect(store.value, isNotNull);
      expect(find.text('写作'), findsOneWidget);
      await revealRecordingField(tester, 'note');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('note')))
            .controller!
            .text,
        '  更正\n备注  ',
      );
      await tap(tester, '保存更正');
      final changed = (await tester.runAsync(
        () => repository.readTimeBlock(id),
      ))!.timeBlock;
      expect(changed.knowledgeState, BlockKnowledgeState.unknown);
      expect(changed.title, '写作');
      expect(changed.startedAt, start);
      expect(changed.endedAt, DateTime(2026, 9, 29, 1).millisecondsSinceEpoch);
      expect(changed.id, id);
      expect(changed.note, '更正\n备注');
      expect(store.value, isNull);
      await tap(tester, '打开');
      await tap(tester, '记得做了什么');
      await tester.enterText(find.byKey(const ValueKey('activity')), '修改后的写作');
      await revealRecordingField(tester, 'note');
      await tester.enterText(find.byKey(const ValueKey('note')), ' \n ');
      await tap(tester, '保存更正');
      final back = (await tester.runAsync(() => repository.readTimeBlock(id)))!
          .timeBlock;
      expect(back.title, '修改后的写作');
      expect(back.knowledgeState, BlockKnowledgeState.known);
      expect(back.note, isNull);
    },
  );

  testWidgets('restored edit for deleted source cannot recreate it', (
    tester,
  ) async {
    final db = (await tester.runAsync(
      () => AppDatabase.open(NativeDatabase.memory()),
    ))!;
    addTearDown(db.close);
    final repository = DriftLedgerRepository(db);
    const id = '00000000-0000-4000-8000-000000000001';
    final store = FormDraftStore();
    final draftContext = RecordingDraftContext.edit(
      date: formContext.date,
      timeBlockId: id,
    );
    await store.save(
      RecordingDraft(
        context: draftContext,
        title: '旧草稿',
        startedAt: 1,
        endedAt: 2,
        startPrecision: TimePrecision.approximate,
        endPrecision: TimePrecision.approximate,
        knowledgeState: BlockKnowledgeState.known,
      ),
    );
    final loader = RecordingLedgerLoader(
      repository: repository,
      resolveDate: resolveDeviceRecordingDate,
    );
    final saver = RecordingEntrySaver(
      repository: repository,
      drafts: store,
      refresh: loader.load,
      newId: () => id,
      now: () => DateTime(2026, 9, 30).millisecondsSinceEpoch,
    );
    await tester.pumpWidget(
      app(
        store,
        draftContext: draftContext,
        editor: RecordingEntryEditor(
          repository: repository,
          drafts: store,
          saver: saver,
        ),
      ),
    );
    await tap(tester, '打开');
    expect(find.text('记录已不存在，无法更正。'), findsOneWidget);
    expect(find.byKey(const ValueKey('activity')), findsNothing);
    await tap(tester, '清除编辑草稿并返回');
    expect(store.value, isNull);
    expect(await tester.runAsync(() => repository.readTimeBlock(id)), isNull);
  });
}
