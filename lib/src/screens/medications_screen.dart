import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  final _api = ApiService(baseUrl: AppConfig.apiBaseUrl);
  final _name = TextEditingController();
  final _dosage = TextEditingController();
  final _frequency = TextEditingController();
  final _times = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _start;
  DateTime? _end;

  List<Medication> _items = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _api.restoreSession();
    await _load();
  }

  Future<void> _load() async {
    try {
      _items = await _api.getMedications();
      setState(() {});
    } catch (_) {}
  }

  Future<void> _add() async {
    await _api.restoreSession();
    if (_name.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await _api.addMedication(
        name: _name.text.trim(),
        dosage: _dosage.text.trim(),
        frequency: _frequency.text.trim(),
        startDate: _start,
        endDate: _end,
        times: _times.text.trim(),
        notes: _notes.text.trim(),
      );
      _name.clear();
      _dosage.clear();
      _frequency.clear();
      _times.clear();
      _notes.clear();
      _start = null;
      _end = null;
      await _load();
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickStart() async {
    final pick = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 3)),
      lastDate: DateTime.now().add(const Duration(days: 720)),
    );
    if (pick != null) setState(() => _start = pick);
  }

  Future<void> _pickEnd() async {
    final pick = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 720)),
    );
    if (pick != null) setState(() => _end = pick);
  }

  @override
  Widget build(BuildContext context) {
    final startText = _start == null ? "Baslangic" : DateFormat("dd.MM.yyyy").format(_start!);
    final endText = _end == null ? "Bitis" : DateFormat("dd.MM.yyyy").format(_end!);

    return Scaffold(
      appBar: AppBar(title: const Text("Ilaclar")),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: "Ilac Adi"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _dosage,
                    decoration: const InputDecoration(labelText: "Doz"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _frequency,
                    decoration: const InputDecoration(labelText: "Siklik"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _times,
                    decoration: const InputDecoration(
                      labelText: "Saatler (ornek: 09:00, 21:00)",
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notes,
                    decoration: const InputDecoration(labelText: "Not"),
                  ),
                  Row(
                    children: [
                      Expanded(child: Text(startText)),
                      TextButton(onPressed: _pickStart, child: const Text("Sec")),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: Text(endText)),
                      TextButton(onPressed: _pickEnd, child: const Text("Sec")),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _add,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text("Ekle"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._items.map(
            (m) => Card(
              child: ListTile(
                title: Text(m.name),
                subtitle: Text(
                  "${m.dosage ?? "-"} ${m.frequency == null ? "" : " - ${m.frequency}"}",
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _loading
                      ? null
                      : () async {
                          await _api.deleteMedication(m.id);
                          await _api.restoreSession();
                          await _load();
                        },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
