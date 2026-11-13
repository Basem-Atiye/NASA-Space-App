import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton_station/data/catalogue.dart';
import 'package:shackleton_station/data/encyclopedia.dart';
import 'package:shackleton_station/data/glossary.dart';
import 'package:shackleton_station/story/campaign.dart';

/// Every line the player reads in a campaign: dialogue, objectives, choices.
List<String> playerText(Campaign c) {
  final out = <String>[];
  for (final t in c.tasks) {
    out.add(t.subtitle);
    for (final s in t.steps) {
      out.add(s.objective);
      out.addAll([for (final l in s.intro) l.text]);
      out.addAll([for (final l in s.outro) l.text]);
      if (s.question.isNotEmpty) out.add(s.question);
      for (final o in s.options) {
        out.add(o.label);
        out.addAll([for (final l in o.result) l.text]);
      }
    }
  }
  return [
    for (final t in out)
      if (t.trim().isNotEmpty) t,
  ];
}

List<int> sentenceLengths(List<String> texts) => [
  for (final t in texts)
    for (final s in t.split(RegExp(r'(?<=[.!?])\s+')))
      if (s.trim().isNotEmpty) s.trim().split(RegExp(r'\s+')).length,
];

void main() {
  test('simple English: short sentences for school readers', () {
    final cadet = sentenceLengths(playerText(campaignById(CampaignId.cadet)));
    final explorer = sentenceLengths(playerText(campaignById(CampaignId.explorer)));
    double avg(List<int> l) => l.reduce((a, b) => a + b) / l.length;
    // Cadet (6–10): about 8 words a sentence or fewer, nothing very long
    expect(avg(cadet), lessThanOrEqualTo(8.0));
    expect(cadet.where((n) => n > 16).length, 0);
    // Explorer (11–14): about 12 words or fewer
    expect(avg(explorer), lessThanOrEqualTo(12.0));
    expect(explorer.where((n) => n > 22).length, 0);
  });

  test('word tips: hard words are found once and explained simply', () {
    final hits = findTips('Regolith covers the crater. More regolith blocks radiation and carbon dioxide stays out.');
    final words = [for (final h in hits) h.tip.word].join(',');
    expect(words, 'regolith,crater,radiation,carbon dioxide');
    // the underline covers exactly the word
    expect('Regolith covers'.substring(hits.first.start, hits.first.end), 'Regolith');
    final ids = <String>{};
    for (final w in glossary) {
      expect(w.meaning.split(' ').length, lessThanOrEqualTo(18), reason: w.word);
      expect(RegExp(r'^[a-z0-9_:.-]{1,64}$').hasMatch(w.id), isTrue, reason: w.id);
      expect(ids.add(w.id), isTrue, reason: w.id);
      expect(tipById(w.id)?.word, w.word);
      // every word the player taps lands in the encyclopedia under Words
      expect(factById(w.id)?.topic, 'Words');
    }
  });

  test('word tips: plurals count, parts of other words do not', () {
    expect(findTips('Two craters and three batteries.').length, 2);
    expect(findTips('The orbiter and the rovers.').map((h) => h.tip.word).join(','), 'rover');
  });
}
