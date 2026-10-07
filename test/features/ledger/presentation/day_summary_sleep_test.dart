import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/day_ledger.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_summary_page.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_summary_view.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
int instant(int day, [int hour = 0, int minute = 0, int second = 0]) =>
    DateTime(2026, 10, day, hour, minute, second).millisecondsSinceEpoch;
CivilDate date(int day) => CivilDate(year: 2026, month: 10, day: day);

Future<AppDatabase> database(WidgetTester tester) async {
  // 大视口让完整分组和记录都可检查；小视口滚动仍由现有 ListView 负责。
  await tester.binding.setSurfaceSize(const Size(1000, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final db = (await tester.runAsync(
    () => AppDatabase.open(NativeDatabase.memory()),
  ))!;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(db.close);
  });
  return db;
}

Future<SleepSession> save(
  WidgetTester tester,
  AppDatabase db,
  int number,
  int start,
  int end, {
  SleepType type = SleepType.mainSleep,
  TimePrecision startPrecision = TimePrecision.exact,
  TimePrecision endPrecision = TimePrecision.exact,
}) async => (await tester.runAsync(
  () => DriftLedgerRepository(db).createSleepSession(
    id: id(number),
    startedAt: start,
    endedAt: end,
    type: type,
    startPrecision: startPrecision,
    endPrecision: endPrecision,
    now: 1,
  ),
))!;

Future<GlobalKey<NavigatorState>> open(
  WidgetTester tester,
  AppDatabase db,
  int day,
  int now,
) async {
  final observer = RouteObserver<ModalRoute<void>>();
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      navigatorKey: navigator,
      navigatorObservers: [observer],
      home: DaySummaryPage(
        loader: createDayLedgerLoader(db),
        now: () => now,
        dateOfInstant: deviceDateOfInstant,
        routeObserver: observer,
        initialDate: date(day),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return navigator;
}

SleepSummaryView summary(WidgetTester tester) =>
    tester.widget<SleepSummaryView>(find.byType(SleepSummaryView));

void main() {
  testWidgets(
    'multiple complete main sleeps and nap stay separate from window coverage',
    (tester) async {
      final db = await database(tester);
      final first = await save(
        tester,
        db,
        1,
        instant(1, 23, 50),
        instant(2, 7, 40),
        startPrecision: TimePrecision.approximate,
      );
      await save(tester, db, 2, instant(2, 9), instant(2, 10));
      await save(
        tester,
        db,
        3,
        instant(2, 11),
        instant(2, 11, 20),
        type: SleepType.nap,
      );
      await open(tester, db, 2, instant(2, 12));
      final view = summary(tester).summary;
      expect(view.mainSleep.records.map((r) => r.id), [id(1), id(2)]);
      expect(view.nap.records.single.id, id(3));
      expect(view.mainSleep.totalDuration.milliseconds, 530 * 60000);
      expect(view.nap.totalDuration.milliseconds, 20 * 60000);
      expect(find.text('约8 小时 50 分钟'), findsOneWidget);
      expect(find.text('20 分钟'), findsOneWidget);
      expect(find.text('已交代：9 小时'), findsOneWidget);
      expect(
        find.text('约2026-10-01 23:50 → 2026-10-02 07:40 · 完整时长 约7 小时 50 分钟'),
        findsOneWidget,
      );
      expect(
        find.text('2026-10-02 09:00 → 2026-10-02 10:00 · 完整时长 1 小时'),
        findsOneWidget,
      );
      expect(
        find.text('2026-10-02 11:00 → 2026-10-02 11:20 · 完整时长 20 分钟'),
        findsOneWidget,
      );
      expect(find.text('更正 / 删除'), findsNothing);
      final original = (await tester.runAsync(
        () => DriftLedgerRepository(db).readSleepSession(first.id),
      ))!;
      expect(original.startedAt, first.startedAt);
      expect(original.endedAt, first.endedAt);
      expect(original.startPrecision, TimePrecision.approximate);
      for (final table in [
        'time_blocks',
        'rhythm_annotations',
        'daily_reviews',
      ]) {
        expect(
          await tester.runAsync(
            () => db.customSelect('SELECT * FROM $table').get(),
          ),
          isEmpty,
        );
      }
    },
  );

  testWidgets(
    'missing groups and exact/approximate subminute totals use existing formatting',
    (tester) async {
      final db = await database(tester);
      await open(tester, db, 2, instant(2, 12));
      expect(find.text('尚未记录主睡眠'), findsOneWidget);
      expect(find.text('尚未记录小睡'), findsOneWidget);
      await save(tester, db, 1, instant(2, 1), instant(2, 1, 0, 20));
      await save(
        tester,
        db,
        2,
        instant(2, 2),
        instant(2, 2, 0, 20),
        type: SleepType.nap,
        endPrecision: TimePrecision.approximate,
      );
      await tester.tap(find.text('刷新摘要'));
      await tester.pumpAndSettle();
      expect(find.text('少于 1 分钟'), findsOneWidget);
      expect(find.text('约少于 1 分钟'), findsOneWidget);
      expect(find.text('尚未记录主睡眠'), findsNothing);
      expect(find.text('尚未记录小睡'), findsNothing);
      await save(tester, db, 3, instant(2, 3), instant(2, 3, 0, 20));
      await tester.tap(find.text('刷新摘要'));
      await tester.pumpAndSettle();
      expect(find.text('1 分钟'), findsOneWidget); // 20s + 20s 仅合计后舍入。
      expect(summary(tester).summary.mainSleep.records, hasLength(2));
      expect(
        summary(tester).summary.mainSleep.totalDuration.milliseconds,
        40000,
      );
    },
  );

  testWidgets(
    'midnight wake and future date have full sleep even with zero window contribution',
    (tester) async {
      final db = await database(tester);
      await save(
        tester,
        db,
        1,
        instant(1, 23),
        instant(2),
        startPrecision: TimePrecision.approximate,
      );
      await save(tester, db, 2, instant(2, 23), instant(3, 7));
      await open(tester, db, 2, instant(2));
      expect(find.text('约1 小时'), findsOneWidget);
      expect(find.text('已交代：0 分钟'), findsOneWidget);
      expect(find.text('尚未记录主睡眠'), findsNothing);
      expect(summary(tester).summary.mainSleep.records.single.id, id(1));
      await open(tester, db, 3, instant(2, 12));
      expect(find.text('8 小时'), findsOneWidget);
      expect(find.text('已交代：0 分钟'), findsOneWidget);
      expect(find.text('尚未记录：0 分钟'), findsOneWidget);
      expect(find.text('当前账本窗口为空，不产生未记录缺口。'), findsOneWidget);
      expect(summary(tester).summary.mainSleep.records.single.id, id(2));
      expect(find.text('尚未记录小睡'), findsOneWidget);
    },
  );

  testWidgets(
    'correcting wake date removes old summary and refreshes new date without losing original identity',
    (tester) async {
      final db = await database(tester);
      final record = await save(
        tester,
        db,
        1,
        instant(1, 23),
        instant(2, 7),
        startPrecision: TimePrecision.approximate,
      );
      await open(tester, db, 2, instant(4, 12));
      final old = summary(tester).summary;
      expect(find.text('约8 小时'), findsOneWidget);
      final corrected = (await tester.runAsync(
        () => DriftLedgerRepository(db).updateSleepSession(
          id: record.id,
          now: 2,
          startedAt: instant(2, 23),
          endedAt: instant(3, 7),
        ),
      ))!;
      await tester.tap(find.text('刷新摘要'));
      await tester.pumpAndSettle();
      expect(find.text('尚未记录主睡眠'), findsOneWidget);
      expect(find.text('约8 小时'), findsNothing);
      expect(find.text('已交代：约1 小时'), findsOneWidget); // 仍有新记录入睡日切片。
      await tester.enterText(find.byType(TextField), '2026-10-03');
      await tester.pumpAndSettle();
      expect(find.text('约8 小时'), findsOneWidget);
      expect(find.text('已交代：7 小时'), findsOneWidget);
      expect(summary(tester).summary.mainSleep.records.single.id, record.id);
      expect(corrected.createdAt, record.createdAt);
      expect(corrected.updatedAt, 2);
      expect(old.mainSleep.records.single.endedAt, record.endedAt);
      expect(
        (await tester.runAsync(
          () => db.customSelect('SELECT * FROM sleep_sessions').get(),
        ))!,
        hasLength(1),
      );
    },
  );
}
