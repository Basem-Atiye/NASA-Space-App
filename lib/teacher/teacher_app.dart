/// The teacher app, on the phone: a clear light dashboard with six tabs.
///
///   Today     who needs help now, class progress, Pip's insights, live lesson
///   Class     learning gain (Readiness Check), skills, where the class gets stuck, goals
///   Students  every student, with a detail page (skills vs class, decisions, nudges)
///   Lessons   the campaign's levels with lesson notes, assign them
///   Live      run a lesson: who is on which step, who asked for help, pause all
///   Me        account, classes (with the age level), sign-in cards, export
///
/// A signed-in teacher sees their own classes; anyone else sees a sample class.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../cloud/link.dart';
import '../cloud/models.dart';
import '../cloud/teacher_repo.dart';
import '../data/catalogue.dart';
import '../main.dart';
import '../story/campaign.dart';
import '../story/story_model.dart' show AgeMode, AgeModeInfo;
import '../ui/theme.dart';
import 'charts.dart';
import 'insights.dart';

class TeacherApp extends StatefulWidget {
  const TeacherApp({super.key});

  @override
  State<TeacherApp> createState() => _TeacherAppState();
}

class _TeacherAppState extends State<TeacherApp> {
  int _tab = 0;
  List<ClassInfo> _classes = [];
  ClassInfo? _class;
  bool _loading = true;
  String? _error;
  int _reload = 0;

  TeacherRepo get repo => Services.of(context).session.teacherRepo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_classes.isEmpty && _loading) _load();
  }

  Future<void> _load({String? select}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await repo.classes();
      if (!mounted) return;
      setState(() {
        _classes = list;
        _class = list.where((c) => c.id == (select ?? _class?.id)).firstOrNull ?? (list.isEmpty ? null : list.first);
        _loading = false;
        _reload++;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void refresh() => _load();

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final top = MediaQuery.of(context).padding.top;
    final pages = <Widget Function()>[
      () => _TodayTab(repo: repo, klass: _class!, key: ValueKey('today-${_class!.id}-$_reload'), onTab: (i) => setState(() => _tab = i)),
      () => _ClassTab(repo: repo, klass: _class!, key: ValueKey('class-${_class!.id}-$_reload')),
      () => _StudentsTab(repo: repo, klass: _class!, key: ValueKey('students-${_class!.id}-$_reload')),
      () => _LessonsTab(repo: repo, klass: _class!, key: ValueKey('lessons-${_class!.id}-$_reload')),
      () => _LiveTab(repo: repo, klass: _class!, key: ValueKey('live-${_class!.id}')),
    ];
    return Theme(
      data: _teacherTheme(),
      child: ColoredBox(
        color: TC.bg,
        child: Column(children: [
          // header: back, title, class switcher
          Container(
            padding: EdgeInsets.fromLTRB(8, top + 6, 12, 10),
            decoration: const BoxDecoration(color: TC.card, border: Border(bottom: BorderSide(color: TC.line))),
            child: Row(children: [
              IconButton(onPressed: () => sv.nav.resetTo(Screen.title), icon: const Icon(Icons.arrow_back_rounded, color: TC.ink)),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('TEACHER', style: TextStyle(fontFamily: F.display, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 2, color: TC.teal)),
                    if (repo.isDemo) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: TC.warn.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: const Text('SAMPLE CLASS', style: TextStyle(fontFamily: F.display, fontWeight: FontWeight.w800, fontSize: 9.5, letterSpacing: 1, color: TC.warn)),
                      ),
                    ],
                  ]),
                  if (_class != null)
                    InkWell(
                      onTap: _pickClass,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(child: Text(_class!.name, style: const TextStyle(fontFamily: F.serif, fontWeight: FontWeight.w700, fontSize: 21, color: TC.ink), overflow: TextOverflow.ellipsis)),
                        const Icon(Icons.expand_more_rounded, color: TC.ink),
                      ]),
                    )
                  else
                    const Text('Your classes', style: TextStyle(fontFamily: F.serif, fontWeight: FontWeight.w700, fontSize: 21, color: TC.ink)),
                ]),
              ),
              if (_class != null) _ageChip(_class!.ageMode),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: TC.blue))
                : _error != null
                    ? _errorView()
                    : (_class == null || _tab == 5)
                        ? _MeTab(repo: repo, classes: _classes, onChanged: (id) => _load(select: id), onCreate: _createClass, onEdit: _editClass, onCards: _addStudents)
                        : AnimatedSwitcher(duration: Motion.fast, child: KeyedSubtree(key: ValueKey('$_tab-${_class!.id}-$_reload'), child: pages[_tab]())),
          ),
          _tabBar(),
        ]),
      ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: TC.faint),
            const SizedBox(height: 10),
            Text(_error ?? '', style: const TextStyle(color: TC.sub), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Try again')),
          ]),
        ),
      );

  Widget _ageChip(AgeMode m) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: TC.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Text('${m.title} · ${m.ages}', style: const TextStyle(fontFamily: F.body, fontWeight: FontWeight.w700, fontSize: 11.5, color: TC.blue)),
      );

  Widget _tabBar() {
    const items = [
      (Icons.today_rounded, 'Today'),
      (Icons.insights_rounded, 'Class'),
      (Icons.people_alt_rounded, 'Students'),
      (Icons.menu_book_rounded, 'Lessons'),
      (Icons.sensors_rounded, 'Live'),
      (Icons.person_rounded, 'Me'),
    ];
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottom, top: 4),
      decoration: const BoxDecoration(color: TC.card, border: Border(top: BorderSide(color: TC.line))),
      child: Row(children: [
        for (var i = 0; i < items.length; i++)
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _tab = i),
              child: SizedBox(
                height: 56,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(items[i].$1, color: _tab == i ? TC.blue : TC.faint, size: 23),
                  const SizedBox(height: 2),
                  Text(items[i].$2, style: TextStyle(fontFamily: F.body, fontWeight: FontWeight.w700, fontSize: 10.5, color: _tab == i ? TC.blue : TC.faint)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  Future<void> _pickClass() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: TC.card,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final c in _classes)
            ListTile(
              leading: CircleAvatar(backgroundColor: TC.blue.withValues(alpha: 0.12), child: Text(c.name.characters.first, style: const TextStyle(color: TC.blue))),
              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, color: TC.ink)),
              subtitle: Text('${c.ageMode.title} · code ${c.joinCode}', style: const TextStyle(color: TC.sub)),
              trailing: c.id == _class?.id ? const Icon(Icons.check_rounded, color: TC.blue) : null,
              onTap: () => Navigator.pop(ctx, c.id),
            ),
          ListTile(
            leading: const Icon(Icons.add_rounded, color: TC.blue),
            title: const Text('New class', style: TextStyle(fontWeight: FontWeight.w700, color: TC.blue)),
            onTap: () => Navigator.pop(ctx, '+'),
          ),
        ]),
      ),
    );
    if (picked == '+') {
      await _createClass();
    } else if (picked != null) {
      setState(() {
        _class = _classes.firstWhere((c) => c.id == picked);
        _reload++;
      });
    }
  }

  Future<void> _createClass() async {
    final r = await showModalBottomSheet<(String, AgeMode, bool)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.card,
      showDragHandle: true,
      builder: (ctx) => const _ClassForm(),
    );
    if (r == null) return;
    try {
      final c = await repo.createClass(r.$1, r.$2, lockRank: r.$3);
      await _load(select: c.id);
      if (!mounted) return;
      await _showCode(c);
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _editClass(ClassInfo c) async {
    final r = await showModalBottomSheet<(String, AgeMode, bool)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.card,
      showDragHandle: true,
      builder: (ctx) => _ClassForm(initial: c),
    );
    if (r == null) return;
    try {
      await repo.updateClass(c.copyWith(name: r.$1, ageMode: r.$2, lockRank: r.$3));
      await _load(select: c.id);
      _snack(r.$2 != c.ageMode ? 'Every student in ${r.$1} now plays the ${r.$2.title} campaign.' : 'Saved.');
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _showCode(ClassInfo c) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: TC.card,
          title: Text('${c.name} is ready', style: const TextStyle(color: TC.ink)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Students who already have an account join with this code:', style: TextStyle(color: TC.sub)),
            const SizedBox(height: 14),
            _JoinCode(code: c.joinCode),
            const SizedBox(height: 14),
            Text('Everyone in this class plays the ${c.ageMode.title} campaign (${c.ageMode.ages}).', style: const TextStyle(color: TC.sub), textAlign: TextAlign.center),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _addStudents(c);
              },
              child: const Text('Make sign-in cards'),
            ),
          ],
        ),
      );

  Future<void> _addStudents(ClassInfo c) async {
    final names = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.card,
      showDragHandle: true,
      builder: (ctx) => const _NamesForm(),
    );
    if (names == null || names.isEmpty || !mounted) return;
    try {
      final r = await repo.createStudents(c.id, names);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => Theme(data: _teacherTheme(), child: CardsPage(klass: c, cards: r.cards, failed: r.failed))));
      _load(select: c.id);
    } catch (e) {
      _snack('$e');
    }
  }

  void _snack(String s) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(s)));
}

ThemeData _teacherTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: F.body,
      colorScheme: ColorScheme.fromSeed(seedColor: C.sapphire, brightness: Brightness.light, surface: TC.card),
      scaffoldBackgroundColor: TC.bg,
      dividerColor: TC.line,
    );

// ------------------------------------------------------------------ shared bits

class _Card extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  const _Card({required this.child, this.title, this.trailing, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: padding,
        decoration: BoxDecoration(
          color: TC.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: TC.line),
          boxShadow: const [BoxShadow(color: Color(0x0D07240F), blurRadius: 16, offset: Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Expanded(child: Text(title!.toUpperCase(), style: const TextStyle(fontFamily: F.display, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.6, color: TC.sub))),
                if (trailing != null) trailing!,
              ]),
            ),
          child,
        ]),
      );
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _Stat(this.value, this.label, {this.color = TC.ink});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontFamily: F.serif, fontWeight: FontWeight.w700, fontSize: 26, color: color)),
        Text(label, style: const TextStyle(fontFamily: F.body, fontWeight: FontWeight.w600, fontSize: 12, color: TC.sub)),
      ]);
}

Widget _avatar(String name, {Color color = TC.blue, double size = 38}) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(), style: TextStyle(fontFamily: F.display, fontWeight: FontWeight.w800, fontSize: size * 0.42, color: color)),
    );

String _ago(DateTime? t) {
  if (t == null) return 'never';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 2) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

Color _reasonColor(HelpReason? r) => switch (r) {
      HelpReason.stuck => TC.bad,
      HelpReason.manyHints => TC.warn,
      HelpReason.inactive => TC.indigo,
      HelpReason.notStarted => TC.faint,
      null => TC.good,
    };

class _Loader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload) builder;
  const _Loader({super.key, required this.load, required this.builder});

  @override
  State<_Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<_Loader<T>> {
  late Future<T> _f = widget.load();

  void _reload() => setState(() => _f = widget.load());

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _f,
        builder: (context, s) {
          if (s.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${s.error}', style: const TextStyle(color: TC.sub), textAlign: TextAlign.center),
                  TextButton(onPressed: _reload, child: const Text('Try again')),
                ]),
              ),
            );
          }
          if (!s.hasData) return const Center(child: CircularProgressIndicator(color: TC.blue));
          return RefreshIndicator(onRefresh: () async => _reload(), child: widget.builder(context, s.data as T, _reload));
        },
      );
}

// ------------------------------------------------------------------ TODAY

class _TodayTab extends StatelessWidget {
  final TeacherRepo repo;
  final ClassInfo klass;
  final void Function(int tab) onTab;
  const _TodayTab({super.key, required this.repo, required this.klass, required this.onTab});

  @override
  Widget build(BuildContext context) {
    final camp = campaignFor(klass.ageMode);
    return _Loader<(ClassOverview, List<StudentRow>, List<SkillScore>, List<LevelStat>, List<Assignment>)>(
      load: () async => (await repo.overview(klass.id), await repo.students(klass.id), await repo.classSkills(klass.id), await repo.levels(klass.id), await repo.assignments(klass.id)),
      builder: (context, d, reload) {
        final (o, students, skills, levels, assignments) = d;
        final help = students.where((s) => s.needsHelp).toList();
        final tips = classInsights(o, students, skills, levels, camp);
        final hour = DateTime.now().hour;
        final hello = hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening');
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text(hello, style: const TextStyle(fontFamily: F.serif, fontWeight: FontWeight.w700, fontSize: 26, color: TC.ink)),
          Text('${klass.name} · ${camp.title}', style: const TextStyle(color: TC.sub, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          _Card(
            child: Row(children: [
              ProgressRing(value: o.progress, center: '${(o.progress * 100).round()}%', sub: 'of the\ncampaign', size: 126),
              const SizedBox(width: 18),
              Expanded(
                child: Wrap(spacing: 18, runSpacing: 12, children: [
                  _Stat('${o.activeToday}/${o.students}', 'played today'),
                  _Stat('${o.avgLevelsDone.toStringAsFixed(1)}', 'levels each'),
                  _Stat('${o.needsHelp}', 'need help', color: o.needsHelp > 0 ? TC.bad : TC.good),
                  _Stat(o.gainPoints == null ? '—' : '+${o.gainPoints}', 'learning gain', color: TC.good),
                ]),
              ),
            ]),
          ),
          _Card(
            title: 'Needs help now',
            trailing: help.isEmpty ? null : TextButton(onPressed: () => onTab(2), child: const Text('All students')),
            child: help.isEmpty
                ? const Text('Everyone is on track. Nice.', style: TextStyle(color: TC.sub))
                : Column(children: [for (final s in help.take(5)) _HelpRow(repo: repo, klass: klass, s: s)]),
          ),
          _Card(
            title: 'Pip\'s insights',
            child: Column(children: [
              for (final t in tips)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: t.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
                      child: Icon(t.icon, size: 18, color: t.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.title, style: const TextStyle(fontWeight: FontWeight.w800, color: TC.ink)),
                        Text(t.body, style: const TextStyle(color: TC.sub, height: 1.35)),
                        if (t.levelId != null)
                          TextButton.icon(
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                            onPressed: () async {
                              await repo.assign(klass.id, t.levelId!);
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Assigned ${catalogueEntry(t.levelId!)?.title ?? t.levelId} to the class.')));
                              reload();
                            },
                            icon: const Icon(Icons.assignment_add, size: 18),
                            label: Text('Assign ${catalogueEntry(t.levelId!)?.title ?? ''}'),
                          ),
                      ]),
                    ),
                  ]),
                ),
            ]),
          ),
          if (assignments.isNotEmpty)
            _Card(
              title: 'Assigned',
              child: Column(children: [
                for (final a in assignments.take(3))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.assignment_rounded, color: TC.blue),
                    title: Text(catalogueEntry(a.levelId)?.title ?? a.levelId, style: const TextStyle(fontWeight: FontWeight.w700, color: TC.ink)),
                    subtitle: Text(a.dueAt == null ? 'No due date' : 'Due ${_ago(a.dueAt).replaceAll(' ago', '')}', style: const TextStyle(color: TC.sub)),
                  ),
              ]),
            ),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: TC.blue),
            onPressed: () => onTab(4),
            icon: const Icon(Icons.sensors_rounded),
            label: const Text('Start a live lesson', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ]);
      },
    );
  }
}

class _HelpRow extends StatelessWidget {
  final TeacherRepo repo;
  final ClassInfo klass;
  final StudentRow s;
  const _HelpRow({required this.repo, required this.klass, required this.s});

  @override
  Widget build(BuildContext context) {
    final c = _reasonColor(s.reason);
    final level = s.stuckLevel == null ? null : catalogueEntry(s.stuckLevel!)?.title;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        _avatar(s.name, color: c),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800, color: TC.ink)),
            Text('${s.reason?.title ?? 'Needs a check-in'}${level == null ? '' : ' · $level'}', style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12.5)),
          ]),
        ),
        IconButton(
          tooltip: 'Send a hint',
          onPressed: () => _nudge(context, s.reason == HelpReason.inactive || s.reason == HelpReason.notStarted ? NudgeKind.reminder : NudgeKind.hint),
          icon: const Icon(Icons.lightbulb_outline_rounded, color: TC.blue),
        ),
        IconButton(
          tooltip: 'Open',
          onPressed: () => openStudent(context, repo, klass, s),
          icon: const Icon(Icons.chevron_right_rounded, color: TC.sub),
        ),
      ]),
    );
  }

  Future<void> _nudge(BuildContext context, NudgeKind k) async {
    await repo.sendNudge(klass.id, s.id, k, levelId: s.stuckLevel);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${k.title} sent to ${s.name}.')));
  }
}

// ------------------------------------------------------------------ CLASS

class _ClassTab extends StatelessWidget {
  final TeacherRepo repo;
  final ClassInfo klass;
  const _ClassTab({super.key, required this.repo, required this.klass});

  @override
  Widget build(BuildContext context) {
    final camp = campaignFor(klass.ageMode);
    return _Loader<(ClassOverview, List<SkillScore>, List<LevelStat>, List<ClassGoal>)>(
      load: () async => (await repo.overview(klass.id), await repo.classSkills(klass.id), await repo.levels(klass.id), await repo.goals(klass.id)),
      builder: (context, d, reload) {
        final (o, skills, levels, goals) = d;
        final finished = [for (final l in levels) l.finished];
        final stuck = bottleneck(levels, o.students);
        return ListView(padding: const EdgeInsets.all(16), children: [
          _Card(
            title: 'Learning gain · Readiness Check',
            child: Column(children: [
              GainBars(before: o.preAvg, after: o.postAvg),
              const SizedBox(height: 8),
              const Text('The same 8 questions before and after the campaign, class average.', style: TextStyle(color: TC.sub, fontSize: 12.5)),
            ]),
          ),
          _Card(
            title: 'Skills',
            child: Column(children: [
              SizedBox(height: 240, child: RadarChart(labels: [for (final s in skills) s.skill.short], values: [for (final s in skills) s.score / 100])),
              for (final s in skills)
                HBar(
                  label: s.skill.title,
                  value: s.score / 100,
                  text: '${s.score}',
                  color: s.score >= 70 ? TC.good : (s.score >= 50 ? TC.blue : TC.warn),
                  mark: goals.where((g) => g.skill == s.skill).map((g) => g.target / 100).firstOrNull,
                ),
            ]),
          ),
          _Card(
            title: 'Levels finished',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              LevelBars(finished: finished, students: o.students, highlight: stuck?.number),
              const SizedBox(height: 8),
              if (stuck != null)
                Text('Most students stop at level ${stuck.number}, ${stuck.title}. Average hints there: ${stuck.avgHints?.toStringAsFixed(1) ?? '—'}.', style: const TextStyle(color: TC.sub)),
            ]),
          ),
          _Card(
            title: 'Class goals',
            trailing: TextButton.icon(onPressed: () => _addGoal(context, reload), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add')),
            child: goals.isEmpty
                ? const Text('Set a shared target, for example "Everyone reaches Systems 70".', style: TextStyle(color: TC.sub))
                : Column(children: [
                    for (final g in goals)
                      _goalRow(context, g, skills, levels, o, () async {
                        await repo.removeGoal(g.id);
                        reload();
                      }),
                  ]),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: () async {
              try {
                final csv = await repo.reportCsv(klass.id);
                await Clipboard.setData(ClipboardData(text: csv));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Class report copied. Paste it into a spreadsheet.')));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            icon: const Icon(Icons.table_view_rounded),
            label: Text('Copy class report (${camp.length} levels, 6 skills)'),
          ),
        ]);
      },
    );
  }

  Widget _goalRow(BuildContext context, ClassGoal g, List<SkillScore> skills, List<LevelStat> levels, ClassOverview o, VoidCallback remove) {
    int now;
    if (g.skill != null) {
      now = skills.where((s) => s.skill == g.skill).map((s) => s.score).firstOrNull ?? 0;
    } else {
      final l = levels.where((x) => x.levelId == g.levelId).firstOrNull;
      now = o.students == 0 || l == null ? 0 : (100 * l.finished / o.students).round();
    }
    return Row(children: [
      Expanded(child: HBar(label: g.title, value: now / 100, text: '$now', mark: g.target / 100, color: now >= g.target ? TC.good : TC.blue)),
      IconButton(onPressed: remove, icon: const Icon(Icons.close_rounded, size: 18, color: TC.faint)),
    ]);
  }

  Future<void> _addGoal(BuildContext context, VoidCallback reload) async {
    Skill skill = Skill.systems;
    var target = 70.0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: TC.card,
          title: const Text('New class goal'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButton<Skill>(
              isExpanded: true,
              value: skill,
              items: [for (final k in Skill.values) DropdownMenuItem(value: k, child: Text(k.title))],
              onChanged: (v) => set(() => skill = v ?? skill),
            ),
            Slider(value: target, min: 40, max: 100, divisions: 12, label: '${target.round()}', onChanged: (v) => set(() => target = v)),
            Text('Everyone reaches ${skill.title} ${target.round()}'),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add goal')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await repo.addGoal(klass.id, title: 'Everyone reaches ${skill.title} ${target.round()}', skill: skill, target: target.round());
    reload();
  }
}

// ------------------------------------------------------------------ STUDENTS

class _StudentsTab extends StatefulWidget {
  final TeacherRepo repo;
  final ClassInfo klass;
  const _StudentsTab({super.key, required this.repo, required this.klass});

  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab> {
  String _q = '';
  bool _helpOnly = false;

  @override
  Widget build(BuildContext context) {
    final camp = campaignFor(widget.klass.ageMode);
    return _Loader<List<StudentRow>>(
      load: () => widget.repo.students(widget.klass.id),
      builder: (context, all, reload) {
        final list = [
          for (final s in all)
            if ((_q.isEmpty || s.name.toLowerCase().contains(_q.toLowerCase())) && (!_helpOnly || s.needsHelp)) s,
        ];
        return ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search ${all.length} students',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: TC.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: TC.line)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(label: const Text('Needs help'), selected: _helpOnly, onSelected: (v) => setState(() => _helpOnly = v)),
          ]),
          const SizedBox(height: 12),
          if (all.isEmpty)
            const _Card(child: Text('No students yet. Open Me → your class → Make sign-in cards, or share the join code.', style: TextStyle(color: TC.sub))),
          for (final s in list)
            _Card(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: InkWell(
                onTap: () async {
                  await openStudent(context, widget.repo, widget.klass, s);
                  reload();
                },
                child: Row(children: [
                  _avatar(s.name, color: _reasonColor(s.needsHelp ? s.reason : null)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: TC.ink))),
                        Text('${s.levelsDone}/${camp.length}', style: const TextStyle(fontFamily: F.mono, fontWeight: FontWeight.w700, color: TC.ink)),
                      ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: camp.length == 0 ? 0 : s.levelsDone / camp.length, minHeight: 7, backgroundColor: TC.line, color: TC.blue),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s.needsHelp ? '${s.reason?.title ?? 'Needs a check-in'} · ${_ago(s.lastActive)}' : '${s.stars} stars · ${_ago(s.lastActive)}${s.gain == null ? '' : ' · gain +${s.gain}'}',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: s.needsHelp ? _reasonColor(s.reason) : TC.sub),
                      ),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: TC.faint),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

Future<void> openStudent(BuildContext context, TeacherRepo repo, ClassInfo klass, StudentRow s) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => Theme(data: _teacherTheme(), child: StudentPage(repo: repo, klass: klass, student: s))));

class StudentPage extends StatelessWidget {
  final TeacherRepo repo;
  final ClassInfo klass;
  final StudentRow student;
  const StudentPage({super.key, required this.repo, required this.klass, required this.student});

  @override
  Widget build(BuildContext context) {
    final s = student;
    final camp = campaignFor(klass.ageMode);
    return Scaffold(
      backgroundColor: TC.bg,
      appBar: AppBar(backgroundColor: TC.card, foregroundColor: TC.ink, title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800)), surfaceTintColor: Colors.transparent),
      body: _Loader<(List<SkillScore>, List<AttemptRow>)>(
        load: () async => (await repo.studentSkills(s.id, klass.id), await repo.studentAttempts(s.id)),
        builder: (context, d, reload) {
          final (skills, attempts) = d;
          final weakest = [...skills]..sort((a, b) => a.score.compareTo(b.score));
          return ListView(padding: const EdgeInsets.all(16), children: [
            _Card(
              child: Row(children: [
                _avatar(s.name, size: 54),
                const SizedBox(width: 14),
                Expanded(
                  child: Wrap(spacing: 18, runSpacing: 8, children: [
                    _Stat('${s.levelsDone}/${camp.length}', 'levels'),
                    _Stat('${s.stars}', 'stars'),
                    _Stat(s.gain == null ? '—' : '+${s.gain}', 'gain', color: TC.good),
                  ]),
                ),
              ]),
            ),
            if (s.needsHelp)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _reasonColor(s.reason).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Icon(Icons.flag_rounded, color: _reasonColor(s.reason)),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${s.reason?.title ?? 'Needs a check-in'}${s.stuckLevel == null ? '' : ' on ${catalogueEntry(s.stuckLevel!)?.title}'}. ${s.hintsWeek} hints this week.', style: TextStyle(color: _reasonColor(s.reason), fontWeight: FontWeight.w700))),
                ]),
              ),
            _Card(
              title: 'Skills vs class average',
              child: Column(children: [
                SizedBox(height: 230, child: RadarChart(labels: [for (final k in skills) k.skill.short], values: [for (final k in skills) k.score / 100], compare: [for (final k in skills) k.classAvg / 100])),
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.circle, size: 10, color: TC.blue),
                  Text(' Student   ', style: TextStyle(color: TC.sub, fontSize: 12)),
                  Icon(Icons.circle_outlined, size: 10, color: TC.faint),
                  Text(' Class average', style: TextStyle(color: TC.sub, fontSize: 12)),
                ]),
                if (weakest.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Practise next: ${weakest.first.skill.title}. ${weakest.first.skill.blurb}', style: const TextStyle(color: TC.sub)),
                ],
              ]),
            ),
            _Card(
              title: 'Send a message (presets only)',
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final k in NudgeKind.values)
                  ActionChip(
                    avatar: Icon(k == NudgeKind.wellDone ? Icons.celebration_rounded : (k == NudgeKind.hint ? Icons.lightbulb_outline : (k == NudgeKind.replay ? Icons.replay : Icons.notifications_none)), size: 18),
                    label: Text(k.title),
                    onPressed: () async {
                      await repo.sendNudge(klass.id, s.id, k, levelId: s.stuckLevel ?? (attempts.isEmpty ? null : attempts.first.levelId));
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sent to ${s.name}: "${k.studentText(null)}"')));
                    },
                  ),
              ]),
            ),
            _Card(
              title: 'Recent plays and decisions',
              child: attempts.isEmpty
                  ? const Text('No plays yet.', style: TextStyle(color: TC.sub))
                  : Column(children: [
                      for (final a in attempts.take(8))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(a.outcome == 'complete' ? Icons.check_circle_rounded : Icons.cancel_rounded, color: a.outcome == 'complete' ? TC.good : TC.bad, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${catalogueEntry(a.levelId)?.title ?? a.levelId} · ${a.stars ?? 0}★ · ${a.mistakes} mistakes · ${a.hints} hints', style: const TextStyle(fontWeight: FontWeight.w700, color: TC.ink, fontSize: 13.5)),
                                Text(_ago(a.startedAt), style: const TextStyle(color: TC.sub, fontSize: 12)),
                                if (a.decisions.isNotEmpty)
                                  Wrap(spacing: 4, runSpacing: 4, children: [
                                    for (final dd in a.decisions.take(6))
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: (dd.good ? TC.good : TC.bad).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                        child: Text('${dd.step.replaceAll('_', ' ')}: ${dd.choice.replaceAll('_', ' ')}', style: TextStyle(fontSize: 11, color: dd.good ? TC.good : TC.bad)),
                                      ),
                                  ]),
                              ]),
                            ),
                          ]),
                        ),
                    ]),
            ),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: s.stuckLevel == null && attempts.isEmpty
                      ? null
                      : () async {
                          await repo.assign(klass.id, s.stuckLevel ?? attempts.first.levelId, studentId: s.id);
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Replay assigned.')));
                        },
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Assign replay'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: s.username == null
                      ? null
                      : () async {
                          try {
                            final card = await repo.resetPin(klass.id, s.id);
                            if (!context.mounted) return;
                            await showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: TC.card, title: const Text('New PIN'), content: _SignInCard(card: card, klass: klass)));
                          } catch (e) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        },
                  icon: const Icon(Icons.password_rounded),
                  label: const Text('New PIN'),
                ),
              ),
            ]),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: TC.bad),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Remove ${s.name}?'),
                    content: const Text('Accounts you created are deleted with all their data. Students who joined with a code just leave the class.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(style: FilledButton.styleFrom(backgroundColor: TC.bad), onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
                    ],
                  ),
                );
                if (ok != true) return;
                await repo.removeStudent(klass.id, s.id);
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.person_remove_rounded),
              label: const Text('Remove from class'),
            ),
          ]);
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ LESSONS

class _LessonsTab extends StatelessWidget {
  final TeacherRepo repo;
  final ClassInfo klass;
  const _LessonsTab({super.key, required this.repo, required this.klass});

  @override
  Widget build(BuildContext context) {
    final camp = campaignFor(klass.ageMode);
    return _Loader<(List<LevelStat>, List<Assignment>, ClassOverview)>(
      load: () async => (await repo.levels(klass.id), await repo.assignments(klass.id), await repo.overview(klass.id)),
      builder: (context, d, reload) {
        final (levels, assigned, o) = d;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('${camp.title} · ${camp.length} levels', style: const TextStyle(fontFamily: F.serif, fontWeight: FontWeight.w700, fontSize: 22, color: TC.ink)),
          Text(camp.tagline, style: const TextStyle(color: TC.sub)),
          const SizedBox(height: 12),
          for (var n = 1; n <= camp.length; n++) _lesson(context, camp, n, levels.where((l) => l.number == n).firstOrNull, assigned, o.students, reload),
        ]);
      },
    );
  }

  Widget _lesson(BuildContext context, Campaign camp, int n, LevelStat? st, List<Assignment> assigned, int students, VoidCallback reload) {
    final t = camp.task(n), info = camp.info(n);
    final entry = catalogueEntry(camp.levelIdFor(n));
    final isAssigned = assigned.any((a) => a.levelId == camp.levelIdFor(n) && a.studentId == null);
    return _Card(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(right: 8, bottom: 12),
          leading: CircleAvatar(backgroundColor: TC.blue.withValues(alpha: 0.12), child: Text('$n', style: const TextStyle(color: TC.blue, fontWeight: FontWeight.w800))),
          title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w800, color: TC.ink)),
          subtitle: Text('${info.minutes[camp.mode.index]} min · ${entry?.skills.map((s) => s.short).join(', ') ?? ''}${st == null ? '' : ' · ${st.finished}/$students done'}', style: const TextStyle(color: TC.sub, fontSize: 12.5)),
          trailing: isAssigned ? const Icon(Icons.assignment_turned_in_rounded, color: TC.good) : null,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info.brief, style: const TextStyle(color: TC.ink, height: 1.4)),
            const SizedBox(height: 8),
            _kv('Lesson', info.moral),
            _kv('Real NASA', info.nasaDoes),
            _kv('Science', t.nasaFact),
            if (camp.mode == AgeMode.engineer) _kv('Maths', info.howCalc),
            _kv('Discuss', 'Ask: ${info.moralBody}'),
            if (st != null && st.avgHints != null) _kv('Your class', 'Average ${st.avgMistakes?.toStringAsFixed(1) ?? '—'} mistakes and ${st.avgHints!.toStringAsFixed(1)} hints.'),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              FilledButton.tonalIcon(
                onPressed: isAssigned
                    ? null
                    : () async {
                        await repo.assign(klass.id, camp.levelIdFor(n), dueAt: DateTime.now().add(const Duration(days: 7)));
                        reload();
                      },
                icon: const Icon(Icons.assignment_add),
                label: Text(isAssigned ? 'Assigned' : 'Assign (due in 7 days)'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: RichText(
          text: TextSpan(style: const TextStyle(fontFamily: F.body, color: TC.ink, height: 1.4, fontSize: 13.5), children: [
            TextSpan(text: '$k  ', style: const TextStyle(fontWeight: FontWeight.w800, color: TC.teal)),
            TextSpan(text: v),
          ]),
        ),
      );
}

// ------------------------------------------------------------------ LIVE

class _LiveTab extends StatefulWidget {
  final TeacherRepo repo;
  final ClassInfo klass;
  const _LiveTab({super.key, required this.repo, required this.klass});

  @override
  State<_LiveTab> createState() => _LiveTabState();
}

class _LiveTabState extends State<_LiveTab> {
  Link? _link;
  StreamSubscription<LinkMessage>? _sub;
  StreamSubscription<List<Map<String, dynamic>>>? _peers;
  int _level = 1;
  bool _paused = false;
  bool _connecting = false;
  final Map<String, Map<String, dynamic>> _students = {};
  final List<(DateTime, String)> _alerts = [];
  final Set<String> _done = {};

  Campaign get camp => campaignFor(widget.klass.ageMode);

  @override
  void dispose() {
    _stop(send: true);
    super.dispose();
  }

  Future<void> _start() async {
    final l = widget.repo.liveLink(widget.klass.id);
    if (l == null) {
      _snack('Live lessons need the cloud connection.');
      return;
    }
    setState(() => _connecting = true);
    _link = l;
    _sub = l.messages.listen(_onMessage);
    _peers = l.peers.listen((list) {
      if (!mounted) return;
      setState(() {
        for (final p in list) {
          if (p['role'] == 'student') _students[p['id'] as String] = p;
        }
      });
    });
    final ok = await l.connect({'role': 'teacher', 'name': 'Teacher'});
    if (!mounted) return;
    setState(() => _connecting = false);
    if (!ok) {
      _snack('Could not open the live channel. Check the connection.');
      await _stop();
      return;
    }
    await l.send('start', {'level': _level, 'level_id': camp.levelIdFor(_level)});
  }

  void _onMessage(LinkMessage m) {
    if (!mounted) return;
    setState(() {
      final name = '${m.data['name'] ?? 'A student'}';
      switch (m.event) {
        case 'step':
          _students[m.from] = {...?_students[m.from], 'name': name, 'step': m.data['step'], 'role': 'student'};
        case 'help':
          _alerts.insert(0, (DateTime.now(), '$name asked for help on step ${(m.data['step'] as num? ?? 0).toInt() + 1}'));
        case 'done':
          _done.add(m.from);
          _alerts.insert(0, (DateTime.now(), '$name finished with ${m.data['stars']}★'));
      }
    });
  }

  Future<void> _stop({bool send = false}) async {
    final l = _link;
    _link = null;
    await _sub?.cancel();
    await _peers?.cancel();
    if (l != null) {
      if (send) await l.send('end', {});
      await l.close();
    }
  }

  Future<void> _togglePause() async {
    setState(() => _paused = !_paused);
    await _link?.send(_paused ? 'pause' : 'resume', {});
  }

  void _snack(String s) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    final live = _link != null;
    final steps = camp.task(_level).steps.length;
    if (!live) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        _Card(
          title: 'Live lesson',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Everyone plays the same level at the same time. You see who is on which step, who asked for help, and you can pause the whole class to talk.', style: TextStyle(color: TC.ink, height: 1.4)),
            const SizedBox(height: 14),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Level', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _level,
                  items: [for (var n = 1; n <= camp.length; n++) DropdownMenuItem(value: n, child: Text('$n · ${camp.task(n).title}'))],
                  onChanged: (v) => setState(() => _level = v ?? 1),
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: TC.blue),
              onPressed: _connecting ? null : _start,
              icon: _connecting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.play_circle_fill_rounded),
              label: const Text('Start live lesson', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 8),
            Text(widget.repo.isDemo ? 'Sample class: simulated students will join.' : 'Students in ${widget.klass.name} see a "Join live lesson" banner.', style: const TextStyle(color: TC.sub, fontSize: 12.5)),
          ]),
        ),
      ]);
    }
    final counts = List.filled(steps + 1, 0);
    for (final s in _students.values) {
      final st = ((s['step'] as num?) ?? 0).toInt().clamp(0, steps);
      counts[st]++;
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      _Card(
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: _paused ? TC.warn : TC.bad, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text('${_paused ? 'PAUSED' : 'LIVE'} · Level $_level · ${camp.task(_level).title}', style: const TextStyle(fontWeight: FontWeight.w800, color: TC.ink))),
          Text('${_students.length} joined', style: const TextStyle(color: TC.sub, fontWeight: FontWeight.w700)),
        ]),
      ),
      _Card(
        title: 'Students on each step',
        child: Column(children: [
          for (var i = 0; i <= steps; i++)
            HBar(
              label: i == steps ? 'Finished' : (i == 0 ? 'Starting' : 'Step $i'),
              value: _students.isEmpty ? 0 : counts[i] / _students.length,
              text: '${counts[i]}',
              color: i == steps ? TC.good : TC.blue,
            ),
        ]),
      ),
      if (_alerts.isNotEmpty)
        _Card(
          title: 'Alerts',
          child: Column(children: [
            for (final (t, a) in _alerts.take(6))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(a.contains('help') ? Icons.back_hand_rounded : Icons.check_circle_rounded, color: a.contains('help') ? TC.warn : TC.good),
                title: Text(a, style: const TextStyle(color: TC.ink, fontWeight: FontWeight.w600)),
                trailing: Text(_ago(t), style: const TextStyle(color: TC.sub, fontSize: 11.5)),
              ),
          ]),
        ),
      _Card(
        title: 'Class',
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in _students.entries)
            Chip(
              avatar: Icon(_done.contains(e.key) ? Icons.check_circle_rounded : Icons.circle, size: 14, color: _done.contains(e.key) ? TC.good : TC.blue),
              label: Text('${e.value['name']} · ${(e.value['step'] as num? ?? 0).toInt()}/$steps'),
            ),
        ]),
      ),
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: _paused ? TC.good : TC.warn),
            onPressed: _togglePause,
            icon: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
            label: Text(_paused ? 'Resume everyone' : 'Pause everyone', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(90, 52)),
          onPressed: () async {
            await _stop(send: true);
            if (mounted) {
              setState(() {
                _students.clear();
                _alerts.clear();
                _done.clear();
                _paused = false;
              });
            }
          },
          child: const Text('End'),
        ),
      ]),
    ]);
  }
}

// ------------------------------------------------------------------ ME

class _MeTab extends StatelessWidget {
  final TeacherRepo repo;
  final List<ClassInfo> classes;
  final void Function(String? id) onChanged;
  final Future<void> Function() onCreate;
  final Future<void> Function(ClassInfo c) onEdit;
  final Future<void> Function(ClassInfo c) onCards;
  const _MeTab({required this.repo, required this.classes, required this.onChanged, required this.onCreate, required this.onEdit, required this.onCards});

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final session = sv.session;
    return ListView(padding: const EdgeInsets.all(16), children: [
      _Card(
        child: Row(children: [
          _avatar(session.isTeacher ? session.name : 'Guest', size: 50),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(session.isTeacher ? session.name : 'Sample class', style: const TextStyle(fontFamily: F.serif, fontWeight: FontWeight.w700, fontSize: 20, color: TC.ink)),
              Text(session.isTeacher ? 'Signed in as a teacher' : 'Sign in as a teacher to make your own classes.', style: const TextStyle(color: TC.sub)),
            ]),
          ),
        ]),
      ),
      if (!session.isTeacher)
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: TC.blue),
          onPressed: () => sv.nav.go(Screen.account),
          icon: const Icon(Icons.login_rounded),
          label: const Text('Teacher sign in or sign up', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      const SizedBox(height: 12),
      Row(children: [
        const Expanded(child: Text('YOUR CLASSES', style: TextStyle(fontFamily: F.display, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.6, color: TC.sub))),
        TextButton.icon(onPressed: onCreate, icon: const Icon(Icons.add_rounded), label: const Text('New class')),
      ]),
      for (final c in classes)
        _Card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: TC.ink))),
              IconButton(onPressed: () => onEdit(c), icon: const Icon(Icons.edit_rounded, color: TC.sub)),
            ]),
            Text('${c.ageMode.title} campaign · ${c.ageMode.ages}${c.lockRank ? ' · age level locked' : ''}', style: const TextStyle(color: TC.sub)),
            const SizedBox(height: 10),
            _JoinCode(code: c.joinCode, small: true),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.tonalIcon(onPressed: () => onCards(c), icon: const Icon(Icons.badge_rounded), label: const Text('Make sign-in cards')),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: 'Join ${c.name} in Shackleton Station: open the app, sign in, tap "Join a class" and enter the code ${c.joinCode}.'));
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitation copied.')));
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy invitation'),
              ),
            ]),
          ]),
        ),
      const _Card(
        title: 'Privacy',
        child: Text(
          'Students sign in with a username and a 4-digit PIN from a card you print: no emails, no surnames, no photos. '
          'You can only send preset messages, never free text. Deleting a student account deletes all of their data.',
          style: TextStyle(color: TC.ink, height: 1.4),
        ),
      ),
      if (session.isTeacher)
        TextButton.icon(
          onPressed: () async {
            await session.signOut();
            onChanged(null);
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
      TextButton.icon(onPressed: () => sv.nav.go(Screen.teacher), icon: const Icon(Icons.description_rounded), label: const Text('Printable lesson guides and classroom settings')),
    ]);
  }
}

class _JoinCode extends StatelessWidget {
  final String code;
  final bool small;
  const _JoinCode({required this.code, this.small = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: small ? 8 : 14),
        decoration: BoxDecoration(color: TC.blue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: TC.blue.withValues(alpha: 0.35))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('JOIN CODE  ', style: TextStyle(fontFamily: F.display, fontWeight: FontWeight.w800, fontSize: small ? 10 : 11, letterSpacing: 1.5, color: TC.sub)),
          Text(code.split('').join(' '), style: TextStyle(fontFamily: F.mono, fontWeight: FontWeight.w700, fontSize: small ? 18 : 28, color: TC.blue)),
        ]),
      );
}

class _ClassForm extends StatefulWidget {
  final ClassInfo? initial;
  const _ClassForm({this.initial});

  @override
  State<_ClassForm> createState() => _ClassFormState();
}

class _ClassFormState extends State<_ClassForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late AgeMode _mode = widget.initial?.ageMode ?? AgeMode.explorer;
  late bool _lock = widget.initial?.lockRank ?? true;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.initial == null ? 'New class' : 'Edit class', style: const TextStyle(fontFamily: F.serif, fontWeight: FontWeight.w700, fontSize: 22, color: TC.ink)),
        const SizedBox(height: 12),
        TextField(controller: _name, maxLength: 40, decoration: const InputDecoration(labelText: 'Class name', hintText: 'Grade 7 Blue', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        const Text('AGE LEVEL', style: TextStyle(fontFamily: F.display, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.6, color: TC.sub)),
        const SizedBox(height: 6),
        for (final m in AgeMode.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _mode = m),
              child: AnimatedContainer(
                duration: Motion.fast,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _mode == m ? TC.blue.withValues(alpha: 0.08) : TC.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _mode == m ? TC.blue : TC.line, width: _mode == m ? 2 : 1),
                ),
                child: Row(children: [
                  Icon(_mode == m ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: _mode == m ? TC.blue : TC.faint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${m.title} · ${m.ages}', style: const TextStyle(fontWeight: FontWeight.w800, color: TC.ink)),
                      Text('${campaignFor(m).title}: ${campaignFor(m).length} levels. ${m.blurb}', style: const TextStyle(color: TC.sub, fontSize: 12.5)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _lock,
          onChanged: (v) => setState(() => _lock = v),
          title: const Text('Lock the age level', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Students cannot switch to another campaign on their phone.'),
        ),
        const SizedBox(height: 6),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: () {
            final n = _name.text.trim();
            if (n.isEmpty) return;
            Navigator.pop(context, (n, _mode, _lock));
          },
          child: Text(widget.initial == null ? 'Create class' : 'Save'),
        ),
      ]),
    );
  }
}

class _NamesForm extends StatefulWidget {
  const _NamesForm();

  @override
  State<_NamesForm> createState() => _NamesFormState();
}

class _NamesFormState extends State<_NamesForm> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  List<String> get _names => [for (final l in _c.text.split(RegExp(r'[\n,]'))) if (l.trim().length >= 2) l.trim()];

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Sign-in cards', style: TextStyle(fontFamily: F.serif, fontWeight: FontWeight.w700, fontSize: 22, color: TC.ink)),
          const SizedBox(height: 4),
          const Text('Type first names only, one per line. Each student gets a username and a 4-digit PIN.', style: TextStyle(color: TC.sub)),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            maxLines: 8,
            minLines: 5,
            decoration: const InputDecoration(hintText: 'Rana\nOmar\nLina', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: _names.isEmpty || _names.length > 40 ? null : () => Navigator.pop(context, _names),
            child: Text(_names.length > 40 ? 'At most 40 at a time' : 'Make ${_names.length} card${_names.length == 1 ? '' : 's'}'),
          ),
        ]),
      );
}

/// The printable sign-in cards (screenshot, or copy the list).
class CardsPage extends StatelessWidget {
  final ClassInfo klass;
  final List<StudentCard> cards;
  final List<String> failed;
  const CardsPage({super.key, required this.klass, required this.cards, this.failed = const []});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: TC.bg,
        appBar: AppBar(
          backgroundColor: TC.card,
          foregroundColor: TC.ink,
          surfaceTintColor: Colors.transparent,
          title: Text('${cards.length} sign-in cards'),
          actions: [
            IconButton(
              tooltip: 'Copy all',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: [for (final c in cards) '${c.name}\tusername: ${c.username}\tPIN: ${c.pin}'].join('\n')));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied. Paste into a document to print.')));
              },
              icon: const Icon(Icons.copy_all_rounded),
            ),
          ],
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('PINs are shown only now. Copy or screenshot them, then cut out one card per student. A lost PIN can be reset from the student\'s page.', style: TextStyle(color: TC.sub)),
          const SizedBox(height: 12),
          for (final f in failed) Text('Not created: $f', style: const TextStyle(color: TC.bad)),
          Wrap(spacing: 10, runSpacing: 10, children: [for (final c in cards) SizedBox(width: (MediaQuery.of(context).size.width - 42) / 2, child: _SignInCard(card: c, klass: klass))]),
        ]),
      );
}

class _SignInCard extends StatelessWidget {
  final StudentCard card;
  final ClassInfo klass;
  const _SignInCard({required this.card, required this.klass});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: TC.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: TC.ink.withValues(alpha: 0.4), style: BorderStyle.solid)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('SHACKLETON STATION · ${klass.name.toUpperCase()}', style: const TextStyle(fontFamily: F.display, fontWeight: FontWeight.w800, fontSize: 8.5, letterSpacing: 1, color: TC.teal), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text(card.name, style: const TextStyle(fontFamily: F.serif, fontWeight: FontWeight.w700, fontSize: 19, color: TC.ink)),
          const SizedBox(height: 6),
          const Text('Username', style: TextStyle(fontSize: 10.5, color: TC.sub)),
          Text(card.username, style: const TextStyle(fontFamily: F.mono, fontWeight: FontWeight.w700, fontSize: 13.5, color: TC.ink)),
          const SizedBox(height: 4),
          const Text('PIN', style: TextStyle(fontSize: 10.5, color: TC.sub)),
          Text(card.pin.split('').join(' '), style: const TextStyle(fontFamily: F.mono, fontWeight: FontWeight.w700, fontSize: 22, color: TC.blue)),
        ]),
      );
}
