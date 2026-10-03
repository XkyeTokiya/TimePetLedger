import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/persistence/database_connection.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_opening_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/annotation_change.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_draft_store.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';
import 'package:time_pet_ledger/features/review/domain/review_draft_store.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form_controller.dart'
    show formatReviewDate;
import 'package:time_pet_ledger/features/review/presentation/review_facts_view.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form.dart';

import 'goal_rhythm_platform_test.dart'
    as ui
    show tapFinder, visible, waitForUI, enter, input;
import 'support/schema_contract.dart' show clearSchemaRows;
import 'support/review_platform_status_native.dart'
    if (dart.library.js_interop) 'support/review_platform_status_web.dart'
    as platform_status;

const runId = String.fromEnvironment('E9_T09_RUN_ID');
String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
final source = CivilDate(year: 2024, month: 2, day: 28);
final leap = CivilDate(year: 2024, month: 2, day: 29);
final entryDate = CivilDate(year: 2024, month: 12, day: 31);
final conflictDate = CivilDate(year: 2025, month: 1, day: 1);
final siblingDate = CivilDate(year: 2024, month: 12, day: 30);
final abandonDate = CivilDate(year: 2024, month: 12, day: 29);
final newContext = ReviewDraftContext.newEntry(date: entryDate);
final editContext = ReviewDraftContext.edit(reviewId: id(30));
final siblingContext = ReviewDraftContext.newEntry(date: siblingDate);
final controlContext = RecordingDraftContext.newEntry(date: source);
const rawSummary = '  新建概述 🐾\n第二段  ';
const rawReflection = '  \n ';
const rawStep = '  先打开原设计图 🐾\n再补一个字段  ';
const editSummary = '  历史更正概述\n保留内部格式  ';
const editReflection = '  我自己的反思 🐾  ';
const editStep = '  明天先读原记录  ';
const siblingStep = '  另一日期独立输入  ';
const conflictMessage = '该日期已有复盘，未覆盖；输入和草稿已保留，请调整日期或返回读取。';
final clock = DateTime(2026, 10, 3, 12);
int at(int h, [int day = 28]) =>
    DateTime(2024, 2, day, h).millisecondsSinceEpoch;

Future<void> tap(WidgetTester t, String label) async {
  debugPrint('E9-T09 action=$label');
  await ui.tapFinder(t, find.text(label));
}

Future<void> select(WidgetTester t, CivilDate date) async {
  final field = find.widgetWithText(TextField, '复盘日期 YYYY-MM-DD');
  await ui.visible(t, field);
  await t.tap(field);
  await t.pumpAndSettle();
  await t.enterText(field, formatReviewDate(date));
  FocusManager.instance.primaryFocus?.unfocus();
  await ui.waitForUI(t);
}

Future<void> openForm(WidgetTester t, {bool edit = false}) =>
    tap(t, edit ? '编辑复盘草稿' : '填写复盘');
Future<void> flush(WidgetTester t) async {
  final model = t.widget<ReviewForm>(find.byType(ReviewForm)).controller;
  expect(await model.flush(), isTrue);
  await ui.waitForUI(t);
}

Future<void> restored(WidgetTester t) async {
  await ui.visible(t, find.text('已恢复未保存的复盘输入。'));
  expect(find.text('已恢复未保存的复盘输入。'), findsOneWidget);
}

Future<void> checkForm(
  WidgetTester t, {
  required String date,
  required String summary,
  required String reflection,
  required String step,
}) async {
  await restored(t);
  expect(await ui.input(t, 'review-date'), date);
  expect(await ui.input(t, 'review-summary'), summary);
  expect(await ui.input(t, 'review-reflection'), reflection);
  expect(await ui.input(t, 'review-step'), step);
}

Future<void> readText(WidgetTester t, String text) async {
  await ui.visible(t, find.text(text));
  expect(find.text(text), findsOneWidget);
}

class App {
  App(this.db, this.drafts);
  final AppDatabase db;
  final DriftReviewDraftStore drafts;
  DriftReviewRepository get reviews => DriftReviewRepository(db);
  DriftGoalRepository get goals => DriftGoalRepository(db);
  Future<Map<String, List<Map<String, Object?>>>> rows({
    bool reviews = true,
  }) async => {
    for (final table in [
      'goals',
      'time_blocks',
      'rhythm_annotations',
      'sleep_sessions',
      if (reviews) 'daily_reviews',
    ])
      table: (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
          .map((r) => r.data)
          .toList(),
  };
  Future<void> sibling() async {
    final draft = (await drafts.read(siblingContext))!;
    expect(draft.date, siblingDate);
    expect(draft.dateInput, formatReviewDate(siblingDate));
    expect(draft.tomorrowFirstStepText, siblingStep);
    expect(draft.summary, '  独立概述  ');
  }
}

Future<void> seed(App app) async {
  // All fixtures belong to this unique run's real platform databases.
  await app.goals.create(id: id(1), name: '历史原目标', now: at(12));
  final ledger = DriftLedgerRepository(app.db);
  await ledger.createSleepSession(
    id: id(20),
    startedAt: at(23, 27),
    endedAt: at(7),
    startPrecision: TimePrecision.approximate,
    endPrecision: TimePrecision.exact,
    type: SleepType.mainSleep,
    now: at(12),
  );
  await ledger.createTimeBlock(
    id: id(10),
    startedAt: at(7),
    endedAt: at(8),
    startPrecision: TimePrecision.exact,
    endPrecision: TimePrecision.exact,
    knowledgeState: BlockKnowledgeState.known,
    title: '原时间事实',
    goalId: id(1),
    annotation: AddAnnotation(
      id: id(11),
      state: RhythmState.progress,
      continuationHint: '原活动接续点',
    ),
    now: at(12),
  );
  await ledger.createTimeBlock(
    id: id(12),
    startedAt: at(8),
    endedAt: at(9),
    startPrecision: TimePrecision.exact,
    endPrecision: TimePrecision.exact,
    knowledgeState: BlockKnowledgeState.unknown,
    now: at(12),
  );
  await app.reviews.create(
    id: id(30),
    date: source,
    summary: '原概述',
    reflection: '原反思',
    tomorrowFirstStepText: '原第一步',
    tomorrowFirstStepGoalId: id(1),
    now: at(12),
  );
  await app.goals.archive(id: id(1), now: at(13));
}

Future<App> openApp(WidgetTester t, {bool initial = false}) async {
  final app = App(
    await AppDatabase.open(await connectDatabase('e9_t09_formal_$runId')),
    await DriftReviewDraftStore.open(
      await connectDatabase('e9_t09_reviews_$runId'),
    ),
  );
  if (initial) {
    expect((await app.rows()).values.every((r) => r.isEmpty), isTrue);
    await seed(app);
  }
  await t.pumpWidget(
    AppBootstrap(
      openDatabase: () async => app.db,
      openReviewDrafts: () async => app.drafts,
      openDrafts: () async => DriftRecordingDraftStore.open(
        await connectDatabase('e9_t09_recording_$runId'),
      ),
      openSleepDrafts: () async => DriftSleepDraftStore.open(
        await connectDatabase('e9_t09_sleep_$runId'),
      ),
      openSleepOpenings: () async {
        final store = await DriftSleepOpeningStore.open(
          await connectDatabase('e9_t09_openings_$runId'),
        );
        await store.claim(CivilDate(year: 2026, month: 10, day: 3));
        return store;
      },
      now: () => clock,
    ),
  );
  await ui.waitForUI(t);
  await tap(t, '打开按日复盘');
  return app;
}

Future<void> facts(WidgetTester t, App app) async {
  final before = await app.rows(reviews: false);
  await select(t, source);
  final view = t.widget<ReviewFactsView>(find.byType(ReviewFactsView)).ledger;
  expect(view.date, source);
  expect(view.accountedDuration.milliseconds, 540 * 60000);
  expect(view.unknownDuration.milliseconds, 60 * 60000);
  expect(view.unresolvedDuration.milliseconds, 900 * 60000);
  expect(view.sleepSummary.mainSleep.totalDuration.milliseconds, 480 * 60000);
  expect(view.goalSummaries.single.progressDuration.milliseconds, 60 * 60000);
  expect(view.goalSummaries.single.isArchived, isTrue);
  expect(await app.rows(reviews: false), before);
}

Future<void> phase0(WidgetTester t) async {
  final app = await openApp(t, initial: true);
  await facts(t, app);
  final before = await app.rows();
  await select(t, siblingDate);
  await openForm(t);
  await ui.enter(t, 'review-summary', '  独立概述  ');
  await ui.enter(t, 'review-step', siblingStep);
  await tap(t, '保留草稿并返回');
  await select(t, entryDate);
  await openForm(t);
  await ui.enter(t, 'review-date', formatReviewDate(conflictDate));
  await ui.enter(t, 'review-summary', rawSummary);
  await ui.enter(t, 'review-reflection', rawReflection);
  await ui.enter(t, 'review-step', '');
  await tap(t, '保留草稿并返回');
  await openForm(t);
  await checkForm(
    t,
    date: formatReviewDate(conflictDate),
    summary: rawSummary,
    reflection: rawReflection,
    step: '',
  );
  await tap(t, '保留草稿并返回');
  await select(t, source);
  await openForm(t, edit: true);
  await ui.enter(t, 'review-date', formatReviewDate(leap));
  await ui.enter(t, 'review-summary', editSummary);
  await ui.enter(t, 'review-reflection', editReflection);
  await ui.enter(t, 'review-step', editStep);
  await tap(t, '保留草稿并返回');
  await openForm(t, edit: true);
  await checkForm(
    t,
    date: formatReviewDate(leap),
    summary: editSummary,
    reflection: editReflection,
    step: editStep,
  );
  await readText(t, '下一自然日：2024-03-01');
  await readText(t, '下一步目标：历史原目标（已归档）');
  await flush(t);
  await app.sibling();
  expect(await app.rows(), before);
  // Keep the changed-date edit form open during actual force-stop / refresh.
}

Future<void> phase1(WidgetTester t) async {
  final app = await openApp(t);
  await facts(t, app);
  final original = await app.rows();
  await openForm(t, edit: true);
  await checkForm(
    t,
    date: formatReviewDate(leap),
    summary: editSummary,
    reflection: editReflection,
    step: editStep,
  );
  await tap(t, '保留草稿并返回');
  await select(t, entryDate);
  await openForm(t);
  await checkForm(
    t,
    date: formatReviewDate(conflictDate),
    summary: rawSummary,
    reflection: rawReflection,
    step: '',
  );
  expect(await app.rows(), original);
  await ui.enter(t, 'review-step', rawStep);
  // A real late write wins the selected date after this form was opened.
  await app.reviews.create(
    id: id(31),
    date: conflictDate,
    tomorrowFirstStepText: '另一份已存第一步',
    now: clock.millisecondsSinceEpoch,
  );
  final competing = await app.rows();
  await tap(t, '保存复盘');
  await readText(t, conflictMessage);
  expect(await app.rows(), competing);
  await flush(t);
  expect((await app.drafts.read(newContext))!.tomorrowFirstStepText, rawStep);
  expect((await app.drafts.read(editContext))!.date, leap);
  await app.sibling();
  // Failed new input stays open and must survive the next lifecycle.
}

Future<void> phase2(WidgetTester t) async {
  final app = await openApp(t);
  await facts(t, app);
  final ledger = await app.rows(reviews: false);
  final original = (await app.reviews.findByDate(source))!;
  await select(t, entryDate);
  await openForm(t);
  await checkForm(
    t,
    date: formatReviewDate(conflictDate),
    summary: rawSummary,
    reflection: rawReflection,
    step: rawStep,
  );
  await tap(t, '保存复盘');
  await readText(t, conflictMessage);
  await ui.enter(t, 'review-date', formatReviewDate(entryDate));
  await tap(t, '保存复盘');
  expect(find.byType(ReviewForm), findsNothing);
  await readText(t, rawStep.trim());
  await readText(t, '下一自然日：2025-01-01');
  final created = (await app.reviews.findByDate(entryDate))!;
  expect(created.summary, rawSummary.trim());
  expect(created.reflection, isNull);
  expect(created.tomorrowFirstStep.text, rawStep.trim());
  expect(await app.drafts.read(newContext), isNull);
  expect(
    await app.drafts.read(ReviewDraftContext.newEntry(date: conflictDate)),
    isNull,
  );
  await select(t, source);
  await openForm(t, edit: true);
  await checkForm(
    t,
    date: formatReviewDate(leap),
    summary: editSummary,
    reflection: editReflection,
    step: editStep,
  );
  await tap(t, '保存更正');
  expect(find.byType(ReviewForm), findsNothing);
  await readText(t, '已存复盘日期：2024-02-29');
  await readText(t, '下一自然日：2024-03-01');
  final corrected = (await app.reviews.findByDate(leap))!;
  expect(corrected.id, original.id);
  expect(corrected.createdAt, original.createdAt);
  expect(corrected.updatedAt, clock.millisecondsSinceEpoch);
  expect(corrected.summary, editSummary.trim());
  expect(corrected.reflection, editReflection.trim());
  expect(corrected.tomorrowFirstStep.text, editStep.trim());
  expect(corrected.tomorrowFirstStep.goalId, id(1));
  expect(await app.reviews.findByDate(source), isNull);
  expect(await app.drafts.read(editContext), isNull);
  expect(await app.rows(reviews: false), ledger);
  await app.sibling();
}

Future<void> phase3(WidgetTester t) async {
  final app = await openApp(t);
  await facts(t, app);
  final ledger = await app.rows(reviews: false);
  expect(await app.reviews.findByDate(source), isNull);
  await select(t, leap);
  await readText(t, '已存复盘日期：2024-02-29');
  await readText(t, editStep.trim());
  await readText(t, '第一步目标：历史原目标（已归档）');
  await readText(t, '下一自然日：2024-03-01');
  await select(t, entryDate);
  await readText(t, rawStep.trim());
  await readText(t, '下一自然日：2025-01-01');
  final original = await app.rows();
  await openForm(t, edit: true);
  await ui.enter(t, 'review-summary', '  未提交编辑后主动放弃  ');
  await tap(t, '放弃此复盘草稿');
  final created = (await app.reviews.findByDate(entryDate))!;
  expect(
    await app.drafts.read(ReviewDraftContext.edit(reviewId: created.id)),
    isNull,
  );
  await select(t, abandonDate);
  await openForm(t);
  await ui.enter(t, 'review-date', '2024-12-');
  await ui.enter(t, 'review-step', '  放弃未完成日期输入  ');
  await tap(t, '放弃此复盘草稿');
  expect(
    await app.drafts.read(ReviewDraftContext.newEntry(date: abandonDate)),
    isNull,
  );
  expect(await app.rows(), original);
  await app.sibling();
  await select(t, leap);
  await openForm(t, edit: true);
  await ui.enter(t, 'review-step', '  删除前未提交输入  ');
  await tap(t, '删除复盘');
  await tap(t, '确认删除');
  expect(find.byType(ReviewForm), findsNothing);
  await readText(t, '这一天尚无复盘。');
  expect(await app.reviews.findByDate(leap), isNull);
  expect(await app.drafts.read(editContext), isNull);
  expect(await app.rows(reviews: false), ledger);
  // A different existing review's edit draft must survive deletion independently.
  await select(t, conflictDate);
  await openForm(t, edit: true);
  await ui.enter(t, 'review-step', '  竞争复盘独立编辑草稿  ');
  await flush(t);
  await app.sibling();
}

Future<void> phase4(WidgetTester t) async {
  final app = await openApp(t);
  await facts(t, app);
  expect(await app.reviews.findByDate(source), isNull);
  expect(await app.reviews.findByDate(leap), isNull);
  await select(t, leap);
  await readText(t, '这一天尚无复盘。');
  await select(t, entryDate);
  await readText(t, rawSummary.trim());
  await readText(t, rawStep.trim());
  await readText(t, '未填写反思');
  final created = (await app.reviews.findByDate(entryDate))!;
  expect(await app.drafts.read(newContext), isNull);
  expect(await app.drafts.read(editContext), isNull);
  expect(
    await app.drafts.read(ReviewDraftContext.edit(reviewId: created.id)),
    isNull,
  );
  expect(
    await app.drafts.read(ReviewDraftContext.newEntry(date: abandonDate)),
    isNull,
  );
  final before = await app.rows();
  await select(t, conflictDate);
  await openForm(t, edit: true);
  await restored(t);
  expect(await ui.input(t, 'review-step'), '  竞争复盘独立编辑草稿  ');
  await tap(t, '放弃此复盘草稿');
  expect(
    await app.drafts.read(ReviewDraftContext.edit(reviewId: id(31))),
    isNull,
  );
  await app.sibling();
  await select(t, siblingDate);
  await openForm(t);
  await restored(t);
  expect(await ui.input(t, 'review-step'), siblingStep);
  await tap(t, '放弃此复盘草稿');
  expect(await app.drafts.read(siblingContext), isNull);
  expect(await app.rows(), before);
  expect(before['daily_reviews'], hasLength(2));
  // Cleanup only the unique run's fixtures, after all assertions passed.
  await clearSchemaRows(app.db);
  expect((await app.rows()).values.every((r) => r.isEmpty), isTrue);
  await t.pumpWidget(const SizedBox.shrink());
  await t.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(runId)) {
    throw StateError('Pass a unique E9_T09_RUN_ID.');
  }
  testWidgets('E9-T09 review save and drafts survive actual platform lifecycle', (
    t,
  ) async {
    final control = await DriftRecordingDraftStore.open(
      await connectDatabase('e9_t09_control_$runId'),
    );
    try {
      final previous = await control.read(controlContext);
      final phase = previous == null ? 0 : int.parse(previous.title!);
      final phases = [phase0, phase1, phase2, phase3, phase4];
      if (phase < 0 || phase >= phases.length) {
        throw StateError('Run already finished: $phase');
      }
      debugPrint(
        'E9-T09 phase=$phase platform=${kIsWeb ? 'web' : defaultTargetPlatform.name} run=$runId',
      );
      await phases[phase](t);
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
      platform_status.reportReviewPlatformPhase(phase + 1);
      debugPrint(
        'E9-T09 phase=${phase + 1} passed platform=${kIsWeb ? 'web' : defaultTargetPlatform.name} run=$runId',
      );
    } catch (_) {
      await control.close();
      rethrow;
    }
  });
}
