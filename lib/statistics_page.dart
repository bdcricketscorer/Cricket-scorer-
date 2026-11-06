import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key, required this.isBangla});
  final bool isBangla;
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> with SingleTickerProviderStateMixin {
  late final TabController tabs = TabController(length: 3, vsync: this);
  List<Map<String, dynamic>> players = [];
  List<Map<String, dynamic>> teams = [];
  List<Map<String, dynamic>> tournaments = [];
  List<Map<String, dynamic>> matches = [];
  List<Map<String, dynamic>> friendly = [];
  String selectedTournament = '';
  bool loading = true;
  String tr(String en, String bn) => widget.isBangla ? bn : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _read(String raw) {
    try {
      return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final loadedTournaments = _read(prefs.getString('tournament_profiles_v1') ?? '[]');
    if (!mounted) return;
    setState(() {
      players = _read(prefs.getString('player_profiles_v1') ?? '[]');
      teams = _read(prefs.getString('team_profiles_v1') ?? '[]');
      tournaments = loadedTournaments;
      matches = _read(prefs.getString('tournament_fixtures_v1') ?? '[]');
      friendly = _read(prefs.getString('friendly_matches_v1') ?? '[]');
      if (selectedTournament.isEmpty && tournaments.isNotEmpty) {
        selectedTournament = tournaments.first['id'].toString();
      }
      loading = false;
    });
  }

  List<Map<String, dynamic>> get allMatches => [...matches, ...friendly];

  Map<String, dynamic> _playerStats(String playerId) {
    int runs = 0, balls = 0, outs = 0, fours = 0, sixes = 0;
    int wickets = 0, ballsBowled = 0, runsConceded = 0;
    final played = <String>{};
    for (final match in allMatches) {
      final matchId = match['id'].toString();
      final innings = match['innings'] as List? ?? [];
      for (final rawInn in innings) {
        final inn = Map<String, dynamic>.from(rawInn);
        final events = inn['events'] as List? ?? [];
        for (final rawEvent in events) {
          final e = Map<String, dynamic>.from(rawEvent);
          final batterId = (e['strikerId'] ?? '').toString();
          final bowlerId = (e['bowlerId'] ?? '').toString();
          final dismissedId = (e['dismissedBatterId'] ?? '').toString();
          final eventRuns = (e['runs'] as num?)?.toInt() ?? 0;
          final batterRuns = (e['batterRuns'] as num?)?.toInt() ?? 0;
          final extras = (e['extras'] as num?)?.toInt() ?? 0;
          if (batterId == playerId) {
            runs += batterRuns;
            if (e['legal'] == true) balls++;
            if (batterRuns == 4) fours++;
            if (batterRuns == 6) sixes++;
            played.add(matchId);
          }
          if (dismissedId == playerId && e['wicket'] == true) {
            outs++;
            played.add(matchId);
          }
          if (bowlerId == playerId) {
            if (e['legal'] == true) ballsBowled++;
            // Byes and leg-byes do not count against the bowler.
            final conceded = eventRuns - (e['legal'] == true ? extras : 0);
            runsConceded += conceded < 0 ? 0 : conceded;
            if (e['wicket'] == true && e['bowlerCredited'] == true) wickets++;
            played.add(matchId);
          }
        }
      }
    }
    return {
      'matches': played.length, 'runs': runs, 'balls': balls, 'outs': outs,
      'average': outs == 0 ? (runs == 0 ? 0.0 : runs.toDouble()) : runs / outs,
      'strikeRate': balls == 0 ? 0.0 : runs * 100 / balls,
      'fours': fours, 'sixes': sixes, 'wickets': wickets,
      'overs': (ballsBowled ~/ 6).toString() + '.' + (ballsBowled % 6).toString(),
      'economy': ballsBowled == 0 ? 0.0 : runsConceded * 6 / ballsBowled,
    };
  }

  String _teamName(String id) {
    final found = teams.where((t) => t['id'].toString() == id).toList();
    return found.isEmpty ? tr('Unknown team', 'অজানা দল') : found.first['name'].toString();
  }

  List<Map<String, dynamic>> _pointsRows() {
    final tournament = tournaments.where((t) => t['id'].toString() == selectedTournament).toList();
    if (tournament.isEmpty) return [];
    final ids = (tournament.first['teamIds'] as List? ?? []).map((e) => e.toString()).toList();
    final rows = <String, Map<String, dynamic>>{};
    for (final id in ids) {
      rows[id] = {
        'id': id, 'team': _teamName(id), 'played': 0, 'won': 0, 'lost': 0,
        'tied': 0, 'points': 0, 'runsFor': 0, 'ballsFor': 0,
        'runsAgainst': 0, 'ballsAgainst': 0,
      };
    }
    for (final match in matches.where((m) => m['tournamentId']?.toString() == selectedTournament && m['status'] == 'Completed')) {
      final innings = (match['innings'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
      if (innings.length < 2) continue;
      final first = innings[0], second = innings[1];
      final aId = first['battingTeamId'].toString();
      final bId = second['battingTeamId'].toString();
      if (!rows.containsKey(aId) || !rows.containsKey(bId)) continue;
      int runs(Map<String, dynamic> inn) {
        final events = inn['events'] as List? ?? [];
        if (events.isEmpty) return (inn['runs'] as num?)?.toInt() ?? 0;
        return events.fold<int>(0, (sum, e) => sum + (((e as Map)['runs'] as num?)?.toInt() ?? 0));
      }
      int balls(Map<String, dynamic> inn) {
        final events = inn['events'] as List? ?? [];
        if (events.isEmpty) return (inn['balls'] as num?)?.toInt() ?? 0;
        return events.where((e) => (e as Map)['legal'] == true).length;
      }
      int wickets(Map<String, dynamic> inn) => (inn['wickets'] as num?)?.toInt() ?? 0;
      int quota = ((match['overs'] as num?)?.toInt() ?? 10) * 6;
      int usedBalls(Map<String, dynamic> inn) => wickets(inn) >= 10 ? quota : balls(inn);
      final ar = runs(first), br = runs(second);
      final ab = usedBalls(first), bb = usedBalls(second);
      final a = rows[aId]!, b = rows[bId]!;
      a['played'] = (a['played'] as int) + 1;
      b['played'] = (b['played'] as int) + 1;
      a['runsFor'] = (a['runsFor'] as int) + ar;
      a['ballsFor'] = (a['ballsFor'] as int) + ab;
      a['runsAgainst'] = (a['runsAgainst'] as int) + br;
      a['ballsAgainst'] = (a['ballsAgainst'] as int) + bb;
      b['runsFor'] = (b['runsFor'] as int) + br;
      b['ballsFor'] = (b['ballsFor'] as int) + bb;
      b['runsAgainst'] = (b['runsAgainst'] as int) + ar;
      b['ballsAgainst'] = (b['ballsAgainst'] as int) + ab;
      if (ar > br) {
        a['won'] = (a['won'] as int) + 1; a['points'] = (a['points'] as int) + 2;
        b['lost'] = (b['lost'] as int) + 1;
      } else if (br > ar) {
        b['won'] = (b['won'] as int) + 1; b['points'] = (b['points'] as int) + 2;
        a['lost'] = (a['lost'] as int) + 1;
      } else {
        a['tied'] = (a['tied'] as int) + 1; b['tied'] = (b['tied'] as int) + 1;
        a['points'] = (a['points'] as int) + 1; b['points'] = (b['points'] as int) + 1;
      }
    }
    final result = rows.values.toList();
    for (final row in result) {
      final bf = row['ballsFor'] as int;
      final ba = row['ballsAgainst'] as int;
      final rf = row['runsFor'] as int;
      final ra = row['runsAgainst'] as int;
      row['nrr'] = bf == 0 || ba == 0 ? 0.0 : (rf * 6 / bf) - (ra * 6 / ba);
    }
    result.sort((a, b) {
      final byPoints = (b['points'] as int).compareTo(a['points'] as int);
      if (byPoints != 0) return byPoints;
      return (b['nrr'] as double).compareTo(a['nrr'] as double);
    });
    return result;
  }

  Widget _statBox(String label, String value) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
        Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
      ]),
    ),
  );

  Widget _playerTab() {
    final sorted = [...players]..sort((a, b) {
      final ar = (_playerStats(a['id'].toString())['runs'] as int);
      final br = (_playerStats(b['id'].toString())['runs'] as int);
      return br.compareTo(ar);
    });
    if (sorted.isEmpty) return Center(child: Text(tr('No player profiles found.', 'কোনো প্লেয়ার প্রোফাইল পাওয়া যায়নি।')));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final p = sorted[index];
        final s = _playerStats(p['id'].toString());
        String n(String key) => (s[key] as num).toStringAsFixed(key == 'average' || key == 'strikeRate' || key == 'economy' ? 2 : 0);
        return Card(
          color: const Color(0xFF102019),
          child: ExpansionTile(
            leading: CircleAvatar(child: Text((index + 1).toString())),
            title: Text(p['name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(tr('Runs: ', 'রান: ') + n('runs') + ' • ' + tr('Wickets: ', 'উইকেট: ') + n('wickets')),
            children: [
              Row(children: [
                _statBox(tr('Matches', 'ম্যাচ'), n('matches')),
                _statBox(tr('Runs', 'রান'), n('runs')),
                _statBox(tr('Average', 'গড়'), n('average')),
                _statBox(tr('Strike rate', 'স্ট্রাইক রেট'), n('strikeRate')),
              ]),
              Row(children: [
                _statBox(tr('4s', 'চার'), n('fours')),
                _statBox(tr('6s', 'ছয়'), n('sixes')),
                _statBox(tr('Wickets', 'উইকেট'), n('wickets')),
                _statBox(tr('Economy', 'ইকোনমি'), n('economy')),
              ]),
              Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(tr('Bowling overs: ', 'বোলিং ওভার: ') + s['overs'].toString())),
            ],
          ),
        );
      },
    );
  }

  Widget _pointsTab() {
    if (tournaments.isEmpty) return Center(child: Text(tr('Create a tournament first.', 'আগে একটি টুর্নামেন্ট তৈরি করুন।')));
    final rows = _pointsRows();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: DropdownButtonFormField<String>(
          value: tournaments.any((t) => t['id'].toString() == selectedTournament) ? selectedTournament : tournaments.first['id'].toString(),
          decoration: InputDecoration(labelText: tr('Select tournament', 'টুর্নামেন্ট নির্বাচন করুন'), border: const OutlineInputBorder()),
          items: tournaments.map((t) => DropdownMenuItem(value: t['id'].toString(), child: Text(t['name'].toString()))).toList(),
          onChanged: (v) => setState(() => selectedTournament = v ?? ''),
        ),
      ),
      Expanded(child: rows.isEmpty
        ? Center(child: Text(tr('No completed matches yet. Points will appear after match results are saved.', 'এখনো কোনো ম্যাচ শেষ হয়নি। ম্যাচের ফলাফল সংরক্ষণের পর পয়েন্ট দেখা যাবে।')))
        : ListView(padding: const EdgeInsets.all(12), children: [
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
            columns: [
              DataColumn(label: Text(tr('Team', 'দল'))),
              DataColumn(label: Text(tr('P', 'ম্যাচ'))),
              DataColumn(label: Text(tr('W', 'জয়'))),
              DataColumn(label: Text(tr('L', 'হার'))),
              DataColumn(label: Text(tr('Pts', 'পয়েন্ট'))),
              DataColumn(label: Text('NRR')),
            ],
            rows: rows.map((r) => DataRow(cells: [
              DataCell(Text(r['team'].toString())),
              DataCell(Text(r['played'].toString())),
              DataCell(Text(r['won'].toString())),
              DataCell(Text(r['lost'].toString())),
              DataCell(Text(r['points'].toString())),
              DataCell(Text((r['nrr'] as double).toStringAsFixed(3))),
            ])).toList(),
          )),
          const SizedBox(height: 8),
          Text(tr('P: Played  •  W: Won  •  L: Lost  •  Pts: Points', 'ম্যাচ: খেলা  •  জয়: জয়ী  •  হার: পরাজয়  •  পয়েন্ট: অর্জিত পয়েন্ট'), style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ])),
    ]);
  }

  List<Map<String, dynamic>> _tournamentAwards() {
    final ms = matches.where((m) => (m['tournamentId'] ?? m['tourId'] ?? '').toString() == selectedTournament).toList();
    if (ms.isEmpty || ms.any((m) => m['status'] != 'Completed')) return [];
    final stats = <String, Map<String, dynamic>>{};
    for (final p in players) {
      final id = p['id'].toString();
      stats[id] = {'id': id, 'name': p['name'].toString(), 'runs': 0, 'wickets': 0, 'ballsBowled': 0, 'runsConceded': 0, 'matches': <String>{}};
    }
    for (final match in ms) {
      final mid = match['id'].toString();
      for (final rawInn in (match['innings'] as List? ?? [])) {
        final inn = Map<String, dynamic>.from(rawInn);
        for (final rawEvent in (inn['events'] as List? ?? [])) {
          final e = Map<String, dynamic>.from(rawEvent);
          final batter = (e['strikerId'] ?? '').toString();
          final bowler = (e['bowlerId'] ?? '').toString();
          final br = (e['batterRuns'] as num?)?.toInt() ?? 0;
          final total = (e['runs'] as num?)?.toInt() ?? 0;
          final extras = (e['extras'] as num?)?.toInt() ?? 0;
          if (stats.containsKey(batter)) {
            stats[batter]!['runs'] = (stats[batter]!['runs'] as int) + br;
            (stats[batter]!['matches'] as Set<String>).add(mid);
          }
          if (stats.containsKey(bowler)) {
            final s = stats[bowler]!;
            if (e['legal'] == true) s['ballsBowled'] = (s['ballsBowled'] as int) + 1;
            final conceded = total - (e['legal'] == true ? extras : 0);
            s['runsConceded'] = (s['runsConceded'] as int) + (conceded < 0 ? 0 : conceded);
            if (e['wicket'] == true && e['bowlerCredited'] == true) s['wickets'] = (s['wickets'] as int) + 1;
            (s['matches'] as Set<String>).add(mid);
          }
        }
      }
    }
    return stats.values.where((s) => (s['matches'] as Set<String>).isNotEmpty).map((s) {
      final balls = s['ballsBowled'] as int;
      return <String, dynamic>{...s, 'matches': (s['matches'] as Set<String>).length,
        'economy': balls == 0 ? 999.0 : (s['runsConceded'] as int) * 6 / balls,
        'allRoundScore': (s['runs'] as int) + (s['wickets'] as int) * 20};
    }).toList();
  }

  Widget _awardCard(String title, Map<String, dynamic>? player, String detail) => Card(
    color: const Color(0xFF102019),
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.emoji_events, color: Color(0xFF00E676))),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(player == null ? tr('Not available', 'তথ্য পাওয়া যায়নি') : player['name'].toString() + ' • ' + detail),
    ),
  );

  Widget _awardsTab() {
    if (tournaments.isEmpty) return Center(child: Text(tr('Create a tournament first.', 'আগে একটি টুর্নামেন্ট তৈরি করুন।')));
    final ms = matches.where((m) => (m['tournamentId'] ?? m['tourId'] ?? '').toString() == selectedTournament).toList();
    final complete = ms.isNotEmpty && ms.every((m) => m['status'] == 'Completed');
    final stats = _tournamentAwards();
    Map<String, dynamic>? best(List<Map<String, dynamic>> list, int Function(Map<String, dynamic>) score) {
      if (list.isEmpty) return null;
      list.sort((a, b) => score(b).compareTo(score(a)));
      return list.first;
    }
    final batter = best(stats.where((s) => (s['runs'] as int) > 0).toList(), (s) => s['runs'] as int);
    final bowler = best(stats.where((s) => (s['wickets'] as int) > 0).toList(), (s) => (s['wickets'] as int) * 10000 - ((s['economy'] as double) * 100).round());
    final allRounder = best(stats.where((s) => (s['runs'] as int) > 0 && (s['wickets'] as int) > 0).toList(), (s) => s['allRoundScore'] as int);
    final pot = best(stats, (s) => (s['allRoundScore'] as int) + (s['matches'] as int));
    return ListView(padding: const EdgeInsets.all(12), children: [
      DropdownButtonFormField<String>(
        initialValue: tournaments.any((t) => t['id'].toString() == selectedTournament) ? selectedTournament : tournaments.first['id'].toString(),
        decoration: InputDecoration(labelText: tr('Select tournament', 'টুর্নামেন্ট নির্বাচন করুন'), border: const OutlineInputBorder()),
        items: tournaments.map((t) => DropdownMenuItem(value: t['id'].toString(), child: Text(t['name'].toString()))).toList(),
        onChanged: (v) => setState(() => selectedTournament = v ?? ''),
      ),
      const SizedBox(height: 12),
      if (!complete) Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(tr('Awards are calculated after every tournament match is completed.', 'টুর্নামেন্টের সব ম্যাচ শেষ হলে পুরস্কার নির্ধারণ হবে।')))),
      if (complete) ...[
        _awardCard(tr('Player of the Tournament', 'টুর্নামেন্ট সেরা খেলোয়াড়'), pot, pot == null ? '' : pot['runs'].toString() + ' runs • ' + pot['wickets'].toString() + ' wickets'),
        _awardCard(tr('Best Batter', 'সেরা ব্যাটার'), batter, batter == null ? '' : batter['runs'].toString() + ' runs'),
        _awardCard(tr('Best Bowler', 'সেরা বোলার'), bowler, bowler == null ? '' : bowler['wickets'].toString() + ' wickets • ' + (bowler['economy'] as double).toStringAsFixed(2) + ' economy'),
        _awardCard(tr('Best All-rounder', 'সেরা অলরাউন্ডার'), allRounder, allRounder == null ? '' : allRounder['runs'].toString() + ' runs • ' + allRounder['wickets'].toString() + ' wickets'),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr('Statistics & Points Table', 'পরিসংখ্যান ও পয়েন্ট টেবিল')),
      bottom: TabBar(controller: tabs, tabs: [
        Tab(text: tr('Player Stats', 'প্লেয়ার পরিসংখ্যান')),
        Tab(text: tr('Points Table', 'পয়েন্ট টেবিল')),
        Tab(text: tr('Tournament Awards', 'টুর্নামেন্ট পুরস্কার')),
      ]),
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: tr('Refresh', 'রিফ্রেশ'))],
    ),
    body: loading ? const Center(child: CircularProgressIndicator()) : TabBarView(
      controller: tabs,
      children: [_playerTab(), _pointsTab(), _awardsTab()],
    ),
  );
}
