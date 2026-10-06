import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/home_theme.dart';
import '../../../core/identity/entity_id.dart';
import '../../../core/time/time_contract.dart';
import '../../ledger/domain/rhythm_state.dart';
import '../../settings/domain/app_preferences.dart';
import '../domain/goal.dart';
import '../domain/goal_history.dart';
import '../domain/goal_repository.dart';
import '../domain/goal_status.dart';

enum _GoalTab { active, archived }

enum _ChartKind { bar, heat }

enum _Pending { archive, delete }

/// 目标管理页：列表（当前 / 已归档）、详情（时间投入 + 此前记录）、
/// 新建 / 改名、归档 / 恢复 / 删除与常用目标。
///
/// 版式按目标管理第二轮原型（assets/goal-management-round-two）；生命周期
/// 与删除语义沿用既有 [GoalRepository]。常用目标是本机偏好，不是 Goal 字段
/// （Q-025），通过 [preferences] 存取；未注入时不做常用操作。
class GoalManagementPage extends StatefulWidget {
  const GoalManagementPage({
    super.key,
    required this.repository,
    required this.newId,
    required this.now,
    this.history,
    this.preferences,
  });

  final GoalRepository repository;
  final EntityId Function() newId;
  final InstantMilliseconds Function() now;
  final GoalHistoryReader? history;
  final AppPreferencesStore? preferences;

  @override
  State<GoalManagementPage> createState() => _GoalManagementPageState();
}

class _GoalManagementPageState extends State<GoalManagementPage> {
  _GoalTab tab = _GoalTab.active;
  Goal? selected;
  _ChartKind chart = _ChartKind.bar;
  HeatRange heatRange = HeatRange.week;
  int? selectedDay;
  bool showAllRecords = false;
  bool busy = false;
  String? error;
  String? status;
  String? commonGoalId;
  List<Goal>? goals;
  List<GoalInvestmentRecord>? records;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      error = null;
      goals = null;
    });
    try {
      final active = await widget.repository.listActive();
      final archived = await widget.repository.listArchived();
      var common = widget.preferences == null
          ? null
          : (await widget.preferences!.read()).commonGoalId;
      // 归档 / 删除后的常用选择必须同步；读取时校验其仍为 active。
      if (common != null && !active.any((goal) => goal.id == common)) {
        final stillExists = await widget.repository.findById(common);
        common = stillExists?.status == GoalStatus.active ? common : null;
      }
      if (!mounted) return;
      setState(() {
        goals = [...active, ...archived];
        commonGoalId = common;
      });
    } catch (_) {
      if (mounted) setState(() => error = '目标暂时没读出来，再试一次吧。');
    }
  }

  Future<void> _loadRecords() async {
    final goal = selected;
    final history = widget.history;
    records = null;
    if (goal == null || history == null) return;
    try {
      final loaded = await history.recordsFor(goal.id);
      if (!mounted) return;
      setState(() => records = loaded);
    } catch (_) {
      if (mounted) setState(() => records = const []);
    }
  }

  Future<void> _write(Future<void> Function() operation) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      status = null;
    });
    try {
      await operation();
    } on GoalNotFoundException {
      if (mounted) setState(() => error = '目标已不存在，请刷新目标列表。');
    } catch (_) {
      if (mounted) setState(() => error = '没保存成功，内容还在。再试一次吧。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _setCommon(Goal goal) => _write(() async {
    if (goal.status != GoalStatus.active) {
      setState(() => error = '这个目标已归档，请先恢复。');
      return;
    }
    final next = commonGoalId == goal.id ? null : goal.id;
    await widget.preferences!.write(
      (await widget.preferences!.read()).copyWith(
        commonGoalId: next,
        clearCommonGoal: next == null,
      ),
    );
    if (!mounted) return;
    setState(() {
      commonGoalId = next;
      status = '常用目标已更新。';
    });
  });

  // ----- list -----

  Widget _list() {
    final items = (goals ?? const <Goal>[])
        .where((goal) => goal.status == _tabGoalStatus)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Text('我的目标', style: _heading),
        const SizedBox(height: 6),
        const Text('点名称看投入，点书签设为常用。', style: _muted),
        if (status != null) ...[const SizedBox(height: 12), _note(status!)],
        if (error != null) ...[const SizedBox(height: 12), _error(error!)],
        const SizedBox(height: 18),
        _tabs(),
        if (goals == null)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tab == _GoalTab.active ? '还没有目标。' : '还没有归档的目标。',
                  style: _value,
                ),
                const SizedBox(height: 6),
                Text(
                  tab == _GoalTab.active
                      ? '先给想投入的事情起个名字。'
                      : '以后暂时不再关联的目标，会放在这里。',
                  style: _muted,
                ),
              ],
            ),
          )
        else
          for (final goal in items) _listRow(goal),
      ],
    );
  }

  GoalStatus get _tabGoalStatus =>
      tab == _GoalTab.active ? GoalStatus.active : GoalStatus.archived;

  Widget _tabs() => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: HomePalette.hairline)),
    ),
    child: Row(
      children: [
        for (final value in _GoalTab.values)
          Expanded(
            child: InkWell(
              key: ValueKey('goal-tab-${value.name}'),
              onTap: busy ? null : () => setState(() => tab = value),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: tab == value
                          ? HomePalette.accentDeep
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  value == _GoalTab.active ? '当前' : '已归档',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: homeSerifFamily,
                    fontSize: 18,
                    color: tab == value
                        ? HomePalette.accentDeep
                        : HomePalette.muted,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  bool _duplicate(Goal goal) =>
      (goals ?? const <Goal>[]).where((g) => g.name == goal.name).length > 1;

  Widget _listRow(Goal goal) {
    final isCommon =
        commonGoalId == goal.id && goal.status == GoalStatus.active;
    return Container(
      decoration: BoxDecoration(
        color: isCommon ? HomePalette.tint : HomePalette.paper,
        border: Border(
          left: BorderSide(
            color: isCommon ? HomePalette.accentDeep : Colors.transparent,
            width: 3,
          ),
          bottom: const BorderSide(color: HomePalette.hairline),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: ValueKey('goal-open-${goal.id}'),
              onTap: busy
                  ? null
                  : () {
                      setState(() {
                        selected = goal;
                        showAllRecords = false;
                        selectedDay = null;
                        status = null;
                        error = null;
                        records = null;
                      });
                      _loadRecords();
                    },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 18, 6, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(goal.name, style: _entryName),
                          if (isCommon)
                            const Text(
                              '常用',
                              style: TextStyle(
                                fontFamily: homeSerifFamily,
                                fontSize: 13,
                                color: HomePalette.accentDeep,
                              ),
                            ),
                          if (_duplicate(goal))
                            Text(
                              '创建于${_dateText(goal.createdAt)}',
                              style: _muted,
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: HomePalette.muted),
                  ],
                ),
              ),
            ),
          ),
          if (goal.status == GoalStatus.active && widget.preferences != null)
            TextButton(
              key: ValueKey('goal-common-${goal.id}'),
              onPressed: busy ? null : () => _setCommon(goal),
              style: TextButton.styleFrom(
                minimumSize: const Size(50, homeTapTarget),
                foregroundColor: HomePalette.accentDeep,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCommon ? Icons.bookmark : Icons.bookmark_border,
                    size: 20,
                  ),
                  Text(
                    isCommon ? '已常用' : '设常用',
                    style: const TextStyle(
                      fontFamily: homeSerifFamily,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ----- detail -----

  Widget _detail(Goal goal) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Text(
          goal.status == GoalStatus.archived ? '已归档' : '当前目标',
          style: _muted,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: InkWell(
                key: const ValueKey('goal-rename'),
                onTap: busy ? null : () => _form(goal),
                child: Container(
                  constraints: const BoxConstraints(minHeight: homeTapTarget),
                  alignment: Alignment.centerLeft,
                  child: Text(goal.name, style: _nameStyle),
                ),
              ),
            ),
            if (goal.status == GoalStatus.active && commonGoalId == goal.id)
              const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Text('常用目标', style: _muted),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text('创建于${_dateText(goal.createdAt)}', style: _muted),
        if (goal.status == GoalStatus.archived) ...[
          const SizedBox(height: 6),
          const Text('以前的记录还在，恢复后可用于新记录。', style: _muted),
        ],
        if (error != null) ...[const SizedBox(height: 12), _error(error!)],
        const SizedBox(height: 24),
        _chartSection(goal),
        _historySection(goal),
      ],
    );
  }

  Widget _chartSection(Goal goal) {
    final now = widget.now();
    final days = _chartDays(now);
    final total = days.fold<int>(0, (sum, day) => sum + day.milliseconds);
    final selected = days.firstWhere(
      (day) => day.day == selectedDay,
      orElse: () => days.firstWhere(
        (day) => day.day == _dayStart(now),
        orElse: () => days.last,
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HomePalette.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('时间投入', style: _sectionHeading)),
              _chartToggle('柱状图', _ChartKind.bar),
              const SizedBox(width: 6),
              _chartToggle('热力图', _ChartKind.heat),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  widget.history == null
                      ? '读取中…'
                      : (total <= 0 ? '尚无相关记录' : _compactDuration(total)),
                  style: const TextStyle(
                    fontFamily: homeSerifFamily,
                    fontSize: 30,
                    color: HomePalette.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(_rangeLabel(), style: _muted),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_dateText(days.first.day)} — ${_dateText(days.last.day)}',
                  style: _muted,
                ),
              ),
              if (chart == _ChartKind.heat && widget.history != null)
                IconButton(
                  key: const ValueKey('goal-chart-settings'),
                  tooltip: '热力图设置',
                  onPressed: busy ? null : _chartSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (chart == _ChartKind.bar) _barChart(days) else _heatMap(days),
          const SizedBox(height: 10),
          Text(
            '${_dateText(selected.day)}${selected.day == _dayStart(now) ? ' · 截至现在' : ''}：'
            '${selected.milliseconds > 0 ? _compactDuration(selected.milliseconds) : '未记录相关投入'}',
            style: _muted,
          ),
        ],
      ),
    );
  }

  Widget _chartToggle(String label, _ChartKind value) => InkWell(
    key: ValueKey('goal-chart-${value.name}'),
    onTap: busy
        ? null
        : () => setState(() {
            chart = value;
            selectedDay = null;
          }),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: homeSerifFamily,
          fontSize: 15,
          color: chart == value ? HomePalette.accentDeep : HomePalette.muted,
          decoration: chart == value ? TextDecoration.underline : null,
          decorationColor: HomePalette.accentDeep,
        ),
      ),
    ),
  );

  Widget _barChart(List<_DayInvestment> days) {
    final maxHours = math.max(
      1,
      (days.map((d) => d.milliseconds).fold<int>(1, math.max) / 3600000).ceil(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('投入（小时）', style: _muted),
            Text('$maxHours h', style: _muted),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final day in days)
                Expanded(
                  child: InkWell(
                    key: ValueKey('goal-day-${day.day}'),
                    onTap: () => setState(() => selectedDay = day.day),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          day.milliseconds <= 0
                              ? '—'
                              : day.milliseconds < 360000
                              ? '＜0.1h'
                              : '${(day.milliseconds / 360000).round() / 10}h',
                          style: _muted,
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              widthFactor: 0.7,
                              heightFactor: day.milliseconds <= 0
                                  ? 0
                                  : (day.milliseconds / (maxHours * 3600000))
                                        .clamp(0.01, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: HomePalette.accent.withValues(
                                    alpha: day.day == selectedDay ? 1 : .65,
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateTime.fromMillisecondsSinceEpoch(day.day).month}/'
                          '${DateTime.fromMillisecondsSinceEpoch(day.day).day}',
                          style: _muted,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heatMap(List<_DayInvestment> days) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final first = DateTime.fromMillisecondsSinceEpoch(days.first.day);
    final padding = (first.weekday - DateTime.monday) % 7;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final label in weekdays)
              Expanded(
                child: Text(label, textAlign: TextAlign.center, style: _muted),
              ),
          ],
        ),
        const SizedBox(height: 5),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
          children: [
            for (var i = 0; i < padding; i++) const SizedBox.shrink(),
            for (final day in days) _heatCell(day),
          ],
        ),
        const SizedBox(height: 10),
        const Text('深浅表示时长。今天只计已经发生的时间。', style: _muted),
        const SizedBox(height: 6),
        _heatLegend(),
      ],
    );
  }

  /// 色阶对应的时长范围，避免只从颜色猜测投入量。
  Widget _heatLegend() => Row(
    children: [
      Text('少', style: _muted),
      const SizedBox(width: 6),
      for (final color in const [
        Color(0xFFEEE0D8),
        Color(0xFFDFB6A5),
        Color(0xFFBF765E),
        Color(0xFF914C3A),
      ])
        Container(
          width: 18,
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      const SizedBox(width: 6),
      Text('多', style: _muted),
      const SizedBox(width: 10),
      const Expanded(child: Text('空白＝当天没有投入；淡格＝尚未到来的日期', style: _muted)),
    ],
  );

  Widget _heatCell(_DayInvestment day) {
    final level = day.future
        ? 0
        : day.milliseconds <= 0
        ? 1
        : day.milliseconds < 3600000
        ? 1
        : day.milliseconds < 7200000
        ? 2
        : day.milliseconds < 14400000
        ? 3
        : 4;
    final colors = [
      HomePalette.tint,
      const Color(0xFFEEE0D8),
      const Color(0xFFDFB6A5),
      const Color(0xFFBF765E),
      const Color(0xFF914C3A),
    ];
    return InkWell(
      key: ValueKey('goal-heat-${day.day}'),
      onTap: day.future ? null : () => setState(() => selectedDay = day.day),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: day.future
              ? HomePalette.tint.withValues(alpha: .45)
              : day.milliseconds <= 0
              ? Colors.transparent
              : colors[level],
          border: day.milliseconds <= 0 && !day.future
              ? Border.all(
                  color: HomePalette.hairline,
                  style: BorderStyle.solid,
                )
              : null,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          '${DateTime.fromMillisecondsSinceEpoch(day.day).day}',
          style: TextStyle(
            fontFamily: homeSerifFamily,
            fontSize: 15,
            color: level >= 3 ? const Color(0xFFFFF8F0) : HomePalette.ink,
            decoration: day.day == selectedDay
                ? TextDecoration.underline
                : null,
          ),
        ),
      ),
    );
  }

  Widget _historySection(Goal goal) {
    final all = widget.history == null
        ? const <GoalInvestmentRecord>[]
        : (records ?? const <GoalInvestmentRecord>[]);
    final sorted = [...all]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final shown = showAllRecords ? sorted : sorted.take(5).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  showAllRecords ? '全部记录' : '此前记录',
                  style: _sectionHeading,
                ),
              ),
              if (widget.history != null)
                Text('${sorted.length}条', style: _muted),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.history == null)
            const Text('目标历史读取尚未配置。', style: _muted)
          else if (records == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (sorted.isEmpty)
            const Text('还没有关联这个目标的记录。', style: _muted)
          else ...[
            for (final record in shown) _historyRow(record),
            if (!showAllRecords && sorted.length > 5)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const ValueKey('goal-all-records'),
                  onPressed: () => setState(() => showAllRecords = true),
                  child: Text('查看全部 ${sorted.length} 条'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _historyRow(GoalInvestmentRecord record) {
    final unknown = record.block.knowledgeState.name == 'unknown';
    final title = unknown ? '想不起来' : (record.block.title ?? '未命名记录');
    final interval =
        '${_dateText(record.startedAt)} · '
        '${_clock(record.startedAt)}–${_clock(record.endedAt)}';
    final duration = _compactDuration(record.endedAt - record.startedAt);
    return Semantics(
      label: '$title，$interval，$duration',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: HomePalette.hairline)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: homeSerifFamily,
                      fontSize: 19,
                      color: HomePalette.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(interval, style: _muted),
                  if (unknown)
                    const Text('已交代 · 想不起来', style: _muted)
                  else if (record.annotation?.state case final state?)
                    Text(_rhythmLabel(state), style: _muted),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(duration, style: _muted),
          ],
        ),
      ),
    );
  }

  Future<void> _chartSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('热力图设置', style: _sectionHeading),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final range in HeatRange.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: OutlinedButton(
                        key: ValueKey('goal-heat-range-${range.name}'),
                        onPressed: () {
                          setState(() {
                            heatRange = range;
                            selectedDay = null;
                          });
                          Navigator.pop(sheetContext);
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: heatRange == range
                              ? HomePalette.tint
                              : null,
                        ),
                        child: Text(range == HeatRange.week ? '本周' : '本月'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _form(Goal? goal) async {
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _GoalNameDialog(
        goal: goal,
        onSave: (name) => Navigator.pop(dialogContext, name),
      ),
    );
    if (value == null || !mounted) return;
    await _write(() async {
      final Goal result;
      if (goal == null) {
        result = await widget.repository.create(
          id: widget.newId(),
          name: value,
          now: widget.now(),
        );
      } else {
        result = await widget.repository.rename(
          id: goal.id,
          name: value,
          now: widget.now(),
        );
      }
      if (!mounted) return;
      setState(() {
        selected = result;
        tab = result.status == GoalStatus.archived
            ? _GoalTab.archived
            : _GoalTab.active;
        status = goal == null ? '目标建好了。' : '目标名称改好了。';
      });
      await _load();
      await _loadRecords();
    });
  }

  Future<void> _confirm(Goal goal, _Pending pending) async {
    final referenced = await _hasReferences(goal);
    if (!mounted) return;
    final archive = pending == _Pending.archive || referenced;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(archive ? '归档这个目标？' : '删除这个目标？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(goal.name),
            const SizedBox(height: 10),
            Text(archive ? '归档后，新记录就不再关联它。以前的记录会保留。' : '这个目标还没有关联的记录，删除后无法恢复。'),
            if (pending == _Pending.delete && referenced)
              const SizedBox(height: 8),
            if (pending == _Pending.delete && referenced)
              const Text('它已有记录，会按归档处理。'),
            if (commonGoalId == goal.id) ...[
              const SizedBox(height: 8),
              const Text('它也会从常用目标中移除，恢复后需重新设置。'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('保留目标'),
          ),
          FilledButton(
            key: const ValueKey('goal-confirm-action'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(archive ? '确认归档' : '确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _write(() async {
      if (archive) {
        await widget.repository.archive(id: goal.id, now: widget.now());
      } else {
        final result = await widget.repository.delete(
          id: goal.id,
          now: widget.now(),
        );
        if (result == GoalDeleteResult.archived) {
          if (!mounted) return;
          setState(() => status = '目标已有记录引用，已归档；记录与引用保留。');
        }
      }
      if (!mounted) return;
      // 归档 / 删除后清除常用选择（Q-025）。
      if (commonGoalId == goal.id && widget.preferences != null) {
        await widget.preferences!.write(
          (await widget.preferences!.read()).copyWith(clearCommonGoal: true),
        );
        if (!mounted) return;
        setState(() => commonGoalId = null);
      }
      setState(() {
        status ??= archive ? '目标已归档，以前的记录还在。' : '目标已删除。';
        selected = null;
        tab = _GoalTab.active;
        records = null;
      });
      await _load();
    });
  }

  Future<void> _restore(Goal goal) => _write(() async {
    await widget.repository.restore(id: goal.id, now: widget.now());
    if (!mounted) return;
    setState(() {
      status = '目标已恢复。';
      tab = _GoalTab.active;
    });
    await _load();
  });

  Future<bool> _hasReferences(Goal goal) async {
    final history = widget.history;
    if (history == null) return false;
    try {
      return (await history.recordsFor(goal.id)).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ----- chrome -----

  @override
  Widget build(BuildContext context) {
    final goal = selected;
    return Theme(
      data: homeTheme,
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            key: const ValueKey('goal-back'),
            onPressed: () {
              if (goal != null) {
                setState(() {
                  selected = null;
                  records = null;
                  showAllRecords = false;
                  error = null;
                  status = null;
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: const Text('目标'),
        ),
        // 桌面视口下限制正文最大宽度，避免列表、图表与按钮被横向拉满。
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: goal == null ? _list() : _detail(goal),
          ),
        ),
        bottomNavigationBar: goal == null
            ? SafeArea(
                top: false,
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: FilledButton.icon(
                        key: const ValueKey('goal-new'),
                        onPressed: busy ? null : () => _form(null),
                        icon: const Icon(Icons.add, size: 19),
                        label: const Text('新建目标'),
                      ),
                    ),
                  ),
                ),
              )
            : Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: _detailFooter(goal),
                ),
              ),
      ),
    );
  }

  Widget _detailFooter(Goal goal) => SafeArea(
    top: false,
    child: Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: HomePalette.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: goal.status == GoalStatus.archived
          ? Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('goal-restore'),
                    onPressed: busy ? null : () => _restore(goal),
                    child: const Text('恢复目标'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('goal-delete'),
                    onPressed: busy
                        ? null
                        : () => _confirm(goal, _Pending.delete),
                    child: const Text('删除'),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('goal-archive'),
                    onPressed: busy
                        ? null
                        : () => _confirm(goal, _Pending.archive),
                    child: const Text('归档目标'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    key: const ValueKey('goal-delete'),
                    onPressed: busy
                        ? null
                        : () => _confirm(goal, _Pending.delete),
                    style: TextButton.styleFrom(
                      foregroundColor: HomePalette.accentDeep,
                    ),
                    child: const Text('删除'),
                  ),
                ),
              ],
            ),
    ),
  );

  // ----- chart helpers -----

  List<_DayInvestment> _chartDays(int now) {
    final today = _dayStart(now);
    final List<int> days;
    if (chart == _ChartKind.bar) {
      days = [for (var i = 6; i >= 0; i--) _shiftDays(today, -i)];
    } else if (heatRange == HeatRange.week) {
      final monday = _shiftDays(
        today,
        -((DateTime.fromMillisecondsSinceEpoch(today).weekday -
                DateTime.monday) %
            7),
      );
      days = [for (var i = 0; i < 7; i++) _shiftDays(monday, i)];
    } else {
      final date = DateTime.fromMillisecondsSinceEpoch(today);
      final first = DateTime(date.year, date.month, 1).millisecondsSinceEpoch;
      final last = DateTime(
        date.year,
        date.month + 1,
        0,
      ).millisecondsSinceEpoch;
      days = [for (var day = first; day <= last; day = _shiftDays(day, 1)) day];
    }
    final all = records ?? const <GoalInvestmentRecord>[];
    return [for (final day in days) _dayInvestment(day, now, all)];
  }

  _DayInvestment _dayInvestment(
    int day,
    int now,
    List<GoalInvestmentRecord> all,
  ) {
    final end = math.min<int>(_shiftDays(day, 1), now);
    var milliseconds = 0;
    for (final record in all) {
      final overlap =
          math.min<int>(record.endedAt, end) -
          math.max<int>(record.startedAt, day);
      if (overlap > 0) milliseconds += overlap;
    }
    return _DayInvestment(
      day: day,
      milliseconds: milliseconds,
      future: day > _dayStart(now),
    );
  }

  String _rangeLabel() => switch (chart) {
    _ChartKind.bar => '近7天 · 已记录投入',
    _ChartKind.heat =>
      heatRange == HeatRange.week ? '本周 · 已记录投入' : '本月 · 已记录投入',
  };

  static int _dayStart(int instant) {
    final date = DateTime.fromMillisecondsSinceEpoch(instant);
    return DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
  }

  static int _shiftDays(int instant, int days) {
    final date = DateTime.fromMillisecondsSinceEpoch(instant);
    return DateTime(
      date.year,
      date.month,
      date.day + days,
    ).millisecondsSinceEpoch;
  }

  String _clock(int instant) {
    final date = DateTime.fromMillisecondsSinceEpoch(instant);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.hour)}:${two(date.minute)}';
  }

  String _dateText(int instant) {
    final date = DateTime.fromMillisecondsSinceEpoch(instant);
    final currentYear = DateTime.fromMillisecondsSinceEpoch(widget.now()).year;
    return date.year == currentYear
        ? '${date.month}月${date.day}日'
        : '${date.year}年${date.month}月${date.day}日';
  }

  String _compactDuration(int milliseconds) {
    final minutes = (milliseconds / 60000).round();
    if (minutes == 0) return '少于1分钟';
    if (minutes < 60) return '$minutes分钟';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0 ? '$hours小时' : '$hours小时$remainder分钟';
  }

  String _rhythmLabel(RhythmState state) => switch (state) {
    RhythmState.progress => '推进',
    RhythmState.stuck => '卡住',
    RhythmState.recovery => '休息',
  };

  Widget _note(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: HomePalette.tint,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: homeSerifFamily,
        fontSize: 15,
        color: HomePalette.recovery,
      ),
    ),
  );

  Widget _error(String text) => Text(
    text,
    style: const TextStyle(
      fontFamily: homeSerifFamily,
      fontSize: 15,
      color: HomePalette.error,
    ),
  );
}

class _DayInvestment {
  const _DayInvestment({
    required this.day,
    required this.milliseconds,
    required this.future,
  });
  final int day;
  final int milliseconds;
  final bool future;
}

/// Owns its name field so the controller is disposed with the route, not the
/// dialog call, avoiding use of a disposed controller during the exit animation.
///
/// 名称校验留在表单内：空名时不关闭弹窗，错误紧邻字段显示，保留输入与焦点。
class _GoalNameDialog extends StatefulWidget {
  const _GoalNameDialog({required this.goal, required this.onSave});
  final Goal? goal;
  final void Function(String name) onSave;

  @override
  State<_GoalNameDialog> createState() => _GoalNameDialogState();
}

class _GoalNameDialogState extends State<_GoalNameDialog> {
  late final TextEditingController name = TextEditingController(
    text: widget.goal?.name ?? '',
  );
  String? error;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void _submit() {
    if (name.text.trim().isEmpty) {
      setState(() => error = '先给目标起个名字。');
      return;
    }
    widget.onSave(name.text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.goal == null ? '想把时间投入什么？' : '给它换个名字'),
    content: TextField(
      key: const ValueKey('goal-name-input'),
      controller: name,
      autofocus: true,
      minLines: 3,
      maxLines: 5,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      onChanged: (_) {
        if (error != null) setState(() => error = null);
      },
      decoration: InputDecoration(
        labelText: '目标名称',
        hintText: '比如：毕业设计',
        errorText: error,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const ValueKey('goal-save-name'),
        onPressed: _submit,
        child: const Text('保存目标'),
      ),
    ],
  );
}

const _heading = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 30,
  height: 1.4,
  fontWeight: FontWeight.w600,
  color: HomePalette.ink,
);
const _sectionHeading = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 22,
  height: 1.5,
  fontWeight: FontWeight.w600,
  color: HomePalette.ink,
);
const _entryName = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 22,
  height: 1.5,
  color: HomePalette.ink,
);
const _nameStyle = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 30,
  height: 1.4,
  color: HomePalette.accentDeep,
  decoration: TextDecoration.underline,
  decorationStyle: TextDecorationStyle.dashed,
  decorationColor: HomePalette.hairline,
  decorationThickness: 1,
);
const _value = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 18,
  color: HomePalette.ink,
);
const _muted = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 14,
  height: 1.6,
  color: HomePalette.muted,
);
