import 'package:flutter/material.dart';

class CategoryIconWidget extends StatelessWidget {
  final String iconName;
  final int colorValue;
  final double size;

  const CategoryIconWidget({
    super.key,
    required this.iconName,
    required this.colorValue,
    this.size = 24,
  });

  static IconData getIconData(String name) {
    switch (name) {
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_bus':
        return Icons.directions_bus;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'receipt_long':
        return Icons.receipt_long;
      case 'movie':
        return Icons.movie;
      case 'medical_services':
        return Icons.medical_services;
      case 'school':
        return Icons.school;
      case 'flight':
        return Icons.flight;
      case 'person':
        return Icons.person;
      case 'work':
        return Icons.work;
      case 'laptop_mac':
        return Icons.laptop_mac;
      case 'store':
        return Icons.store;
      case 'trending_up':
        return Icons.trending_up;
      case 'card_giftcard':
        return Icons.card_giftcard;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      case 'home':
        return Icons.home;
      case 'electric_bolt':
        return Icons.electric_bolt;
      case 'phone_android':
        return Icons.phone_android;
      case 'directions_car':
        return Icons.directions_car;
      case 'fitness_center':
        return Icons.fitness_center;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue);
    return Container(
      padding: EdgeInsets.all(size * 0.35),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(
        getIconData(iconName),
        color: color,
        size: size,
      ),
    );
  }
}
