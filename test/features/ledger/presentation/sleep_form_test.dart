import '../../../support/date_time_pickers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_form.dart';

import 'sleep_form_controller_test.dart' show FormSleepStore, model;

Future<void> tapText(WidgetTester tester, String label) async {
  if (['返回', '重新填写', '删除睡眠'].contains(label) &&
      find.text(label).evaluate().isEmpty) {
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
  }
  final target = find.text(label);
  await tester.scrollUntilVisible(
    target,
    ['主睡眠', '小睡', '入睡准确', '入睡大约', '醒来准确', '醒来大约', '记录睡眠'].contains(label)
        ? -150
        : 150,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String value) async {
  if (key != 'sleep-note') {
    await chooseEndpoint(tester, key, value);
    return;
  }
  await showField(tester, key);
  await tester.enterText(find.byKey(ValueKey(key)), value);
  await tester.pumpAndSettle();
}

Future<void> showField(WidgetTester tester, String key) async {
  if (key == 'sleep-note' && find.byKey(ValueKey(key)).evaluate().isEmpty) {
    await tester.tap(find.byKey(const ValueKey('sleep-note-toggle')));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(
    find.byKey(ValueKey(key == 'sleep-note' ? key : '$key-time')),
  );
  await tester.pumpAndSettle();
}

Future<void> open(WidgetTester tester, FormSleepStore store) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () {
              final c = model(store);
              Navigator.of(context)
                  .push<void>(
                    MaterialPageRoute(builder: (_) => SleepForm(controller: c)),
                  )
                  .then((_) => c.dispose());
            },
            child: const Text('打开睡眠'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开睡眠'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'cross-day minute input, independent precision, new entry defaults to main sleep',
    (tester) async {
      final store = FormSleepStore();
      await open(tester, store);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '主睡眠'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '小睡'))
            .selected,
        isFalse,
      );
      for (final label in ['入睡准确', '入睡大约', '醒来准确', '醒来大约']) {
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
              .selected,
          isFalse,
        );
      }
      expect(find.textContaining('Goal'), findsNothing);
      await enter(tester, 'sleep-start', '2026-09-28 23:50');
      await enter(tester, 'sleep-end', '2026-09-29 07:40');
      await tapText(tester, '入睡大约');
      await tapText(tester, '醒来准确');
      expect(store.value!.type, SleepType.mainSleep);
      expect(store.value!.startPrecision, TimePrecision.approximate);
      expect(store.value!.endPrecision, TimePrecision.exact);
      await enter(tester, 'sleep-start', '2026-09-28 23:40');
      await tapText(tester, '小睡');
      expect(store.value!.startPrecision, TimePrecision.approximate);
      expect(store.value!.endPrecision, TimePrecision.exact);
      expect(store.value!.type, SleepType.nap);
      await tapText(tester, '返回');
      expect(find.text('打开睡眠'), findsOneWidget);
      await tester.tap(find.text('打开睡眠'));
      await tester.pumpAndSettle();
      final reopened = tester
          .widget<SleepForm>(find.byType(SleepForm))
          .controller;
      await reopened.resumePendingInput();
      await tester.pumpAndSettle();
      await showField(tester, 'sleep-start');
      // 新入口的时间端点始终按当前建议重算，只恢复类型与精度。
      expect(reopened.startedAtInput, '');
      expect(reopened.type, SleepType.nap);
      // 时间端点重算后，端点精度不再沿用旧输入。
      expect(reopened.startPrecision, isNull);
      expect(reopened.endPrecision, isNull);
      await tapText(tester, '重新填写');
      await tapText(tester, '重新填写');
      expect(store.value, isNull);
      await showField(tester, 'sleep-start');
      expect(reopened.startedAtInput, '');
    },
  );

  testWidgets(
    'missing, zero and reversed intervals stay editable; historical/future accepted',
    (tester) async {
      final store = FormSleepStore();
      await open(tester, store);
      await enter(tester, 'sleep-start', '2026-09-29 07:40');
      expect(store.value!.endedAt, isNull);
      await enter(tester, 'sleep-end', '2026-09-29 07:40');
      expect(store.value!.endedAt, store.value!.startedAt);
      await enter(tester, 'sleep-end', '2026-09-29 06:00');
      expect(store.value!.endedAt!, lessThan(store.value!.startedAt!));
      await enter(tester, 'sleep-start', '1900-01-01 00:00');
      await enter(tester, 'sleep-end', '2200-01-01 00:00');
      expect(find.text('醒来时间必须晚于入睡时间。'), findsNothing);
      // 兼容旧草稿中的未完成文本；新选择器自身不会产生不合法日期。
      tester
          .widget<SleepForm>(find.byType(SleepForm))
          .controller
          .setEndedAtInput('2026-');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(store.value!.endedAtInput, '2026-');
      expect(store.value!.endedAt, isNull);
    },
  );

  testWidgets(
    'autosave failure blocks leave; clear failure retains visible input',
    (tester) async {
      final store = FormSleepStore()..failSave = true;
      await open(tester, store);
      await enter(tester, 'sleep-start', '2026-09-28 23:50');
      await tapText(tester, '返回');
      await tester.scrollUntilVisible(
        find.text('暂时无法保留本次填写，输入仍在此页，请重试。'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('暂时无法保留本次填写，输入仍在此页，请重试。'), findsOneWidget);
      await showField(tester, 'sleep-start');
      expect(find.byKey(const ValueKey('sleep-start-time')), findsOneWidget);
      store.failSave = false;
      await tapText(tester, '重试保留本次填写');
      store.failClear = true;
      await tapText(tester, '重新填写');
      await tapText(tester, '重新填写');
      await tester.scrollUntilVisible(
        find.text('暂时无法清空本次填写，请重试。'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('暂时无法清空本次填写，请重试。'), findsOneWidget);
      expect(store.value!.startedAtInput, '2026-09-28 23:50');
      store.failClear = false;
      await tapText(tester, '重新填写');
      await tapText(tester, '重新填写');
      expect(store.value, isNull);
      expect(find.byType(SleepForm), findsOneWidget);
    },
  );

  testWidgets(
    'read failure presents retry without leaking diagnostics or enabling input',
    (tester) async {
      final store = FormSleepStore()..failRead = true;
      await open(tester, store);
      expect(find.text('无法读取未完成睡眠输入或时间建议，请重试。'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('private'), findsNothing);
      store.failRead = false;
      await tester.tap(find.text('重试读取'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sleep-start-date')), findsOneWidget);
    },
  );
}
