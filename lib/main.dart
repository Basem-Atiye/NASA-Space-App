import 'ui/game_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'base/base_content.dart';
import 'base/base_engine.dart';
import 'base/base_store.dart';
import 'base/ui/base_results.dart';
import 'base/ui/base_screens.dart';
import 'base/ui/mission_control.dart';
import 'data/catalogue.dart';
import 'data/missions.dart';
import 'game/game_controller.dart';
import 'screens/briefing_screen.dart';
import 'screens/debrief_screen.dart';
import 'screens/encyclopedia_screen.dart';
import 'screens/ending_screen.dart';
import 'screens/game_screen.dart';
import 'screens/info_screens.dart';
import 'screens/map_screen.dart';
import 'screens/account_screen.dart';
import 'screens/missions_screen.dart';
import 'screens/rank_screen.dart';
import 'screens/readiness_screen.dart';
import 'screens/skills_screen.dart';
import 'screens/story_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/title_screen.dart';
import 'services/audio.dart';
import 'services/env.dart';
import 'services/progress.dart';
import 'services/session.dart';
import 'services/voice.dart';
import 'story/story_controller.dart';
import 'supply/supply_run.dart';
import 'teacher/teacher_app.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: C.bg,
  ));
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final progress = Progress();
  await progress.load();
  final audio = Audio(progress);
  await audio.init();
  final base = BaseStore();
  await base.load(progress.prefs);
  final session = Session(progress: progress);
  // sign-in and cloud start in the background: the game never waits for the network
  session.start();
  runApp(ShackletonApp(progress: progress, audio: audio, voice: Voice(progress), session: session, base: base));
}

/// Shared services, available anywhere below with [Services.of].
class Services extends InheritedWidget {
  final Progress progress;
  final Audio audio;
  final Voice voice;
  final AppNav nav;
  final Session session;

  /// Base Commander progress (stars, badges, the game in progress).
  final BaseStore base;

  const Services({super.key, required this.progress, required this.audio, required this.voice, required this.nav, required this.session, required this.base, required super.child});

  static Services of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<Services>()!;

  @override
  bool updateShouldNotify(Services old) => false;
}

enum Screen {
  welcome,
  title,
  rank,
  map,
  story,
  ending,
  encyclopedia,
  missions,
  briefing,
  game,
  debrief,
  data,
  teacher,
  settings,
  account,
  readiness,
  skills,
  teacherApp,
  // the Figma flow (Base Commander)
  missionSelect,
  baseBriefing,
  baseControl,
  baseResult,
  howToPlay,
  badges,
  supplyRun,
  station,
}

/// A very small navigator: one screen at a time, with a history for Back.
class AppNav extends ChangeNotifier {
  Screen screen = Screen.welcome;
  int missionId = 1;
  GameController? game;
  VoidCallback? gameBack;
  final List<Screen> _history = [];

  /// 1 when moving forward, -1 when going back (sets the transition).
  int direction = 1;

  /// The running story level, if any.
  StoryController? story;

  // ---- Base Commander
  int baseMissionN = 1;
  BaseState? base;
  MissionResult? baseResult;

  /// The mission the Supply Run leads to (its supplies go there).
  int supplyNext = 2;

  /// Which planet the Missions screen shows (false: Moon).
  bool showMars = false;

  /// Starts (or resumes) a Base Commander mission.
  void startBase(int n, Services sv, {bool fresh = false}) {
    baseMissionN = n;
    final saved = fresh ? null : sv.base.resume(n);
    base = saved ?? BaseState(baseMission(n), level: levelFor(sv.progress.ageMode), bonus: sv.base.takeBonus());
    baseResult = null;
    if (screen != Screen.baseControl) _history.add(screen);
    _history.removeWhere((x) => x == Screen.baseBriefing || x == Screen.baseResult || x == Screen.supplyRun);
    direction = 1;
    screen = Screen.baseControl;
    notifyListeners();
  }

  /// A mission ended: show the results.
  void showBaseResult(MissionResult r) {
    baseResult = r;
    direction = 1;
    screen = Screen.baseResult;
    notifyListeners();
  }

  /// Bumped to rebuild the story screen for a replay of the same level.
  int storyRun = 0;

  /// After choosing a rank, where to go next.
  Screen afterRank = Screen.map;

  /// Which campaign's ending to show.
  CampaignId endingCampaign = CampaignId.explorer;
  int endingLevel = 10;

  void startStory(int task, Services sv) {
    story?.dispose();
    story = StoryController.forLevel(sv.progress.campaign, task, audio: sv.audio, progress: sv.progress, voice: sv.voice)
      ..onFinished = sv.session.recordLevel
      ..onStep = sv.session.liveStep
      ..onHelp = sv.session.liveHelp;
    storyRun++;
    if (screen != Screen.story) _history.add(screen);
    direction = 1;
    screen = Screen.story;
    notifyListeners();
  }

  void endStory({required Screen to}) {
    story?.dispose();
    story = null;
    _history.removeWhere((s) => s == Screen.story);
    direction = -1;
    screen = to;
    notifyListeners();
  }

  void go(Screen s, {int? mission}) {
    if (mission != null) missionId = mission;
    if (screen != s) _history.add(screen);
    direction = 1;
    screen = s;
    notifyListeners();
  }

  bool back() {
    switch (screen) {
      case Screen.game:
      case Screen.story:
      case Screen.baseControl:
      case Screen.supplyRun:
        return false; // the game screens handle back themselves (pause menu)
      case Screen.welcome:
        return false;
      case Screen.title:
        // back from the station goes to the welcome screen
        _history.clear();
        direction = -1;
        screen = Screen.welcome;
        notifyListeners();
        return true;
      default:
        var prev = _history.isNotEmpty ? _history.removeLast() : Screen.title;
        final gameOver = game == null || game!.finished;
        if (prev == Screen.debrief || (prev == Screen.game && gameOver)) prev = Screen.missions;
        if (prev == Screen.story || prev == Screen.ending) prev = Screen.map;
        if (prev == Screen.readiness && screen == Screen.readiness) prev = Screen.map;
        // back from a finished base game (or its results) goes to the missions
        if (prev == Screen.baseResult || prev == Screen.supplyRun || (prev == Screen.baseControl && (base == null || base!.outcome != BaseOutcome.running))) prev = Screen.missionSelect;
        direction = -1;
        screen = prev;
        notifyListeners();
        return true;
    }
  }

  /// The teacher app: a teacher's own classes, or the sample class.
  void openTeacher(Services sv) => go(Screen.teacherApp);

  void resetTo(Screen s) {
    _history.clear();
    direction = -1;
    screen = s;
    notifyListeners();
  }
}

class ShackletonApp extends StatefulWidget {
  final Progress progress;
  final Audio audio;
  final Voice voice;
  final Session session;
  final BaseStore base;
  const ShackletonApp({super.key, required this.progress, required this.audio, required this.voice, required this.session, required this.base});

  @override
  State<ShackletonApp> createState() => _ShackletonAppState();
}

class _ShackletonAppState extends State<ShackletonApp> with WidgetsBindingObserver {
  final nav = AppNav();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      widget.audio.pauseAll();
      widget.voice.stop();
      final g = nav.game;
      if (nav.screen == Screen.game && g != null && !g.finished && !g.userPaused) g.togglePause();
      final st = nav.story;
      if (nav.screen == Screen.story && st != null && !st.paused && !st.finished) nav.gameBack?.call();
      final b = nav.base;
      if (b != null && b.outcome == BaseOutcome.running) widget.base.save(b);
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.resumeAll();
      widget.session.flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Services(
      progress: widget.progress,
      audio: widget.audio,
      voice: widget.voice,
      nav: nav,
      session: widget.session,
      base: widget.base,
      child: MaterialApp(
        title: 'Open Bounds',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        builder: (context, child) {
          // the phone's text size and the game's own Text size setting (A A A)
          final mq = MediaQuery.of(context);
          return ListenableBuilder(
            listenable: widget.progress,
            builder: (context, _) {
              final own = const [0.9, 1.0, 1.12][widget.progress.textSize.clamp(0, 2)];
              final scaled = TextScaler.linear((mq.textScaler.scale(16) / 16 * own).clamp(0.85, 1.35));
              return MediaQuery(data: mq.copyWith(textScaler: scaled), child: Overlay.wrap(child: GameHelper(reducedMotion: widget.progress.reducedMotion, child: child!)));
            },
          );
        },
        home: const AppShell(),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final reduced = sv.progress.reducedMotion || MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: C.bg,
      resizeToAvoidBottomInset: false,
      body: AnimatedBuilder(
        animation: sv.nav,
        builder: (context, _) {
          final dir = sv.nav.direction;
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (sv.nav.screen == Screen.game || sv.nav.screen == Screen.story || sv.nav.screen == Screen.baseControl || sv.nav.screen == Screen.supplyRun) {
                sv.nav.gameBack?.call();
                return;
              }
              if (!sv.nav.back()) SystemNavigator.pop();
            },
            child: AnimatedSwitcher(
              duration: Motion.slow,
              reverseDuration: Motion.normal,
              switchInCurve: Motion.curve,
              switchOutCurve: Curves.easeIn,
              layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, if (current != null) current]),
              transitionBuilder: (child, anim) {
                if (reduced) return FadeTransition(opacity: anim, child: child);
                // forward: the new screen rises and settles; back: it slides in from the left
                final slide = Tween<Offset>(begin: dir > 0 ? const Offset(0, 0.04) : const Offset(-0.08, 0), end: Offset.zero).animate(anim);
                final scale = Tween<double>(begin: dir > 0 ? 0.97 : 1, end: 1).animate(anim);
                return FadeTransition(opacity: anim, child: SlideTransition(position: slide, child: ScaleTransition(scale: scale, child: child)));
              },
              child: KeyedSubtree(
                key: ValueKey('${sv.nav.screen}-${sv.nav.missionId}-${sv.nav.game?.hashCode}-${sv.nav.storyRun}-${sv.nav.base?.hashCode}'),
                child: _screenFor(sv.nav),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _screenFor(AppNav nav) {
    switch (nav.screen) {
      case Screen.welcome:
        return const WelcomeScreen();
      case Screen.title:
      case Screen.station:
        return const TitleScreen();
      case Screen.missionSelect:
        return const MissionSelectScreen();
      case Screen.baseBriefing:
        return BaseBriefingScreen(n: nav.baseMissionN);
      case Screen.baseControl:
        return MissionControlScreen(state: nav.base!);
      case Screen.baseResult:
        return BaseResultScreen(state: nav.base!, result: nav.baseResult!);
      case Screen.howToPlay:
        return const HowToPlayScreen();
      case Screen.badges:
        return const BadgesScreen();
      case Screen.supplyRun:
        return SupplyRunScreen(nextMission: nav.supplyNext);
      case Screen.rank:
        return const RankScreen();
      case Screen.map:
        return const MapScreen();
      case Screen.story:
        return StoryScreen(controller: nav.story!);
      case Screen.ending:
        return const EndingScreen();
      case Screen.encyclopedia:
        return const EncyclopediaScreen();
      case Screen.missions:
        return const MissionsScreen();
      case Screen.briefing:
        return BriefingScreen(mission: missionById(nav.missionId));
      case Screen.game:
        return GameScreen(controller: nav.game!);
      case Screen.debrief:
        return DebriefScreen(controller: nav.game!);
      case Screen.data:
        return const MissionDataScreen();
      case Screen.teacher:
        return const TeacherScreen();
      case Screen.settings:
        return const SettingsScreen();
      case Screen.account:
        return const AccountScreen();
      case Screen.readiness:
        return const ReadinessScreen();
      case Screen.skills:
        return const SkillsScreen();
      case Screen.teacherApp:
        return const TeacherApp();
    }
  }
}
