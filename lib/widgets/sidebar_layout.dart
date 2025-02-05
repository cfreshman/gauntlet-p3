import 'package:flutter/material.dart';
import '../theme/colors.dart';

class SidebarLayout extends StatelessWidget {
  final Widget child;
  final bool showBackButton;
  final VoidCallback? onBack;

  const SidebarLayout({
    super.key,
    required this.child,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    if (!showBackButton) return child;
    
    return Row(
      children: [
        // Back button sidebar
        Container(
          width: 60,
          color: AppColors.background,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onBack ?? () => Navigator.pop(context),
              child: Center(
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
        // Vertical divider
        VerticalDivider(
          thickness: 1,
          width: 1,
          color: AppColors.accent.withOpacity(0.2),
        ),
        // Main content
        Expanded(child: child),
      ],
    );
  }
} 