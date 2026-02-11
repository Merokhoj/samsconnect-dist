import 'package:flutter/material.dart';

class LayoutTopBar extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  const LayoutTopBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.leading,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    // Professional Top Bar: Simple, clean, context-aware with logo
    final theme = Theme.of(context);

    return Container(
      height: 56, // Standard density
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor, // Blend with background
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 16)],

          // App Logo Image
          Image.asset(
            'assets/images/app_logo.png',
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),

          // Title
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.textTheme.titleMedium?.color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          Row(mainAxisSize: MainAxisSize.min, children: actions),
        ],
      ),
    );
  }
}

class TopBarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final Color? color;

  const TopBarAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
        ),
      );
    }

    // Context-aware text buttons (cleaner than OutlinedButton for toolbar)
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: color),
        label: Text(label, style: TextStyle(color: color)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6), // Consistent with theme
          ),
        ),
      ),
    );
  }
}
