import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/persistence/database_connection.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_opening_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

import 'support/recording_platform_status_native.dart'
    if (dart.library.js_interop) 'support/recording_platform_status_web.dart'
    as platform_status;
import 'support/schema_contract.dart' show clearSchemaRows;

/// Run the same target five times against one isolated run id. Between runs,
/// force-stop and relaunch Android or refresh the same Web tab. The separate
/// control store advances only after every assertion in a phase passes.
const runId = String.fromEnvironment('E4_T08_RUN_ID');
const conflictId = '00000000-0000-4000-8000-000000000008';
final recordDate = CivilDate(year: 2026, month: 9, day: 28);
final controlDate = CivilDate(year: 2000, month: 1, day: 1);
final newContext = RecordingDraftContext.newEntry(date: recordDate);
final controlContext = RecordingDraftContext.newEntry(date: controlDate);

int at(int hour, [int minute = 0]) =>
    DateTime(2026, 9, 28, hour, minute).millisecondsSinceEpoch;

typedef AppHandles = ({
  AppDatabase database,
  DriftRecordingDraftStore drafts,
  DriftLedgerRepository repository,
});

Future<AppHandles> openTestApp(WidgetTester tester) async {
  late AppDatabase database;
  late DriftRecordingDraftStore drafts;
  await tester.pumpWidget(
    AppBootstrap(
      openSleepOpenings: () async => DriftSleepOpeningStore.open(
        await connectDatabase('e4_t08_sleep_openings_$runId'),
      ),
      openDatabase: () async {
        database = await AppDatabase.open(
          await connectDatabase('e4_t08_formal_$runId'),
        );
        return database;
      },
      openDrafts: () async {
        drafts = await DriftRecordingDraftStore.open(
          await connectDatabase('e4_t08_drafts_$runId'),
        );
        return drafts;
      },
      now: () => DateTime(2026, 9, 29, 12),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('时间账本'), findsOneWidget);
  if (find.text('继续账本').evaluate().isNotEmpty) {
    await tester.tap(find.text('继续账本'));
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byType(TextField).first, '2026-09-28');
  await tester.pumpAndSettle();
  return (
    database: database,
    drafts: drafts,
    repository: DriftLedgerRepository(database),
  );
}

Future<void> tapVisible(WidgetTester tester, String text) async {
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

Future<void> tapBlockEdit(WidgetTester tester, String id) async {
  final target = find.byKey(ValueKey('edit-$id'));
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> enterTime(WidgetTester tester, String label, String value) async {
  await tapVisible(tester, label);
  await tester.enterText(
    find.byKey(const ValueKey('time-dialog-input')),
    value,
  );
  await tapVisible(tester, '确认');
}

Future<List<TimeBlock>> blocks(AppHandles app) async {
  final snapshot = await app.repository.readWindow(
    startedAt: at(0),
    endedAt: DateTime(2026, 9, 29).millisecondsSinceEpoch,
  );
  return snapshot.timeBlocks;
}

Future<void> phase0(WidgetTester tester) async {
  final app = await openTestApp(tester);
  expect(await blocks(app), isEmpty);
  expect(await app.drafts.read(newContext), isNull);
  await tapVisible(tester, '补一笔');
  expect(find.text('未填写'), findsNWidgets(2));
  await tapVisible(tester, '记得做了什么');
  await tester.enterText(find.byKey(const ValueKey('activity')), '写作草稿');
  await tester.enterText(find.byKey(const ValueKey('note')), '  新建\n备注  ');
  await enterTime(tester, '开始时间', '2026-09-28 10:00');
  await tapVisible(tester, '开始准确');
  await tapVisible(tester, '保留草稿并返回');
  final draft = (await app.drafts.read(newContext))!;
  expect(draft.title, '写作草稿');
  expect(draft.note, '  新建\n备注  ');
  expect(draft.startedAt, at(10));
  expect(draft.endedAt, isNull);
  expect(draft.startPrecision, TimePrecision.exact);
  expect(draft.endPrecision, TimePrecision.approximate);
  expect(draft.knowledgeState, BlockKnowledgeState.known);
  expect(await blocks(app), isEmpty);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

Future<void> phase1(WidgetTester tester) async {
  final app = await openTestApp(tester);
  expect(await blocks(app), isEmpty);
  await tapVisible(tester, '补一笔');
  expect(find.text('已恢复上次输入'), findsOneWidget);
  expect(
    tester
        .widget<TextField>(find.byKey(const ValueKey('note')))
        .controller!
        .text,
    '  新建\n备注  ',
  );
  expect(find.text('2026-09-28 10:00'), findsOneWidget);
  expect(find.text('未填写'), findsOneWidget);
  expect(
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '开始准确')).selected,
    isTrue,
  );
  await enterTime(tester, '结束时间', '2026-09-28 11:00');
  await tapVisible(tester, '确认并保存到账本');
  expect(find.text('已交代 约60 分钟'), findsOneWidget);
  expect(await app.drafts.read(newContext), isNull);
  final saved = (await blocks(app)).single;
  expect(saved.title, '写作草稿');
  expect(saved.note, '新建\n备注');
  expect(saved.startPrecision, TimePrecision.exact);
  expect(saved.endPrecision, TimePrecision.approximate);
  await tapBlockEdit(tester, saved.id);
  await tester.enterText(find.byKey(const ValueKey('activity')), '待更正写作');
  await tester.enterText(find.byKey(const ValueKey('note')), '  编辑\n备注  ');
  await enterTime(tester, '结束时间', '2026-09-28 11:30');
  await tapVisible(tester, '结束准确');
  await tapVisible(tester, '保留草稿并返回');
  final editContext = RecordingDraftContext.edit(
    date: recordDate,
    timeBlockId: saved.id,
  );
  final editDraft = (await app.drafts.read(editContext))!;
  expect(editDraft.title, '待更正写作');
  expect(editDraft.note, '  编辑\n备注  ');
  expect(editDraft.endedAt, at(11, 30));
  expect(editDraft.endPrecision, TimePrecision.exact);
  expect(
    (await app.repository.readTimeBlock(saved.id))!.timeBlock.title,
    '写作草稿',
  );
  expect(
    (await app.repository.readTimeBlock(saved.id))!.timeBlock.endedAt,
    at(11),
  );
  expect(
    (await app.repository.readTimeBlock(saved.id))!.timeBlock.note,
    '新建\n备注',
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

Future<void> phase2(WidgetTester tester) async {
  final app = await openTestApp(tester);
  await tapVisible(tester, '查看记录');
  final original = (await blocks(app)).single;
  expect(original.title, '写作草稿');
  expect(original.note, '新建\n备注');
  expect(await app.drafts.read(newContext), isNull);
  final editContext = RecordingDraftContext.edit(
    date: recordDate,
    timeBlockId: original.id,
  );
  expect((await app.drafts.read(editContext))!.title, '待更正写作');
  // This fact arrives after the edit draft was saved in the previous process.
  await app.repository.createTimeBlock(
    id: conflictId,
    startedAt: at(11),
    endedAt: at(12),
    startPrecision: TimePrecision.exact,
    endPrecision: TimePrecision.exact,
    knowledgeState: BlockKnowledgeState.known,
    title: '插入的活动',
    now: 2,
  );
  await tapBlockEdit(tester, original.id);
  expect(find.text('已恢复上次输入'), findsOneWidget);
  expect(
    tester
        .widget<TextField>(find.byKey(const ValueKey('note')))
        .controller!
        .text,
    '  编辑\n备注  ',
  );
  expect(find.text('2026-09-28 11:30'), findsOneWidget);
  await tapVisible(tester, '保存更正');
  expect(find.text('时间与已有记录冲突，请手动调整后再保存。'), findsOneWidget);
  expect(find.textContaining('冲突记录：活动'), findsOneWidget);
  expect((await app.drafts.read(editContext))!.endedAt, at(11, 30));
  expect((await app.drafts.read(editContext))!.note, '  编辑\n备注  ');
  expect(
    (await app.repository.readTimeBlock(original.id))!.timeBlock.title,
    '写作草稿',
  );
  expect(
    (await app.repository.readTimeBlock(original.id))!.timeBlock.endedAt,
    at(11),
  );
  expect(
    (await app.repository.readTimeBlock(original.id))!.timeBlock.note,
    '新建\n备注',
  );
  await tapVisible(tester, '保留草稿并返回');
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

Future<void> phase3(WidgetTester tester) async {
  final app = await openTestApp(tester);
  await tapVisible(tester, '查看记录');
  final original = (await blocks(app))
      .singleWhere((block) => block.id != conflictId);
  final editContext = RecordingDraftContext.edit(
    date: recordDate,
    timeBlockId: original.id,
  );
  if (original.title == '写作草稿') {
    await tapBlockEdit(tester, original.id);
    expect(find.text('已恢复上次输入'), findsOneWidget);
    expect(find.text('待更正写作'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('note')))
          .controller!
          .text,
      '  编辑\n备注  ',
    );
    await enterTime(tester, '结束时间', '2026-09-28 11:00');
    await tapVisible(tester, '保存更正');
    expect(find.text('更正已保存到账本。'), findsOneWidget);
  } else {
    // A previous interrupted test attempt may have committed this edit before
    // advancing the control marker. Resume only its remaining cleanup checks.
    expect(original.title, '待更正写作');
  }
  expect(
    (await app.repository.readTimeBlock(original.id))!.timeBlock.title,
    '待更正写作',
  );
  expect(
    (await app.repository.readTimeBlock(original.id))!.timeBlock.endPrecision,
    TimePrecision.exact,
  );
  expect(
    (await app.repository.readTimeBlock(original.id))!.timeBlock.note,
    '编辑\n备注',
  );
  expect(await app.drafts.read(editContext), isNull);
  // The previous success SnackBar can cover the bottom action on a short Web
  // viewport. Let it leave before exercising the separate discard action.
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  await tapVisible(tester, '补一笔');
  await tester.enterText(find.byKey(const ValueKey('activity')), '主动放弃的草稿');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tapVisible(tester, '放弃草稿');
  for (
    var attempt = 0;
    attempt < 100 && find.text('时间账本').evaluate().isEmpty;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.text('时间账本'), findsOneWidget);
  expect(await app.drafts.read(newContext), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

Future<void> phase4(WidgetTester tester) async {
  final app = await openTestApp(tester);
  await tapVisible(tester, '查看记录');
  final saved = (await blocks(app))
      .singleWhere((block) => block.id != conflictId);
  expect(saved.title, '待更正写作');
  expect(saved.endedAt, at(11));
  expect(saved.endPrecision, TimePrecision.exact);
  expect(saved.note, '编辑\n备注');
  expect(find.text('待更正写作'), findsOneWidget);
  expect(await app.drafts.read(newContext), isNull);
  final editContext = RecordingDraftContext.edit(
    date: recordDate,
    timeBlockId: saved.id,
  );
  expect(await app.drafts.read(editContext), isNull);
  await tapBlockEdit(tester, saved.id);
  expect(find.text('已恢复上次输入'), findsNothing);
  await tapVisible(tester, '保留草稿并返回');
  await tapVisible(tester, '补一笔');
  expect(find.text('已恢复上次输入'), findsNothing);
  await tapVisible(tester, '放弃草稿');
  await clearSchemaRows(app.database);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (runId.isEmpty) {
    throw StateError('Pass a unique E4_T08_RUN_ID for isolated platform data.');
  }
  testWidgets('E4-T08 recording survives actual platform lifecycle steps', (
    tester,
  ) async {
    final control = await DriftRecordingDraftStore.open(
      await connectDatabase('e4_t08_control_$runId'),
    );
    try {
      final previous = await control.read(controlContext);
      final phase = previous == null ? 0 : int.parse(previous.title!);
      debugPrint(
        'E4-T08 phase=$phase platform=${kIsWeb ? 'web' : defaultTargetPlatform.name} run=$runId',
      );
      switch (phase) {
        case 0:
          await phase0(tester);
        case 1:
          await phase1(tester);
        case 2:
          await phase2(tester);
        case 3:
          await phase3(tester);
        case 4:
          await phase4(tester);
        default:
          throw StateError('Isolated platform run already finished: $phase');
      }
      await control.save(
        RecordingDraft(
          context: controlContext,
          title: '${phase + 1}',
          startedAt: null,
          endedAt: null,
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          knowledgeState: null,
        ),
      );
      await control.close();
      platform_status.reportRecordingPlatformPhase(phase + 1);
      debugPrint(
        'E4-T08 phase=${phase + 1} passed platform=${kIsWeb ? 'web' : defaultTargetPlatform.name} run=$runId',
      );
    } catch (_) {
      await control.close();
      rethrow;
    }
  });
}
