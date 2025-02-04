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
        GestureDetector(
          onTap: onBack ?? () => Navigator.pop(context),
          child: Container(
            width: 60,
            color: AppColors.background,
            child: Center(
              child: Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.textPrimary,
                size: 24,
              ),
            ),
          ),
        ),
        // Main content
        Expanded(child: child),
      ],
    );
  }
} 