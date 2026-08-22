import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/invite_token_service.dart';
import '../../../providers/app_providers.dart';
import 'invitation_preview_sheet.dart';

class JoinRoomByTokenScreen extends ConsumerStatefulWidget {
  final String token;

  const JoinRoomByTokenScreen({super.key, required this.token});

  @override
  ConsumerState<JoinRoomByTokenScreen> createState() => _JoinRoomByTokenScreenState();
}

class _JoinRoomByTokenScreenState extends ConsumerState<JoinRoomByTokenScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _processJoinToken());
  }

  Future<void> _processJoinToken() async {
    final cleanToken = InviteTokenService.extractTokenFromQr(widget.token) ?? widget.token;
    final roomRepo = ref.read(roomRepositoryProvider);
    final room = await roomRepo.findRoomByInviteToken(cleanToken);

    if (!mounted) return;

    if (room == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid or expired room invitation link ($cleanToken).';
      });
      return;
    }

    final roomDetails = await roomRepo.getRoomWithDetails(room.id);
    final owner = (roomDetails != null && roomDetails.members.isNotEmpty)
        ? roomDetails.members.firstWhere((m) => m.role == 'Owner', orElse: () => roomDetails.members.first)
        : null;

    if (!mounted) return;

    final joined = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InvitationPreviewSheet(
        roomName: room.name,
        createdBy: owner?.name ?? 'Room Owner',
        memberCount: roomDetails?.members.length ?? 1,
        totalExpenseRupees: (roomDetails?.totalRoomExpensesPaise ?? 0) / 100.0,
        token: cleanToken,
        onAcceptJoin: (userName) async {
          return roomRepo.joinRoomWithToken(cleanToken, userName);
        },
      ),
    );

    if (!mounted) return;

    if (joined == true) {
      context.go('/rooms/${room.id}');
    } else {
      context.go('/rooms');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Joining Room...'),
      ),
      body: Center(
        child: _isLoading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Resolving invitation link...', style: TextStyle(fontWeight: FontWeight.w500)),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: AppColors.expense),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage ?? 'Unable to process invitation.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/rooms'),
                      icon: const Icon(Icons.meeting_room),
                      label: const Text('Go to Rooms Dashboard'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
