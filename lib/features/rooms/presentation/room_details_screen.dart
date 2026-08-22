import 'package:flutter/material.dart';
import '../../../repositories/room_repository.dart';
import 'room_workspace_screen.dart';

class RoomDetailsScreen extends StatelessWidget {
  final RoomWithDetails roomDetails;

  const RoomDetailsScreen({
    super.key,
    required this.roomDetails,
  });

  @override
  Widget build(BuildContext context) {
    return RoomWorkspaceScreen(roomId: roomDetails.room.id);
  }
}
