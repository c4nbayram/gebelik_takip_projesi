import 'package:flutter/material.dart';

import 'appointments_screen.dart';
import 'chat_screen.dart';
import 'dashboard_screen.dart';
import 'medications_screen.dart';
import 'track_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _pages = const [
    DashboardScreen(),
    TrackScreen(),
    ChatScreen(),
    AppointmentsScreen(),
    MedicationsScreen(),
  ];

  final _labels = const [
    "Ana Sayfa",
    "Takip",
    "AI Chat",
    "Randevular",
    "Ilaclar",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: "Ana Sayfa"),
          NavigationDestination(icon: Icon(Icons.favorite), label: "Takip"),
          NavigationDestination(icon: Icon(Icons.smart_toy), label: "AI Chat"),
          NavigationDestination(icon: Icon(Icons.event), label: "Randevular"),
          NavigationDestination(icon: Icon(Icons.medication), label: "Ilaclar"),
        ],
      ),
    );
  }
}

