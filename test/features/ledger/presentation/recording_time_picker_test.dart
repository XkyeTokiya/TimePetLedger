import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/app_theme.dart';
import 'package:time_pet_ledger/app/theme/home_theme.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_date_dialog.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_time_picker.dart';
import 'package:time_pet_ledger/features/settings/domain/app_preferences.dart';

final date = CivilDate(year: 2026, month: 12, day: 31);
int at(int day, int hour, int minute) =>
    DateTime(2026, 12, day, hour, minute).millisecondsSinceEpoch;

const captureKey = ValueKey('picker-capture');

Future<void> captureShot(WidgetTester t, String name) async {
  final dir = Platform.environment['PICKER_CAPTURE_DIR'];
  if (dir == null) return;
  await t.runAsync(() async {
    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await Directory(dir).create(recursive: true);
    await File('$dir/$name.png').writeAsBytes(bytes.buffer.asUint8List());
    image.dispose();
  });
}

void wheels(WidgetTester t, int hour, int minute) {
  final w = t
      .widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView))
      .toList();
  (w[0].controller! as FixedExtentScrollController).jumpToItem(hour);
  (w[1].controller! as FixedExtentScrollController).jumpToItem(minute);
}

Widget app({required ValueChanged<int> onPick, int? value}) => MaterialApp(
  theme: homeTheme,
  home: Builder(
    builder: (context) => Scaffold(
      body: Column(
        children: [
          TextButton(
            onPressed: () async {
              final picked = await showRecordingTimePicker(
                context,
                value: value,
                date: date,
              );
              if (picked != null) onPick(picked);
            },
            child: const Text('时间'),
          ),
          TextButton(
            onPressed: () async {
              final picked = await showRecordingDatePicker(
                context,
                value: value,
                date: date,
              );
              if (picked != null) onPick(picked);
            },
            child: const Text('日期'),
          ),
        ],
      ),
    ),
  ),
);
void main() {
  final fold = DateTime.utc(2026, 11, 1, 6, 30, 32, 123).toLocal();
  final spring = DateTime(2026, 3, 8, 1, 30);
  testWidgets(
    'unchanged endpoint preserves the original instant in a repeated local hour',
    (t) async {
      int? result;
      await t.pumpWidget(
        app(value: fold.millisecondsSinceEpoch, onPick: (v) => result = v),
      );
      for (final label in ['时间', '日期']) {
        result = null;
        await t.tap(find.text(label));
        await t.pumpAndSettle();
        await t.tap(
          find.byKey(
            ValueKey(
              label == '时间' ? 'time-picker-confirm' : 'date-picker-confirm',
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(result, fold.millisecondsSinceEpoch);
      }
    },
    skip: fold.hour != 1 || fold.timeZoneOffset != const Duration(hours: -5),
  );
  testWidgets(
    'nonexistent local clock leaves the endpoint unchanged and asks for another choice',
    (t) async {
      int? result;
      await t.pumpWidget(
        app(value: spring.millisecondsSinceEpoch, onPick: (v) => result = v),
      );
      await t.tap(find.text('时间'));
      await t.pumpAndSettle();
      wheels(t, 2, 30);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('time-picker-confirm')));
      await t.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('所选日期与时间在当地不存在，请重新选择。'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    },
    skip: DateTime(2026, 3, 8, 2, 30).hour == 2,
  );

  testWidgets(
    'time confirm applies immediately without changing date or seconds',
    (t) async {
      final original = at(31, 23, 50) + 32123;
      int? result;
      await t.pumpWidget(app(value: original, onPick: (v) => result = v));
      await t.tap(find.text('时间'));
      await t.pumpAndSettle();
      final w = t
          .widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView))
          .toList();
      expect(
        (w[0].controller! as FixedExtentScrollController).selectedItem,
        23,
      );
      expect(
        (w[1].controller! as FixedExtentScrollController).selectedItem,
        50,
      );
      expect(result, isNull);
      wheels(t, 0, 20);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('time-picker-confirm')));
      await t.pumpAndSettle();
      expect(result, at(31, 0, 20) + 32123);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const ValueKey('date-picker-confirm')), findsNothing);
    },
  );
  testWidgets('date confirm crosses year preserving time and milliseconds', (
    t,
  ) async {
    final original = at(31, 23, 50) + 32123;
    int? result;
    await t.pumpWidget(app(value: original, onPick: (v) => result = v));
    await t.tap(find.text('日期'));
    await t.pumpAndSettle();
    expect(find.text('2026年12月'), findsOneWidget);
    expect(find.byType(ListWheelScrollView), findsNothing);
    expect(result, isNull);
    await t.tap(find.byTooltip('下个月'));
    await t.pumpAndSettle();
    await t.tap(find.text('1').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('date-picker-confirm')));
    await t.pumpAndSettle();
    expect(
      result,
      DateTime(2027, 1, 1, 23, 50, 32, 123).millisecondsSinceEpoch,
    );
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('opening or cancelling either picker keeps original input', (
    t,
  ) async {
    int? result;
    await t.pumpWidget(app(value: at(31, 14, 0), onPick: (v) => result = v));
    for (final label in ['时间', '日期']) {
      await t.tap(find.text(label));
      await t.pumpAndSettle();
      expect(result, isNull);
      await t.tap(find.text('取消'));
      await t.pumpAndSettle();
      expect(result, isNull);
      expect(find.byType(AlertDialog), findsNothing);
    }
  });
  testWidgets('empty input opens either picker with entry date and noon', (
    t,
  ) async {
    int? result;
    await t.pumpWidget(app(onPick: (v) => result = v));
    await t.tap(find.text('日期'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('date-picker-confirm')));
    await t.pumpAndSettle();
    expect(result, at(31, 12, 0));
    await t.tap(find.text('时间'));
    await t.pumpAndSettle();
    wheels(t, 7, 20);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('time-picker-confirm')));
    await t.pumpAndSettle();
    expect(result, at(31, 7, 20));
  });
  testWidgets(
    'duration reverses from end across dates and permits more than a day',
    (t) async {
      ({int start, int end})? result;
      final end = DateTime(2027, 1, 2, 7).millisecondsSinceEpoch;
      await t.pumpWidget(
        MaterialApp(
          theme: homeTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showRecordingDurationPicker(
                    context,
                    startedAt: end - 1800000,
                    endedAt: end,
                  );
                },
                child: const Text('时长'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('时长'));
      await t.pumpAndSettle();
      // 时长拨轮与时分拨轮共用中央高亮。
      expect(
        find.byKey(const ValueKey('duration-picker-hour-band')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('duration-picker-minute-band')),
        findsOneWidget,
      );
      await t.tap(find.text('从结束算'));
      await t.pumpAndSettle();
      final wheels = t
          .widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView))
          .toList();
      (wheels[0].controller! as FixedExtentScrollController).jumpToItem(36);
      (wheels[1].controller! as FixedExtentScrollController).jumpToItem(0);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('duration-picker-confirm')));
      await t.pumpAndSettle();
      expect(result, (
        start: end - const Duration(hours: 36).inMilliseconds,
        end: end,
      ));
    },
  );

  test(
    'ledgerClockRangeFor constrains same-day pairs and stays off across days',
    () {
      // 终点按起点：最早 = 起点 + 1 分钟。
      final endRange = ledgerClockRangeFor(
        startedAt: at(31, 9, 0),
        endedAt: null,
        isStart: false,
        entryDate: date,
      );
      expect(endRange.first, const TimeOfDay(hour: 9, minute: 1));
      expect(endRange.last, isNull);

      // 起点按终点：最晚 = 终点 − 1 分钟。
      final startRange = ledgerClockRangeFor(
        startedAt: null,
        endedAt: at(31, 10, 0),
        isStart: true,
        entryDate: date,
      );
      expect(startRange.first, isNull);
      expect(startRange.last, const TimeOfDay(hour: 9, minute: 59));

      // 跨日不按时刻约束（跨日睡眠仍是正区间）。
      expect(
        ledgerClockRangeFor(
          startedAt: at(30, 23, 40),
          endedAt: at(31, 7, 20),
          isStart: false,
          entryDate: date,
        ),
        (first: null, last: null),
      );

      // 另一端无值：不约束。
      expect(
        ledgerClockRangeFor(
          startedAt: null,
          endedAt: null,
          isStart: false,
          entryDate: date,
        ),
        (first: null, last: null),
      );

      // 当日没有合法分钟：退回不约束，仍由提交校验兜底。
      expect(
        ledgerClockRangeFor(
          startedAt: at(31, 23, 59),
          endedAt: null,
          isStart: false,
          entryDate: date,
        ),
        (first: null, last: null),
      );
      expect(
        ledgerClockRangeFor(
          startedAt: null,
          endedAt: at(31, 0, 0),
          isStart: true,
          entryDate: date,
        ),
        (first: null, last: null),
      );

      // 无值端点按入口日期判断是否同日。
      expect(
        ledgerClockRangeFor(
          startedAt: at(30, 9, 0),
          endedAt: null,
          isStart: false,
          entryDate: date,
        ),
        (first: null, last: null),
      );
    },
  );

  testWidgets('end picker range blocks times before the start', (t) async {
    int? result;
    await t.pumpWidget(
      MaterialApp(
        theme: homeTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showRecordingTimePicker(
                  context,
                  value: null,
                  date: date,
                  first: const TimeOfDay(hour: 9, minute: 1),
                );
              },
              child: const Text('时间'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('时间'));
    await t.pumpAndSettle();
    var wheels = t
        .widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView))
        .toList();
    // 起点 09:00 的当天：小时只保留 09–23，00–08 不可选。
    expect(wheels[0].childDelegate.estimatedChildCount, 15);
    (wheels[0].controller! as FixedExtentScrollController).jumpToItem(0);
    await t.pumpAndSettle();
    wheels = t
        .widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView))
        .toList();
    // 09 时内分钟从 01 起：09:00 不可选（严格正区间）。
    expect(wheels[1].childDelegate.estimatedChildCount, 59);
    (wheels[1].controller! as FixedExtentScrollController).jumpToItem(0);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('time-picker-confirm')));
    await t.pumpAndSettle();
    expect(result, at(31, 9, 1));
  });

  testWidgets('start picker range blocks times after the end', (t) async {
    int? result;
    await t.pumpWidget(
      MaterialApp(
        theme: homeTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showRecordingTimePicker(
                  context,
                  value: null,
                  date: date,
                  last: const TimeOfDay(hour: 10, minute: 59),
                );
              },
              child: const Text('时间'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('时间'));
    await t.pumpAndSettle();
    var wheels = t
        .widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView))
        .toList();
    // 终点 11:00 的当天：小时只保留 00–10，11–23 不可选。
    expect(wheels[0].childDelegate.estimatedChildCount, 11);
    (wheels[0].controller! as FixedExtentScrollController).jumpToItem(10);
    await t.pumpAndSettle();
    wheels = t
        .widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView))
        .toList();
    expect(wheels[1].childDelegate.estimatedChildCount, 60);
    (wheels[1].controller! as FixedExtentScrollController).jumpToItem(59);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('time-picker-confirm')));
    await t.pumpAndSettle();
    expect(result, at(31, 10, 59));
  });

  testWidgets('wheel center selection is highlighted', (t) async {
    await t.pumpWidget(app(value: at(31, 14, 0), onPick: (_) {}));
    await t.tap(find.text('时间'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('time-picker-hour-band')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('time-picker-minute-band')),
      findsOneWidget,
    );
    final colors = Theme.of(t.element(find.text('选择时分'))).colorScheme;
    final hourWheel = find.byKey(const ValueKey('time-picker-hour'));
    final selected = t.widget<Text>(
      find.descendant(of: hourWheel, matching: find.text('14')),
    );
    expect(selected.style?.color, colors.primary);
    expect(selected.style?.fontWeight, FontWeight.w600);
    final other = t.widget<Text>(
      find.descendant(of: hourWheel, matching: find.text('13')),
    );
    expect(other.style?.color, colors.onSurface);
  });

  for (final size in [const Size(320, 640), const Size(360, 800)]) {
    testWidgets('pickers fit $size with enlarged text', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          theme: homeTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => showRecordingTimePicker(
                      context,
                      value: at(31, 14, 0),
                      date: date,
                    ),
                    child: const Text('时间'),
                  ),
                  TextButton(
                    onPressed: () => showRecordingDatePicker(
                      context,
                      value: at(31, 14, 0),
                      date: date,
                    ),
                    child: const Text('日期'),
                  ),
                  TextButton(
                    onPressed: () => showRecordingDurationPicker(
                      context,
                      startedAt: at(31, 14, 0),
                      endedAt: at(31, 15, 0),
                    ),
                    child: const Text('时长'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('时间'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(const ValueKey('time-picker-confirm')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.tap(find.text('日期'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(const ValueKey('date-picker-confirm')));
      await t.pumpAndSettle();
      await t.tap(find.text('时长'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(const ValueKey('duration-picker-confirm')));
      await t.pumpAndSettle();
    });
  }

  testWidgets('picker capture: highlight, range and duration', (t) async {
    final captureDir = Platform.environment['PICKER_CAPTURE_DIR'];
    if (captureDir != null) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader('NotoSerifSC')
            ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-Regular.otf'))
            ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-SemiBold.otf')))
          .load();
    }
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(390, 800);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final themes = <(String, ThemeData)>[
      ('warm', homeTheme),
      (
        'm3',
        buildAppTheme(
          scheme: ThemeScheme.defaultM3,
          brightness: Brightness.light,
          fontChoice: AppFontChoice.system,
        ),
      ),
    ];
    for (final (name, theme) in themes) {
      await t.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: (context, child) =>
              RepaintBoundary(key: captureKey, child: child!),
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => showRecordingTimePicker(
                      context,
                      value: at(31, 14, 0),
                      date: date,
                      first: const TimeOfDay(hour: 9, minute: 1),
                    ),
                    child: const Text('受限时间'),
                  ),
                  TextButton(
                    onPressed: () => showRecordingDurationPicker(
                      context,
                      startedAt: at(31, 14, 0),
                      endedAt: at(31, 15, 0),
                    ),
                    child: const Text('时长'),
                  ),
                  TextButton(
                    onPressed: () => showRecordingDatePicker(
                      context,
                      value: at(31, 14, 0),
                      date: date,
                    ),
                    child: const Text('日期'),
                  ),
                  TextButton(
                    onPressed: () => showDayLedgerDateDialog(
                      context,
                      CivilDate(year: 2026, month: 12, day: 31),
                      onToday: () {},
                      modeDescription: '跟随今天',
                    ),
                    child: const Text('账本日期'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('受限时间'));
      await t.pumpAndSettle();
      await captureShot(t, 'time-picker-range-$name');
      await t.tap(find.text('取消'));
      await t.pumpAndSettle();
      await t.tap(find.text('时长'));
      await t.pumpAndSettle();
      await captureShot(t, 'duration-picker-$name');
      await t.tap(find.text('取消'));
      await t.pumpAndSettle();
      await t.tap(find.text('日期'));
      await t.pumpAndSettle();
      await captureShot(t, 'date-picker-$name');
      await t.tap(find.text('取消'));
      await t.pumpAndSettle();
      await t.tap(find.text('账本日期'));
      await t.pumpAndSettle();
      await captureShot(t, 'ledger-date-dialog-$name');
      await t.tap(find.text('取消'));
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox.shrink());
    }
    expect(t.takeException(), isNull);
  });
}
