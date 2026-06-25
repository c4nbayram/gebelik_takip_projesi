import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../core/premium_gate.dart';
import '../models/app_models.dart';
import '../providers/premium_provider.dart';
import '../services/api_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _api = ApiService(
    baseUrl: AppConfig.apiBaseUrl,
    localOnly: AppConfig.localOnly,
  );
  final _msg = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];
  bool _loading = false;
  bool _waitingForFirstToken = false;
  int? _streamingReplyIndex;

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        message: "Merhaba, bana sorularini yazabilirsin.",
        fromUser: false,
        createdAt: DateTime.now(),
      ),
    );
    _initConversation();
  }

  Future<void> _initConversation() async {
    await _api.restoreSession();
    final history = await _api.getChatHistory();
    if (!mounted) return;
    if (history.isNotEmpty) {
      setState(() {
        _messages
          ..clear()
          ..addAll(history);
      });
      _scrollToBottom();
    } else {
      await _loadProfileGreeting();
    }
  }

  @override
  void dispose() {
    _msg.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadProfileGreeting() async {
    final prefs = await SharedPreferences.getInstance();
    final role = (prefs.getString(AppConfig.caregiverRoleKey) ?? "").trim();
    final babyName = (prefs.getString(AppConfig.babyNameKey) ?? "").trim();
    final planningBaby = prefs.getBool(AppConfig.planningBabyKey) ?? false;

    String roleTag = role;
    const map = {
      "Annesiyim": "Anne",
      "Babasiyim": "Baba",
      "Abisiyim": "Abi",
      "Halasiyim": "Hala",
      "Babannesiyim": "Babaanne",
      "Teyzesiyim": "Teyze",
    };
    roleTag = map[roleTag] ?? roleTag;
    if (roleTag.isEmpty) {
      roleTag = "Aile uyesi";
    }

    final babyRef = babyName.isEmpty ? "bebeginiz" : babyName;
    final message = planningBaby
        ? "Merhaba $roleTag, bebek planlama surecinde yanindayim. Merak ettigin her seyi yazabilirsin."
        : (babyName.isEmpty
            ? "Merhaba $roleTag, bu hafta nasil hissediyorsun? Bana sorularini yazabilirsin."
            : "Merhaba $roleTag, $babyRef ile ilgili merak ettiklerini yazabilirsin. Istersen $babyRef'in haftasini birlikte degerlendirelim.");

    if (!mounted || _messages.isEmpty) return;
    setState(() {
      _messages[0] = ChatMessage(
        message: message,
        fromUser: false,
        createdAt: DateTime.now(),
      );
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send() async {
    await _api.restoreSession();
    final text = _msg.text.trim();
    if (text.isEmpty || _loading) return;

    final userMessage =
        ChatMessage(message: text, fromUser: true, createdAt: DateTime.now());
    _messages.add(userMessage);
    _msg.clear();
    setState(() {
      _loading = true;
      _waitingForFirstToken = true;
      _streamingReplyIndex = null;
    });
    _scrollToBottom();

    try {
      await for (final delta in _api.sendChatStream(
        text,
        history: List<ChatMessage>.from(_messages),
        includeLatest: true,
      )) {
        if (!mounted) return;
        setState(() {
          _waitingForFirstToken = false;
          if (_streamingReplyIndex == null) {
            _messages.add(
              ChatMessage(
                message: delta,
                fromUser: false,
                createdAt: DateTime.now(),
              ),
            );
            _streamingReplyIndex = _messages.length - 1;
          } else {
            final current = _messages[_streamingReplyIndex!];
            _messages[_streamingReplyIndex!] = ChatMessage(
              message: "${current.message}$delta",
              fromUser: false,
              createdAt: current.createdAt,
            );
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _waitingForFirstToken = false;
          _streamingReplyIndex = null;
          _messages.add(
            ChatMessage(
              message: e.toString(),
              fromUser: false,
              createdAt: DateTime.now(),
            ),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _waitingForFirstToken = false;
          _streamingReplyIndex = null;
        });
      }
      _scrollToBottom();
    }
  }

  void _insertSuggestion(String text) {
    _msg.text = text;
    _msg.selection = TextSelection.collapsed(offset: text.length);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final hasGuide =
        context.watch<PremiumProvider>().hasFeature(PremiumFeatures.guide);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            if (!hasGuide)
              Expanded(child: _lockedState())
            else ...[
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  itemCount:
                      _messages.length + (_loading && _waitingForFirstToken ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (_loading && _waitingForFirstToken && i == _messages.length) {
                      return const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.xs),
                        child: _TypingIndicator(),
                      );
                    }
                    final msg = _messages[i];
                    final showTime = i == _messages.length - 1 ||
                        _messages[i + 1].fromUser != msg.fromUser;
                    return _ChatBubble(message: msg, showTime: showTime);
                  },
                ),
              ),
              if (_messages.length <= 1) _suggestionChips(),
              _composer(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lockedState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: const [
        PremiumLockCard(
          title: "Gebelik Rehberi premium'a özel",
          message:
              "Gebelik yolculuğunda kişiselleştirilmiş, kural tabanlı rehberlik için premium üyeliğe geç. Ölçümlerine ve profiline göre bilgi alırsın.",
          feature: PremiumFeatures.guide,
        ),
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: context.palette.brandGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow:
                  AppShadows.glow(context.palette.primary, strength: 0.3),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Gebelik Rehberi",
                  style: TextStyle(
                    color: context.palette.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const _StatusDot(),
                    const SizedBox(width: 6),
                    Text(
                      "Sorularini yanitlamaya hazirim",
                      style: TextStyle(
                        color: context.palette.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionChips() {
    const suggestions = [
      "Bu haftaki gelisim nasil?",
      "Beslenmem icin onerin var mi?",
      "Hafif sancilarim normal mi?",
      "Uyku duzeni nasil olmali?",
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Hizli sorular",
            style: TextStyle(
              color: context.palette.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final s in suggestions)
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: InkWell(
                    onTap: () => _insertSuggestion(s),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: context.palette.surface.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: context.palette.borderSoft),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.flash_on_rounded,
                            size: 13,
                            color: context.palette.primarySoft,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            s,
                            style: TextStyle(
                              color: context.palette.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          6,
          6,
          6,
        ),
        decoration: BoxDecoration(
          color: context.palette.bgElevated.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: context.palette.borderSoft),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _msg,
                maxLines: 4,
                minLines: 1,
                onSubmitted: (_) => _send(),
                textInputAction: TextInputAction.send,
                style: TextStyle(
                  color: context.palette.textPrimary,
                  fontSize: 14.5,
                ),
                cursorColor: context.palette.primarySoft,
                decoration: InputDecoration(
                  hintText: "Rehbere soru sor...",
                  hintStyle: TextStyle(
                    color: context.palette.textMuted,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxs,
                    vertical: AppSpacing.sm,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _sendButton(),
          ],
        ),
      ),
    );
  }

  Widget _sendButton() {
    final disabled = _loading;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: disabled ? null : _send,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: disabled
                  ? const [Color(0xFF3E3E62), Color(0xFF4A4A70)]
                  : context.palette.brandGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: disabled
                ? null
                : AppShadows.glow(context.palette.primary, strength: 0.3),
          ),
          child: disabled
              ? const Center(
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      width: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.palette.success,
        boxShadow: [
          BoxShadow(
            color: context.palette.success.withValues(alpha: 0.6),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.showTime,
  });

  final ChatMessage message;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final isUser = message.fromUser;
    final timeText = DateFormat("HH:mm").format(message.createdAt);

    final bubble = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        gradient: isUser
            ? LinearGradient(
                colors: context.palette.brandGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isUser ? null : context.palette.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppRadius.md),
          topRight: const Radius.circular(AppRadius.md),
          bottomLeft: Radius.circular(isUser ? AppRadius.md : 4),
          bottomRight: Radius.circular(isUser ? 4 : AppRadius.md),
        ),
        border: Border.all(
          color: isUser
              ? Colors.white.withValues(alpha: 0.15)
              : context.palette.borderSoft,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Text(
        message.message,
        style: TextStyle(
          color: isUser ? Colors.white : context.palette.textPrimary,
          fontSize: 14.2,
          height: 1.5,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) _avatar(context, isUser),
              if (!isUser) const SizedBox(width: 6),
              Flexible(child: bubble),
              if (isUser) const SizedBox(width: 6),
              if (isUser) _avatar(context, isUser),
            ],
          ),
          if (showTime)
            Padding(
              padding: EdgeInsets.only(
                left: isUser ? 0 : 36,
                right: isUser ? 36 : 0,
                top: 4,
              ),
              child: Text(
                timeText,
                style: TextStyle(
                  color: context.palette.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context, bool isUser) {
    return Container(
      height: 30,
      width: 30,
      decoration: BoxDecoration(
        color: isUser ? context.palette.surfaceHigh : null,
        gradient: isUser
            ? null
            : LinearGradient(colors: context.palette.accentGradient),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(
          color: isUser ? context.palette.borderSoft : Colors.transparent,
        ),
      ),
      child: Icon(
        isUser ? Icons.person_rounded : Icons.auto_awesome_rounded,
        size: 14,
        color: isUser ? context.palette.textSecondary : Colors.white,
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            height: 30,
            width: 30,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: context.palette.accentGradient),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: context.palette.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: context.palette.borderSoft),
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final phase = (_ctrl.value - i * 0.18).clamp(0.0, 1.0);
                    final scale = 0.6 +
                        0.6 *
                            (0.5 * (1 - (2 * phase - 1).abs())).clamp(0.0, 1.0);
                    return Padding(
                      padding: EdgeInsets.only(right: i == 2 ? 0 : 5),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          height: 8,
                          width: 8,
                          decoration: BoxDecoration(
                            color: context.palette.primarySoft,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
