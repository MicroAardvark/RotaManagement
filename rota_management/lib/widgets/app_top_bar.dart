import 'package:flutter/material.dart';
import '../services/session_store.dart';
import 'staff_avatar.dart';

/// Primary purple used across the reference design — swap this if you
/// want the top bar in a different shade to the rest of the app.
const Color _kTopBarColor = Color(0xFF5B21B6);

/// Shared top navigation bar. Implements PreferredSizeWidget so it can
/// be dropped straight into Scaffold(appBar: const AppTopBar()).
///
/// Manager items show when [isManager] is passed as true, or when the
/// logged-in user (from SessionStore) is a manager.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  /// Which nav item is currently active, for highlighting. Pass the
  /// label exactly as it appears in [_navItems], e.g. 'Home'.
  final String activeItem;
  final bool isManager;

  const AppTopBar({super.key, this.activeItem = 'Home', this.isManager = false});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  List<_NavItem> _buildNavItems(bool isManager) {
    return [
      _NavItem('Home', route: '/home'),
      _NavItem('Rotas', children: [
        _NavChild('View rota', route: '/rota'),
        if (isManager) _NavChild('Edit rota', route: '/rota/edit'),
      ]),
      // _NavItem('Cost control', children: [
      //   _NavChild('Overview', route: '/cost-control'),
      //   _NavChild('Budgets', route: '/cost-control/budgets'),
      // ]),
      if (isManager) _NavItem('Manage', children: [
        _NavChild('Staff', route: '/staff'),
        _NavChild('Clients', route: '/clients'),
        _NavChild('Job types', route: '/job-types'),
      ]),
      // _NavItem('Attendance', route: '/attendance'),
      _NavItem('Settings', route: '/settings'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SessionStore.instance,
      builder: (context, _) => _buildBar(context, SessionStore.instance.user),
    );
  }

  Widget _buildBar(BuildContext context, CurrentUser? user) {
    final showManagerItems = isManager || (user?.isManager ?? false);
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: _kTopBarColor,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          // Logo — swap for Image.asset('assets/logo.png', height: 28)
          // once you've got a mark to drop in.
          const Icon(Icons.cleaning_services, color: Colors.white, size: 24),
          const SizedBox(width: 24),
          ..._buildNavItems(showManagerItems).map((item) => _buildNavItem(context, item)),
        ],
      ),
      actions: [
        // IconButton(
        //   icon: const Icon(Icons.notifications_none, color: Colors.white),
        //   onPressed: () {},
        // ),
        // IconButton(
        //   icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
        //   onPressed: () {},
        // ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Your profile',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: activeItem == 'Profile'
                ? null
                : () => Navigator.of(context).pushNamed('/profile'),
            child: user == null
                ? const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, color: Colors.white, size: 18),
                  )
                : StaffAvatar(
                    id: user.id,
                    name: user.name,
                    photoVersion: user.photoVersion,
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                  ),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildNavItem(BuildContext context, _NavItem item) {
    final isActive = item.label == activeItem;

    if (item.children == null) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: _NavButton(
          label: item.label,
          isActive: isActive,
          onTap: () {
            if (item.route != null) Navigator.of(context).pushNamed(item.route!);
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 44),
        color: Colors.white,
        onSelected: (route) => Navigator.of(context).pushNamed(route),
        itemBuilder: (context) => item.children!
            .map((child) => PopupMenuItem<String>(
                  value: child.route,
                  child: Text(child.label),
                ))
            .toList(),
        child: _NavButton(
          label: item.label,
          isActive: isActive,
          hasDropdown: true,
          onTap: null, // handled by PopupMenuButton itself
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool hasDropdown;
  final VoidCallback? onTap;

  const _NavButton({
    required this.label,
    required this.isActive,
    this.hasDropdown = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isActive ? _kTopBarColor : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          if (hasDropdown) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: isActive ? _kTopBarColor : Colors.white,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: content,
    );
  }
}

class _NavItem {
  final String label;
  final String? route;
  final List<_NavChild>? children;

  _NavItem(this.label, {this.route, this.children});
}

class _NavChild {
  final String label;
  final String route;

  _NavChild(this.label, {required this.route});
}