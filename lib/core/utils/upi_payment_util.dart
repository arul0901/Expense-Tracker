import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_colors.dart';
import 'haptic_feedback_util.dart';

class UpiPaymentUtil {
  static const _storage = FlutterSecureStorage();

  /// Gets saved UPI VPA for a member by name.
  static Future<String?> getSavedUpiId(String memberName) async {
    final key = 'upi_vpa_${memberName.trim().toLowerCase()}';
    return await _storage.read(key: key);
  }

  /// Saves UPI VPA for a member by name for future occasions.
  static Future<void> saveUpiId(String memberName, String upiId) async {
    final key = 'upi_vpa_${memberName.trim().toLowerCase()}';
    await _storage.write(key: key, value: upiId.trim());
  }

  /// Fetches receiver's saved default UPI ID and directly launches UPI payment app chooser.
  /// Prompts for UPI ID only if not saved yet.
  static Future<void> launchUpiPaymentWithPrompt(
    BuildContext context, {
    required String receiverName,
    required double amountRupees,
    required String note,
    VoidCallback? onPaymentLaunched,
  }) async {
    HapticFeedbackUtil.mediumImpact();

    String? savedVpa = await getSavedUpiId(receiverName);

    if (savedVpa != null && savedVpa.isNotEmpty) {
      // Receiver has a saved UPI ID -> DIRECTLY launch payment app!
      if (context.mounted) {
        await launchUpiPayment(
          context,
          receiverVpa: savedVpa,
          receiverName: receiverName,
          amountRupees: amountRupees,
          note: note,
        );
        onPaymentLaunched?.call();
      }
      return;
    }

    // No saved UPI ID yet -> Prompt user to enter & save it
    final defaultVpa = '${receiverName.toLowerCase().replaceAll(' ', '')}@upi';
    if (!context.mounted) return;

    final controller = TextEditingController(text: defaultVpa);
    final selectedVpa = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text('Pay $receiverName via UPI')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter $receiverName\'s UPI ID (e.g. name@okicici, phone@paytm):',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Receiver UPI VPA ID',
                hintText: 'e.g. arul@okicici',
                prefixIcon: Icon(Icons.payment),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Amount to pay: ₹${amountRupees.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.income),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Save & Pay via UPI'),
          ),
        ],
      ),
    );

    if (selectedVpa != null && selectedVpa.isNotEmpty && context.mounted) {
      await saveUpiId(receiverName, selectedVpa);
      if (!context.mounted) return;
      await launchUpiPayment(
        context,
        receiverVpa: selectedVpa,
        receiverName: receiverName,
        amountRupees: amountRupees,
        note: note,
      );
      onPaymentLaunched?.call();
    }
  }

  /// Launches universal UPI Deep-link URI (upi://pay?...).
  static Future<void> launchUpiPayment(
    BuildContext context, {
    required String receiverVpa,
    required String receiverName,
    required double amountRupees,
    required String note,
  }) async {
    final String upiUrl = 'upi://pay?'
        'pa=${Uri.encodeComponent(receiverVpa)}'
        '&pn=${Uri.encodeComponent(receiverName)}'
        '&am=${amountRupees.toStringAsFixed(2)}'
        '&cu=INR'
        '&tn=${Uri.encodeComponent(note)}';

    final Uri uri = Uri.parse(upiUrl);

    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        _showUpiDialog(context, receiverVpa, receiverName, amountRupees);
      }
    } catch (e) {
      if (context.mounted) {
        _showUpiDialog(context, receiverVpa, receiverName, amountRupees);
      }
    }
  }

  /// Fallback dialog showing VPA & Amount if direct launch fails or on web/emulator.
  static void _showUpiDialog(
    BuildContext context,
    String vpa,
    String receiverName,
    double amount,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text('Pay $receiverName via UPI')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Copy the details below to complete payment in Google Pay, PhonePe, or Paytm:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('UPI VPA / ID:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  SelectableText(vpa, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                  const SizedBox(height: 10),
                  const Text('Amount to Pay:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.income)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
