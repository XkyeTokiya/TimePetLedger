import 'package:flutter/foundation.dart';

import '../../../../core/time/civil_date.dart';
import '../../application/day_ledger_loader.dart';
import '../../application/recording_ledger_loader.dart';
import '../../domain/projection/day_ledger_view.dart';
import '../day_ledger_date_dialog.dart' show adjacentLedgerDate;

enum LedgerFeedStatus { idle, loading, ready, failed }

/// 一个已提交窗口的只读渲染快照；退出动效期间仍保留当时的事实投影。
final class LedgerFeedFrame {
  LedgerFeedFrame({
    required this.version,
    required this.endDate,
    required this.focusDate,
    required this.status,
    required List<CivilDate> dates,
    required Map<CivilDate, DayLedgerView> views,
  }) : dates = List.unmodifiable(dates),
       _views = Map.unmodifiable(views);

  final int version;
  final CivilDate endDate;
  final CivilDate focusDate;
  final LedgerFeedStatus status;
  final List<CivilDate> dates;
  final Map<CivilDate, DayLedgerView> _views;

  DayLedgerView? viewFor(CivilDate date) => _views[date];
}

/// 首页跨日期连续时间轴的只读数据窗口。
///
/// 每一天仍由既有 [DayLedgerLoader] 做单日投影，窗口只决定一次装载哪些
/// 自然日：不在午夜拆分事实、不重复统计，也不写入事实、偏好或草稿。
/// [focusDate] 是“当前浏览日期”，驱动顶部日期与当日覆盖统计；跨日滚动、
/// 按钮切日和日历跳转都通过同一套方法更新它。
final class LedgerFeedController extends ChangeNotifier {
  LedgerFeedController({
    required this.loader,
    required this.now,
    required this.dateOfInstant,
    required CivilDate initialDate,
    this.windowDays = 14,
    this.earlierStep = 7,
  }) : _end = initialDate,
       _start = _startFor(initialDate, windowDays),
       _focus = initialDate;

  /// 计算以 [end] 为最后一天、共 [length] 天的窗口起点。
  static CivilDate _startFor(CivilDate end, int length) {
    var start = end;
    for (var i = 1; i < length; i++) {
      start = adjacentLedgerDate(start, -1);
    }
    return start;
  }

  final DayLedgerLoader loader;
  final int Function() now;
  final CivilDate Function(int) dateOfInstant;

  /// 一个完整窗口装载的自然日数量。
  final int windowDays;

  /// 滚动到最早一天后继续向前扩展的自然日数量。
  final int earlierStep;

  CivilDate _start;
  CivilDate _end;
  CivilDate _focus;
  final Map<CivilDate, DayLedgerView> _views = {};
  final Map<CivilDate, RecordingDateContext> _contexts = {};
  LedgerFeedStatus _status = LedgerFeedStatus.idle;
  int _request = 0;
  int _dataVersion = 0;
  bool _disposed = false;
  bool _extending = false;
  bool _loading = false;
  bool _refreshFailed = false;
  CivilDate? _futureNavigationLimit;
  CivilDate? _requestedDate;
  CivilDate? _revealRequest;
  bool _requestedResetReading = true;
  bool revealResetsReading = true;

  /// 显式跳转（日历 / 按钮 / 返回今天）要求时间轴定位到该日。
  CivilDate? takeRevealRequest() {
    final request = _revealRequest;
    _revealRequest = null;
    return request;
  }

  /// 每次成功装载后递增；视图用它决定何时按锚点恢复阅读位置。
  int get dataVersion => _dataVersion;

  CivilDate get startDate => _start;
  CivilDate get endDate => _end;
  CivilDate get focusDate => _focus;
  CivilDate? get futureNavigationLimit => _futureNavigationLimit;

  /// 连续切日基于尚在装载的目标；读取失败后重新以可见日期导航。
  CivilDate get navigationDate => _loading ? _requestedDate ?? _focus : _focus;

  /// 普通浏览默认以今天为上限；成功手选未来日后，该日在
  /// 返回今天前作为本次会话的临时上限（Q-044）。
  CivilDate navigationLimit(CivilDate today) => _futureNavigationLimit ?? today;

  bool canNavigateTo(CivilDate date, CivilDate today) =>
      !_isBefore(navigationLimit(today), date);

  /// 已装载内容存在时保持 ready，刷新失败不清空正在阅读的时间轴。
  LedgerFeedStatus get status =>
      _views.isEmpty ? _status : LedgerFeedStatus.ready;

  /// 一次刷新失败但保留了既有内容时为 true，供界面提示重试。
  bool get refreshFailed => _refreshFailed;

  DayLedgerView? get focusView => _views[_focus];
  RecordingDateContext? get focusContext => _contexts[_focus];
  DayLedgerView? viewFor(CivilDate date) => _views[date];

  LedgerFeedFrame captureFrame() => LedgerFeedFrame(
    version: _dataVersion,
    endDate: _end,
    focusDate: _focus,
    status: status,
    dates: loadedDates,
    views: _views,
  );

  bool contains(CivilDate date) =>
      !_isBefore(date, _start) && !_isBefore(_end, date);

  /// 窗口内全部日期，从最早到最新。
  List<CivilDate> get loadedDates {
    final dates = <CivilDate>[];
    for (
      var date = _start;
      !_isBefore(_end, date);
      date = adjacentLedgerDate(date, 1)
    ) {
      dates.add(date);
    }
    return dates;
  }

  /// 日历跳转 / 按钮切日 / 返回今天：目标日成为窗口最新一天。
  Future<bool> showDate(CivilDate date, {bool resetReading = true}) {
    if (_disposed) return Future.value(false);
    _requestedDate = date;
    _requestedResetReading = resetReading;
    return _load(
      start: _startFor(date, windowDays),
      end: date,
      revealDate: date,
      resetReading: resetReading,
    );
  }

  /// 日历主动选日；只有未来日读取成功才建立临时上限。
  Future<bool> showSelectedDate(
    CivilDate date, {
    required CivilDate today,
    bool resetReading = true,
  }) async {
    final loaded = await showDate(date, resetReading: resetReading);
    if (loaded && _isBefore(today, date)) {
      _futureNavigationLimit = date;
      notifyListeners();
    }
    return loaded;
  }

  /// 返回今天成功后才清除手选未来上限；失败保留原状态。
  Future<bool> returnToToday(
    CivilDate today, {
    bool resetReading = true,
  }) async {
    final loaded = await showDate(today, resetReading: resetReading);
    if (loaded && _futureNavigationLimit != null) {
      _futureNavigationLimit = null;
      notifyListeners();
    }
    return loaded;
  }

  /// 编辑记录返回后的数据刷新；保持窗口与当前浏览日期。
  Future<bool> refresh() {
    final requested = _requestedDate;
    return requested == null
        ? _load(start: _start, end: _end)
        : showDate(requested, resetReading: _requestedResetReading);
  }

  /// 向上滚动到窗口最早一天后继续向前装载；不改变浏览日期。
  /// 返回是否真正装载了新的一天；失败或本次未执行时返回 false，
  /// 调用方据此解除重试闩锁（待重试的跳转目标不得阻塞向前装载）。
  Future<bool> extendEarlier() async {
    if (_disposed || _extending || _loading) return false;
    _extending = true;
    final request = ++_request;
    final start = _startFor(_start, earlierStep + 1);
    final end = adjacentLedgerDate(_start, -1);
    try {
      final loaded = await _readRange(start, end);
      if (_disposed || request != _request) return false;
      _views.addAll(loaded.views);
      _contexts.addAll(loaded.contexts);
      _start = start;
      _status = LedgerFeedStatus.ready;
      _refreshFailed = false;
      _dataVersion++;
      notifyListeners();
      return true;
    } catch (_) {
      if (_disposed || request != _request) return false;
      _refreshFailed = true;
      notifyListeners();
      return false;
    } finally {
      _extending = false;
    }
  }

  /// 滚动驱动：浏览日期在窗口内移动，不重新装载。
  void noteFocus(CivilDate date) {
    if (_disposed || date == _focus || !contains(date)) return;
    _focus = date;
    notifyListeners();
  }

  Future<bool> _load({
    required CivilDate start,
    required CivilDate end,
    CivilDate? revealDate,
    bool resetReading = false,
  }) async {
    if (_disposed) return false;
    final request = ++_request;
    _loading = true;
    final firstLoad = _views.isEmpty;
    if (firstLoad) {
      _status = LedgerFeedStatus.loading;
      notifyListeners();
    }
    try {
      final loaded = await _readRange(start, end);
      if (_disposed || request != _request) return false;
      // 日期、窗口与数据一起提交；失败时全部保留已显示的阅读上下文。
      _start = start;
      _end = end;
      if (revealDate != null) {
        _focus = revealDate;
        _revealRequest = revealDate;
        revealResetsReading = resetReading;
      }
      _views
        ..clear()
        ..addAll(loaded.views);
      _contexts
        ..clear()
        ..addAll(loaded.contexts);
      _status = LedgerFeedStatus.ready;
      _refreshFailed = false;
      _requestedDate = null;
      _dataVersion++;
    } catch (_) {
      if (_disposed || request != _request) return false;
      if (firstLoad) {
        _status = LedgerFeedStatus.failed;
      } else {
        _refreshFailed = true;
      }
    }
    _loading = false;
    notifyListeners();
    return !_refreshFailed && _status == LedgerFeedStatus.ready;
  }

  Future<
    ({
      Map<CivilDate, DayLedgerView> views,
      Map<CivilDate, RecordingDateContext> contexts,
    })
  >
  _readRange(CivilDate start, CivilDate end) async {
    final views = <CivilDate, DayLedgerView>{};
    final contexts = <CivilDate, RecordingDateContext>{};
    // 整个窗口共用一次 now：今天只计到同一时刻，未来部分不计 Gap（Q-009）。
    final instant = now();
    for (
      var date = start;
      !_isBefore(end, date);
      date = adjacentLedgerDate(date, 1)
    ) {
      late RecordingDateContext context;
      final view = await DayLedgerLoader(
        resolveDate: loader.resolveDate,
        readFacts: (loaded) {
          context = loaded;
          return loader.readFacts(loaded);
        },
      ).load(date: date, now: instant);
      views[date] = view;
      contexts[date] = context;
    }
    return (views: views, contexts: contexts);
  }

  static bool _isBefore(CivilDate a, CivilDate b) {
    if (a.year != b.year) return a.year < b.year;
    if (a.month != b.month) return a.month < b.month;
    return a.day < b.day;
  }

  @override
  void dispose() {
    _disposed = true;
    ++_request;
    super.dispose();
  }
}
