import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/home_theme.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_time_picker.dart';

final date = CivilDate(year: 2026, month: 12, day: 31);
int at(int day, int hour, int minute) =>
    DateTime(2026, 12, day, hour, minute).millisecondsSinceEpoch;
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
}
