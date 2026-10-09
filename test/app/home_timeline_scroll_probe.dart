// 首页时间轴滑动专项探针（非常规回归；手动运行）：
//   flutter test -r expanded test/app/home_timeline_scroll_probe.dart
//
// 聚焦「纵向阅读手势 → 顶部收起 → 日期横线过顶切日 → 反向回展 →
// 惯性收束 → 触顶装载更早窗口」这条链路，逐帧记录调试构建下测试线程
// 的墙钟耗时，并按阶段（未收起 / 收起中 / 紧凑 / 切日后 / 松手后）拆分。
// widget 测试为调试构建、无 GPU，数字只作同机相对比较；帧按 60Hz
// （16ms/帧）推进，阶段帧数≈真机动画时长。
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/day_ledger.dart';
import 'package:time_pet_ledger/app/theme/home_theme.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_shell.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_timeline_tab.dart';

import '../support/home_feed.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

final oct1 = CivilDate(year: 2026, month: 10, day: 1);
final oct2 = CivilDate(year: 2026, month: 10, day: 2);

int at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 10, day, hour, minute).millisecondsSinceEpoch;

void main() {
  testWidgets('home timeline scroll probe', (tester) async {
    final db = await _openLedger(tester);
    final shell = await _mountHome(tester, db);
    final timeline = find.byType(HomeTimelineTab).last;
    final scroll = tester
        .state<ScrollableState>(
          find
              .descendant(of: timeline, matching: find.byType(Scrollable))
              .first,
        )
        .position;
    final startTitle = homeDateTitle(tester);
    // ignore: avoid_print
    print(
      'SCROLL 起点=$startTitle px=${scroll.pixels.toStringAsFixed(0)} '
      '窗口最早=${_hasDivider('2026-9-19')}',
    );

    // —— S0 静置基线 ——
    final base = _Run('S0 静置基线（不触摸）');
    for (var i = 0; i < 24; i++) {
      await _pump(base, tester, shell, scroll, 'idle');
    }
    _report(base);

    // —— S1 慢速下拖（阅读更早）：收起 → 跨到 10/1 ——
    Future<_Run> slowDragToEarlier(String label) async {
      final run = _Run(label);
      final runStartTitle = homeDateTitle(tester);
      final gesture = await tester.startGesture(tester.getCenter(timeline));
      var switchedAt = -1;
      for (var i = 0; i < 420; i++) {
        await gesture.moveBy(const Offset(0, 16));
        await _pump(run, tester, shell, scroll, 'step=$i');
        final progress = shell.reading.progress;
        if (!run.has('收起开始') && progress > 0) run.mark('收起开始');
        if (!run.has('收起完成') && progress >= 1) run.mark('收起完成');
        if (!run.has('切到 10/1') && homeDateTitle(tester) != runStartTitle) {
          run.mark('切到 10/1');
          switchedAt = run.frames.length - 1;
        }
        if (!run.has('sticky 出现') &&
            find
                .byKey(const ValueKey('home-sticky-day'))
                .evaluate()
                .isNotEmpty) {
          run.mark('sticky 出现');
        }
        if (switchedAt >= 0 && run.frames.length - 1 - switchedAt >= 20) break;
      }
      await gesture.up();
      await _settle(run, tester, shell, scroll, '松手后');
      return run;
    }

    void reportSlowDrag(_Run run) {
      _report(run);
      _phase(run, '拖拽未收起(p=0)', (f) => f.progress == 0);
      _phase(run, '收起中(0<p<1)', (f) => f.progress > 0 && f.progress < 1);
      _phase(
        run,
        '紧凑保持(p=1, 未跨日)',
        (f) => f.progress == 1 && f.date == startTitle,
      );
      _phase(
        run,
        '紧凑已跨日(p=1, 10/1)',
        (f) => f.progress == 1 && f.date != startTitle,
      );
      _phase(run, '松手后', (f) => f.note.startsWith('松手后'));
    }

    reportSlowDrag(await slowDragToEarlier('S1 慢速下拖 16px/帧：收起→切到 10/1（冷）'));
    // 回到今天重置，再测一轮热态，排除首轮 JIT。
    await shell.openDate(oct2);
    await settleNative(tester);
    reportSlowDrag(await slowDragToEarlier('S1w 慢速下拖复测：收起→切到 10/1（热）'));

    // —— S2 反向指上拖动：10/2 横线过顶 → 回展并切回今天 ——
    if (homeDateTitle(tester) == startTitle) {
      // ignore: avoid_print
      print('SCROLL S2 跳过：S1 未完成跨日');
    } else {
      final divider = dayDivider(oct2).last;
      final timelineTop = tester.getTopLeft(timeline).dy;
      scroll.jumpTo(
        scroll.pixels + tester.getTopLeft(divider).dy - timelineTop - 30,
      );
      await settleNative(tester);
      final s2 = _Run('S2 指上拖动：10/2 横线过顶→回展+切回');
      final g2 = await tester.startGesture(tester.getCenter(timeline));
      for (var i = 0; i < 80; i++) {
        await g2.moveBy(const Offset(0, -20));
        await _pump(s2, tester, shell, scroll, 'step=$i');
        final progress = shell.reading.progress;
        if (!s2.has('切回 10/2') && homeDateTitle(tester) == startTitle) {
          s2.mark('切回 10/2');
        }
        if (!s2.has('回展开始') && progress < 1) s2.mark('回展开始');
        if (s2.has('回展开始') && progress == 0) {
          s2.mark('回展完成');
          break;
        }
      }
      await g2.up();
      await _settle(s2, tester, shell, scroll, '松手后');
      _report(s2);
      _phase(s2, '紧凑(p=1)', (f) => f.progress == 1);
      _phase(s2, '回展中(0<p<1)', (f) => f.progress > 0 && f.progress < 1);
      _phase(s2, '已回展(p=0)', (f) => f.progress == 0);
      _phase(s2, '松手后', (f) => f.note.startsWith('松手后'));
    }

    // —— S2b 中途松手：从收起途中连续收束到紧凑 ——
    final s2b = _Run('S2b 中途松手（拖 120px，收起途中松手→紧凑）');
    final g2b = await tester.startGesture(tester.getCenter(timeline));
    for (var i = 0; i < 8; i++) {
      await g2b.moveBy(const Offset(0, 15));
      await _pump(s2b, tester, shell, scroll, 'step=$i');
    }
    s2b.mark('松手前');
    await g2b.up();
    await _settle(s2b, tester, shell, scroll, '松手后');
    _report(s2b);
    _phase(s2b, '松手前拖拽', (f) => f.note.startsWith('step='));
    _phase(s2b, '松手后收束', (f) => f.note.startsWith('松手后'));

    // —— S3 快速下拖惯性：动量中收起 / 跨日 / 收束 ——
    final s3 = _Run('S3 快速下拖惯性（约 460px 起手）');
    final g3 = await tester.startGesture(tester.getCenter(timeline));
    for (final dy in [30, 30, 40, 50, 60, 70, 80, 90]) {
      await g3.moveBy(Offset(0, dy.toDouble()));
      await _pump(s3, tester, shell, scroll, 'fling-move');
    }
    await g3.up();
    await _settle(s3, tester, shell, scroll, '松手后');
    _report(s3);
    final s3Start = s3.frames.first.date;
    final s3Switch = s3.frames.indexWhere((f) => f.date != s3Start);
    if (s3Switch >= 0) {
      // ignore: avoid_print
      print(
        '  marker 惯性中切日 @f$s3Switch: ${s3.frames[s3Switch].us}µs '
        '(p=${s3.frames[s3Switch].progress.toStringAsFixed(2)} '
        'px=${s3.frames[s3Switch].pixels.toStringAsFixed(0)})',
      );
    }

    // —— S4 触顶装载更早窗口（jumpTo(0) 程序触发） ——
    final s4 = _Run('S4 触顶装载更早窗口（jumpTo(0) 程序触发）');
    scroll.jumpTo(0);
    for (var i = 0; i < 400; i++) {
      await _pump(s4, tester, shell, scroll, 'load');
      if (_hasDivider('2026-9-12')) {
        s4.mark('9/12 出现');
        break;
      }
    }
    await _settle(s4, tester, shell, scroll, '松手后');
    _report(s4);
    _phase(s4, '装载后静置', (f) => f.note.startsWith('松手后'));

    // —— S4w 再次触顶装载（热态路径复测） ——
    final s4w = _Run('S4w 再次触顶装载（热态复测）');
    scroll.jumpTo(0);
    for (var i = 0; i < 400; i++) {
      await _pump(s4w, tester, shell, scroll, 'load');
      if (_hasDivider('2026-9-5')) {
        s4w.mark('9/5 出现');
        break;
      }
    }
    await _settle(s4w, tester, shell, scroll, '松手后');
    _report(s4w);
  }, timeout: const Timeout(Duration(minutes: 15)));
}

Future<void> _pump(
  _Run run,
  WidgetTester tester,
  HomeShellState shell,
  ScrollPosition scroll,
  String note,
) async {
  final watch = Stopwatch()..start();
  await tester.pump(const Duration(milliseconds: 16));
  watch.stop();
  run.frames.add(
    _F(
      watch.elapsedMicroseconds,
      note,
      shell.reading.progress,
      homeDateTitle(tester),
      scroll.pixels,
    ),
  );
}

Future<void> _settle(
  _Run run,
  WidgetTester tester,
  HomeShellState shell,
  ScrollPosition scroll,
  String note,
) async {
  for (var i = 0; i < 900; i++) {
    if (!tester.binding.hasScheduledFrame) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1)),
      );
      if (!tester.binding.hasScheduledFrame) break;
    }
    await _pump(run, tester, shell, scroll, '$note#f$i');
  }
}

bool _hasDivider(String suffix) =>
    find.byKey(ValueKey('day-divider-$suffix')).evaluate().isNotEmpty;

void _report(_Run run) {
  final frames = run.frames;
  if (frames.isEmpty) return;
  final totalUs = frames.fold<int>(0, (sum, f) => sum + f.us);
  final sorted = [...frames]..sort((a, b) => b.us.compareTo(a.us));
  // ignore: avoid_print
  print(
    'SCROLL ${run.label} | frames=${frames.length} '
    'total=${(totalUs / 1000).round()}ms avg=${(totalUs / frames.length).round()}µs '
    'max=${sorted.first.us}µs',
  );
  for (final (name, index) in run.markers) {
    final f = frames[index];
    // ignore: avoid_print
    print(
      '  marker $name @f$index: ${f.us}µs '
      '(p=${f.progress.toStringAsFixed(2)} ${f.date} '
      'px=${f.pixels.toStringAsFixed(0)})',
    );
  }
  for (final f in sorted.take(4)) {
    // ignore: avoid_print
    print(
      '  spike: ${f.us}µs @ ${f.note} '
      '(p=${f.progress.toStringAsFixed(2)} ${f.date} '
      'px=${f.pixels.toStringAsFixed(0)})',
    );
  }
}

void _phase(_Run run, String label, bool Function(_F) test) {
  final frames = run.frames.where(test).toList();
  if (frames.isEmpty) return;
  final totalUs = frames.fold<int>(0, (sum, f) => sum + f.us);
  final maxUs = frames.map((f) => f.us).reduce((a, b) => a > b ? a : b);
  // ignore: avoid_print
  print(
    '  phase $label: n=${frames.length} '
    'avg=${(totalUs / frames.length).round()}µs max=$maxUs µs',
  );
}

class _Run {
  _Run(this.label);
  final String label;
  final List<_F> frames = [];
  final List<(String, int)> markers = [];

  bool has(String name) => markers.any((marker) => marker.$1 == name);

  void mark(String name) => markers.add((name, frames.length - 1));
}

class _F {
  _F(this.us, this.note, this.progress, this.date, this.pixels);
  final int us;
  final String note;
  final double progress;
  final String date;
  final double pixels;
}

Future<AppDatabase> _openLedger(WidgetTester tester) async {
  final db = (await tester.runAsync(
    () => AppDatabase.open(NativeDatabase.memory()),
  ))!;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(db.close);
  });
  final repo = DriftLedgerRepository(db);
  await tester.runAsync(() async {
    // 跨日睡眠：9 月 30 日 23:40 → 10 月 1 日 07:20。
    await repo.createSleepSession(
      id: id(1),
      startedAt: DateTime(2026, 9, 30, 23, 40).millisecondsSinceEpoch,
      endedAt: at(1, 7, 20),
      startPrecision: TimePrecision.approximate,
      endPrecision: TimePrecision.exact,
      type: SleepType.mainSleep,
      now: 1,
    );
    await repo.createTimeBlock(
      id: id(2),
      startedAt: at(1, 9),
      endedAt: at(1, 10),
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.exact,
      knowledgeState: BlockKnowledgeState.known,
      title: '十月一日活动',
      now: 1,
    );
    await repo.createTimeBlock(
      id: id(3),
      startedAt: at(2, 8),
      endedAt: at(2, 9),
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.exact,
      knowledgeState: BlockKnowledgeState.known,
      title: '十月二日活动',
      now: 1,
    );
  });
  return db;
}

Future<HomeShellState> _mountHome(WidgetTester tester, AppDatabase db) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: homeTheme,
      home: HomeShell(
        ledgerLoader: createDayLedgerLoader(db),
        now: () => at(3, 9),
        dateOfInstant: deviceDateOfInstant,
        initialDate: oct2,
        busy: false,
        onOpenSummary: (_) {},
        onOpenReview: (_) {},
        onRecordActivity: () {},
        onRecordSleep: () {},
      ),
    ),
  );
  await settleNative(tester);
  return tester.state<HomeShellState>(find.byType(HomeShell));
}
