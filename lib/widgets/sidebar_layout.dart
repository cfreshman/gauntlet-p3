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
    if (!showBackButton) {
      return child;
    }
    
    return Stack(
      children: [
        Container(color: AppColors.background),
        SafeArea(
          bottom: false,
          child: Row(
            children: [
              Container(
                width: 60,
                color: Colors.transparent,
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
              Container(
                width: 1,
                color: AppColors.accent.withOpacity(0.2),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ],
    );
  }
} 