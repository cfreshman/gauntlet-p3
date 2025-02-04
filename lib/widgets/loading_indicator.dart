import 'package:flutter/material.dart';
import '../theme/colors.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.accent,
        ),
      ),
    );
  }
} 