import 'package:flutter/material.dart';
import '../ui/game_helper.dart';

import '../main.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import '../world/characters.dart';
import 'info_screens.dart';

/// Optional in-app accounts. Guests can always play without signing in.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

enum _Mode { choose, signIn, signUp, student, teacherIn }

class _AccountScreenState extends State<AccountScreen> {
  _Mode _mode = _Mode.choose;
  bool _asTeacher = false;
  bool _showPass = false;
  final _user = TextEditingController();
  final _pin = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  final _join = TextEditingController();
  String? _error;
  String? _info;
  bool _busy = false;
  /// Just signed in as a player — keep the plaque visible (no bounce to Station).
  bool _welcome = false;

  @override
  void dispose() {
    for (final c in [_user, _pin, _email, _pass, _name, _join]) {
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
        return InfoFrame(
          title: switch (_mode) {
            _Mode.signIn => 'Welcome back',
            _Mode.signUp => _asTeacher ? 'Teacher account' : 'Create account',
            _Mode.student => 'Class card',
            _Mode.teacherIn => 'Teacher sign in',
            _Mode.choose => 'Station access',
          },
          subtitle: switch (_mode) {
            _Mode.signIn => 'Pick up where you left off on this device.',
            _Mode.signUp => _asTeacher ? 'Make classes and try demo rooms.' : 'Optional — you can always play as a guest.',
            _Mode.student => 'Username and PIN from your teacher.',
            _Mode.teacherIn => 'Open demo classes with students and levels.',
            _Mode.choose => 'Sign in, or keep playing as a guest.',
          },
          child: EnterAnim(
            child: AnimatedSwitcher(
              duration: Motion.normal,
              child: KeyedSubtree(key: ValueKey(_mode), child: _authCard(_body())),
            ),
          ),
        );
      },
    );
  }

  Widget _authCard(Widget child) => GlassPanel(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: child,
      );

  Widget _body() {
    final sv = Services.of(context);
    final s = sv.session;
    switch (_mode) {
      case _Mode.choose:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Center(child: PipFigure(size: 64, eye: PipEye.happy)),
          const SizedBox(height: 14),
          _lane(Icons.login_rounded, 'Player sign in', 'Email and password', () => setState(() => _mode = _Mode.signIn)),
          _lane(Icons.badge_rounded, 'Class card', 'Username and PIN', () => setState(() => _mode = _Mode.student)),
          _lane(Icons.school_rounded, 'Teacher', 'Demo classes ready', () => setState(() => _mode = _Mode.teacherIn)),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => setState(() {
              _mode = _Mode.signUp;
              _asTeacher = false;
              _error = null;
            }),
            child: const GameText('Create an account'),
          ),
          TextButton(
            onPressed: () => sv.nav.openTeacher(sv),
            child: const GameText('Teacher demo'),
          ),
          TextButton(
            onPressed: () => sv.nav.resetTo(Screen.title),
            child: GameText('Continue as guest', style: T.body.copyWith(color: C.muted)),
          ),
        ]);
      case _Mode.signIn:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _field(_email, 'Email', icon: Icons.mail_rounded, email: true),
          _field(_pass, 'Password', icon: Icons.lock_rounded, obscure: !_showPass, togglePass: true),
          _status(),
          PrimaryButton(
            label: _busy ? 'Signing in…' : 'Sign in',
            icon: Icons.login_rounded,
            onTap: _busy
                ? null
                : () => _run(
                      () => s.signInEmail(_email.text, _pass.text),
                      then: () => s.isTeacher ? sv.nav.openTeacher(sv) : setState(() => _welcome = true),
                    ),
          ),
          TextButton(
            onPressed: () => setState(() {
              _mode = _Mode.signUp;
              _asTeacher = false;
              _error = null;
            }),
            child: const GameText('Need an account? Create one'),
          ),
          _back(),
        ]);
      case _Mode.signUp:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _field(_name, 'Display name', hint: 'Alex', icon: Icons.badge_rounded),
          _field(_email, 'Email', icon: Icons.mail_rounded, email: true),
          _field(_pass, 'Password', icon: Icons.lock_rounded, obscure: !_showPass, togglePass: true),
          _roleToggle(),
          _status(),
          PrimaryButton(
            label: _busy ? 'Creating…' : 'Create account',
            icon: Icons.check_rounded,
            onTap: _busy
                ? null
                : () => _run(
                      () => s.signUp(name: _name.text, email: _email.text, password: _pass.text, asTeacher: _asTeacher),
                      then: () => _asTeacher ? sv.nav.openTeacher(sv) : setState(() => _welcome = true),
                    ),
          ),
          _back(),
        ]);
      case _Mode.student:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Center(child: PipFigure(size: 70, eye: PipEye.happy)),
          const SizedBox(height: 12),
          _field(_user, 'Username', hint: 'rana_7b4mxq', icon: Icons.person_rounded),
          _field(_pin, 'PIN', hint: '4 numbers', icon: Icons.pin_rounded, number: true, obscure: true, max: 4),
          _status(),
          PrimaryButton(
            label: _busy ? 'Signing in…' : 'Sign in',
            icon: Icons.login_rounded,
            onTap: _busy
                ? null
                : () => _run(() => s.signInStudent(_user.text, _pin.text), then: () => setState(() => _welcome = true)),
          ),
          _back(),
        ]);
      case _Mode.teacherIn:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _field(_email, 'School email', icon: Icons.mail_rounded, email: true),
          _field(_pass, 'Password', icon: Icons.lock_rounded, obscure: !_showPass, togglePass: true),
          _status(),
          PrimaryButton(
            label: _busy ? 'Signing in…' : 'Sign in',
            icon: Icons.login_rounded,
            onTap: _busy ? null : () => _run(() => s.signInTeacher(_email.text, _pass.text), then: () => sv.nav.openTeacher(sv)),
          ),
          const SizedBox(height: 8),
          HudButton(
            label: 'CREATE A TEACHER ACCOUNT',
            onTap: () => setState(() {
              _mode = _Mode.signUp;
              _asTeacher = true;
            }),
          ),
          const SizedBox(height: 12),
          _note('Demo: teacher1@openbounds.app / TeacherDemo1!'),
          _back(),
        ]);
    }
  }

  Widget _roleToggle() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, top: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: C.panelDeep, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Expanded(child: _roleChip('Player', !_asTeacher, () => setState(() => _asTeacher = false))),
        Expanded(child: _roleChip('Teacher', _asTeacher, () => setState(() => _asTeacher = true))),
      ]),
    );
  }

  Widget _roleChip(String label, bool on, VoidCallback tap) {
    return Pressable(
      onTap: tap,
      child: AnimatedContainer(
        duration: Motion.fast,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: on ? C.sapphire : Colors.transparent, borderRadius: BorderRadius.circular(12)),
        child: GameText(label.toUpperCase(), style: T.label.copyWith(color: on ? Colors.white : C.muted, fontSize: 11)),
      ),
    );
  }

  Widget _signedIn() {
    final sv = Services.of(context);
    final s = sv.session;
    final p = sv.progress;
    final trimmed = s.name.trim();
    final initial = trimmed.isEmpty ? 'C' : trimmed[0].toUpperCase();
    return InfoFrame(
      title: 'Crew plaque',
      subtitle: s.isTeacher ? 'Teacher · demo classes on this device' : 'Signed in · progress stays on this device',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_welcome && !s.isTeacher) ...[
          EnterAnim(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: C.cyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: C.cyan.withValues(alpha: 0.35)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, color: C.cyan, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: GameText(
                    p.className == null ? 'Welcome aboard, ${s.name}. Join a class below, or head back to the Station.' : 'Welcome back, ${s.name}.',
                    style: T.body.copyWith(color: C.frozen, fontSize: 14),
                  ),
                ),
              ]),
            ),
          ),
        ],
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [C.panelDeep, C.sapphire.withValues(alpha: 0.35)]),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: C.cyan.withValues(alpha: 0.35)),
          ),
          child: Row(children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: C.cyan.withValues(alpha: 0.18),
                border: Border.all(color: C.cyan.withValues(alpha: 0.55), width: 1.4),
              ),
              child: GameText(initial, style: T.h2.copyWith(color: C.cyan, fontSize: 28)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GameText(s.name, style: T.h2.copyWith(fontSize: 22)),
                if ((s.auth.email ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  GameText(s.auth.email!, style: T.bodySmall.copyWith(color: C.muted)),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: C.cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: C.cyan.withValues(alpha: 0.35)),
                  ),
                  child: GameText(s.isTeacher ? 'TEACHER' : 'PLAYER', style: T.label.copyWith(fontSize: 10, color: C.cyan)),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        if (s.isTeacher) ...[
          PrimaryButton(label: 'Open the teacher dashboard', icon: Icons.dashboard_rounded, onTap: () => sv.nav.openTeacher(sv)),
          const SizedBox(height: 10),
          HudButton(label: 'Back to Station', icon: Icons.home_rounded, onTap: () => sv.nav.resetTo(Screen.title)),
        ] else ...[
          GlassPanel(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GameText('MY CLASS', style: T.label.copyWith(fontSize: 11)),
              const SizedBox(height: 8),
              if (p.className != null) ...[
                GameText(p.className!, style: T.h2.copyWith(fontSize: 20)),
                if ((p.teacherName ?? '').isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 4), child: GameText('Teacher: ${p.teacherName}', style: T.bodySmall)),
                const SizedBox(height: 8),
                GameText('Campaign: ${p.campaign.title}', style: T.body.copyWith(color: C.muted)),
              ] else ...[
                GameText('Not in a class yet. Try demo code MOON7B.', style: T.body.copyWith(color: C.muted)),
                const SizedBox(height: 12),
                _field(_join, 'Class code', hint: 'MOON7B', icon: Icons.groups_rounded, max: 6, caps: true),
                _status(),
                PrimaryButton(
                  label: _busy ? 'Joining…' : 'Join class',
                  icon: Icons.group_add_rounded,
                  onTap: _busy ? null : () => _run(() => s.joinClass(_join.text)),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          const GlassPanel(
            padding: EdgeInsets.all(16),
            child: Row(children: [
              Icon(Icons.phone_android_rounded, color: C.cyan),
              SizedBox(width: 10),
              Expanded(child: GameText('Progress is saved on this device while you play.', style: T.body)),
            ]),
          ),
          const SizedBox(height: 12),
          HudButton(label: 'Back to Station', icon: Icons.home_rounded, onTap: () => sv.nav.resetTo(Screen.title)),
        ],
        const SizedBox(height: 18),
        HudButton(
          label: 'SIGN OUT',
          icon: Icons.logout_rounded,
          color: C.muted,
          onTap: () async {
            await s.signOut();
            if (mounted) {
              setState(() {
                _mode = _Mode.choose;
                _welcome = false;
              });
            }
          },
        ),
      ]),
    );
  }

  Widget _lane(IconData icon, String title, String sub, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Pressable(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: C.panelDeep.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: C.line),
            ),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: C.cyan.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: C.cyan),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  GameText(title, style: T.h3.copyWith(fontSize: 16)),
                  GameText(sub, style: T.bodySmall),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: C.dim),
            ]),
          ),
        ),
      );

  Widget _field(
    TextEditingController c,
    String label, {
    String? hint,
    IconData? icon,
    bool obscure = false,
    bool number = false,
    bool email = false,
    int? max,
    bool caps = false,
    bool togglePass = false,
  }) =>
      Padding(
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
            suffixIcon: togglePass
                ? IconButton(
                    onPressed: () => setState(() => _showPass = !_showPass),
                    icon: Icon(_showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: C.muted),
                  )
                : null,
            filled: true,
            fillColor: C.panelDeep,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                padding: const EdgeInsets.only(top: 4, bottom: 10),
                child: GameText(_error ?? _info!, style: T.body.copyWith(color: _error != null ? C.red : C.cyan)),
              ),
      );

  Widget _note(String s) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.cyan.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.cyan.withValues(alpha: 0.28)),
        ),
        child: GameText(s, style: T.bodySmall.copyWith(color: C.muted, fontSize: 12)),
      );

  Widget _back({_Mode to = _Mode.choose}) => TextButton(
        onPressed: () => setState(() {
          _mode = to;
          _error = null;
          _showPass = false;
        }),
        child: const GameText('Back'),
      );
}
