import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _api = ApiService(baseUrl: AppConfig.apiBaseUrl);
  final _msg = TextEditingController();
  final _messages = <ChatMessage>[];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _api.restoreSession();
  }

  Future<void> _send() async {
    await _api.restoreSession();
    final text = _msg.text.trim();
    if (text.isEmpty || _loading) return;

    _messages.add(ChatMessage(message: text, fromUser: true, createdAt: DateTime.now()));
    _msg.clear();
    setState(() => _loading = true);

    try {
      final reply = await _api.sendChat(text, includeLatest: true);
      _messages.add(ChatMessage(message: reply, fromUser: false, createdAt: DateTime.now()));
    } catch (e) {
      _messages.add(ChatMessage(message: e.toString(), fromUser: false, createdAt: DateTime.now()));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Asistan")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final msg = _messages[i];
                return Align(
                  alignment:
                      msg.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 320),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: msg.fromUser ? Colors.indigo : Colors.blueGrey[100],
                    ),
                    child: Text(
                      msg.message,
                      style: TextStyle(
                        color: msg.fromUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msg,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Asistana soru sor...",
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _send,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
