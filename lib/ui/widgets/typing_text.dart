/// Text that types itself onto the screen, with a soft click every second
/// letter (none on spaces) and a short pause at full stops and commas.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../data/glossary.dart';

/// When each character appears (seconds from the start). Pure, for tests.
List<double> typeSchedule(String text, {double speed = 1, double charsPerSecond = 46}) {
  final step = 1 / (charsPerSecond * speed.clamp(0.3, 3.0));
  final out = <double>[];
  var t = 0.0;
  for (var i = 0; i < text.length; i++) {
    out.add(t);
    final ch = text[i];
    t += step;
    if ('.!?'.contains(ch)) t += 0.24 / speed;
    if (',;:'.contains(ch)) t += 0.11 / speed;
  }
  return out;
}

/// Characters visible at time [t].
int typedChars(List<double> schedule, double t) {
  var lo = 0, hi = schedule.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (schedule[mid] <= t) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}

/// Drives the typing: call [tick] every frame; [onClick] fires on every
/// second non-space letter.
class TypingClock {
  final String text;
  final List<double> _sched;
  final VoidCallback? onClick;
  int shown = 0;
  int _letters = 0;

  TypingClock(this.text, {double speed = 1, this.onClick}) : _sched = typeSchedule(text, speed: speed);

  bool get done => shown >= text.length;

  /// Returns true when more text appeared.
  bool tick(double elapsed) {
    final n = typedChars(_sched, elapsed);
    if (n <= shown) return false;
    for (var i = shown; i < n; i++) {
      final ch = text[i];
      if (ch.trim().isNotEmpty) {
        _letters++;
        if (_letters.isOdd) onClick?.call();
      }
    }
    shown = n;
    return true;
  }

  void finish() => shown = text.length;
}

/// Text spans for a line that is [shown] characters typed. Hard words get a
/// dotted underline and can be tapped ([recognizers] holds one per tip).
/// The untyped rest is laid out invisibly so the box never jumps.
List<InlineSpan> typedSpans(
  String text,
  int shown, {
  List<TipHit> tips = const [],
  Map<String, TapGestureRecognizer> recognizers = const {},
  Color tipColor = const Color(0xFF09BBC8),
}) {
  final spans = <InlineSpan>[];
  const hidden = TextStyle(color: Colors.transparent);
  void plain(int a, int b) {
    if (a >= b) return;
    if (shown >= b) {
      spans.add(TextSpan(text: text.substring(a, b)));
    } else if (shown <= a) {
      spans.add(TextSpan(text: text.substring(a, b), style: hidden));
    } else {
      spans
        ..add(TextSpan(text: text.substring(a, shown)))
        ..add(TextSpan(text: text.substring(shown, b), style: hidden));
    }
  }

  var at = 0;
  for (final h in tips) {
    if (h.start < at || h.end > text.length) continue;
    plain(at, h.start);
    if (shown >= h.end) {
      spans.add(
        TextSpan(
          text: text.substring(h.start, h.end),
          recognizer: recognizers[h.tip.id],
          style: TextStyle(color: tipColor, decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dotted, decorationColor: tipColor, decorationThickness: 2),
        ),
      );
    } else {
      plain(h.start, h.end);
    }
    at = h.end;
  }
  plain(at, text.length);
  return spans;
}

/// Keeps one tap recognizer per word tip, and disposes them.
class TipRecognizers {
  final Map<String, TapGestureRecognizer> map = {};
  void sync(List<TipHit> tips, void Function(WordTip tip)? onTip) {
    dispose();
    if (onTip == null) return;
    for (final h in tips) {
      map[h.tip.id] = TapGestureRecognizer()..onTap = () => onTip(h.tip);
    }
  }

  void dispose() {
    for (final r in map.values) {
      r.dispose();
    }
    map.clear();
  }
}

/// A self-contained typing text (Pip's cards and other short messages).
class TypingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double speed;
  final bool instant;
  final VoidCallback? onClick;
  final int? maxLines;

  /// Hard words to underline, and what happens when one is tapped.
  final List<TipHit> tips;
  final void Function(WordTip tip)? onTip;
  const TypingText(this.text, {super.key, this.style, this.speed = 1, this.instant = false, this.onClick, this.maxLines, this.tips = const [], this.onTip});

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> with SingleTickerProviderStateMixin {
  late TypingClock _clock = TypingClock(widget.text, speed: widget.speed, onClick: widget.onClick);
  Ticker? _ticker;
  final _rec = TipRecognizers();

  @override
  void initState() {
    super.initState();
    _rec.sync(widget.tips, widget.onTip);
    if (widget.instant) {
      _clock.finish();
    } else {
      _ticker = createTicker((e) {
        if (_clock.tick(e.inMicroseconds / 1e6)) setState(() {});
        if (_clock.done) _ticker?.stop();
      })..start();
    }
  }

  @override
  void didUpdateWidget(covariant TypingText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _rec.sync(widget.tips, widget.onTip);
      _clock = TypingClock(widget.text, speed: widget.speed, onClick: widget.onClick);
      if (widget.instant) {
        _clock.finish();
      } else {
        _ticker?.stop();
        _ticker?.start();
      }
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _rec.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.text;
    final n = _clock.shown.clamp(0, t.length);
    // the rest of the text is laid out invisibly, so the box never jumps
    return Text.rich(
      TextSpan(
        children: typedSpans(t, n, tips: widget.tips, recognizers: _rec.map),
      ),
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}
