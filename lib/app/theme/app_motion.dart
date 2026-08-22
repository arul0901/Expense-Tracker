import 'package:flutter/material.dart';

class AppMotion {
  AppMotion._();

  // Durations
  static const Duration durationFast = Duration(milliseconds: 180);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 550);
  static const Duration durationSplash = Duration(milliseconds: 800);

  // Curves
  static const Curve curveFast = Curves.easeOutCubic;
  static const Curve curveNormal = Curves.easeInOutCubic;
  static const Curve curveSlow = Curves.fastOutSlowIn;
  static const Curve curveEmphasized = Curves.easeInOutBack;

  // Stagger delays
  static const Duration staggerDelay = Duration(milliseconds: 60);
}
