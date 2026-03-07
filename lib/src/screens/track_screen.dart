import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';

class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  final _api = ApiService(baseUrl: AppConfig.apiBaseUrl);
  final _form = GlobalKey<FormState>();
  final _week = TextEditingController(text: "1");
  final _age = TextEditingController();
  final _medical = TextEditingController();
  final _sistolik = TextEditingController();
  final _diastolik = TextEditingController();
  final _bs = TextEditingController();
  final _temp = TextEditingController();
  final _bmi = TextEditingController();
  final _nabiz = TextEditingController();
  HealthAnalyzeResult? _result;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api.restoreSession();
  }

  Future<void> _submit() async {
    await _api.restoreSession();
    if (!(_form.currentState?.validate() ?? false)) return;
    final weekNo = int.tryParse(_week.text.trim()) ?? 1;
    final req = HealthAnalyzeRequest(
      weekNo: weekNo,
      profileAge: int.tryParse(_age.text.trim()),
      medicalHistory: _medical.text.trim().isEmpty ? null : _medical.text.trim(),
      systolic: double.parse(_sistolik.text.trim()),
      diastolic: double.parse(_diastolik.text.trim()),
      bloodSugar: double.parse(_bs.text.trim()),
      bodyTemp: double.parse(_temp.text.trim()),
      bmi: double.parse(_bmi.text.trim()),
      heartRate: double.parse(_nabiz.text.trim()),
    );

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      if (weekNo == 1 && req.profileAge != null) {
        await _api.saveWeekProfile(req.profileAge!, req.medicalHistory);
      }
      final result = await _api.analyzeWeek(req);
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _field(String label, TextEditingController c, {TextInputType type = TextInputType.number}) {
    return TextFormField(
      controller: c,
      keyboardType: type,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return "zorunlu";
        if (type == TextInputType.text) return null;
        return double.tryParse(v.trim()) == null ? "numeric" : null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedWeek = int.tryParse(_week.text.trim()) ?? 1;
    final showFirstWeek = selectedWeek == 1;

    return Scaffold(
      appBar: AppBar(title: const Text("Haftalik Takip")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(
                  controller: _week,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Hafta (1-40)"),
                  validator: (v) {
                    final w = int.tryParse(v?.trim() ?? "");
                    if (w == null || w < 1 || w > 40) return "1-40 arasi";
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                if (showFirstWeek) ...[
                  _field("Yas", _age),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _medical,
                    decoration: const InputDecoration(labelText: "Saglik gecmisi"),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                ],
                _field("Sistolik", _sistolik),
                const SizedBox(height: 12),
                _field("Diastolik", _diastolik),
                const SizedBox(height: 12),
                _field("Kan sekeri", _bs),
                const SizedBox(height: 12),
                _field("Vucut sicakligi", _temp),
                const SizedBox(height: 12),
                _field("BMI", _bmi),
                const SizedBox(height: 12),
                _field("Nabiz", _nabiz),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Analiz et"),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Card(
              child: ListTile(
                title: const Text("Hata"),
                subtitle: Text(_error!),
              ),
            ),
          if (_result != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Hafta ${_result!.weekNo} - ${_result!.riskLabel}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text("Risk: ${(_result!.riskScore * 100).toStringAsFixed(1)}%"),
                    Text("Knn: K=${_result!.knnK} / High=${_result!.knnHigh}"),
                    const SizedBox(height: 8),
                    const Divider(),
                    Text(_result!.aiAdvice),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
