import '../../ledger/presentation/recording_time_picker.dart'
    show showLedgerClockPicker;

import 'package:flutter/material.dart';

import '../../../app/theme/home_theme.dart';
import '../../../core/identity/entity_id.dart';
import '../../ledger/application/home_suggestion.dart';
import '../domain/app_preferences.dart';
import '../domain/data_overview.dart';

/// 设置页：分组入口（界面设置 / 记录与提醒 / 高级设置 / 关于）。
///
/// 版式按设置页第一轮原型（assets/settings-round-one）。偏好通过
/// [AppPreferencesStore] 本机存取；高级操作通过 [DataMaintenance] 作用于
/// 正式事实；两者失败都不表现为成功。版本号由宿主注入，不写模拟值。
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.preferences,
    required this.maintenance,
    required this.newGoalId,
    required this.newFactId,
    required this.now,
    this.versionLabel,
  });

  final AppPreferencesStore preferences;
  final DataMaintenance maintenance;
  final EntityId Function() newGoalId;
  final EntityId Function() newFactId;
  final int Function() now;
  final String? versionLabel;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

enum _View { home, display, recording, advanced, about }

class _SettingsPageState extends State<SettingsPage> {
  _View view = _View.home;
  AppPreferences? prefs;
  DataCounts? counts;
  bool busy = false;
  String? error;
  String? status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      error = null;
      prefs = null;
      counts = null;
    });
    try {
      final preferences = await widget.preferences.read();
      final counts = await widget.maintenance.counts();
      if (!mounted) return;
      setState(() {
        prefs = preferences;
        this.counts = counts;
      });
    } catch (_) {
      if (mounted) setState(() => error = '设置暂时读不出来，再试一次吧。');
    }
  }

  Future<void> _savePreference(
    AppPreferences Function(AppPreferences) change,
  ) async {
    if (busy) return;
    final previous = prefs;
    final next = change(previous!);
    setState(() {
      busy = true;
      error = null;
      status = null;
      prefs = next;
    });
    try {
      await widget.preferences.write(next);
      if (!mounted) return;
      setState(() => status = '设置已保存。');
    } catch (_) {
      if (mounted) {
        setState(() {
          prefs = previous;
          error = '没保存成功，仍使用之前的设置。再试一次吧。';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _confirmClear() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空当前数据？'),
        content: const Text(
          '会清空记录、睡眠、目标、复盘和未完成的填写，并清除常用目标选择。'
          '界面、记录方式和提醒设置会保留。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('settings-confirm-clear'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    await _runData(() async {
      await widget.maintenance.clear();
      await _savePreference(
        (current) => current.copyWith(clearCommonGoal: true),
      );
    }, '数据已清空，设置已保留。');
  }

  Future<void> _confirmSeed() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加测试数据？'),
        content: const Text('将添加今天及之前六天的示例记录。设置保持原样，测试目标不会自动设为常用。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('settings-confirm-seed'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认添加'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    await _runData(() async {
      await widget.maintenance.seed(
        newGoalId: widget.newGoalId,
        newFactId: widget.newFactId,
        now: widget.now(),
      );
    }, '测试数据已添加。');
  }

  Future<void> _runData(
    Future<void> Function() operation,
    String message,
  ) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      status = null;
    });
    try {
      await operation();
      final counts = await widget.maintenance.counts();
      if (!mounted) return;
      setState(() {
        this.counts = counts;
        status = message;
      });
    } on DataMaintenanceConflict {
      if (mounted) setState(() => error = '已有数据，不能添加测试数据。');
    } catch (_) {
      if (mounted) setState(() => error = '操作失败，数据没有改变。再试一次吧。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: homeTheme,
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(
          key: const ValueKey('settings-back'),
          onPressed: () {
            if (view == _View.home) {
              Navigator.pop(context);
            } else {
              setState(() {
                view = _View.home;
                error = null;
                status = null;
              });
            }
          },
        ),
        title: Text(_title),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              TimeLedgerSpacing.page,
              TimeLedgerSpacing.xxs,
              TimeLedgerSpacing.page,
              TimeLedgerSpacing.xl,
            ),
            children: [
              if (error != null) ...[
                _error(error!),
                const SizedBox(height: 12),
              ],
              if (status != null) ...[
                _note(status!),
                const SizedBox(height: 12),
              ],
              ..._body(),
            ],
          ),
        ),
      ),
    ),
  );

  String get _title => switch (view) {
    _View.home => '设置',
    _View.display => '界面设置',
    _View.recording => '记录与提醒',
    _View.advanced => '高级设置',
    _View.about => '关于',
  };

  List<Widget> _body() {
    final prefs = this.prefs;
    if (prefs == null) {
      return const [
        SizedBox(height: 40),
        Center(child: CircularProgressIndicator()),
      ];
    }
    switch (view) {
      case _View.home:
        return [
          _entry(
            _View.display,
            '界面设置',
            '目标热力图 · ${_rangeText(prefs)}',
            Icons.tune,
          ),
          _entry(
            _View.recording,
            '记录与提醒',
            '${_modeText(prefs)} · 首页提醒${prefs.reminders == false ? '已关闭' : '已开启'}',
            Icons.edit_note,
          ),
          _entry(_View.advanced, '高级设置', '测试数据与数据清空', Icons.settings),
          _entry(_View.about, '关于', '日账本 · 版本信息', Icons.info_outline),
        ];
      case _View.display:
        return [
          _sectionHeader(
            '目标热力图',
            value: _rangeText(prefs),
            valueKey: const ValueKey('settings-heat-current'),
          ),
          for (final range in HeatRange.values)
            _choice(
              key: 'settings-heat-${range.name}',
              selected: prefs.heatRange == range,
              title: range == HeatRange.week ? '本周' : '本月',
              description: range == HeatRange.week ? '查看本自然周的投入' : '查看本自然月的投入',
              onTap: busy
                  ? null
                  : () => _savePreference((c) => c.copyWith(heatRange: range)),
            ),
        ];
      case _View.recording:
        return [
          _sectionHeader(
            '记录方式',
            value: _modeText(prefs),
            valueKey: const ValueKey('settings-mode-current'),
          ),
          for (final mode in RecordingMode.values)
            _choice(
              key: 'settings-mode-${mode.name}',
              selected: prefs.recordingMode == mode,
              title: mode == RecordingMode.guided ? '问答引导' : '表单',
              description: mode == RecordingMode.guided
                  ? '一步步回想，再记下来'
                  : '在一页中填写记录',
              onTap: busy
                  ? null
                  : () =>
                        _savePreference((c) => c.copyWith(recordingMode: mode)),
            ),
          const SizedBox(height: TimeLedgerSpacing.xl),
          Text('提醒', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: TimeLedgerSpacing.xxs),
          _toggleRow(
            key: const ValueKey('settings-reminders'),
            value: prefs.reminders ?? true,
            onChanged: busy
                ? null
                : (value) =>
                      _savePreference((c) => c.copyWith(reminders: value)),
            title: '首页提醒',
            subtitle: prefs.reminders == false
                ? '首页不再显示提醒与问候区域。'
                : '打开首页时，提醒睡眠、补记或复盘。',
          ),
          _timeRow(
            key: 'settings-sleep-reminder',
            label: '提醒记录睡眠',
            minutes: prefs.sleepReminderMinutes ?? defaultSleepReminderMinutes,
            enabled: prefs.reminders != false && !busy,
            onTap: () => _pickReminderTime(
              current:
                  prefs.sleepReminderMinutes ?? defaultSleepReminderMinutes,
              onPicked: (minutes) => _savePreference(
                (c) => c.copyWith(sleepReminderMinutes: minutes),
              ),
            ),
          ),
          _timeRow(
            key: 'settings-review-reminder',
            label: '提醒复盘',
            minutes:
                prefs.reviewReminderMinutes ?? defaultReviewReminderMinutes,
            enabled: prefs.reminders != false && !busy,
            onTap: () => _pickReminderTime(
              current:
                  prefs.reviewReminderMinutes ?? defaultReviewReminderMinutes,
              onPicked: (minutes) => _savePreference(
                (c) => c.copyWith(reviewReminderMinutes: minutes),
              ),
            ),
          ),
        ];
      case _View.advanced:
        final counts = this.counts;
        if (counts == null) {
          return const [
            SizedBox(height: 40),
            Center(child: CircularProgressIndicator()),
          ];
        }
        return [
          _sectionHeader('当前数据'),
          if (counts.isEmpty)
            Text('目前还没有数据。', style: Theme.of(context).textTheme.bodySmall)
          else
            _countsList(counts),
          const SizedBox(height: TimeLedgerSpacing.xl),
          Text('数据操作', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: TimeLedgerSpacing.xxs),
          _action(
            key: 'settings-seed',
            icon: Icons.storage,
            label: '添加测试数据',
            onTap: counts.isEmpty && !busy ? _confirmSeed : null,
          ),
          Text(
            counts.isEmpty ? '添加今天及之前六天的示例记录，方便体验。' : '已有数据，暂时不能添加测试数据。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: TimeLedgerSpacing.lg),
          _action(
            key: 'settings-clear',
            icon: Icons.delete_outline,
            label: '清空当前数据',
            onTap: counts.isEmpty || busy ? null : _confirmClear,
            destructive: true,
          ),
          Text(
            counts.isEmpty ? '目前没有需要清空的数据。' : '清空记录、目标、复盘和未完成的填写，保留设置。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ];
      case _View.about:
        return [
          Text('日账本', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: TimeLedgerSpacing.xxs),
          Text('把一天慢慢记清楚。', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: TimeLedgerSpacing.lg),
          _aboutRow('应用名称', 'Time Pet Ledger'),
          _aboutRow('版本', widget.versionLabel ?? '—'),
        ];
    }
  }

  Widget _entry(
    _View target,
    String title,
    String description,
    IconData icon,
  ) => Semantics(
    button: true,
    child: InkWell(
      key: ValueKey('settings-open-${target.name}'),
      onTap: busy
          ? null
          : () => setState(() {
              view = target;
              error = null;
              status = null;
            }),
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(vertical: TimeLedgerSpacing.sm),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: HomePalette.hairline)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: HomePalette.muted),
            const SizedBox(width: TimeLedgerSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: TimeLedgerSpacing.xxs),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: HomePalette.muted),
          ],
        ),
      ),
    ),
  );

  Widget _sectionHeader(String title, {String? value, Key? valueKey}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: TimeLedgerSpacing.xs),
        child: Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (value != null) ...[
              const Spacer(),
              Text(
                value,
                key: valueKey,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: HomePalette.accentDeep),
              ),
            ],
          ],
        ),
      );

  Widget _choice({
    required String key,
    required bool selected,
    required String title,
    required String description,
    required VoidCallback? onTap,
  }) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      key: ValueKey(key),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(vertical: TimeLedgerSpacing.xs),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: HomePalette.hairline)),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: selected ? HomePalette.accentDeep : HomePalette.muted,
            ),
            const SizedBox(width: TimeLedgerSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: TimeLedgerSpacing.xxs),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _toggleRow({
    required Key key,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required String title,
    required String subtitle,
  }) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: HomePalette.hairline)),
    ),
    child: SwitchListTile.adaptive(
      key: key,
      value: value,
      onChanged: onChanged,
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      contentPadding: EdgeInsets.zero,
    ),
  );

  /// 可编辑的提醒时点行：显示当前时分，点击打开时间选择（Q-029）。
  Widget _timeRow({
    required String key,
    required String label,
    required int minutes,
    required bool enabled,
    required VoidCallback onTap,
  }) => InkWell(
    key: ValueKey(key),
    onTap: enabled ? onTap : null,
    child: Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(vertical: TimeLedgerSpacing.xs),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HomePalette.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleMedium),
          ),
          Text(
            _formatMinutes(minutes),
            key: ValueKey('$key-value'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(width: TimeLedgerSpacing.xs),
          Icon(
            Icons.schedule,
            size: 20,
            color: enabled ? HomePalette.accentDeep : HomePalette.muted,
          ),
        ],
      ),
    ),
  );

  Future<void> _pickReminderTime({
    required int current,
    required void Function(int minutes) onPicked,
  }) async {
    final picked = await showLedgerClockPicker(
      context,
      initial: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (!mounted || picked == null) return;
    onPicked(picked.hour * 60 + picked.minute);
  }

  static String _formatMinutes(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  Widget _countsList(DataCounts counts) => Column(
    children: [
      _countRow('活动记录', '${counts.activities}条'),
      _countRow('睡眠记录', '${counts.sleep}条'),
      _countRow('目标', '${counts.goals}个'),
      _countRow('每日复盘', '${counts.reviews}条'),
    ],
  );

  Widget _countRow(String label, String value) => Container(
    constraints: const BoxConstraints(minHeight: homeTapTarget),
    padding: const EdgeInsets.symmetric(vertical: TimeLedgerSpacing.xs),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: HomePalette.hairline)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );

  Widget _aboutRow(String label, String value) => Container(
    constraints: const BoxConstraints(minHeight: homeTapTarget),
    padding: const EdgeInsets.symmetric(vertical: TimeLedgerSpacing.xs),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: HomePalette.hairline)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Flexible(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );

  Widget _action({
    required String key,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool destructive = false,
  }) => InkWell(
    key: ValueKey(key),
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(vertical: TimeLedgerSpacing.xs),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HomePalette.hairline)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: onTap == null
                ? HomePalette.faint
                : destructive
                ? HomePalette.error
                : HomePalette.accentDeep,
          ),
          const SizedBox(width: TimeLedgerSpacing.sm),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: onTap == null
                  ? HomePalette.faint
                  : destructive
                  ? HomePalette.error
                  : HomePalette.accentDeep,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _note(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(TimeLedgerSpacing.sm),
    decoration: BoxDecoration(
      color: HomePalette.tint,
      borderRadius: BorderRadius.circular(TimeLedgerRadius.panel),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: HomePalette.recovery),
    ),
  );

  Widget _error(String text) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: HomePalette.error),
  );

  String _rangeText(AppPreferences prefs) => switch (prefs.heatRange) {
    HeatRange.week => '本周',
    HeatRange.month => '本月',
    null => '未设置',
  };

  String _modeText(AppPreferences prefs) => switch (prefs.recordingMode) {
    RecordingMode.guided => '问答引导',
    RecordingMode.form => '表单',
    null => '未设置',
  };
}
