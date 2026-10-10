import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/persistence/database_connection.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_opening_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_segment.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_reading_state.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_shell.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_timeline_geometry.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_timeline_tab.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep/sleep_recording_page.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_draft_store.dart';
import 'package:time_pet_ledger/features/settings/data/drift_app_preferences_store.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
int at(int hour, [int minute = 0]) =>
    DateTime(2026, 10, 7, hour, minute).millisecondsSinceEpoch;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'HOME-TIME real platform storage, short chooser, Gap/context, sleep, menu and reading restoration',
    (t) async {
      // All storage has a unique test namespace. Never opens the user's DB.
      final name =
          'home_time_platform_${DateTime.now().microsecondsSinceEpoch}';
      final database = await AppDatabase.open(
        await connectDatabase('${name}_formal'),
      );
      final repo = DriftLedgerRepository(database);
      await repo.createSleepSession(
        id: id(1),
        startedAt: at(-2),
        endedAt: at(7),
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        type: SleepType.mainSleep,
        now: 1,
      );
      for (final (n, from, to, unknown) in [
        (2, 420, 425, true),
        (3, 425, 430, false),
        (4, 450, 540, false),
      ]) {
        await repo.createTimeBlock(
          id: id(n),
          startedAt: at(0) + from * 60000,
          endedAt: at(0) + to * 60000,
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          knowledgeState: unknown
              ? BlockKnowledgeState.unknown
              : BlockKnowledgeState.known,
          title: unknown ? '只记得路上' : '平台活动$n',
          now: 1,
        );
      }
      await t.pumpWidget(
        AppBootstrap(
          openDatabase: () async => database,
          openDrafts: () async => DriftRecordingDraftStore.open(
            await connectDatabase('${name}_legacy_activity'),
          ),
          openSleepDrafts: () async => DriftSleepDraftStore.open(
            await connectDatabase('${name}_sleep_learning'),
          ),
          openSleepOpenings: () async => DriftSleepOpeningStore.open(
            await connectDatabase('${name}_openings'),
          ),
          openReviewDrafts: () async => DriftReviewDraftStore.open(
            await connectDatabase('${name}_legacy_review'),
          ),
          openPreferences: () async => DriftAppPreferencesStore.open(
            await connectDatabase('${name}_preferences'),
          ),
          now: () => DateTime(2026, 10, 7, 12),
        ),
      );
      await t.pumpAndSettle();
      final shell = t.state<HomeShellState>(find.byType(HomeShell));
      expect(shell.feed.focusView, isNotNull);
      expect(shell.reading.state, HomeHeaderState.expanded);
      final view = shell.feed.focusView!;
      final date = view.date;
      final items = TimelineInterval.fromView(view);
      final unknown = items.firstWhere(
        (item) =>
            item.fact is TimeBlockSegment &&
            (item.fact as TimeBlockSegment).source.knowledgeState ==
                BlockKnowledgeState.unknown,
      );
      final gap = items.firstWhere(
        (item) => item.gap != null && item.startedAt == at(7, 10),
      );
      final sleep = items.firstWhere(
        (item) => item.fact is SleepSessionSegment,
      );
      Finder target(TimelineInterval item) =>
          find.byKey(ValueKey(item.id)).last;
      Future<void> showTarget(TimelineInterval item) async {
        await t.ensureVisible(target(item));
        await t.pumpAndSettle();
      }

      Future<void> back() async {
        await t.binding.handlePopRoute();
        await t.pumpAndSettle();
      }

      await showTarget(unknown);
      await t.tapAt(t.getCenter(target(unknown)));
      await t.pumpAndSettle();
      expect(find.text('时段选择'), findsOneWidget);
      final unknownChoice = find.byKey(ValueKey(('time-choice', unknown.id)));
      expect(t.getSize(unknownChoice).height, greaterThanOrEqualTo(48));
      await t.tap(unknownChoice);
      await t.pumpAndSettle();
      expect(find.text('记录详情'), findsOneWidget);
      expect(find.text('只记得路上'), findsOneWidget);
      await back();

      await showTarget(gap);
      await t.tapAt(t.getCenter(target(gap)));
      await t.pumpAndSettle();
      expect(find.text('时段选择'), findsOneWidget);
      await t.tap(find.byKey(ValueKey(('time-choice', gap.id))));
      await t.pumpAndSettle();
      // Q-047 记录面板：时间在顶部直接可改，日期继承所选 Gap。
      expect(find.byKey(const ValueKey('activity-primary')), findsOneWidget);
      expect(find.text('07:10'), findsOneWidget);
      expect(find.text('07:30'), findsOneWidget);
      await back();
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('activity-primary')), findsNothing);

      await showTarget(sleep);
      await t.tapAt(t.getCenter(target(sleep)).translate(0, 0));
      await t.pumpAndSettle();
      expect(find.text('完整睡眠区间'), findsOneWidget);
      expect(find.text('10月6日 22:00'), findsWidgets);
      expect(find.text('10月7日 07:00'), findsWidgets);
      await back();

      await t.tap(find.byKey(const ValueKey('home-record-activity')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('activity-primary')), findsOneWidget);
      expect(find.text('记录一笔'), findsOneWidget);
      await back();
      await t.tap(find.byKey(const ValueKey('home-record-sleep')));
      await t.pumpAndSettle();
      expect(find.byType(SleepRecordingPage), findsOneWidget);
      await back();

      // Restore the today positioning, then use an actual continuous pointer
      // sequence against the platform's rendering/gesture pipeline.
      await shell.openDate(date);
      await t.pumpAndSettle();
      final gesture = await t.startGesture(
        t.getCenter(find.byType(HomeTimelineTab)),
      );
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await t.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await t.pumpAndSettle();
      expect(shell.reading.state, HomeHeaderState.collapsed);
      final position = t
          .state<HomeTimelineTabState>(find.byType(HomeTimelineTab))
          .readingPosition!;
      expect(find.byKey(const ValueKey('home-coverage')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-suggestion-card')), findsNothing);
      for (final destination in ['menu-summary', 'menu-review']) {
        await t.tap(find.byKey(const ValueKey('home-menu')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(ValueKey(destination)));
        await t.pumpAndSettle();
        await back();
        expect(shell.reading.state, HomeHeaderState.collapsed);
        expect(
          t
              .state<HomeTimelineTabState>(find.byType(HomeTimelineTab))
              .readingPosition!
              .instant,
          position.instant,
        );
      }
      expect(t.takeException(), isNull);
      debugPrint(
        'HOME_TIME_PLATFORM_PASS ${kIsWeb ? 'Web' : defaultTargetPlatform.name}: actual engine + isolated real SQLite + chooser/Unknown/Gap/Sleep/record/menu/return',
      );
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    },
  );
}
