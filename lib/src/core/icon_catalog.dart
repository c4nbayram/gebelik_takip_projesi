import 'package:flutter/material.dart';

IconData iconForName(String? name,
    {IconData fallback = Icons.notifications_rounded}) {
  switch (name) {
    case "local_drink_rounded":
      return Icons.local_drink_rounded;
    case "monitor_heart_rounded":
      return Icons.monitor_heart_rounded;
    case "medication_rounded":
      return Icons.medication_rounded;
    case "eco_rounded":
      return Icons.eco_rounded;
    case "event_rounded":
      return Icons.event_rounded;
    case "restaurant_rounded":
      return Icons.restaurant_rounded;
    case "fitness_center_rounded":
      return Icons.fitness_center_rounded;
    case "checklist_rounded":
      return Icons.checklist_rounded;
    case "self_improvement_rounded":
      return Icons.self_improvement_rounded;
    case "child_care_rounded":
      return Icons.child_care_rounded;
    case "auto_awesome_rounded":
      return Icons.auto_awesome_rounded;
    case "info":
    case "info_rounded":
      return Icons.info_rounded;
    case "campaign_rounded":
      return Icons.campaign_rounded;
    default:
      return fallback;
  }
}
