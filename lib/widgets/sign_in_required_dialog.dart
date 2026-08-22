import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app/theme/app_colors.dart';

/// Helper to check if the current user is unauthenticated or an anonymous guest.
bool isAnonymousUser() {
  final suUser = Supabase.instance.client.auth.currentUser;
  if (suUser != null) {
    if (suUser.email != null && suUser.email!.isNotEmpty) return false;
    if (suUser.phone != null && suUser.phone!.isNotEmpty) return false;
    if (!suUser.isAnonymous) return false;
  }
  if (Supabase.instance.client.auth.currentSession != null) return false;
  return suUser == null;
}

/// Displays an error box/dialog informing the user that sign-in is required.
Future<void> showSignInRequiredDialog(
  BuildContext context, {
  String title = 'Sign In Required',
  String message = 'Please sign in first to create or open room workspaces.',
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.expenseLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline, color: AppColors.expense, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(fontSize: 14, height: 1.4),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            context.push('/login');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}
