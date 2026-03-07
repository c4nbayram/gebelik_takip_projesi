import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _tabIndex = ValueNotifier<int>(0);

  Future<void> _submit(BuildContext context, AuthProvider auth, bool isLogin) async {
    final mail = _email.text.trim();
    final pass = _pass.text;
    if (!isLogin && _name.text.trim().isEmpty) return;
    if (mail.isEmpty || pass.isEmpty) return;

    bool ok;
    if (isLogin) {
      ok = await auth.login(mail, pass);
    } else {
      ok = await auth.register(_name.text.trim(), mail, pass);
    }

    if (!mounted) return;
    if (!ok && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Bebek Takip",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            ValueListenableBuilder<int>(
              valueListenable: _tabIndex,
              builder: (context, tab, _) {
                return Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _tabIndex.value = 0,
                        style: tab == 0
                            ? null
                            : FilledButton.styleFrom(
                                backgroundColor: Colors.grey.shade300,
                                foregroundColor: Colors.black87,
                              ),
                        child: const Text("Giris"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _tabIndex.value = 1,
                        style: tab == 1
                            ? null
                            : FilledButton.styleFrom(
                                backgroundColor: Colors.grey.shade300,
                                foregroundColor: Colors.black87,
                              ),
                        child: const Text("Kayit"),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<int>(
              valueListenable: _tabIndex,
              builder: (context, tab, _) {
                final isLogin = tab == 0;
                return Column(
                  children: [
                    if (!isLogin)
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: "Ad Soyad",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    if (!isLogin) const SizedBox(height: 12),
                    TextField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: "E-posta",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass,
                      decoration: const InputDecoration(
                        labelText: "Sifre",
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: auth.busy ? null : () => _submit(context, auth, isLogin),
                        child: auth.busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(isLogin ? "Giris Yap" : "Kayit Ol"),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

