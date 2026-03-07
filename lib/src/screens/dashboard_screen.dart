import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _api = ApiService(baseUrl: AppConfig.apiBaseUrl);
  late final Future<List<dynamic>> _init;
  int _selectedWeek = 1;
  WeekInfo? _weekInfo;
  List<WeekEntry> _entries = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _init = _load();
  }

  Future<List<dynamic>> _load() async {
    await _api.restoreSession();
    try {
      final info = await _api.getWeekInfo(_selectedWeek);
      final entries = await _api.getWeekEntries();
      _weekInfo = info;
      _entries = entries;
      _error = null;
      return [info, entries];
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }

  Future<void> _refreshWeek(int week) async {
    setState(() {
      _selectedWeek = week;
      _init = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ana Sayfa")),
      body: FutureBuilder<List<dynamic>>(
        future: _init,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () => _refreshWeek(_selectedWeek),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionCard(
                  "Hafta Bilgisi",
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<int>(
                        value: _selectedWeek,
                        items: List.generate(
                          40,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text("${i + 1}. Hafta"),
                          ),
                        ),
                        onChanged: (v) {
                          if (v != null) _refreshWeek(v);
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_weekInfo != null)
                        Text(_weekInfo!.text),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                _sectionCard(
                  "Kayıtlar",
                  _entries.isEmpty
                      ? const Text("Henüz kayıt yok.")
                      : Column(
                          children: _entries
                              .map(
                                (e) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text("${e.weekNo}. hafta"),
                                  subtitle: Text(
                                    "Guncellenme: ${e.updatedAt != null ? DateFormat("dd.MM.yyyy").format(e.updatedAt!) : "-"}",
                                  ),
                                  trailing: e.riskLabel == null
                                      ? null
                                      : Chip(label: Text("${e.riskLabel} ${((e.riskScore ?? 0) * 100).toInt()}%")),
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  "Ne Zaman Kullanilir",
                  const Text(
                    "Haftalik kan basinci, kan sekeri, nabiz ve vucut sicakligi degerlerini girerek sistemden risk analizi ve AI tavsiyeleri alabilirsin.",
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionCard(String title, Widget body) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            body,
          ],
        ),
      ),
    );
  }
}

