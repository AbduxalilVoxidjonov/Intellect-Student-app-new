/// Asl matn → yaxshilangan matn farqi (so'z darajasidagi LCS) — SOF mantiq.
///
/// AI tekshiruvi ekranida yaxshilangan matnda QO'SHILGAN/O'ZGARTIRILGAN
/// so'zlar ajratib ko'rsatiladi. Bu yerda faqat "qaysi token o'zgargan"
/// savoliga javob beriladi; rang/stil UI tomonida qo'llanadi.
library;

/// Yaxshilangan matnning bitta bo'lagi (so'z yoki oraliq bo'shliq).
class DiffToken {
  /// Asl matn bo'lagi — barcha tokenlarni ketma-ket qo'shsak, kirish matni chiqadi.
  final String text;

  /// `true` — bu bo'lak asl matnda yo'q edi (qo'shilgan yoki o'zgartirilgan).
  /// Bo'shliq va tinish belgilaridan iborat bo'laklar hech qachon belgilanmaydi.
  final bool changed;

  const DiffToken(this.text, {required this.changed});

  @override
  String toString() => 'DiffToken($text, changed: $changed)';

  @override
  bool operator ==(Object other) =>
      other is DiffToken && other.text == text && other.changed == changed;

  @override
  int get hashCode => Object.hash(text, changed);
}

final RegExp _tokenRe = RegExp(r'\s+|[^\s]+');
final RegExp _wsRe = RegExp(r'^\s+$');
final RegExp _edgeRe = RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true);

List<String> _tokenize(String s) => _tokenRe.allMatches(s).map((m) => m[0]!).toList();

/// Solishtirish uchun normallashtirish: kichik harf + chetdagi tinish belgilarini olib tashlash.
String _normTok(String t) {
  if (_wsRe.hasMatch(t)) return ' ';
  return t.toLowerCase().replaceAll(_edgeRe, '');
}

/// [improved] matnini bo'laklarga ajratadi va har biri uchun "o'zgarganmi"
/// bayrog'ini qaytaradi (LCS orqali [original] bilan solishtiriladi).
List<DiffToken> diffImproved(String original, String improved) {
  final o = _tokenize(original);
  final m = _tokenize(improved);
  final no = o.map(_normTok).toList();
  final nm = m.map(_normTok).toList();
  final n = o.length;
  final k = m.length;

  // LCS DP (orqaga) — bo'sh normli tokenlar mos kelmaydi.
  final dp = List.generate(n + 1, (_) => List<int>.filled(k + 1, 0));
  for (int i = n - 1; i >= 0; i--) {
    for (int j = k - 1; j >= 0; j--) {
      dp[i][j] = (no[i] == nm[j] && no[i] != '' && no[i] != ' ')
          ? dp[i + 1][j + 1] + 1
          : (dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
    }
  }

  // Backtrack — yaxshilangan tomonda qaysi tokenlar o'zgarmagan.
  final matched = List<bool>.filled(k, false);
  int i = 0;
  int j = 0;
  while (i < n && j < k) {
    if (no[i] == nm[j] && no[i] != '' && no[i] != ' ') {
      matched[j] = true;
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }

  final out = <DiffToken>[];
  for (int idx = 0; idx < k; idx++) {
    final tok = m[idx];
    final plain = _wsRe.hasMatch(tok) || _normTok(tok) == '' || matched[idx];
    out.add(DiffToken(tok, changed: !plain));
  }
  return out;
}
