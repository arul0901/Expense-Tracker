import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_motion.dart';
import '../core/utils/haptic_feedback_util.dart';

class ExpandableFab extends StatefulWidget {
  final VoidCallback onAddExpense;
  final VoidCallback onAddIncome;
  final VoidCallback onAddReminder;
  final VoidCallback onCreateEvent;

  const ExpandableFab({
    super.key,
    required this.onAddExpense,
    required this.onAddIncome,
    required this.onAddReminder,
    required this.onCreateEvent,
  });

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: _isOpen ? 1.0 : 0.0,
      duration: AppMotion.durationNormal,
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      curve: AppMotion.curveNormal,
      reverseCurve: Curves.easeInCubic,
      parent: _controller,
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(_expandAnimation); // 45 deg turn
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedbackUtil.selectionClick();
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _runAction(VoidCallback action) {
    _toggle();
    action();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isOpen) ...[
          _buildActionButton(
            label: 'File an expense',
            icon: Icons.remove,
            color: AppColors.expense,
            onTap: () => _runAction(widget.onAddExpense),
          ),
          const SizedBox(height: 10),
          _buildActionButton(
            label: 'Report income',
            icon: Icons.add,
            color: AppColors.income,
            onTap: () => _runAction(widget.onAddIncome),
          ),
          const SizedBox(height: 10),
          _buildActionButton(
            label: 'Add reminder',
            icon: Icons.notifications_active_outlined,
            color: AppColors.warning,
            onTap: () => _runAction(widget.onAddReminder),
          ),
          const SizedBox(height: 10),
          _buildActionButton(
            label: 'Create event',
            icon: Icons.event_outlined,
            color: AppColors.primaryAccent,
            onTap: () => _runAction(widget.onCreateEvent),
          ),
          const SizedBox(height: 14),
        ],
        FloatingActionButton(
          heroTag: null,
          onPressed: _toggle,
          backgroundColor: AppColors.primaryInk,
          child: RotationTransition(
            turns: _rotateAnimation,
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ScaleTransition(
      scale: _expandAnimation,
      child: FadeTransition(
        opacity: _expandAnimation,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryInk,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
