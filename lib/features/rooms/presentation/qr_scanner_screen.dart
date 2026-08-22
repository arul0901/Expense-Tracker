import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../core/utils/invite_token_service.dart';
import '../../../providers/app_providers.dart';
import 'invitation_preview_sheet.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  final _tokenInputController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _tokenInputController.dispose();
    super.dispose();
  }

  Future<void> _handleScannedToken(String token) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    HapticFeedbackUtil.selectionClick();

    final roomRepo = ref.read(roomRepositoryProvider);
    final room = await roomRepo.findRoomByInviteToken(token);

    if (!mounted) return;

    if (room == null) {
      HapticFeedbackUtil.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Invalid or expired QR invitation code.'),
          backgroundColor: AppColors.expense,
        ),
      );
      setState(() => _isProcessing = false);
      return;
    }

    final roomDetails = await roomRepo.getRoomWithDetails(room.id);
    final owner = (roomDetails != null && roomDetails.members.isNotEmpty)
        ? roomDetails.members.firstWhere((m) => m.role == 'Owner', orElse: () => roomDetails.members.first)
        : null;

    if (!mounted) return;

    // Show preview sheet for consent
    final joined = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InvitationPreviewSheet(
        roomName: room.name,
        createdBy: owner?.name ?? 'Room Owner',
        memberCount: roomDetails?.members.length ?? 1,
        totalExpenseRupees: (roomDetails?.totalRoomExpensesPaise ?? 0) / 100.0,
        token: token,
        onAcceptJoin: (userName) async {
          return roomRepo.joinRoomWithToken(token, userName);
        },
      ),
    );

    if (joined == true && mounted) {
      Navigator.of(context).pop();
    } else {
      setState(() => _isProcessing = false);
    }
  }

  void _showManualTokenDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Invite Code'),
        content: TextField(
          controller: _tokenInputController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'e.g. INV-8F92A1',
            labelText: 'Invite Token / Link',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final raw = _tokenInputController.text;
              final extracted = InviteTokenService.extractTokenFromQr(raw) ?? raw;
              Navigator.pop(context);
              if (extracted.isNotEmpty) {
                _handleScannedToken(extracted);
              }
            },
            child: const Text('Join Room'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Scan Room QR'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.amber);
                  default:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                }
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final raw = barcode.rawValue;
                if (raw != null) {
                  final token = InviteTokenService.extractTokenFromQr(raw);
                  if (token != null) {
                    _handleScannedToken(token);
                    break;
                  }
                }
              }
            },
          ),
          // Scanner Box Frame Overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isProcessing ? AppColors.income : Colors.white,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Column(
              children: [
                const Text(
                  'Point camera at Room QR Code to join',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _showManualTokenDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Enter Code Manually'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
