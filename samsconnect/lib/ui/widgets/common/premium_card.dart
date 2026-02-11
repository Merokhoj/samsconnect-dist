import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PremiumCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final bool glassmorphism;
  final double blur;
  final double opacity;
  final Color? color;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const PremiumCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.glassmorphism = true,
    this.blur = 10.0,
    this.opacity = 0.1,
    this.color,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = color ?? (isDark ? AppTheme.darkSurface : Colors.white);
    final effectiveBorderRadius =
        borderRadius ?? BorderRadius.circular(AppTheme.cardRadius);

    Widget cardContent = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: glassmorphism ? baseColor.withValues(alpha: opacity) : baseColor,
        borderRadius: effectiveBorderRadius,
        border: glassmorphism
            ? Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.05,
                ),
                width: 1.5,
              )
            : null,
        boxShadow: !glassmorphism ? AppTheme.premiumShadow : null,
      ),
      child: child,
    );

    if (onTap != null) {
      cardContent = Material(
        color: Colors.transparent,
        borderRadius: effectiveBorderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveBorderRadius,
          child: cardContent,
        ),
      );
    }

    if (!glassmorphism) {
      return cardContent;
    }

    return ClipRRect(
      borderRadius: effectiveBorderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: cardContent,
      ),
    );
  }
}
