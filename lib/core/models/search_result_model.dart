import 'package:flutter/material.dart';

enum SearchCategory {
  all('All', Icons.border_all),
  transaction('Transactions', Icons.receipt_long_outlined),
  room('Rooms', Icons.groups_outlined),
  event('Events', Icons.event_outlined),
  reminder('Reminders', Icons.notifications_active_outlined),
  task('Tasks', Icons.task_alt_outlined),
  subscription('Subscriptions', Icons.subscriptions_outlined);

  final String label;
  final IconData icon;

  const SearchCategory(this.label, this.icon);
}

class SearchResultModel {
  final String id;
  final SearchCategory category;
  final String title;
  final String subtitle;
  final double? amountRupees;
  final String? amountType; // 'income', 'expense', 'neutral'
  final DateTime? date;
  final String? contextInfo;
  final String deepLinkRoute;
  final IconData icon;
  final Color iconColor;
  final Map<String, dynamic>? metadata;

  SearchResultModel({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    this.amountRupees,
    this.amountType,
    this.date,
    this.contextInfo,
    required this.deepLinkRoute,
    required this.icon,
    required this.iconColor,
    this.metadata,
  });
}
