import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/home_theme.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_entry_editor.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep/sleep_recording_page.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_form_controller.dart';

import '../../../../app/review_form_entry_test.dart' show settleNative;

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
final date = CivilDate(year: 2026, month: 10, day: 1);
final newContext = SleepDraftContext.newEntry(date: date);
final editContext = SleepDraftContext.edit(date: date, sleepSessionId: id(8));
int ts(int month, int day, int hour, [int minute = 0]) =>
    DateTime(2026, month, day, hour, minute).millisecondsSinceEpoch;

class Fixture {
  Fixture(this.db, this.drafts);
  final AppDatabase db;
  final DriftSleepDraftStore drafts;
  late final repo = DriftLedgerRepository(db);
  late final loader = SleepLedgerLoader(
    repository: repo,
    resolveDate: resolveDeviceRecordingDate,
  );
  int ids = 100;
  bool failRefresh = false;
  late final saver = SleepEntrySaver(
    repository: repo,
    drafts: drafts,
    refresh: ({required date, required now}) {
      if (failRefresh) throw StateError('refresh');
      return loader.load(date: date, now: now);
    },
    newId: () => id(ids++),
    now: () => ts(10, 2, 12),
  );
  late final editor = SleepEntryEditor(
    repository: repo,
    drafts: drafts,
    saver: saver,
    dateOfInstant: deviceDateOfInstant,
  );

  static Future<Fixture> open() async => Fixture(
    await AppDatabase.open(NativeDatabase.memory()),
    await DriftSleepDraftStore.open(NativeDatabase.memory()),
  );

  Future<void> close() async {
    await drafts.close();
    await db.close();
  }

  Future<void> source() => repo.createSleepSession(
    id: id(8),
    startedAt: ts(9, 30, 23, 40),
    endedAt: ts(10, 1, 7, 20),
    startPrecision: TimePrecision.approximate,
    endPrecision: TimePrecision.approximate,
    type: SleepType.mainSleep,
    note: '夜里醒了一次',
    now: 1,
  );

  Widget app(SleepDraftContext context) => MaterialApp(
    theme: homeTheme,
    home: Builder(
      builder: (outer) => Scaffold(
        body: TextButton(
          key: const ValueKey('open'),
          onPressed: () => Navigator.push(
            outer,
            MaterialPageRoute<Object?>(
              builder: (_) => SleepRecordingPage(
                controller: SleepFormController(
                  context: context,
                  store: drafts,
                  entrySaver: saver,
                  entryEditor: context.isEditing ? editor : null,
                ),
              ),
            ),
          ),
          child: const Text('打开'),
        ),
      ),
    ),
  );
}

Future<Fixture> open(WidgetTester t) async {
  final fixture = (await t.runAsync(Fixture.open))!;
  addTearDown(fixture.close);
  return fixture;
}

Finder key(String value) => find.byKey(ValueKey(value));

Future<void> tapKey(WidgetTester t, String value) async {
  FocusManager.instance.primaryFocus?.unfocus();
  t.testTextInput.hide();
  await settleNative(t);
  final target = key(value);
  if (target.evaluate().isEmpty) {
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await t.scrollUntilVisible(target, 160, scrollable: scrollable.last);
    }
  }
  if (target.evaluate().isEmpty) fail('key "$value" not found');
  await t.ensureVisible(target.first);
  await settleNative(t);
  await t.tap(target.first);
  await settleNative(t);
}

/// Drives an endpoint directly: time component, then date component.
Future<void> pickTimes(WidgetTester t, String start, String end) async {
  for (final entry in [('sleep-start', start), ('sleep-end', end)]) {
    final target = DateTime.parse(entry.$2);
    await tapKey(t, '${entry.$1}-date');
    expect(find.byKey(const ValueKey('time-picker-confirm')), findsNothing);
    while (true) {
      final heading = t
          .widgetList<Text>(find.byType(Text))
          .map((v) => v.data ?? '')
          .firstWhere((v) => RegExp(r'^\d+年\d+月$').hasMatch(v));
      final values = RegExp(r'(\d+)年(\d+)月').firstMatch(heading)!;
      final shown = int.parse(values[1]!) * 12 + int.parse(values[2]!);
      final wanted = target.year * 12 + target.month;
      if (shown == wanted) break;
      await t.tap(find.byTooltip(shown > wanted ? '上个月' : '下个月'));
      await settleNative(t);
    }
    await t.tap(find.text('${target.day}').last);
    await settleNative(t);
    await tapKey(t, 'date-picker-confirm');
    await tapKey(t, '${entry.$1}-time');
    expect(find.byKey(const ValueKey('sleep-time-apply')), findsNothing);
    final wheels = t
        .widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView))
        .toList();
    (wheels[0].controller! as FixedExtentScrollController).jumpToItem(
      target.hour,
    );
    (wheels[1].controller! as FixedExtentScrollController).jumpToItem(
      target.minute,
    );
    await settleNative(t);
    await tapKey(t, 'time-picker-confirm');
  }
}

void main() {
  testWidgets('saves a main sleep with both ends approximate and a note', (
    t,
  ) async {
    final f = await open(t);
    await t.pumpWidget(f.app(newContext));
    await settleNative(t);
    await tapKey(t, 'open');

    expect(find.text('几点睡，\n几点醒？'), findsOneWidget);
    // No precision choice: Q-030 keeps review input uniformly approximate.
    expect(find.byType(ChoiceChip), findsNothing);

    // 新建睡眠默认选中主睡眠（2026-10-07 用户决定）。
    expect(
      t.widget<AnimatedAlign>(key('sleep-type-indicator')).alignment,
      Alignment.centerLeft,
    );

    await pickTimes(t, '2026-09-30 23:40', '2026-10-01 07:20');

    // Prototype row order: date on the left, clock on the right.
    expect(
      t.getCenter(key('sleep-start-date')).dx <
          t.getCenter(key('sleep-start-time')).dx,
      isTrue,
    );
    // Prototype note affordance is the red text link, not a filled panel.
    final noteToggle = t.widget<TextButton>(key('sleep-note-toggle'));
    expect(
      noteToggle.style?.foregroundColor?.resolve({}),
      HomePalette.accentDeep,
    );
    expect(find.text('补充备注'), findsOneWidget);

    await tapKey(t, 'sleep-note-toggle');
    await t.enterText(key('sleep-note'), '夜里醒了一次');
    await settleNative(t);

    await tapKey(t, 'sleep-primary');
    await settleNative(t);

    final saved = (await t.runAsync(
      () => f.repo.readWindow(
        startedAt: DateTime(2026, 9, 30).millisecondsSinceEpoch,
        endedAt: DateTime(2026, 10, 2).millisecondsSinceEpoch,
      ),
    ))!;
    expect(saved.sleepSessions, hasLength(1));
    final sleep = saved.sleepSessions.single;
    expect(sleep.type, SleepType.mainSleep);
    expect(sleep.startPrecision, TimePrecision.approximate);
    expect(sleep.endPrecision, TimePrecision.approximate);
    expect(sleep.note, '夜里醒了一次');
    expect(await t.runAsync(() => f.drafts.read(newContext)), isNull);
  });

  testWidgets(
    'new entry defaults to main sleep and requires times before saving',
    (t) async {
      final f = await open(t);
      await t.pumpWidget(f.app(newContext));
      await settleNative(t);
      await tapKey(t, 'open');

      expect(
        t
            .widget<SleepRecordingPage>(find.byType(SleepRecordingPage))
            .controller
            .type,
        SleepType.mainSleep,
      );

      // Missing times are surfaced without a type error and without saving.
      await tapKey(t, 'sleep-primary');
      await t.scrollUntilVisible(
        find.text('请填写有效的入睡和醒来日期时间。'),
        160,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('先选择主睡眠或小睡。'), findsNothing);
      expect(find.text('请填写有效的入睡和醒来日期时间。'), findsOneWidget);
      expect(
        (await t.runAsync(
          () => f.repo.readWindow(
            startedAt: DateTime(2026, 10, 1).millisecondsSinceEpoch,
            endedAt: DateTime(2026, 10, 2).millisecondsSinceEpoch,
          ),
        ))!.sleepSessions,
        isEmpty,
      );
    },
  );

  testWidgets('sleep type segment slides selection without ink press overlay', (
    t,
  ) async {
    final f = await open(t);
    await t.pumpWidget(f.app(newContext));
    await settleNative(t);
    await tapKey(t, 'open');

    InkWell well(String value) => t.widget<InkWell>(
      find.descendant(of: key(value), matching: find.byType(InkWell)),
    );
    AnimatedAlign indicator() =>
        t.widget<AnimatedAlign>(key('sleep-type-indicator'));
    Rect pill() => t.getRect(key('sleep-type-pill'));

    for (final value in ['sleep-type-main', 'sleep-type-nap']) {
      // 分段切换的按压不叠加高亮 / 水波，选择态由滑动底纸表达。
      expect(well(value).splashFactory, NoSplash.splashFactory);
      expect(well(value).highlightColor, Colors.transparent);
      expect(well(value).hoverColor, Colors.transparent);
    }
    expect(indicator().alignment, Alignment.centerLeft);
    final before = pill();

    // 点击小睡后底纸滑向右侧，途中位置严格介于两端之间。
    await t.tap(key('sleep-type-nap'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
    final mid = pill();
    expect(mid.left, greaterThan(before.left));

    await settleNative(t);
    final ended = pill();
    expect(mid.left, lessThan(ended.left));
    expect(indicator().alignment, Alignment.centerRight);

    await tapKey(t, 'sleep-type-main');
    expect(indicator().alignment, Alignment.centerLeft);
  });

  testWidgets('edit mode loads the source, keeps precision and corrects', (
    t,
  ) async {
    final f = await open(t);
    await t.runAsync(f.source);
    await t.pumpWidget(f.app(editContext));
    await settleNative(t);
    await tapKey(t, 'open');

    expect(find.text('编辑睡眠'), findsOneWidget);
    expect(find.text('夜里醒了一次'), findsNothing);
    await tapKey(t, 'sleep-note-toggle');
    expect(t.widget<TextField>(key('sleep-note')).controller!.text, '夜里醒了一次');

    await pickTimes(t, '2026-09-30 23:50', '2026-10-01 07:30');
    await tapKey(t, 'sleep-primary');
    await settleNative(t);

    final saved = (await t.runAsync(
      () => f.repo.readWindow(
        startedAt: DateTime(2026, 9, 30).millisecondsSinceEpoch,
        endedAt: DateTime(2026, 10, 2).millisecondsSinceEpoch,
      ),
    ))!;
    expect(saved.sleepSessions.single.startedAt, ts(9, 30, 23, 50));
    expect(saved.sleepSessions.single.note, '夜里醒了一次');
  });

  testWidgets('delete removes the fact and pops with the refreshed ledger', (
    t,
  ) async {
    final f = await open(t);
    await t.runAsync(f.source);
    await t.pumpWidget(f.app(editContext));
    await settleNative(t);
    await tapKey(t, 'open');

    await tapKey(t, 'sleep-delete');
    await settleNative(t);
    await t.tap(find.text('确认删除'));
    await settleNative(t);

    expect(
      (await t.runAsync(
        () => f.repo.readWindow(
          startedAt: DateTime(2026, 9, 29).millisecondsSinceEpoch,
          endedAt: DateTime(2026, 10, 2).millisecondsSinceEpoch,
        ),
      ))!.sleepSessions,
      isEmpty,
    );
  });
}
