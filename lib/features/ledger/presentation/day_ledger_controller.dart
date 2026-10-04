import 'package:flutter/foundation.dart';

import '../../../core/time/civil_date.dart';
import '../application/day_ledger_loader.dart';
import '../application/recording_ledger_loader.dart';
import '../domain/projection/day_ledger_view.dart';

enum DayLedgerStatus { idle, loading, empty, ready, failed }

/// null 选择表示跟随设备的今天；明确选择的历史日期不在午夜偷偷跳日。
final class DayLedgerController extends ChangeNotifier {
  DayLedgerController({
    required this.loader,
    required this.now,
    required this.dateOfInstant,
    this.selectedDate,
  });

  final DayLedgerLoader loader;
  final int Function() now;
  final CivilDate Function(int) dateOfInstant;
  CivilDate? selectedDate;
  CivilDate? date;
  DayLedgerView? view;

  /// 与成功投影同一次请求的完整自然日边界；仅供头部展示，不持久化。
  RecordingDateContext? dateContext;
  DayLedgerStatus status = DayLedgerStatus.idle;
  int _request = 0;
  bool _disposed = false;

  Future<void> select(CivilDate? selectedDate) {
    this.selectedDate = selectedDate;
    return refresh();
  }

  void invalidate() {
    ++_request;
    view = null;
    dateContext = null;
    status = DayLedgerStatus.idle;
    notifyListeners();
  }

  Future<void> refresh() async {
    final request = ++_request;
    view = null;
    dateContext = null;
    status = DayLedgerStatus.loading;
    notifyListeners();
    try {
      final instant = now();
      final selected = selectedDate ?? dateOfInstant(instant);
      date = selected;
      late RecordingDateContext loadedContext;
      // 在原加载流程中捕获一次解析的上下文，避免 I/O 后再次解析时区
      // 或 now，导致全天比例与已有投影使用不同的日边界。
      final result = await DayLedgerLoader(
        resolveDate: loader.resolveDate,
        readFacts: (context) {
          loadedContext = context;
          return loader.readFacts(context);
        },
      ).load(date: selected, now: instant);
      if (_disposed || request != _request) return;
      view = result;
      dateContext = loadedContext;
      // 空窗口也可能有完整睡眠摘要，不能仅靠 Gap 或数值零判空。
      status =
          result.segments.isEmpty &&
              result.sleepSummary.mainSleep.records.isEmpty &&
              result.sleepSummary.nap.records.isEmpty
          ? DayLedgerStatus.empty
          : DayLedgerStatus.ready;
    } catch (_) {
      if (_disposed || request != _request) return;
      status = DayLedgerStatus.failed;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_request;
    super.dispose();
  }
}
