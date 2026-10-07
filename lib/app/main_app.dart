import 'dart:async';

import 'package:flutter/material.dart';

import 'theme/home_theme.dart';
import '../features/ledger/presentation/day_date_selection.dart';
import '../features/ledger/presentation/day_read_scroll.dart';
import '../features/ledger/domain/sleep_session.dart';

import '../features/goals/domain/goal_repository.dart';
import '../features/review/application/review_context_loader.dart';
import '../features/review/application/review_entry_saver.dart';
import '../features/review/domain/review_draft_store.dart';
import '../features/review/presentation/review_context_page.dart';

import '../features/ledger/application/day_ledger_loader.dart';
import '../features/ledger/presentation/day_ledger_controller.dart';
import '../features/ledger/presentation/home/home_shell.dart';
import '../features/ledger/presentation/home/home_suggestion_card.dart';
import '../features/ledger/presentation/home/home_summary_tab.dart';
import '../features/ledger/presentation/home/home_timeline_tab.dart';
import '../features/ledger/domain/projection/ledger_coverage.dart';
import '../features/ledger/domain/projection/ledger_segment.dart';
import '../features/ledger/application/home_suggestion.dart';
import '../features/settings/domain/app_preferences.dart';

import 'time/device_recording_date.dart';
import '../features/ledger/application/sleep_first_open.dart';

import '../core/time/civil_date.dart';
import '../features/ledger/application/recording_entry_saver.dart';
import '../features/ledger/application/recording_entry_editor.dart';
import '../features/ledger/application/recording_ledger_loader.dart';
import '../features/ledger/application/recording_time_suggestion.dart';
import '../features/ledger/application/sleep_ledger_loader.dart';
import '../features/ledger/domain/recording_draft_store.dart';
import '../features/ledger/domain/sleep_draft_store.dart';
import '../features/ledger/presentation/activity/activity_recording_entry.dart';

class MainApp extends StatefulWidget {
  const MainApp({
    super.key,
    required this.ledger,
    required this.drafts,
    required this.now,
    required this.entrySaver,
    required this.entryEditor,
    required this.sleepEntry,
    required this.sleepLedger,
    this.firstSleepOpen,
    this.dayLedger,
    this.reviewContext,
    this.reviewDrafts,
    this.reviewSaver,
    this.goalEntry,
    this.settingsEntry,
    this.goals,
    this.preferences,
  });
  final Widget Function()? goalEntry;
  final Widget Function()? settingsEntry;
  final GoalRepository? goals;

  /// 首页建议区域读取提醒开关与时点（Q-028 / Q-029）；不写入。
  final AppPreferencesStore? preferences;
  final DayLedgerLoader? dayLedger;
  final ReviewContextLoader? reviewContext;
  final ReviewDraftStore? reviewDrafts;
  final ReviewEntrySaver? reviewSaver;
  final RecordingLedgerLoader ledger;
  final SleepLedgerLoader sleepLedger;
  final SleepFirstOpenCoordinator? firstSleepOpen;
  final RecordingDraftStore drafts;
  final DateTime Function() now;
  final RecordingEntrySaver entrySaver;
  final RecordingEntryEditor entryEditor;
  final Widget Function(SleepDraftContext) sleepEntry;
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _dayRoutes = RouteObserver<ModalRoute<void>>();
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Time Pet Ledger',
    theme: homeTheme,
    navigatorObservers: [_dayRoutes],
    home: _RecordingHome(
      goals: widget.goals,
      goalEntry: widget.goalEntry,
      settingsEntry: widget.settingsEntry,
      preferences: widget.preferences,
      dayLedger: widget.dayLedger,
      reviewContext: widget.reviewContext,
      reviewDrafts: widget.reviewDrafts,
      reviewSaver: widget.reviewSaver,
      dayRoutes: _dayRoutes,
      ledger: widget.ledger,
      drafts: widget.drafts,
      now: widget.now,
      entrySaver: widget.entrySaver,
      entryEditor: widget.entryEditor,
      sleepEntry: widget.sleepEntry,
      sleepLedger: widget.sleepLedger,
      firstSleepOpen: widget.firstSleepOpen,
    ),
  );
}

class _RecordingHome extends StatefulWidget {
  const _RecordingHome({
    required this.ledger,
    required this.drafts,
    required this.now,
    required this.entrySaver,
    required this.entryEditor,
    required this.sleepEntry,
    required this.sleepLedger,
    required this.firstSleepOpen,
    required this.dayLedger,
    required this.reviewContext,
    required this.reviewDrafts,
    required this.reviewSaver,
    required this.dayRoutes,
    required this.goalEntry,
    required this.settingsEntry,
    required this.goals,
    required this.preferences,
  });
  final Widget Function()? goalEntry;
  final Widget Function()? settingsEntry;
  final GoalRepository? goals;
  final AppPreferencesStore? preferences;
  final DayLedgerLoader? dayLedger;
  final ReviewContextLoader? reviewContext;
  final ReviewDraftStore? reviewDrafts;
  final ReviewEntrySaver? reviewSaver;
  final RouteObserver<ModalRoute<void>> dayRoutes;
  final RecordingLedgerLoader ledger;
  final SleepLedgerLoader sleepLedger;
  final SleepFirstOpenCoordinator? firstSleepOpen;
  final RecordingDraftStore drafts;
  final DateTime Function() now;
  final RecordingEntrySaver entrySaver;
  final RecordingEntryEditor entryEditor;
  final Widget Function(SleepDraftContext) sleepEntry;
  @override
  State<_RecordingHome> createState() => _RecordingHomeState();
}

class _RecordingHomeState extends State<_RecordingHome>
    with WidgetsBindingObserver, RouteAware {
  final selection = DayDateSelection();
  final homeShellKey = GlobalKey<HomeShellState>();
  final scrollSession = DayReadScrollSession();
  bool opening = false;
  bool ledgerInteraction = false;
  bool reviewInteraction = false;
  bool checkingSleep = false;
  bool? recordedMainSleepToday;
  String? firstSleepError;
  AppPreferences? preferences;
  ModalRoute<void>? route;

  bool get busy => opening || ledgerInteraction || reviewInteraction;
  CivilDate get selectedDate =>
      selection.date ??
      deviceDateOfInstant(widget.now().millisecondsSinceEpoch);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _refreshSuggestionState(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context);
    if (route != current) {
      widget.dayRoutes.unsubscribe(this);
      route = current;
      if (current != null) widget.dayRoutes.subscribe(this, current);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshSuggestionState();
  }

  @override
  void didPopNext() => WidgetsBinding.instance.addPostFrameCallback(
    (_) => _refreshSuggestionState(),
  );

  /// 读取本机偏好；失败时按默认值展示建议区域，不阻止记账。
  ///
  /// 不阻塞首页与导航：偏好尚未就绪时先按默认开关 / 时点展示。
  /// 存储不可用时（例如缺少平台实现的测试环境）静默按默认值处理，
  /// 读取失败不得逃逸为未捕获的异步错误。
  void _loadPreferences() {
    final store = widget.preferences;
    if (store == null) return;
    runZonedGuarded(() {
      store.read().then((loaded) {
        if (mounted) setState(() => preferences = loaded);
      }, onError: (Object _) {});
    }, (Object _, StackTrace _) {});
  }

  /// 重算建议区域所需的睡眠已记录状态（Q-029）。
  ///
  /// 取代每日首次打开的确认弹窗：只读取状态驱动建议区域，不弹模态框。
  /// 读取失败只显示可重试横幅，不阻止记账、不消费首次标记。
  Future<void> _refreshSuggestionState() async {
    final coordinator = widget.firstSleepOpen;
    if (!mounted ||
        coordinator == null ||
        checkingSleep ||
        busy ||
        route?.isCurrent != true) {
      return;
    }
    checkingSleep = true;
    final instant = widget.now().millisecondsSinceEpoch;
    final today = deviceDateOfInstant(instant);
    setState(() => firstSleepError = null);
    try {
      final result = await coordinator.check(date: today, now: instant);
      if (!mounted ||
          deviceDateOfInstant(widget.now().millisecondsSinceEpoch) != today) {
        return;
      }
      setState(
        () => recordedMainSleepToday = result.ledger.recordedMainSleepToday,
      );
    } catch (_) {
      if (mounted) {
        setState(() => firstSleepError = '主睡眠检查失败；可继续记账，或重试检查。');
      }
    } finally {
      checkingSleep = false;
      if (mounted &&
          deviceDateOfInstant(widget.now().millisecondsSinceEpoch) != today) {
        _refreshSuggestionState();
      }
    }
  }

  void _interaction(bool value, {required bool review}) {
    if (!mounted) return;
    setState(() {
      if (review) {
        reviewInteraction = value;
      } else {
        ledgerInteraction = value;
      }
    });
    if (!value) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _refreshSuggestionState(),
      );
    }
  }

  Widget _activity(CivilDate date) => ActivityRecordingEntry(
    goals: widget.goals,
    context: RecordingDraftContext.newEntry(date: date),
    store: widget.drafts,
    entrySaver: widget.entrySaver,
    loadSuggestion: () => widget.ledger.loadTimeSuggestion(
      date: date,
      now: widget.now().millisecondsSinceEpoch,
    ),
  );

  Future<void> _pushSleep(CivilDate date) async {
    final result = await Navigator.of(context).push<SleepLedger>(
      MaterialPageRoute(
        builder: (_) =>
            widget.sleepEntry(SleepDraftContext.newEntry(date: date)),
      ),
    );
    if (mounted && result != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('睡眠已保存到账本。')));
    }
  }

  Future<void> _recordActivity() async {
    if (busy) return;
    final date = selectedDate;
    setState(() => opening = true);
    try {
      final result = await Navigator.of(context).push<RecordingLedger>(
        MaterialPageRoute(builder: (_) => _activity(date)),
      );
      if (mounted && result != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已保存到账本。')));
      }
    } finally {
      if (mounted) {
        setState(() => opening = false);
        selection.refresh();
        await _refreshSuggestionState();
      }
    }
  }

  Future<void> _recordSleep() async {
    if (busy) return;
    final date = selectedDate;
    setState(() => opening = true);
    try {
      await _pushSleep(date);
    } finally {
      if (mounted) {
        setState(() => opening = false);
        selection.refresh();
        await _refreshSuggestionState();
      }
    }
  }

  /// 侧边栏入口：进入独立「我的目标」整页。
  Future<void> _openGoals() => _pushMenuEntry(widget.goalEntry);

  /// 侧边栏入口：进入独立「设置」整页。
  Future<void> _openSettings() => _pushMenuEntry(widget.settingsEntry);

  Future<void> _pushMenuEntry(Widget Function()? entry) async {
    if (busy || entry == null) return;
    setState(() => opening = true);
    try {
      await Navigator.of(context)
          .push<void>(MaterialPageRoute(builder: (_) => entry()));
    } finally {
      if (mounted) {
        setState(() => opening = false);
        selection.refresh();
        await _refreshSuggestionState();
      }
    }
  }

  Widget _reviewPage(CivilDate date, {required bool active}) =>
      ReviewContextPage(
        loader: widget.reviewContext!,
        drafts: widget.reviewDrafts,
        saver: widget.reviewSaver,
        goals: widget.goals,
        now: () => widget.now().millisecondsSinceEpoch,
        dateOfInstant: deviceDateOfInstant,
        routeObserver: widget.dayRoutes,
        initialDate: date,
        selection: selection,
        embedded: true,
        active: active,
        scrollSession: scrollSession,
        onInteraction: (value) => _interaction(value, review: true),
      );

  Widget _ledgerTimeline(DayLedgerController controller, bool active) =>
      ListenableBuilder(
        listenable: controller,
        builder: (context, _) => HomeTimelineTab(
          view: controller.view,
          scrollSession: scrollSession,
          // While an editor or modal is on top the list is not the active
          // reading surface; on return it restores the saved anchor.
          active: active && !busy,
          placeholder: switch (controller.status) {
            DayLedgerStatus.failed => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('账本读取失败。'),
                TextButton(
                  onPressed: busy ? null : controller.refresh,
                  child: const Text('重试读取'),
                ),
              ],
            ),
            DayLedgerStatus.empty => const Text('这一天还没有记录。'),
            _ => const Center(child: CircularProgressIndicator()),
          },
          onEditFact: busy ? null : _openFact,
          onDeleteTimeBlock: busy ? null : _deleteTimeBlock,
          onFillGap: busy ? null : _openGap,
          bottomInset: widget.reviewContext == null ? 0 : 88,
        ),
      );

  Future<void> _openGap(CivilDate date, UnresolvedSpan gap) async {
    if (busy) return;
    setState(() => opening = true);
    try {
      final committed = await Navigator.of(context).push<RecordingLedger>(
        MaterialPageRoute<RecordingLedger>(
          builder: (_) => ActivityRecordingEntry(
            goals: widget.goals,
            context: RecordingDraftContext.gap(
              date: date,
              startedAt: gap.startedAt,
              endedAt: gap.endedAt,
            ),
            store: widget.drafts,
            entrySaver: widget.entrySaver,
            loadSuggestion: () => widget.ledger.loadTimeSuggestion(
              date: date,
              now: widget.now().millisecondsSinceEpoch,
              explicitGap: gap,
            ),
          ),
        ),
      );
      if (mounted && committed != null) _snack('已保存到账本。');
    } finally {
      if (mounted) {
        setState(() => opening = false);
        selection.refresh();
        await _refreshSuggestionState();
      }
    }
  }

  /// 从详情压入编辑器；返回是否提交了正式变更，供详情页决定是否离开。
  Future<bool> _openFact(CivilDate date, LedgerSegment segment) async {
    if (busy) return false;
    setState(() => opening = true);
    var committed = false;
    try {
      final result = await Navigator.of(context).push<Object>(
        MaterialPageRoute<Object>(
          builder: (_) => switch (segment) {
            TimeBlockSegment(:final source) => ActivityRecordingEntry(
              goals: widget.goals,
              context: RecordingDraftContext.edit(
                date: date,
                timeBlockId: source.id,
              ),
              store: widget.drafts,
              entryEditor: widget.entryEditor,
              loadSuggestion: () async => const ManualTimeEntry(),
            ),
            SleepSessionSegment(:final source) => widget.sleepEntry(
              SleepDraftContext.edit(date: date, sleepSessionId: source.id),
            ),
          },
        ),
      );
      if (result != null) {
        committed = true;
        if (mounted) _snack('记录更改已应用。');
      }
    } finally {
      if (mounted) {
        setState(() => opening = false);
        selection.refresh();
        await _refreshSuggestionState();
      }
    }
    return committed;
  }

  Future<void> _deleteTimeBlock(TimeBlockSegment segment) async {
    if (busy) return;
    setState(() => opening = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('删除时间记录'),
          content: const Text('删除完整记录时，依附的节奏解释也会删除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('删除记录'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final draftContext = RecordingDraftContext.edit(
        date: selectedDate,
        timeBlockId: segment.reference.id,
      );
      final result = await widget.entryEditor.delete(draftContext);
      if (!mounted) return;
      if (result is RecordingDeleteFailed) {
        _snack('删除失败，记录未改变，请重试。');
      } else if (result is RecordingDeleteCommitted) {
        if (!result.complete) {
          await widget.entryEditor.finishDelete(
            context: draftContext,
            draftCleared: result.draftCleared,
          );
          if (!mounted) return;
        }
        _snack('记录已删除。');
      }
    } finally {
      if (mounted) {
        setState(() => opening = false);
        selection.refresh();
        await _refreshSuggestionState();
      }
    }
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  /// 首页建议区域：按 Q-028 优先级与 Q-029 边界由已提交投影推导。
  ///
  /// 只读当前 [DayLedgerController] 的视图与日期上下文；不查询、不写入。
  Widget _suggestionCard(DayLedgerController controller) {
    final view = controller.view;
    final dateContext = controller.dateContext;
    if (view == null || dateContext == null) return const SizedBox.shrink();
    // 当地时刻用日边界与当前 instant 之差求得，不再次读取时区。
    final nowMinutes = (dateContext.now - dateContext.dayStartedAt) ~/ 60000;
    final suggestion = resolveHomeSuggestion(
      relation: dateContext.relation,
      nowMinutes: nowMinutes,
      sleepReminderMinutes:
          preferences?.sleepReminderMinutes ?? defaultSleepReminderMinutes,
      reviewReminderMinutes:
          preferences?.reviewReminderMinutes ?? defaultReviewReminderMinutes,
      hasRecordedMainSleepToday: recordedMainSleepToday ?? false,
      trailingGapMinutes: trailingGapEndingAt(
        view.unresolvedSpans,
        view.window.endedAt,
      ),
    );
    return Padding(
      key: const ValueKey('home-suggestion'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: HomeSuggestionCard(
        suggestion: suggestion,
        onAction: switch (suggestion.kind) {
          HomeSuggestionKind.greeting => null,
          HomeSuggestionKind.sleep => busy ? null : _recordSleep,
          HomeSuggestionKind.record => busy ? null : _recordActivity,
          HomeSuggestionKind.review =>
            busy ? null : () => homeShellKey.currentState?.openReviewTab(),
        },
      ),
    );
  }

  Future<void> _editCompleteSleep(CivilDate date, SleepSession sleep) async {
    if (busy) return;
    setState(() => opening = true);
    try {
      await Navigator.of(context).push<SleepLedger>(
        MaterialPageRoute(
          builder: (_) => widget.sleepEntry(
            SleepDraftContext.edit(date: date, sleepSessionId: sleep.id),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => opening = false);
        selection.refresh();
        await _refreshSuggestionState();
      }
    }
  }

  @override
  void dispose() {
    widget.dayRoutes.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dayLedger = widget.dayLedger;
    if (dayLedger == null) {
      return const Scaffold(body: Center(child: Text('日账本入口尚未配置。')));
    }
    return HomeShell(
      key: homeShellKey,
      selection: selection,
      ledgerLoader: dayLedger,
      now: () => widget.now().millisecondsSinceEpoch,
      dateOfInstant: deviceDateOfInstant,
      busy: busy,
      banner: firstSleepError == null
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(firstSleepError!, style: const TextStyle(fontSize: 13)),
                  TextButton(
                    onPressed: busy ? null : _refreshSuggestionState,
                    child: const Text('重试主睡眠检查'),
                  ),
                ],
              ),
            ),
      onGoals: widget.goalEntry == null ? null : _openGoals,
      onSettings: widget.settingsEntry == null ? null : _openSettings,
      onRecordActivity: _recordActivity,
      onRecordSleep: _recordSleep,
      reviewEnabled: widget.reviewContext != null,
      floatingCard: (preferences?.reminders ?? true) ? _suggestionCard : null,
      timeline: _ledgerTimeline,
      summary: (controller, _) => HomeSummaryTab(
        controller: controller,
        onEditSleep: busy
            ? null
            : (sleep) => _editCompleteSleep(selectedDate, sleep),
        onRetry: controller.refresh,
      ),
      review: (active) => _reviewPage(selectedDate, active: active),
    );
  }
}
