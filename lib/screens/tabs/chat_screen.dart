import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/student_api.dart';
import '../../models/models.dart';
import '../../services/session.dart';
import '../../theme/app_theme.dart';
import '../../utils/errors.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';

/// Guruh chati (TAB) — o'zining xabari o'ngda accent, boshqalarniki chapda (avatar+nom+rol).
/// Har 4 sekundda yangi xabarlarni so'raydi (since=oxirgi createdAt).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _scroll = ScrollController();
  final _text = TextEditingController();
  List<StudentChatMessage> _messages = [];
  bool _loading = true;
  String? _error;
  Timer? _poll;

  /// So'rov allaqachon ketyaptimi — sekin tarmoqda so'rovlar to'planib qolmasin.
  bool _fetching = false;

  /// Tab ko'rinib turibdimi (`TickerMode` — shell.dart IndexedStack beradi).
  bool _visible = true;

  /// Ilova old planda (foreground) turibdimi.
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = (WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed) ==
        AppLifecycleState.resumed;
    _load();
    // Timer `didChangeDependencies` da yoqiladi (TickerMode holatiga qarab).
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Boshqa tabga o'tilganda `TickerMode` o'chadi va bu qayta chaqiriladi.
    _visible = TickerMode.valuesOf(context).enabled;
    _syncPoll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ilova fonga o'tganda 4 sekundlik so'rov batareya va trafikni yeydi.
    _foreground = state == AppLifecycleState.resumed;
    _syncPoll();
  }

  /// Davriy so'rovni FAQAT tab ko'rinib turganda va ilova old planda bo'lganda
  /// ishlatadi — aks holda to'xtatadi.
  void _syncPoll() {
    final want = _visible && _foreground;
    if (want && _poll == null) {
      _poll = Timer.periodic(const Duration(seconds: 4), (_) => _fetchNew());
    } else if (!want && _poll != null) {
      _poll!.cancel();
      _poll = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _scroll.dispose();
    _text.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _load() async {
    try {
      final msgs = await StudentApi.chat();
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _error = null; // avvalgi xato yozuvi qolib ketmasin
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Xom `DioException`/`Exception` matni emas — o'zbekcha tushunarli xabar.
        _error = humanError(e, "Xabarlarni yuklab bo'lmadi");
        _loading = false;
      });
    }
  }

  Future<void> _fetchNew() async {
    if (_fetching) return;
    _fetching = true;
    try {
      // Ro'yxat BO'SH bo'lsa `since` yo'q — to'liq ro'yxat so'raladi.
      // Ilgari bu yerda `if (_messages.isEmpty) return;` turardi: yangi o'quvchi
      // bo'sh chatni ochsa, o'qituvchi yozgan xabarni ilova qayta ochilmaguncha
      // KO'RMAS edi.
      if (_messages.isEmpty) {
        await _load();
        return;
      }
      final since = _messages.last.createdAt;
      final fresh = await StudentApi.chat(since: since);
      if (!mounted || fresh.isEmpty) return;
      final known = _messages.map((m) => m.id).toSet();
      final add = fresh.where((m) => !known.contains(m.id)).toList();
      if (add.isNotEmpty) {
        setState(() => _messages.addAll(add));
        _scrollToBottom();
      }
    } catch (_) {
      // jim — keyingi urinishda qayta
    } finally {
      _fetching = false;
    }
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    _text.clear();
    try {
      final m = await StudentApi.sendChat(t);
      if (!mounted) return;
      setState(() => _messages.add(m));
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      _text.text = t;
      // Xom istisno matni emas — o'zbekcha xabar.
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Yuborilmadi: ${humanError(e)}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final meId = context.watch<Session>().userId;

    return Column(
      children: [
        _header(c),
        Expanded(
          child: _loading
              ? const Loader()
              : _error != null
                  ? Center(
                      child: EmptyState(
                        icon: Icons.error_outline_rounded,
                        text: "Yuklab bo'lmadi.\n$_error",
                      ),
                    )
                  : _messages.isEmpty
                      ? const Center(
                          child: EmptyState(
                            icon: Icons.chat_bubble_outline_rounded,
                            text: "Xabar yo'q. Hozircha guruhda xabar yo'q.",
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.all(14),
                          itemCount: _messages.length,
                          itemBuilder: (context, i) {
                            final m = _messages[i];
                            // Kunlik SANA ajratgichi: xabarning kuni avvalgisidan farq qilsa
                            // (yoki bu birinchi xabar bo'lsa) tepasida "Bugun / Kecha / 12 Iyul".
                            final showDate = i == 0 || !sameDay(_messages[i - 1].createdAt, m.createdAt);
                            // Yangi kun boshlansa yuboruvchi qayta ko'rsatiladi (avatar + nom).
                            final prevSame =
                                i > 0 && !showDate && _messages[i - 1].senderUserId == m.senderUserId;
                            final bubble = _Bubble(m: m, mine: m.senderUserId == meId, prevSame: prevSame);
                            if (!showDate) return bubble;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [_DateDivider(iso: m.createdAt), bubble],
                            );
                          },
                        ),
        ),
        _composer(c),
      ],
    );
  }

  Widget _header(AppColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.border))),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.chat_bubble_rounded, color: c.accent, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Guruh chati', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: c.text)),
              Text("O'qituvchilar va ma'muriyat", style: TextStyle(fontSize: 12.5, color: c.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _composer(AppColors c) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 12 + bottomInset),
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Xabar yozing...',
                filled: true,
                fillColor: c.surface2,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: c.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: c.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: c.accent)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: c.accent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _send,
              child: const SizedBox(width: 44, height: 44, child: Icon(Icons.send_rounded, color: Colors.white, size: 20)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chatdagi kunlik sana ajratgichi — "Bugun" / "Kecha" / "12 Iyul"
/// (o'tgan yil bo'lsa "12 Iyul, 2025"). Matn mantiqi: `dayDividerLabel`.
class _DateDivider extends StatelessWidget {
  final String iso;
  const _DateDivider({required this.iso});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: c.border, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(10)),
              child: Text(
                dayDividerLabel(iso),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.muted),
              ),
            ),
          ),
          Expanded(child: Divider(color: c.border, height: 1)),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final StudentChatMessage m;
  final bool mine;
  final bool prevSame;
  const _Bubble({required this.m, required this.mine, required this.prevSame});

  Color _roleColor(AppColors c) {
    switch (m.senderRole) {
      case 'teacher':
        return c.accent;
      case 'admin':
        return const Color(0xFF7C3AED);
      case 'parent':
        return c.amber;
      default:
        return c.green;
    }
  }

  String _roleLabel() {
    switch (m.senderRole) {
      case 'teacher':
        return "O'qituvchi";
      case 'admin':
        return "Ma'muriyat";
      case 'parent':
        return 'Ota-ona';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final maxW = MediaQuery.of(context).size.width;

    if (mine) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 3),
          constraints: BoxConstraints(maxWidth: maxW * 0.78),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(5),
                  ),
                ),
                child: Text(m.text,
                    style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.4, fontWeight: FontWeight.w500)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 3, 4, 8),
                child: Text(fmtTime(m.createdAt), style: TextStyle(color: c.faint, fontSize: 10.5)),
              ),
            ],
          ),
        ),
      );
    }

    final rc = _roleColor(c);
    final rl = _roleLabel();
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        constraints: BoxConstraints(maxWidth: maxW * 0.82),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 32, child: prevSame ? null : Avatar(name: m.senderName, size: 32)),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!prevSame)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 0, 2, 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(m.senderName, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: rc)),
                          if (rl.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration:
                                  BoxDecoration(color: rc.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
                              child: Text(rl, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: rc)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.border),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(5),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Text(m.text,
                        style: TextStyle(fontSize: 14.5, height: 1.4, fontWeight: FontWeight.w500, color: c.text)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 3, 2, 8),
                    child: Text(fmtTime(m.createdAt), style: TextStyle(color: c.faint, fontSize: 10.5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
