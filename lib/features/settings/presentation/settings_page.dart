import '../../ledger/presentation/recording_time_picker.dart'
    show showLedgerClockPicker;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/home_theme.dart';
import '../../../app/theme/semantic_colors.dart';
import '../../../core/identity/entity_id.dart';
import '../../ledger/application/home_suggestion.dart';
import '../domain/app_preferences.dart';
import '../domain/data_overview.dart';

/// 设置页：分组入口（界面设置 / 记录与提醒 / 高级设置 / 关于）。
///
/// 视觉按用户 2026-10-10 参考稿重设计：分组圆角卡片、圆形图标、
/// 行尾当前值 / 开关；多选在底部面板中完成（主题模式、自选主题色、
/// 字体、记录方式）。偏好通过 [AppPreferencesStore] 本机存取；高级操作
/// 通过 [DataMaintenance] 作用于正式事实；两者失败都不表现为成功。
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.preferences,
    required this.maintenance,
    required this.newGoalId,
    required this.newFactId,
    required this.now,
    this.versionLabel,
    this.onSaved,
  });

  final AppPreferencesStore preferences;
  final DataMaintenance maintenance;
  final EntityId Function() newGoalId;
  final EntityId Function() newFactId;
  final int Function() now;
  final String? versionLabel;

  /// 偏好保存成功后的通知（根主题即时重建用；Q-041）。
  final ValueChanged<AppPreferences>? onSaved;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

enum _View { home, display, recording, advanced, about }

class _SettingsPageState extends State<SettingsPage> {
  ColorScheme get _colors => Theme.of(context).colorScheme;
  TextTheme get _text => Theme.of(context).textTheme;
  TimeLedgerSemanticColors get _semantics => context.semanticColors;
  _View view = _View.home;
  AppPreferences? prefs;
  DataCounts? counts;
  bool busy = false;
  String? error;
  String? status;

  /// 关闭动态色彩时恢复的上一次自选方案（仅会话内记忆）。
  ThemeScheme? _lastPreset;

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
      final saved = preferences.themeScheme;
      if (saved != null && saved != ThemeScheme.dynamic) _lastPreset = saved;
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
      widget.onSaved?.call(next);
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
  Widget build(BuildContext context) => Scaffold(
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
            TimeLedgerSpacing.xxl,
          ),
          children: [
            if (error != null) ...[_error(error!), const SizedBox(height: 12)],
            if (status != null) ...[_note(status!), const SizedBox(height: 12)],
            ..._body(),
          ],
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
      return [
        const SizedBox(height: 40),
        // 读取失败时给出重试入口，不保留无限加载指示（失败可恢复）。
        if (error == null)
          const Center(child: CircularProgressIndicator())
        else
          Center(
            child: TextButton(
              key: const ValueKey('settings-retry'),
              onPressed: _load,
              child: const Text('重试读取'),
            ),
          ),
      ];
    }
    switch (view) {
      case _View.home:
        return [
          _card([
            _navRow(
              key: const ValueKey('settings-open-display'),
              icon: Icons.tune,
              title: '界面设置',
              subtitle:
                  '快捷区${_quickPanelSideText(prefs)} · 目标热力图 · ${_rangeText(prefs)}',
              target: _View.display,
            ),
            _navRow(
              key: const ValueKey('settings-open-recording'),
              icon: Icons.edit_note,
              title: '记录与提醒',
              subtitle: '首页提醒${prefs.reminders == false ? '已关闭' : '已开启'}',
              target: _View.recording,
            ),
            _navRow(
              key: const ValueKey('settings-open-advanced'),
              icon: Icons.settings,
              title: '高级设置',
              subtitle: '测试数据与数据清空',
              target: _View.advanced,
            ),
            _navRow(
              key: const ValueKey('settings-open-about'),
              icon: Icons.info_outline,
              title: '关于',
              subtitle: '日账本 · 版本信息',
              target: _View.about,
            ),
          ]),
        ];
      case _View.display:
        final scheme = prefs.themeScheme ?? ThemeScheme.defaultM3;
        final isDynamic = scheme == ThemeScheme.dynamic;
        return [
          _sectionLabel('主题'),
          DynamicColorBuilder(
            builder: (lightDynamic, darkDynamic) {
              final dynamicAvailable =
                  lightDynamic != null && darkDynamic != null;
              return _card([
                _row(
                  key: const ValueKey('settings-theme-mode'),
                  icon: Icons.brightness_6_outlined,
                  title: '主题模式',
                  subtitle: '浅色 / 深色 / 跟随系统',
                  trailing: _navTrailing(
                    _themeModeText(prefs),
                    valueKey: const ValueKey('settings-theme-mode-current'),
                  ),
                  onTap: busy ? null : () => _pickThemeMode(prefs),
                ),
                if (dynamicAvailable)
                  _row(
                    icon: Icons.wallpaper_outlined,
                    title: '动态色彩',
                    subtitle: isDynamic ? '已根据壁纸生成主题色' : '未启用 · 使用自选主题色',
                    trailing: Switch(
                      key: const ValueKey('settings-theme-dynamic'),
                      value: isDynamic,
                      onChanged: busy
                          ? null
                          : (value) => _setDynamic(value, prefs),
                    ),
                  ),
                _row(
                  key: const ValueKey('settings-theme-picker'),
                  icon: Icons.palette_outlined,
                  title: '自选主题色',
                  subtitle: isDynamic ? '选择后将关闭动态色彩' : '选择一款主题配色',
                  trailing: _navTrailing(
                    isDynamic ? '未选择' : _schemeTitle(scheme),
                    valueKey: const ValueKey('settings-theme-current'),
                  ),
                  onTap: busy ? null : () => _pickThemeScheme(prefs),
                ),
              ]);
            },
          ),
          _sectionLabel('字体'),
          _card([
            _row(
              key: const ValueKey('settings-font'),
              icon: Icons.text_fields,
              title: '字体',
              subtitle: '系统字体 / 衬线字体',
              trailing: _navTrailing(
                _fontText(prefs),
                valueKey: const ValueKey('settings-font-current'),
              ),
              onTap: busy ? null : () => _pickFont(prefs),
            ),
          ]),
          _sectionLabel(
            '快捷区位置',
            value: _quickPanelSideText(prefs),
            valueKey: const ValueKey('settings-quick-panel-current'),
          ),
          _card([
            for (final side in HomeQuickPanelSide.values)
              _choiceRow(
                key: 'settings-quick-panel-${side.name}',
                selected:
                    (prefs.homeQuickPanelSide ?? HomeQuickPanelSide.left) ==
                    side,
                title: side == HomeQuickPanelSide.left ? '左侧' : '右侧',
                description: side == HomeQuickPanelSide.left
                    ? '向右滑打开，菜单在日期行左侧'
                    : '向左滑打开，菜单在日期行右侧',
                onTap: busy
                    ? null
                    : () => _savePreference(
                        (c) => c.copyWith(homeQuickPanelSide: side),
                      ),
              ),
            _row(
              icon: Icons.menu,
              title: '显示菜单按钮',
              subtitle: (prefs.showHomeMenuButton ?? true)
                  ? '日期行显示菜单按钮；关闭后从屏幕边缘滑出快捷区。'
                  : '已隐藏；从屏幕边缘滑出快捷区。',
              trailing: Switch(
                key: const ValueKey('settings-menu-button'),
                value: prefs.showHomeMenuButton ?? true,
                onChanged: busy
                    ? null
                    : (value) => _savePreference(
                        (c) => c.copyWith(showHomeMenuButton: value),
                      ),
              ),
            ),
          ]),
          _sectionLabel('目标热力图', value: _rangeText(prefs)),
          _card([
            for (final range in HeatRange.values)
              _choiceRow(
                key: 'settings-heat-${range.name}',
                selected: prefs.heatRange == range,
                title: range == HeatRange.week ? '本周' : '本月',
                description: range == HeatRange.week
                    ? '查看本自然周的投入'
                    : '查看本自然月的投入',
                onTap: busy
                    ? null
                    : () =>
                          _savePreference((c) => c.copyWith(heatRange: range)),
              ),
          ]),
        ];
      case _View.recording:
        return [
          _sectionLabel('提醒'),
          _card([
            _row(
              icon: Icons.notifications_none,
              title: '首页提醒',
              subtitle: prefs.reminders == false
                  ? '首页不再显示提醒与问候区域。'
                  : '打开首页时，提醒睡眠、补记或复盘。',
              trailing: Switch(
                key: const ValueKey('settings-reminders'),
                value: prefs.reminders ?? true,
                onChanged: busy
                    ? null
                    : (value) =>
                          _savePreference((c) => c.copyWith(reminders: value)),
              ),
            ),
            _row(
              key: const ValueKey('settings-sleep-reminder'),
              icon: Icons.bedtime_outlined,
              title: '提醒记录睡眠',
              enabled: prefs.reminders != false && !busy,
              trailing: _timeTrailing(
                key: 'settings-sleep-reminder',
                minutes:
                    prefs.sleepReminderMinutes ?? defaultSleepReminderMinutes,
              ),
              onTap: () => _pickReminderTime(
                current:
                    prefs.sleepReminderMinutes ?? defaultSleepReminderMinutes,
                onPicked: (minutes) => _savePreference(
                  (c) => c.copyWith(sleepReminderMinutes: minutes),
                ),
              ),
            ),
            _row(
              key: const ValueKey('settings-review-reminder'),
              icon: Icons.menu_book_outlined,
              title: '提醒复盘',
              enabled: prefs.reminders != false && !busy,
              trailing: _timeTrailing(
                key: 'settings-review-reminder',
                minutes:
                    prefs.reviewReminderMinutes ?? defaultReviewReminderMinutes,
              ),
              onTap: () => _pickReminderTime(
                current:
                    prefs.reviewReminderMinutes ?? defaultReviewReminderMinutes,
                onPicked: (minutes) => _savePreference(
                  (c) => c.copyWith(reviewReminderMinutes: minutes),
                ),
              ),
            ),
          ]),
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
          _sectionLabel('当前数据'),
          _card(
            counts.isEmpty
                ? [
                    _row(
                      icon: Icons.inbox_outlined,
                      title: '目前还没有数据',
                      subtitle: '添加测试数据后，这里会显示各类数量。',
                    ),
                  ]
                : [
                    _row(
                      icon: Icons.schedule,
                      title: '活动记录',
                      trailing: _value('${counts.activities}条'),
                    ),
                    _row(
                      icon: Icons.bedtime_outlined,
                      title: '睡眠记录',
                      trailing: _value('${counts.sleep}条'),
                    ),
                    _row(
                      icon: Icons.flag_outlined,
                      title: '目标',
                      trailing: _value('${counts.goals}个'),
                    ),
                    _row(
                      icon: Icons.menu_book_outlined,
                      title: '每日复盘',
                      trailing: _value('${counts.reviews}条'),
                    ),
                  ],
          ),
          _sectionLabel('数据操作'),
          _card([
            _row(
              key: const ValueKey('settings-seed'),
              icon: Icons.storage,
              title: '添加测试数据',
              subtitle: counts.isEmpty
                  ? '添加今天及之前六天的示例记录，方便体验。'
                  : '已有数据，暂时不能添加测试数据。',
              enabled: counts.isEmpty && !busy,
              onTap: _confirmSeed,
            ),
            _row(
              key: const ValueKey('settings-clear'),
              icon: Icons.delete_outline,
              title: '清空当前数据',
              subtitle: counts.isEmpty
                  ? '目前没有需要清空的数据。'
                  : '清空记录、目标、复盘和未完成的填写，保留设置。',
              destructive: true,
              enabled: !counts.isEmpty && !busy,
              onTap: _confirmClear,
            ),
          ]),
        ];
      case _View.about:
        return [
          const SizedBox(height: 8),
          Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.menu_book_outlined,
                  size: 30,
                  color: _colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 12),
              Text('日账本', style: _text.headlineSmall),
              const SizedBox(height: 4),
              Text(
                '把一天慢慢记清楚。',
                style: _text.bodySmall?.copyWith(
                  color: _colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _card([
            _row(
              icon: Icons.badge_outlined,
              title: '应用名称',
              trailing: _value('Time Pet Ledger'),
            ),
            _row(
              icon: Icons.tag,
              title: '版本',
              trailing: _value(widget.versionLabel ?? '—'),
            ),
          ]),
        ];
    }
  }

  // ----- navigation -----

  Widget _navRow({
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required _View target,
  }) => _row(
    key: key,
    icon: icon,
    title: title,
    subtitle: subtitle,
    trailing: _navTrailing(null),
    onTap: busy
        ? null
        : () => setState(() {
            view = target;
            error = null;
            status = null;
          }),
  );

  // ----- bottom sheets -----

  Future<void> _pickThemeMode(AppPreferences prefs) => _showOptionsSheet(
    title: '主题模式',
    subtitle: '切换浅色 / 深色 / 跟随系统',
    children: [
      for (final mode in AppThemeMode.values)
        _sheetTile(
          key: 'settings-theme-mode-${mode.name}',
          selected: (prefs.themeMode ?? AppThemeMode.system) == mode,
          title: _modeTitle(mode),
          description: _modeDescription(mode),
          onTap: () {
            Navigator.pop(context);
            _savePreference((c) => c.copyWith(themeMode: mode));
          },
        ),
    ],
  );

  Future<void> _pickFont(AppPreferences prefs) => _showOptionsSheet(
    title: '字体',
    subtitle: '与任意配色自由组合',
    children: [
      for (final font in AppFontChoice.values)
        _sheetTile(
          key: 'settings-font-${font.name}',
          selected: (prefs.fontChoice ?? AppFontChoice.system) == font,
          title: font == AppFontChoice.system ? '系统字体' : '衬线（NotoSerifSC）',
          description: font == AppFontChoice.system
              ? '跟随平台默认字体'
              : '暖纸主题使用的衬线字体',
          onTap: () {
            Navigator.pop(context);
            _savePreference((c) => c.copyWith(fontChoice: font));
          },
        ),
    ],
  );

  void _setDynamic(bool value, AppPreferences prefs) {
    if (value) {
      final current = prefs.themeScheme;
      if (current != null && current != ThemeScheme.dynamic) {
        _lastPreset = current;
      }
      _savePreference((c) => c.copyWith(themeScheme: ThemeScheme.dynamic));
      return;
    }
    _savePreference(
      (c) => c.copyWith(themeScheme: _lastPreset ?? ThemeScheme.defaultM3),
    );
  }

  Future<void> _pickThemeScheme(AppPreferences prefs) async {
    final current = prefs.themeScheme ?? ThemeScheme.defaultM3;
    await _showOptionsSheet(
      title: '自选主题色',
      subtitle: current == ThemeScheme.dynamic ? '选择后将关闭动态色彩' : '选择一款主题配色',
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
          children: [
            for (final scheme in const [
              ThemeScheme.defaultM3,
              ThemeScheme.blue,
              ThemeScheme.green,
              ThemeScheme.orange,
              ThemeScheme.teal,
              ThemeScheme.warmPaper,
            ])
              _schemeCell(scheme, current),
          ],
        ),
      ],
    );
  }

  Widget _schemeCell(ThemeScheme scheme, ThemeScheme current) {
    final preview = previewLightScheme(scheme);
    final selected = current == scheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: InkWell(
            key: ValueKey('settings-theme-${scheme.name}'),
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.pop(context);
              _lastPreset = scheme;
              _savePreference((c) => c.copyWith(themeScheme: scheme));
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: preview.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? _colors.primary : preview.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Abc',
                    style: TextStyle(
                      color: preview.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 5,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: preview.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    height: 5,
                    width: 36,
                    decoration: BoxDecoration(
                      color: preview.secondary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: preview.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _schemeTitle(scheme),
          textAlign: TextAlign.center,
          style: _text.bodySmall?.copyWith(
            color: selected ? _colors.primary : _colors.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }

  Future<void> _showOptionsSheet({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(
        TimeLedgerSpacing.page,
        0,
        TimeLedgerSpacing.page,
        TimeLedgerSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: _text.titleLarge),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: _text.bodySmall?.copyWith(color: _colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  Widget _sheetTile({
    required String key,
    required bool selected,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) => InkWell(
    key: ValueKey(key),
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TimeLedgerSpacing.xxs,
        vertical: TimeLedgerSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 22,
            color: selected ? _colors.primary : _colors.onSurfaceVariant,
          ),
          const SizedBox(width: TimeLedgerSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _text.titleMedium),
                const SizedBox(height: 2),
                Text(description, style: _text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  // ----- components -----

  Widget _sectionLabel(String title, {String? value, Key? valueKey}) => Padding(
    padding: const EdgeInsets.fromLTRB(
      TimeLedgerSpacing.xxs,
      TimeLedgerSpacing.md,
      TimeLedgerSpacing.xxs,
      TimeLedgerSpacing.xs,
    ),
    child: Row(
      children: [
        Text(title, style: _text.titleSmall?.copyWith(color: _colors.primary)),
        if (value != null) ...[
          const Spacer(),
          Text(
            value,
            key: valueKey,
            style: _text.labelMedium?.copyWith(color: _colors.onSurfaceVariant),
          ),
        ],
      ],
    ),
  );

  Widget _card(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: TimeLedgerSpacing.xxs),
    decoration: BoxDecoration(
      color: _colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 1,
              indent: TimeLedgerSpacing.md,
              endIndent: TimeLedgerSpacing.md,
              color: _colors.outlineVariant,
            ),
          children[i],
        ],
      ],
    ),
  );

  Widget _row({
    Key? key,
    IconData? icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool destructive = false,
    bool enabled = true,
  }) {
    final active = enabled && onTap != null;
    final titleColor = !enabled
        ? _colors.outline
        : destructive
        ? _colors.error
        : _colors.onSurface;
    return InkWell(
      key: key,
      onTap: active ? onTap : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TimeLedgerSpacing.md,
            vertical: TimeLedgerSpacing.sm,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _colors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: !enabled
                        ? _colors.outline
                        : destructive
                        ? _colors.error
                        : _colors.primary,
                  ),
                ),
                const SizedBox(width: TimeLedgerSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: _text.titleMedium?.copyWith(color: titleColor),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: _text.bodySmall),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: TimeLedgerSpacing.sm),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _choiceRow({
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TimeLedgerSpacing.md,
            vertical: TimeLedgerSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20,
                color: selected ? _colors.primary : _colors.onSurfaceVariant,
              ),
              const SizedBox(width: TimeLedgerSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: _text.titleMedium),
                    const SizedBox(height: 2),
                    Text(description, style: _text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _navTrailing(String? value, {Key? valueKey}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (value != null)
        Text(
          value,
          key: valueKey,
          style: _text.labelLarge?.copyWith(color: _colors.onSurfaceVariant),
        ),
      const SizedBox(width: TimeLedgerSpacing.xxs),
      Icon(Icons.chevron_right, size: 20, color: _colors.onSurfaceVariant),
    ],
  );

  Widget _timeTrailing({required String key, required int minutes}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        _formatMinutes(minutes),
        key: ValueKey('$key-value'),
        style: _text.labelLarge?.copyWith(color: _colors.onSurfaceVariant),
      ),
      const SizedBox(width: TimeLedgerSpacing.xxs),
      Icon(Icons.chevron_right, size: 20, color: _colors.onSurfaceVariant),
    ],
  );

  Widget _value(String text) => Text(text, style: _text.bodyMedium);

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

  Widget _note(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(TimeLedgerSpacing.sm),
    decoration: BoxDecoration(
      color: _colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(TimeLedgerRadius.panel),
    ),
    child: Text(
      text,
      style: _text.bodyMedium?.copyWith(color: _semantics.recovery),
    ),
  );

  Widget _error(String text) =>
      Text(text, style: _text.bodyMedium?.copyWith(color: _colors.error));

  String _rangeText(AppPreferences prefs) => switch (prefs.heatRange) {
    HeatRange.week => '本周',
    HeatRange.month => '本月',
    null => '未设置',
  };

  String _schemeTitle(ThemeScheme scheme) => switch (scheme) {
    ThemeScheme.defaultM3 => '默认（紫）',
    ThemeScheme.blue => '蓝',
    ThemeScheme.green => '绿',
    ThemeScheme.orange => '橙',
    ThemeScheme.teal => '青',
    ThemeScheme.warmPaper => '暖纸',
    ThemeScheme.dynamic => '跟随壁纸',
  };

  String _themeModeText(AppPreferences prefs) =>
      _modeTitle(prefs.themeMode ?? AppThemeMode.system);

  String _modeTitle(AppThemeMode mode) => switch (mode) {
    AppThemeMode.system => '跟随系统',
    AppThemeMode.light => '浅色',
    AppThemeMode.dark => '深色',
  };

  String _modeDescription(AppThemeMode mode) => switch (mode) {
    AppThemeMode.system => '随系统明暗自动切换',
    AppThemeMode.light => '始终使用浅色',
    AppThemeMode.dark => '始终使用深色',
  };

  String _fontText(AppPreferences prefs) =>
      (prefs.fontChoice ?? AppFontChoice.system) == AppFontChoice.system
      ? '系统字体'
      : '衬线';

  String _quickPanelSideText(AppPreferences prefs) =>
      (prefs.homeQuickPanelSide ?? HomeQuickPanelSide.left) ==
          HomeQuickPanelSide.left
      ? '左侧'
      : '右侧';
}
