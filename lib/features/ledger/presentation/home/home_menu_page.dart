import 'package:flutter/material.dart';

import '../../../../app/theme/home_theme.dart';

/// 左侧菜单页：只承接「我的目标」与「设置」两个入口。
///
/// 版式按贯通原型第一轮（assets/app-flow-round-one，菜单页只有这两项）。
/// 它是独立整页路由，不再用底部弹层充当菜单；账本自身的刷新与时间分布
/// 说明不占用菜单。
class HomeMenuPage extends StatelessWidget {
  const HomeMenuPage({super.key, this.goalsPage, this.settingsPage});

  /// 目标管理入口的页面构建器；为空时不显示该项。
  final Widget Function()? goalsPage;

  /// 设置入口的页面构建器；为空时不显示该项。
  final Widget Function()? settingsPage;

  @override
  Widget build(BuildContext context) => Theme(
    data: homeTheme,
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(key: const ValueKey('menu-back')),
        title: const Text('菜单'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          if (goalsPage != null)
            _Entry(
              key: const ValueKey('menu-goals'),
              icon: Icons.flag_outlined,
              label: '我的目标',
              // 菜单只是入口：目标 / 设置替换菜单路由，返回直接回首页。
              onTap: () => Navigator.of(context).pushReplacement<void, void>(
                MaterialPageRoute(builder: (_) => goalsPage!()),
              ),
            ),
          if (settingsPage != null)
            _Entry(
              key: const ValueKey('menu-settings'),
              icon: Icons.settings_outlined,
              label: '设置',
              onTap: () => Navigator.of(context).pushReplacement<void, void>(
                MaterialPageRoute(builder: (_) => settingsPage!()),
              ),
            ),
        ],
      ),
    ),
  );
}

class _Entry extends StatelessWidget {
  const _Entry({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: homeTapTarget + 8),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HomePalette.hairline)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 26, color: HomePalette.muted),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: homeSerifFamily,
                fontSize: 22,
                color: HomePalette.ink,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: HomePalette.muted),
        ],
      ),
    ),
  );
}
