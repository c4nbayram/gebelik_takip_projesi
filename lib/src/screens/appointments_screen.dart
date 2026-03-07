import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _api = ApiService(baseUrl: AppConfig.apiBaseUrl);
  final _title = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _selected;
  TimeOfDay? _time;
  List<Appointment> _items = [];
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
      _items = await _api.getAppointments();
      setState(() {});
    } catch (_) {}
  }

  Future<void> _add() async {
    await _api.restoreSession();
    if (_title.text.trim().isEmpty || _selected == null || _time == null) return;
    final date = DateTime(
      _selected!.year,
      _selected!.month,
      _selected!.day,
      _time!.hour,
      _time!.minute,
    );
    final model = Appointment(
      id: 0,
      title: _title.text.trim(),
      appointmentAt: date,
      notes: _notes.text.trim(),
    );
    setState(() => _loading = true);
    try {
      await _api.addAppointment(model);
      _title.clear();
      _notes.clear();
      _selected = null;
      _time = null;
      await _load();
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final pick = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 720)),
    );
    if (pick != null) setState(() => _selected = pick);
  }

  Future<void> _pickTime() async {
    final pick = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pick != null) setState(() => _time = pick);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = _selected == null ? "Tarih secilmedi" : DateFormat("dd.MM.yyyy").format(_selected!);
    final selectedTime = _time == null ? "Saat secilmedi" : _time!.format(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Randevular")),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: "Baslik"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notes,
                    decoration: const InputDecoration(labelText: "Not"),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Text(selectedDate)),
                      TextButton(onPressed: _pickDate, child: const Text("Tarih")),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: Text(selectedTime)),
                      TextButton(onPressed: _pickTime, child: const Text("Saat")),
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
            (a) => Card(
              child: ListTile(
                title: Text(a.title),
                subtitle: Text(a.notes ?? ""),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _loading
                      ? null
                      : () async {
                          await _api.restoreSession();
                          await _api.deleteAppointment(a.id);
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
