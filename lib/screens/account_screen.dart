import 'package:flutter/material.dart';

import '../main.dart';
import '../story/story_model.dart' show AgeModeInfo;
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import '../world/characters.dart';
import 'info_screens.dart';

/// Sign in, sign up and the student's class. Guests can always just play.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

enum _Mode { choose, student, teacherIn, teacherUp, code }

class _AccountScreenState extends State<AccountScreen> {
  _Mode _mode = _Mode.choose;
  final _user = TextEditingController();
  final _pin = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _join = TextEditingController();
  String? _error;
  String? _info;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_user, _pin, _email, _pass, _name, _code, _join]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() f, {VoidCallback? then}) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final err = await f();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
    if (err == null) then?.call();
  }

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final s = sv.session;
    return AnimatedBuilder(
      animation: Listenable.merge([s, sv.progress]),
      builder: (context, _) {
        if (s.signedIn) return _signedIn();
        if (!s.cloudAvailable) {
          return InfoFrame(
            title: 'Your account',
            subtitle: 'This build runs offline: everything is saved on this phone.',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _note('Sign-in, classes and online co-op need the cloud keys (see README → Cloud setup). The whole game, same-phone co-op and the sample teacher dashboard work without them.'),
              const SizedBox(height: 16),
              PrimaryButton(label: 'Play as a guest', icon: Icons.play_arrow_rounded, onTap: () => sv.nav.resetTo(Screen.title)),
              const SizedBox(height: 10),
              HudButton(label: 'SEE THE TEACHER DASHBOARD', icon: Icons.dashboard_rounded, onTap: () => sv.nav.openTeacher(sv)),
            ]),
          );
        }
        return InfoFrame(
          title: switch (_mode) {
            _Mode.student => 'Student sign in',
            _Mode.teacherIn => 'Teacher sign in',
            _Mode.teacherUp || _Mode.code => 'New teacher account',
            _Mode.choose => 'Who is playing?',
          },
          subtitle: switch (_mode) {
            _Mode.student => 'Use the card your teacher gave you.',
            _Mode.teacherIn || _Mode.teacherUp => 'Make classes, set the age level, and see who needs help.',
            _Mode.code => 'We emailed you a 6-digit code.',
            _Mode.choose => 'Sign in to save progress for your class. Or just play: progress stays on this phone.',
          },
          child: AnimatedSwitcher(duration: Motion.normal, child: KeyedSubtree(key: ValueKey(_mode), child: _body())),
        );
      },
    );
  }

  Widget _body() {
    final sv = Services.of(context);
    final s = sv.session;
    switch (_mode) {
      case _Mode.choose:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _choice(Icons.badge_rounded, 'I am a student', 'Username and PIN from my teacher', () => setState(() => _mode = _Mode.student)),
          _choice(Icons.school_rounded, 'I am a teacher', 'Sign in or create an account', () => setState(() => _mode = _Mode.teacherIn)),
          _choice(Icons.rocket_launch_rounded, 'Just play', 'As a guest, no account', () => sv.nav.resetTo(Screen.title)),
          const SizedBox(height: 8),
          _note('We never ask children for an email. Student accounts are made by teachers and use a username and a 4-digit PIN.'),
        ]);
      case _Mode.student:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: PipFigure(size: 70, eye: _error == null ? PipEye.happy : PipEye.thinking)),
          const SizedBox(height: 12),
          _field(_user, 'Username', hint: 'rana_7b4mxq', icon: Icons.person_rounded),
          _field(_pin, 'PIN', hint: '4 numbers', icon: Icons.pin_rounded, number: true, obscure: true, max: 4),
          _status(),
          PrimaryButton(
            label: _busy ? 'Signing in…' : 'Sign in',
            icon: Icons.login_rounded,
            onTap: _busy ? null : () => _run(() => s.signInStudent(_user.text, _pin.text), then: () => sv.nav.resetTo(Screen.title)),
          ),
          _back(),
        ]);
      case _Mode.teacherIn:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _field(_email, 'School email', icon: Icons.mail_rounded, email: true),
          _field(_pass, 'Password', icon: Icons.lock_rounded, obscure: true),
          _status(),
          PrimaryButton(
            label: _busy ? 'Signing in…' : 'Sign in',
            icon: Icons.login_rounded,
            onTap: _busy ? null : () => _run(() => s.signInTeacher(_email.text, _pass.text), then: () => sv.nav.openTeacher(sv)),
          ),
          const SizedBox(height: 10),
          HudButton(label: 'CREATE A TEACHER ACCOUNT', onTap: () => setState(() => _mode = _Mode.teacherUp)),
          _back(),
        ]);
      case _Mode.teacherUp:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _field(_name, 'Name students will see', hint: 'Ms Haddad', icon: Icons.badge_rounded),
          _field(_email, 'School email', icon: Icons.mail_rounded, email: true),
          _field(_pass, 'Password (8+ characters)', icon: Icons.lock_rounded, obscure: true),
          _status(),
          PrimaryButton(
            label: _busy ? 'Sending code…' : 'Send me a code',
            icon: Icons.mark_email_read_rounded,
            onTap: _busy ? null : () => _run(() => s.startTeacherSignUp(_name.text, _email.text, _pass.text), then: () => setState(() => _mode = s.signedIn ? _Mode.choose : _Mode.code)),
          ),
          _back(to: _Mode.teacherIn),
        ]);
      case _Mode.code:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _field(_code, '6-digit code', icon: Icons.password_rounded, number: true, max: 6),
          _status(),
          PrimaryButton(
            label: _busy ? 'Checking…' : 'Finish sign-up',
            icon: Icons.check_rounded,
            onTap: _busy ? null : () => _run(() => s.verifyTeacherCode(_code.text), then: () => sv.nav.openTeacher(sv)),
          ),
          _back(to: _Mode.teacherUp),
        ]);
    }
  }

  Widget _signedIn() {
    final sv = Services.of(context);
    final s = sv.session;
    final p = sv.progress;
    return InfoFrame(
      title: s.name,
      subtitle: s.isTeacher ? 'Teacher account' : 'Student · ${p.campaign.mode.title} level${p.rankLocked ? ', set by your teacher' : ''}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (s.isTeacher) ...[
          PrimaryButton(label: 'Open the teacher dashboard', icon: Icons.dashboard_rounded, onTap: () => sv.nav.openTeacher(sv)),
        ] else ...[
          GlassPanel(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('MY CLASS', style: T.label.copyWith(fontSize: 11)),
              const SizedBox(height: 6),
              if (p.className != null) ...[
                Text(p.className!, style: T.h2),
                if ((p.teacherName ?? '').isNotEmpty) Text('Teacher: ${p.teacherName}', style: T.bodySmall),
                const SizedBox(height: 6),
                Text('You play the ${p.campaign.title} campaign.', style: T.body.copyWith(color: C.muted)),
              ] else ...[
                Text('Not in a class yet. Ask your teacher for the 6-letter code.', style: T.body.copyWith(color: C.muted)),
                const SizedBox(height: 10),
                _field(_join, 'Class code', hint: 'MOON7B', icon: Icons.groups_rounded, max: 6, caps: true),
                _status(),
                PrimaryButton(label: _busy ? 'Joining…' : 'Join class', icon: Icons.group_add_rounded, onTap: _busy ? null : () => _run(() => s.joinClass(_join.text))),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(s.pending == 0 ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded, color: s.pending == 0 ? C.cyan : C.violet),
              const SizedBox(width: 10),
              Expanded(child: Text(s.pending == 0 ? 'Progress saved to your class.' : '${s.pending} result${s.pending == 1 ? '' : 's'} waiting to sync. They are safe on this phone.', style: T.body)),
              if (s.pending > 0) TextButton(onPressed: s.flush, child: const Text('Sync now')),
            ]),
          ),
          if (s.lastError != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(s.lastError!, style: T.bodySmall.copyWith(color: C.violet))),
        ],
        const SizedBox(height: 16),
        HudButton(label: 'SIGN OUT', icon: Icons.logout_rounded, color: C.muted, onTap: () async {
          await s.signOut();
          if (mounted) setState(() => _mode = _Mode.choose);
        }),
      ]),
    );
  }

  Widget _choice(IconData icon, String title, String sub, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Pressable(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: C.panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.line)),
            child: Row(children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: C.cyan.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: C.cyan)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: T.h3.copyWith(fontSize: 16)), Text(sub, style: T.bodySmall)])),
              const Icon(Icons.chevron_right_rounded, color: C.dim),
            ]),
          ),
        ),
      );

  Widget _field(TextEditingController c, String label, {String? hint, IconData? icon, bool obscure = false, bool number = false, bool email = false, int? max, bool caps = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          obscureText: obscure,
          maxLength: max,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: caps ? TextCapitalization.characters : TextCapitalization.none,
          keyboardType: number ? TextInputType.number : (email ? TextInputType.emailAddress : TextInputType.text),
          style: T.body.copyWith(fontSize: 16),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            counterText: '',
            prefixIcon: icon == null ? null : Icon(icon, color: C.muted),
            filled: true,
            fillColor: C.panelDeep,
            labelStyle: T.body.copyWith(color: C.muted),
            hintStyle: T.body.copyWith(color: C.dim),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: C.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: C.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: C.cyan, width: 1.6)),
          ),
        ),
      );

  Widget _status() => AnimatedSize(
        duration: Motion.fast,
        child: _error == null && _info == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error ?? _info!, style: T.body.copyWith(color: _error != null ? C.violet : C.cyan)),
              ),
      );

  Widget _note(String s) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.cyan.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(16), border: Border.all(color: C.cyan.withValues(alpha: 0.3))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.shield_rounded, color: C.cyan, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(s, style: T.bodySmall.copyWith(color: C.text))),
        ]),
      );

  Widget _back({_Mode to = _Mode.choose}) => TextButton(
        onPressed: () {
          if (_mode == _Mode.code) Services.of(context).session.auth.cancelSignUp();
          setState(() {
            _mode = to;
            _error = null;
          });
        },
        child: const Text('Back'),
      );
}
