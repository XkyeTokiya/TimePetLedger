import 'package:flutter/material.dart';

import '../../../app/theme/home_theme.dart';
import '../../../core/identity/entity_id.dart';
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
          '会清空记录、睡眠、目标、复盘和未保存草稿，并清除常用目标选择。'
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
        content: const Text('将添加一组示例数据。设置保持原样，测试目标不会自动设为常用。'),
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
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
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
          const SizedBox(height: 4),
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
          Row(
            children: [
              Text('目标热力图', style: _sectionHeading),
              const Spacer(),
              Text(
                _rangeText(prefs),
                key: const ValueKey('settings-heat-current'),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
          Row(
            children: [
              Text('记录方式', style: _sectionHeading),
              const Spacer(),
              Text(
                _modeText(prefs),
                key: const ValueKey('settings-mode-current'),
              ),
            ],
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
          const SizedBox(height: 12),
          SwitchListTile(
            key: const ValueKey('settings-reminders'),
            value: prefs.reminders ?? true,
            onChanged: busy
                ? null
                : (value) =>
                      _savePreference((c) => c.copyWith(reminders: value)),
            title: const Text('首页提醒'),
            subtitle: Text(
              prefs.reminders == false ? '首页不再显示提醒与问候区域。' : '打开首页时，提醒睡眠、补记或复盘。',
            ),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          const Text('睡眠 08:00 · 复盘 22:00', style: _muted),
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
          Text('当前数据', style: _sectionHeading),
          const SizedBox(height: 8),
          if (counts.isEmpty)
            const Text('目前还没有数据。', style: _muted)
          else
            _countsList(counts),
          const SizedBox(height: 20),
          _action(
            key: 'settings-seed',
            icon: Icons.storage,
            label: '添加测试数据',
            onTap: counts.isEmpty && !busy ? _confirmSeed : null,
          ),
          Text(
            counts.isEmpty ? '添加一组示例记录，方便体验。' : '已有数据，暂时不能添加测试数据。',
            style: _muted,
          ),
          const SizedBox(height: 20),
          _action(
            key: 'settings-clear',
            icon: Icons.delete_outline,
            label: '清空当前数据',
            onTap: counts.isEmpty || busy ? null : _confirmClear,
          ),
          Text(
            counts.isEmpty ? '目前没有需要清空的数据。' : '清空记录、目标、复盘和草稿，保留设置。',
            style: _muted,
          ),
        ];
      case _View.about:
        return [
          const Text('日账本', style: _aboutMark),
          const SizedBox(height: 6),
          const Text('把一天慢慢记清楚。', style: _muted),
          const SizedBox(height: 16),
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
  ) => InkWell(
    key: ValueKey('settings-open-${target.name}'),
    onTap: busy
        ? null
        : () => setState(() {
            view = target;
            error = null;
            status = null;
          }),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HomePalette.hairline)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 26, color: HomePalette.muted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _entryTitle),
                const SizedBox(height: 3),
                Text(description, style: _muted),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: HomePalette.muted),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: HomePalette.hairline)),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 22,
              color: selected ? HomePalette.accentDeep : HomePalette.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _entryTitle),
                  const SizedBox(height: 2),
                  Text(description, style: _muted),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _countsList(DataCounts counts) => Column(
    children: [
      _countRow('活动记录', '${counts.activities}条'),
      _countRow('睡眠记录', '${counts.sleep}条'),
      _countRow('目标', '${counts.goals}个'),
      _countRow('每日复盘', '${counts.reviews}条'),
      _countRow('未保存草稿', '${counts.drafts}条'),
    ],
  );

  Widget _countRow(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: HomePalette.hairline)),
    ),
    child: Row(
      children: [
        Expanded(child: Text(label, style: _muted)),
        Text(value, style: _value),
      ],
    ),
  );

  Widget _aboutRow(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: HomePalette.hairline)),
    ),
    child: Row(
      children: [
        Expanded(child: Text(label, style: _muted)),
        Flexible(
          child: Text(value, style: _value, textAlign: TextAlign.right),
        ),
      ],
    ),
  );

  Widget _action({
    required String key,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) => InkWell(
    key: ValueKey(key),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 26,
            color: onTap == null ? HomePalette.muted : HomePalette.accentDeep,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontFamily: homeSerifFamily,
              fontSize: 21,
              color: onTap == null ? HomePalette.muted : HomePalette.accentDeep,
            ),
          ),
        ],
      ),
    ),
  );

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

const _sectionHeading = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 22,
  height: 1.5,
  fontWeight: FontWeight.w600,
  color: HomePalette.ink,
);
const _entryTitle = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 22,
  height: 1.5,
  color: HomePalette.ink,
);
const _aboutMark = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 38,
  height: 1.3,
  color: HomePalette.ink,
);
const _value = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 17,
  color: HomePalette.ink,
);
const _muted = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 14,
  height: 1.6,
  color: HomePalette.muted,
);
