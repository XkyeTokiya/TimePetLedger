import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/app_theme.dart';
import 'package:time_pet_ledger/app/theme/home_theme.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/day_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_shell.dart';
import 'package:time_pet_ledger/features/settings/domain/app_preferences.dart';

import '../features/ledger/presentation/day_ledger_overview_layout_test.dart'
    show mixedFacts;

const captureKey = ValueKey('r1-home-capture');
final sampleDate = CivilDate(year: 2026, month: 10, day: 2);

/// R1 evidence: the rebuilt home shell rendered with the bundled serif and the
/// real projection, so screenshots can be compared against home-reference.png.
void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('NotoSerifSC')
          ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-Regular.otf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-SemiBold.otf')))
        .load();
  });

  Future<void> capture(WidgetTester t, String name) async {
    final dir = Platform.environment['R1_CAPTURE_DIR'];
    if (dir == null) return;
    await t.runAsync(() async {
      final image = await t
          .renderObject<RenderRepaintBoundary>(find.byKey(captureKey))
          .toImage(pixelRatio: 2);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await Directory(dir).create(recursive: true);
      await File('$dir/$name.png').writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> mount(
    WidgetTester t,
    Size size,
    DayLedgerLoader loader, {
    VoidCallback? onGoals,
    VoidCallback? onSettings,
    VoidCallback? onSummary,
    VoidCallback? onReview,
    CivilDate? initialDate,
    HomeQuickPanelSide quickPanelSide = HomeQuickPanelSide.left,
    ThemeData? theme,
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = size;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: theme ?? homeTheme,
        builder: (context, child) =>
            RepaintBoundary(key: captureKey, child: child!),
        home: HomeShell(
          ledgerLoader: loader,
          now: () => DateTime(2026, 10, 3, 9).millisecondsSinceEpoch,
          dateOfInstant: deviceDateOfInstant,
          initialDate: initialDate ?? sampleDate,
          busy: false,
          onGoals: onGoals ?? () {},
          onSettings: onSettings ?? () {},
          onOpenSummary: (_) => (onSummary ?? () {})(),
          onOpenReview: (_) => (onReview ?? () {})(),
          onRecordActivity: () {},
          onRecordSleep: () {},
          quickPanelSide: quickPanelSide,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  DayLedgerLoader sampleLoader({bool longText = false}) => DayLedgerLoader(
    resolveDate: resolveDeviceRecordingDate,
    readFacts: (_) async => mixedFacts(longText: longText),
  );

  /// 覆盖数值是数字 / 单位分层的富文本，按 key 读取纯文本。
  String coverageText(WidgetTester t, String label) => t
      .widget<Text>(find.byKey(ValueKey('coverage-$label')))
      .textSpan!
      .toPlainText();

  testWidgets('home feed reference capture at 360 and 320', (t) async {
    for (final width in [360.0, 320.0]) {
      await mount(t, Size(width, 800), sampleLoader());
      expect(t.takeException(), isNull);
      await capture(t, 'home-feed-$width');
      await t.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('top bar opens the quick panel with summary and review', (
    t,
  ) async {
    var summary = 0;
    var review = 0;
    var goals = 0;
    var settings = 0;
    await mount(
      t,
      const Size(390, 800),
      sampleLoader(),
      onSummary: () => summary++,
      onReview: () => review++,
      onGoals: () => goals++,
      onSettings: () => settings++,
    );

    // 首页不再有标签页；右上角入口与时间分布说明均已移除。
    expect(find.byKey(const ValueKey('home-date')), findsNothing);
    expect(find.byKey(const ValueKey('home-distribution')), findsNothing);
    expect(find.byKey(const ValueKey('home-tab-timeline')), findsNothing);

    await t.tap(find.byKey(const ValueKey('home-menu')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-quick-panel')), findsOneWidget);
    expect(find.text('当日概览'), findsOneWidget);
    expect(find.text('当日复盘'), findsOneWidget);
    expect(find.text('我的目标'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    await capture(t, 'home-quick-panel-left');

    await t.tap(find.byKey(const ValueKey('menu-summary')));
    await t.pumpAndSettle();
    expect(summary, 1);
    expect(find.byKey(const ValueKey('home-quick-panel-scrim')), findsNothing);

    await t.tap(find.byKey(const ValueKey('home-menu')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('menu-review')));
    await t.pumpAndSettle();
    expect(review, 1);

    await t.tap(find.byKey(const ValueKey('home-menu')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('menu-goals')));
    await t.pumpAndSettle();
    expect(goals, 1);

    await t.tap(find.byKey(const ValueKey('home-menu')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('menu-settings')));
    await t.pumpAndSettle();
    expect(settings, 1);
  });

  testWidgets('quick panel follows the settings card and row treatment', (
    t,
  ) async {
    await mount(t, const Size(390, 800), sampleLoader());
    await t.tap(find.byKey(const ValueKey('home-menu')));
    await t.pumpAndSettle();
    final panel = find.byKey(const ValueKey('home-quick-panel'));

    // 2026-10-10 用户要求：快捷区样式贴近设置页——分组标题、行说明、
    // 圆形图标与行尾箭头；分组、顺序与入口名称不变。
    expect(
      find.descendant(of: panel, matching: find.text('当日')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: panel, matching: find.text('更多')),
      findsOneWidget,
    );
    for (final subtitle in const [
      '这天的摘要与统计',
      '这天的解释与下一步',
      '回到今天的浏览位置',
      '用于记录时间归属',
      '外观、记录与提醒',
    ]) {
      expect(
        find.descendant(of: panel, matching: find.text(subtitle)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: panel, matching: find.byIcon(Icons.chevron_right)),
      findsNWidgets(5),
    );
    // 浏览日为昨天：第一组含“返回今天”，与顶部入口互为镜像。
    expect(
      find.descendant(of: panel, matching: find.byIcon(Icons.today_outlined)),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('right quick panel mirrors the complete home surface', (t) async {
    await mount(
      t,
      const Size(390, 800),
      sampleLoader(),
      quickPanelSide: HomeQuickPanelSide.right,
    );
    await t.tap(find.byKey(const ValueKey('home-menu')));
    await t.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('home-quick-panel-scrim')),
      findsOneWidget,
    );
    await capture(t, 'home-quick-panel-right');
    expect(t.takeException(), isNull);
  });

  testWidgets('quick panel capture: default M3 and warm paper', (t) async {
    final themes = {
      'm3': buildAppTheme(
        scheme: ThemeScheme.defaultM3,
        brightness: Brightness.light,
        fontChoice: AppFontChoice.system,
      ),
      'warm': homeTheme,
    };
    for (final MapEntry(key: name, value: theme) in themes.entries) {
      for (final side in HomeQuickPanelSide.values) {
        await mount(
          t,
          const Size(390, 800),
          sampleLoader(),
          quickPanelSide: side,
          theme: theme,
        );
        await t.tap(find.byKey(const ValueKey('home-menu')));
        await t.pumpAndSettle();
        await capture(t, 'quick-panel-$name-${side.name}');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      }
    }
  });

  testWidgets('quick panel capture: large text', (t) async {
    for (final scale in [1.5, 2.0]) {
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await mount(t, const Size(320, 800), sampleLoader());
      await t.tap(find.byKey(const ValueKey('home-menu')));
      await t.pumpAndSettle();
      expect(find.text('当日概览'), findsOneWidget);
      await capture(t, 'quick-panel-scale-$scale');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets(
    'unknown reads as a state and intervals use proportional heights',
    (t) async {
      await mount(t, const Size(390, 800), sampleLoader());

      // "想不起来" is the fact; the half-remembered text is residue that belongs
      // in the detail sheet, never in the row heading.
      expect(find.text('想不起来'), findsOneWidget);
      expect(find.text('已交代'), findsWidgets);
      expect(find.text('只记得出门办事'), findsNothing);

      // A gap's 补记 is an inline affordance, not a button: a 48px tap target is
      // what made gap rows twice as tall as the records around them. The whole
      // row is already the tap target.
      expect(find.widgetWithText(TextButton, '补记'), findsNothing);
      expect(find.text('尚未记录'), findsWidgets);
      // Heights follow elapsed time, independent of labels and button minima.
      final breakfast = find
          .ancestor(of: find.text('早餐'), matching: find.byType(InkWell))
          .first;
      expect(t.getSize(breakfast).height, 48); // 40 minutes at 72dp/h.
    },
  );

  testWidgets('home shell survives large text and long content', (t) async {
    for (final scale in [1.5, 2.0]) {
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await mount(t, const Size(320, 800), sampleLoader(longText: true));
      expect(t.takeException(), isNull);
      await capture(t, 'home-feed-scale-$scale');
      await t.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('date header follows the browsing day and offers back-to-today', (
    t,
  ) async {
    // 浏览日为 10 月 2 日（设备今天为 10 月 3 日）。
    await mount(t, const Size(390, 800), sampleLoader());
    expect(find.byKey(const ValueKey('home-date-title')), findsOneWidget);
    expect(find.text('10月2日'), findsWidgets);
    // 返回今天占用日期行宽度时，星期按规范先缩短（读屏仍播报完整星期）。
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').startsWith('周五'),
      ),
      findsWidgets,
    );
    expect(find.byKey(const ValueKey('home-back-to-today')), findsOneWidget);
    // 覆盖统计只属于当前浏览日：睡眠 7h20m + 活动 3h40m = 11 小时已交代。
    expect(coverageText(t, '已交代'), '11 小时');
    expect(coverageText(t, '尚未记录'), '13 小时');

    await t.tap(find.byKey(const ValueKey('home-back-to-today')));
    await t.pumpAndSettle();
    expect(find.text('10月3日'), findsWidgets);
    expect(find.byKey(const ValueKey('home-back-to-today')), findsNothing);
    // 10 月 3 日没有事实：已交代 0 分钟，今天窗口只到 09:00。
    expect(coverageText(t, '已交代'), '0 分钟');
    expect(coverageText(t, '尚未记录'), '9 小时');
    expect(t.takeException(), isNull);
  });

  testWidgets('cross-year expanded date stacks the year above the day', (
    t,
  ) async {
    // 设备今天是 2026-10-03：跨年日期在窄屏放不下整行时改用两行。
    await mount(
      t,
      const Size(320, 800),
      sampleLoader(),
      initialDate: CivilDate(year: 2025, month: 12, day: 31),
    );
    expect(
      t.widget<Text>(find.byKey(const ValueKey('home-date-year'))).data,
      '2025年',
    );
    expect(
      t.widget<Text>(find.byKey(const ValueKey('home-date-title')).last).data,
      '12月31日',
    );
    await capture(t, 'home-cross-year-header-narrow');
    expect(t.takeException(), isNull);

    // 宽屏单行放得下时保持整行。
    await t.pumpWidget(const SizedBox.shrink());
    await mount(
      t,
      const Size(800, 800),
      sampleLoader(),
      initialDate: CivilDate(year: 2025, month: 12, day: 31),
    );
    expect(find.byKey(const ValueKey('home-date-year')), findsNothing);
    expect(
      t.widget<Text>(find.byKey(const ValueKey('home-date-title')).last).data,
      '2025年12月31日',
    );
    await capture(t, 'home-cross-year-header-wide');
    expect(t.takeException(), isNull);
  });
}
