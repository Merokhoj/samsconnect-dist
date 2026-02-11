import 'package:flutter/material.dart';

class SidebarItem {
  final String id;
  final String label;
  final IconData icon;
  final List<SidebarItem> children;
  final bool isExpanded;

  const SidebarItem({
    required this.id,
    required this.label,
    required this.icon,
    this.children = const [],
    this.isExpanded = true,
  });
}

class Sidebar extends StatelessWidget {
  final List<SidebarItem> items;
  final String selectedId;
  final ValueChanged<String> onItemSelected;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onThemeToggle;

  const Sidebar({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onItemSelected,
    this.onSettingsTap,
    this.onThemeToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        //  color: isDark ? const Color(0xFF030A1C) : Colors.white,
        border: Border(
          right: BorderSide(
            //   color: theme.colorScheme.outline.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo/Branding
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.tertiary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'SamsConnect',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _buildItem(context, items[index], level: 0);
              },
            ),
          ),

          // Bottom Actions
          if (onSettingsTap != null || onThemeToggle != null) ...[
            _buildBottomActions(context),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    SidebarItem item, {
    required int level,
  }) {
    final isSelected = item.id == selectedId;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (item.children.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Text(
              item.label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary.withValues(alpha: 0.8),
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                fontSize: 10,
              ),
            ),
          ),
          ...item.children.map(
            (child) => _buildItem(context, child, level: level + 1),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onItemSelected(item.id),
          borderRadius: BorderRadius.circular(12),
          hoverColor: theme.colorScheme.primary.withValues(alpha: 0.05),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color:
                  isSelected ? theme.colorScheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected && !isDark
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          if (onThemeToggle != null)
            _ActionButton(
              icon: theme.brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              onPressed: onThemeToggle!,
              tooltip: 'Theme',
            ),
          if (onSettingsTap != null)
            _ActionButton(
              icon: Icons.settings_outlined,
              onPressed: onSettingsTap!,
              tooltip: 'Settings',
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _ActionButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      tooltip: tooltip,
      splashRadius: 20,
      visualDensity: VisualDensity.compact,
    );
  }
}
