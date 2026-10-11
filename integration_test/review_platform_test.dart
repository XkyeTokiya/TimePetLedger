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
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_opening_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_draft_store.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';

import 'support/platform_flow.dart'
    as ui
    show tapFinder, visible, waitForUI, enter, input;
import 'support/schema_contract.dart' show clearSchemaRows;
import 'support/review_platform_status_native.dart'
    if (dart.library.js_interop) 'support/review_platform_status_web.dart'
    as platform_status;

/// E9-T09 重基线（Q-012，REVIEW-R2-12/R2-13）：
/// 会话输入只在当前应用会话内保留（force-stop 后消失），正式复盘跨
/// force-stop 保留；需要真机 / 真实浏览器按 phase 逐次运行。
const runId = String.fromEnvironment('E9_T09_RUN_ID');
String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
final day = CivilDate(year: 2026, month: 10, day: 2);
final clock = DateTime(2026, 10, 2, 20);
final controlContext = RecordingDraftContext.newEntry(
  date: CivilDate(year: 1999, month: 1, day: 1),
);

Future<void> tap(WidgetTester t, String label) async {
  debugPrint('E9-T09 action=$label');
  await ui.tapFinder(t, find.text(label));
}

Future<void> tapKey(WidgetTester t, String key) async {
  debugPrint('E9-T09 key=$key');
  await ui.tapFinder(t, find.byKey(ValueKey(key)));
}

Future<void> readText(WidgetTester t, String text) async {
  await ui.visible(t, find.text(text));
  expect(find.text(text), findsOneWidget);
}

/// 经首页快捷区进入当日复盘。
Future<void> openReview(WidgetTester t) async {
  await tapKey(t, 'home-menu');
  await ui.waitForUI(t);
  await tapKey(t, 'menu-review');
  await ui.waitForUI(t);
}

/// 从向导返回首页（3→2→1→pop）。
Future<void> backToHome(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await tapKey(t, 'review-back');
    await ui.waitForUI(t);
  }
}

Future<void> openReflow(WidgetTester t) async {
  await tapKey(t, 'review-menu');
  await ui.waitForUI(t);
  await tapKey(t, 'review-reflow');
  await ui.waitForUI(t);
}

class App {
  App(this.db);
  final AppDatabase db;
  DriftReviewRepository get reviews => DriftReviewRepository(db);
  Future<Map<String, List<Map<String, Object?>>>> rows() async => {
    for (final table in [
      'goals',
      'time_blocks',
      'rhythm_annotations',
      'sleep_sessions',
      'daily_reviews',
    ])
      table: (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
          .map((r) => r.data)
          .toList(),
  };
}

Future<App> openApp(WidgetTester t, {bool initial = false}) async {
  final app = App(
    await AppDatabase.open(await connectDatabase('e9_t09_formal_$runId')),
  );
  if (initial) {
    expect((await app.rows()).values.every((r) => r.isEmpty), isTrue);
    await seed(app);
  }
  await t.pumpWidget(
    AppBootstrap(
      openDatabase: () async => app.db,
      openDrafts: () async => DriftRecordingDraftStore.open(
        await connectDatabase('e9_t09_recording_$runId'),
      ),
      openSleepDrafts: () async => DriftSleepDraftStore.open(
        await connectDatabase('e9_t09_sleep_$runId'),
      ),
      openReviewDrafts: () async => DriftReviewDraftStore.open(
        await connectDatabase('e9_t09_reviews_$runId'),
      ),
      openSleepOpenings: () async {
        final store = await DriftSleepOpeningStore.open(
          await connectDatabase('e9_t09_openings_$runId'),
        );
        await store.claim(day);
        return store;
      },
      now: () => clock,
    ),
  );
  await ui.waitForUI(t);
  await openReview(t);
  return app;
}

Future<void> seed(App app) async {
  final ledger = DriftLedgerRepository(app.db);
  await ledger.createTimeBlock(
    id: id(10),
    startedAt: DateTime(2026, 10, 2, 9).millisecondsSinceEpoch,
    endedAt: DateTime(2026, 10, 2, 10).millisecondsSinceEpoch,
    startPrecision: TimePrecision.exact,
    endPrecision: TimePrecision.exact,
    knowledgeState: BlockKnowledgeState.known,
    title: '原时间事实',
    now: 1,
  );
  await app.reviews.create(
    id: id(30),
    date: day,
    tomorrowFirstStepText: '原第一步',
    now: 2,
  );
}

/// 同一会话内的未完成输入写入会话快照；force-stop 后由 phase1 断言消失。
Future<void> phase0(WidgetTester t) async {
  await openApp(t, initial: true);
  await readText(t, '原第一步');
  await openReflow(t);
  await tap(t, '下一步');
  await tap(t, '下一步');
  await ui.enter(t, 'review-next-step', '平台会话输入');
  await backToHome(t);
}

/// 正式复盘跨 force-stop 保留；会话输入不恢复，但同一会话内离开再进入可继续。
Future<void> phase1(WidgetTester t) async {
  final app = await openApp(t);
  await readText(t, '原第一步');
  await openReflow(t);
  expect(find.text('继续上次修改？'), findsNothing);
  expect(find.text('整理今天'), findsOneWidget);
  await tap(t, '下一步');
  await tap(t, '下一步');
  await ui.enter(t, 'review-next-step', '本会话输入');
  await backToHome(t);

  await openReview(t);
  await openReflow(t);
  await ui.visible(t, find.text('继续上次修改？'));
  await tap(t, '继续填写');
  await ui.waitForUI(t);
  expect(await ui.input(t, 'review-next-step'), '本会话输入');
  await tap(t, '下一步');
  await tap(t, '完成今天的回顾');
  await ui.waitForUI(t);
  expect((await app.reviews.findByDate(day))!.tomorrowFirstStep.text, '本会话输入');
}

/// 重新整理后的正式内容跨 force-stop 保留；删除只移除复盘。
Future<void> phase2(WidgetTester t) async {
  final app = await openApp(t);
  await readText(t, '本会话输入');
  await tapKey(t, 'review-menu');
  await ui.waitForUI(t);
  await tapKey(t, 'review-delete');
  await ui.waitForUI(t);
  await ui.visible(t, find.text('删除这次回顾？'));
  await tapKey(t, 'review-delete-confirm');
  await ui.waitForUI(t);
  expect(find.text('整理今天'), findsOneWidget);
  expect(await app.reviews.findByDate(day), isNull);
}

/// 删除后没有可恢复的会话输入；清理本次 run 的夹具。
Future<void> phase3(WidgetTester t) async {
  final app = await openApp(t);
  expect(find.text('整理今天'), findsOneWidget);
  expect(find.text('继续上次填写？'), findsNothing);
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
  testWidgets(
    'E9-T09 review session input and formal review across platform lifecycle',
    (t) async {
      final control = await DriftRecordingDraftStore.open(
        await connectDatabase('e9_t09_control_$runId'),
      );
      try {
        final previous = await control.read(controlContext);
        final phase = previous == null ? 0 : int.parse(previous.title!);
        final phases = [phase0, phase1, phase2, phase3];
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
    },
  );
}
