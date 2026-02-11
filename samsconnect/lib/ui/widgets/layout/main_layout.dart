import 'package:flutter/material.dart';
import 'sidebar.dart';
import 'top_bar.dart';

class MainLayout extends StatelessWidget {
  final List<SidebarItem> sidebarItems;
  final String selectedSidebarId;
  final ValueChanged<String> onSidebarItemSelected;
  final Widget child; // The main content
  final String title; // Top bar title
  final List<Widget> actions; // Top bar actions
  final VoidCallback? onSettingsTap;
  final VoidCallback? onThemeToggle;

  const MainLayout({
    super.key,
    required this.sidebarItems,
    required this.selectedSidebarId,
    required this.onSidebarItemSelected,
    required this.child,
    this.title = '',
    this.actions = const [],
    this.onSettingsTap,
    this.onThemeToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 900;

    final sidebarWidget = Sidebar(
      items: sidebarItems,
      selectedId: selectedSidebarId,
      onItemSelected: (id) {
        onSidebarItemSelected(id);
        if (isMobile) {
          Navigator.of(context).maybePop(); // Close drawer on selection
        }
      },
      onSettingsTap: onSettingsTap,
      onThemeToggle: onThemeToggle,
    );

    return Scaffold(
      drawer: isMobile ? Drawer(child: sidebarWidget) : null,
      body: Row(
        children: [
          // Left Sidebar (Permanent on Desktop)
          if (!isMobile) ...[
            sidebarWidget,
            VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),
          ],

          // Main Content Area (Layout: TopBar + Content)
          Expanded(
            child: Column(
              children: [
                LayoutTopBar(
                  title: title,
                  actions: actions,
                  leading: isMobile
                      ? Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(Icons.menu),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                        )
                      : null,
                ),
                Expanded(
                  child: Container(
                    color: theme.scaffoldBackgroundColor,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
