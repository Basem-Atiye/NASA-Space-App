import 'package:flutter/material.dart';

import '../data/encyclopedia.dart';
import '../main.dart';
import '../ui/theme.dart';
import '../ui/kit.dart';
import '../ui/widgets/common.dart';
import '../world/characters.dart';

/// Every fact found with Pip's scanner, grouped by topic.
class EncyclopediaScreen extends StatelessWidget {
  const EncyclopediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sv = Services.of(context);
    final found = sv.progress.facts;
    final n = encyclopedia.where((f) => found.contains(f.id)).length;
    return AuroraBackground(
      intensity: 0.7,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: Row(children: [
                RoundButton(onTap: sv.nav.back),
                const Spacer(),
                const PipFigure(size: 44, eye: PipEye.happy),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('PIP\'S SCANNER', style: T.label.copyWith(letterSpacing: 3)),
                const SizedBox(height: 6),
                Text('Moon Encyclopedia', style: T.hero.copyWith(fontSize: 34)),
                const SizedBox(height: 8),
                Text('$n of ${encyclopedia.length} facts found. Tap things in the story, or press Scan, and Pip adds what he learns here.', style: T.body.copyWith(color: C.muted)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: encyclopedia.isEmpty ? 0 : n / encyclopedia.length, minHeight: 6, color: C.cyan, backgroundColor: C.lineSoft),
                ),
              ]),
            ),
          ),
          for (final topic in topics) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                child: SectionLabel(topic),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList.list(children: [
                for (final f in encyclopedia.where((f) => f.topic == topic)) _card(f, found.contains(f.id)),
              ]),
            ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: 24 + MediaQuery.of(context).padding.bottom)),
        ]),
      ),
    );
  }

  Widget _card(Fact f, bool unlocked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: unlocked ? C.panel : C.panelDeep.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: unlocked ? C.cyan.withValues(alpha: 0.35) : C.lineSoft),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(unlocked ? Icons.auto_awesome_rounded : Icons.lock_outline_rounded, color: unlocked ? C.cyan : C.dim, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(unlocked ? f.title : 'Not found yet', style: T.h3.copyWith(color: unlocked ? C.text : C.dim)),
            const SizedBox(height: 4),
            Text(unlocked ? f.text : 'Scan more of the Moon with Pip to unlock this fact.', style: T.body.copyWith(fontSize: 13.5, color: unlocked ? C.muted : C.dim)),
          ]),
        ),
      ]),
    );
  }
}
