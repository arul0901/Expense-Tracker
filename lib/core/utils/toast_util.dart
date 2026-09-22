import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import 'haptic_feedback_util.dart';

class ToastUtil {
  static void showSuccess(BuildContext context, String message) {
    HapticFeedbackUtil.mediumImpact();
    _showToast(
      context,
      message,
      icon: Icons.check_circle,
      backgroundColor: AppColors.income,
    );
  }

  static void showError(BuildContext context, String message) {
    HapticFeedbackUtil.heavyImpact();
    _showToast(
      context,
      message,
      icon: Icons.error,
      backgroundColor: AppColors.expense,
    );
  }

  static void showInfo(BuildContext context, String message) {
    HapticFeedbackUtil.lightImpact();
    _showToast(
      context,
      message,
      icon: Icons.info,
      backgroundColor: AppColors.primary,
    );
  }

  static void _showToast(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color backgroundColor,
  }) {
    // Hide current snackbar if any
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
