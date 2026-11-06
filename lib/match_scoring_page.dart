import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MatchCenterPage extends StatefulWidget {
  const MatchCenterPage({super.key, required this.isBangla});
  final bool isBangla;
  @override
  State<MatchCenterPage> createState() => _MatchCenterPageState();
}

class _MatchCenterPageState extends State<MatchCenterPage> {
  List<Map<String, dynamic>> teams = [];
  List<Map<String, dynamic>> fixtures = [];
  List<Map<String, dynamic>> friendly = [];
  bool loading = true;
  String tr(String en, String bn) => widget.isBangla ? bn : en;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> read(String key) {
      try {
        return (jsonDecode(prefs.getString(key) ?? '[]') as List)
            .map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) { return []; }
    }
    if (!mounted) return;
    setState(() {
      teams = read('team_profiles_v1');
      fixtures = read('tournament_fixtures_v1');
      friendly = read('friendly_matches_v1');
      loading = false;
    });
  }

  Future<void> _saveFriendly() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('friendly_matches_v1', jsonEncode(friendly));
  }

  String _teamName(String id) {
    for (final team in teams) {
      if (team['id'].toString() == id) return team['name'].toString();
    }
    return tr('Unknown team', 'অজানা দল');
  }

  Future<void> _createMatch() async {
    if (teams.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('Create at least two teams first.', 'আগে কমপক্ষে দুটি দল তৈরি করুন।'))));
      return;
    }
    String a = teams[0]['id'].toString();
    String b = teams[1]['id'].toString();
    int overs = 10;
    final result = await showDialog<bool>(context: context, builder: (ctx) =>
      StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
        title: Text(tr('Create Friendly Match', 'প্রীতি ম্যাচ তৈরি করুন')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: a,
            decoration: InputDecoration(labelText: tr('Team A', 'দল A')),
            items: teams.map((t) => DropdownMenuItem(
              value: t['id'].toString(), child: Text(t['name'].toString()))).toList(),
            onChanged: (v) => refresh(() { a = v ?? a; if (a == b) {
              b = teams.firstWhere((t) => t['id'].toString() != a)['id'].toString();
            }})),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: b,
            decoration: InputDecoration(labelText: tr('Team B', 'দল B')),
            items: teams.where((t) => t['id'].toString() != a).map((t) =>
              DropdownMenuItem(value: t['id'].toString(), child: Text(t['name'].toString()))).toList(),
            onChanged: (v) => refresh(() => b = v ?? b)),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: overs,
            decoration: InputDecoration(labelText: tr('Overs per innings', 'প্রতি ইনিংসে ওভার')),
            items: [5, 6, 10, 12, 15, 20, 25, 50].map((n) =>
              DropdownMenuItem(value: n, child: Text(n.toString()))).toList(),
            onChanged: (v) => refresh(() => overs = v ?? 10)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel', 'বাতিল'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Create', 'তৈরি করুন'))),
        ],
      )));
    if (result != true) return;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() => friendly.insert(0, {
      'id': id, 'tournamentId': '', 'tournament': 'Friendly',
      'teamAId': a, 'teamBId': b, 'teamA': _teamName(a), 'teamB': _teamName(b),
      'overs': overs, 'stage': 'Friendly', 'status': 'Scheduled',
      'innings': <Map<String, dynamic>>[], 'currentInnings': 0,
    }));
    await _saveFriendly();
  }

  Future<void> _openMatch(Map<String, dynamic> source, {required bool isFriendly}) async {
    final copy = Map<String, dynamic>.from(source);
    await Navigator.push(context, MaterialPageRoute(builder: (_) =>
      LiveScoringPage(match: copy, isBangla: widget.isBangla, teams: teams)));
    final prefs = await SharedPreferences.getInstance();
    if (isFriendly) {
      final i = friendly.indexWhere((m) => m['id'] == copy['id']);
      if (i >= 0) friendly[i] = copy;
      await prefs.setString('friendly_matches_v1', jsonEncode(friendly));
    } else {
      final i = fixtures.indexWhere((m) => m['id'] == copy['id']);
      if (i >= 0) fixtures[i] = copy;
      await prefs.setString('tournament_fixtures_v1', jsonEncode(fixtures));
    }
    if (mounted) setState(() {});
  }

  Widget _matchCard(Map<String, dynamic> match, {required bool isFriendly}) {
    final status = match['status']?.toString() ?? 'Scheduled';
    final a = match['teamA']?.toString() ?? _teamName(match['teamAId'].toString());
    final b = match['teamB']?.toString() ?? _teamName(match['teamBId'].toString());
    final innings = (match['innings'] as List?) ?? [];
    String score(int index) {
      if (innings.length <= index) return '—';
      final inn = Map<String, dynamic>.from(innings[index]);
      return inn['runs'].toString() + '/' + inn['wickets'].toString();
    }
    return Card(
      color: const Color(0xFF102019),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: status == 'Live' ? const Color(0xFF07552D) : Colors.black26,
          child: Icon(status == 'Live' ? Icons.sensors : Icons.sports_cricket,
            color: const Color(0xFF00E676))),
        title: Text(a + '  vs  ' + b, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text((match['tournament']?.toString() ?? 'Friendly') +
          ' • ' + match['overs'].toString() + ' overs\n' +
          (innings.isEmpty ? status : score(0) + '  |  ' + (innings.length > 1 ? score(1) : '—') + ' • ' + status)),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openMatch(match, isFriendly: isFriendly),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheduled = fixtures.where((m) => m['status'] != 'Completed').toList();
    final completed = fixtures.where((m) => m['status'] == 'Completed').toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Matches & Live Scoring', 'ম্যাচ ও লাইভ স্কোরিং'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createMatch, icon: const Icon(Icons.add),
        label: Text(tr('Friendly Match', 'প্রীতি ম্যাচ'))),
      body: loading ? const Center(child: CircularProgressIndicator()) :
        RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(12), children: [
          if (friendly.isNotEmpty) ...[
            Text(tr('Friendly Matches', 'প্রীতি ম্যাচ'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ...friendly.map((m) => _matchCard(m, isFriendly: true)),
            const SizedBox(height: 12),
          ],
          Text(tr('Tournament Fixtures', 'টুর্নামেন্টের ফিক্সচার'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          if (scheduled.isEmpty) Padding(
            padding: const EdgeInsets.all(18),
            child: Text(tr('No scheduled tournament matches. Generate fixtures in Tournament Management.', 'কোনো নির্ধারিত ম্যাচ নেই। Tournament Management থেকে ফিক্সচার তৈরি করুন।'))),
          ...scheduled.map((m) => _matchCard(m, isFriendly: false)),
          if (completed.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(tr('Completed Matches', 'শেষ হওয়া ম্যাচ'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ...completed.map((m) => _matchCard(m, isFriendly: false)),
          ],
        ])),
    );
  }
}

class LiveScoringPage extends StatefulWidget {
  const LiveScoringPage({super.key, required this.match, required this.isBangla, required this.teams});
  final Map<String, dynamic> match;
  final bool isBangla;
  final List<Map<String, dynamic>> teams;
  @override
  State<LiveScoringPage> createState() => _LiveScoringPageState();
}

class _LiveScoringPageState extends State<LiveScoringPage> {
  late Map<String, dynamic> match;
  List<Map<String, dynamic>> players = [];
  bool saving = false;
  String tr(String en, String bn) => widget.isBangla ? bn : en;

  @override
  void initState() { super.initState(); match = widget.match; _loadPlayers(); _ensureInnings(); }

  Future<void> _loadPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString('player_profiles_v1') ?? '[]';
      final data = (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)).toList();
      if (mounted) setState(() => players = data);
    } catch (_) {}
  }

  List<Map<String, dynamic>> get innings {
    final raw = match['innings'] as List? ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  int get currentIndex => (match['currentInnings'] as num?)?.toInt() ?? 0;
  Map<String, dynamic> get current => innings[currentIndex];
  int get maxBalls => ((match['overs'] as num?)?.toInt() ?? 10) * 6;

  void _ensureInnings() {
    if (innings.isEmpty) {
      match['innings'] = [{
        'battingTeamId': match['teamAId'], 'bowlingTeamId': match['teamBId'],
        'runs': 0, 'wickets': 0, 'balls': 0, 'events': <Map<String, dynamic>>[],
        'strikerId': '', 'nonStrikerId': '', 'bowlerId': '',
      }];
      match['currentInnings'] = 0;
    }
  }

  String _teamName(String id) {
    for (final t in widget.teams) {
      if (t['id'].toString() == id) return t['name'].toString();
    }
    return 'Team';
  }

  List<Map<String, dynamic>> _squad(String teamId) {
    final team = widget.teams.where((t) => t['id'].toString() == teamId).toList();
    if (team.isEmpty) return [];
    final ids = List<String>.from(team.first['playerIds'] ?? <String>[]);
    return players.where((p) => ids.contains(p['id'].toString())).toList();
  }

  String _playerName(String id) {
    for (final p in players) { if (p['id'].toString() == id) return p['name'].toString(); }
    return '';
  }

  List<Map<String, dynamic>> _events() =>
    (current['events'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();

  int _legalBalls() => _events().where((e) => e['legal'] == true).length;
  int _runs() => _events().fold<int>(0, (n, e) => n + ((e['runs'] as num?)?.toInt() ?? 0));
  int _wickets() => _events().where((e) => e['wicket'] == true).length;

  String _oversText() {
    final balls = _legalBalls();
    return (balls ~/ 6).toString() + '.' + (balls % 6).toString();
  }

  Future<void> _persist() async {
    if (saving) return;
    saving = true;
    final prefs = await SharedPreferences.getInstance();
    final inningsList = innings;
    for (final inn in inningsList) {
      final ev = (inn['events'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
      inn['runs'] = ev.fold<int>(0, (n, e) => n + ((e['runs'] as num?)?.toInt() ?? 0));
      inn['wickets'] = ev.where((e) => e['wicket'] == true).length;
      inn['balls'] = ev.where((e) => e['legal'] == true).length;
    }
    match['innings'] = inningsList;
    if (match['status'] != 'Completed') match['status'] = 'Live';
    if ((match['tournamentId']?.toString() ?? '').isEmpty) {
      final all = <Map<String, dynamic>>[];
      try { all.addAll((jsonDecode(prefs.getString('friendly_matches_v1') ?? '[]') as List).map((e) => Map<String, dynamic>.from(e))); } catch (_) {}
      final i = all.indexWhere((m) => m['id'] == match['id']);
      if (i >= 0) all[i] = match; else all.insert(0, match);
      await prefs.setString('friendly_matches_v1', jsonEncode(all));
    } else {
      final all = <Map<String, dynamic>>[];
      try { all.addAll((jsonDecode(prefs.getString('tournament_fixtures_v1') ?? '[]') as List).map((e) => Map<String, dynamic>.from(e))); } catch (_) {}
      final i = all.indexWhere((m) => m['id'] == match['id']);
      if (i >= 0) all[i] = match;
      await prefs.setString('tournament_fixtures_v1', jsonEncode(all));
    }
    saving = false;
  }

  Future<void> _addBall({int runs = 0, int batterRuns = 0, int extras = 0, bool legal = true, bool wicket = false}) async {
    if (_legalBalls() >= maxBalls || _wickets() >= 10 || match['status'] == 'Completed') return;
    final striker = current['strikerId']?.toString() ?? '';
    if (striker.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Select the striker first.', 'আগে স্ট্রাইকার নির্বাচন করুন।'))));
      return;
    }
    final events = _events();
    final beforeStriker = striker;
    final beforeNon = current['nonStrikerId']?.toString() ?? '';
    final beforeBowler = current['bowlerId']?.toString() ?? '';
    events.add({
      'runs': runs, 'batterRuns': batterRuns, 'extras': extras,
      'legal': legal, 'wicket': wicket, 'strikerId': striker,
      'bowlerId': beforeBowler, 'beforeStriker': beforeStriker,
      'beforeNonStriker': beforeNon, 'beforeBowler': beforeBowler,
    });
    current['events'] = events;
    if (wicket) {
      current['strikerId'] = '';
    } else {
      if (runs.isOdd) {
        current['strikerId'] = beforeNon;
        current['nonStrikerId'] = beforeStriker;
      }
      if (legal && (_legalBalls() % 6 == 0)) {
        final s = current['strikerId'];
        current['strikerId'] = current['nonStrikerId'];
        current['nonStrikerId'] = s;
        current['bowlerId'] = '';
      }
    }
    final target = innings.isNotEmpty && currentIndex == 1
      ? ((innings[0]['runs'] as num?)?.toInt() ?? 0) + 1 : null;
    if (currentIndex == 1 && target != null && _runs() >= target) {
      match['status'] = 'Completed';
    } else if (_legalBalls() >= maxBalls || _wickets() >= 10) {
      if (currentIndex == 1) match['status'] = 'Completed';
    }
    setState(() {});
    await _persist();
    if (mounted) setState(() {});
  }

  Future<void> _undo() async {
    final events = _events();
    if (events.isEmpty) return;
    final last = events.removeLast();
    current['events'] = events;
    current['strikerId'] = last['beforeStriker'] ?? '';
    current['nonStrikerId'] = last['beforeNonStriker'] ?? '';
    current['bowlerId'] = last['beforeBowler'] ?? '';
    if (match['status'] == 'Completed') match['status'] = 'Live';
    setState(() {});
    await _persist();
    if (mounted) setState(() {});
  }

  Future<void> _startSecondInnings() async {
    if (currentIndex != 0 || (_legalBalls() < maxBalls && _wickets() < 10)) return;
    final first = current;
    final second = <String, dynamic>{
      'battingTeamId': match['teamBId'], 'bowlingTeamId': match['teamAId'],
      'runs': 0, 'wickets': 0, 'balls': 0, 'events': <Map<String, dynamic>>[],
      'strikerId': '', 'nonStrikerId': '', 'bowlerId': '',
    };
    final list = innings;
    list.add(second);
    match['innings'] = list;
    match['currentInnings'] = 1;
    match['status'] = 'Live';
    setState(() {});
    await _persist();
  }

  Widget _playerSelect(String label, String key, List<Map<String, dynamic>> squad) {
    final value = current[key]?.toString() ?? '';
    final valid = squad.any((p) => p['id'].toString() == value);
    return DropdownButtonFormField<String>(
      initialValue: valid ? value : '',
      isExpanded: true,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
      items: [
        DropdownMenuItem(value: '', child: Text(tr('Select', 'নির্বাচন করুন'))),
        ...squad.map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text(p['name'].toString(), overflow: TextOverflow.ellipsis))),
      ],
      onChanged: (v) async {
        current[key] = v ?? '';
        setState(() {});
        await _persist();
      },
    );
  }

  Widget _scoreButton(String label, VoidCallback action, {Color? color}) =>
    SizedBox(height: 54, child: FilledButton(
      style: FilledButton.styleFrom(backgroundColor: color ?? const Color(0xFF07552D)),
      onPressed: action, child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))));

  @override
  Widget build(BuildContext context) {
    _ensureInnings();
    final battingId = current['battingTeamId'].toString();
    final bowlingId = current['bowlingTeamId'].toString();
    final batting = _squad(battingId);
    final bowling = _squad(bowlingId);
    final events = _events();
    final ended = _legalBalls() >= maxBalls || _wickets() >= 10;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Live Scoring', 'লাইভ স্কোরিং')),
        actions: [IconButton(onPressed: events.isEmpty ? null : _undo, tooltip: tr('Undo last ball', 'শেষ বল বাতিল'), icon: const Icon(Icons.undo))],
      ),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Card(color: const Color(0xFF102019), child: Padding(
          padding: const EdgeInsets.all(18), child: Column(children: [
            Text(_teamName(battingId), style: const TextStyle(color: Color(0xFFB9F6CA), fontSize: 16)),
            const SizedBox(height: 4),
            Text(_runs().toString() + '/' + _wickets().toString(),
              style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
            Text(_oversText() + ' / ' + (match['overs']?.toString() ?? '10') + ' ' + tr('overs', 'ওভার'),
              style: const TextStyle(fontSize: 16)),
            if (currentIndex == 1 && innings.isNotEmpty)
              Text(tr('Target: ', 'লক্ষ্য: ') + (((innings[0]['runs'] as num?)?.toInt() ?? 0) + 1).toString()),
            const SizedBox(height: 8),
            Text(_teamName(bowlingId) + '  •  ' + (match['tournament']?.toString() ?? 'Friendly'),
              style: TextStyle(color: Colors.grey.shade400)),
          ]))),
        if (match['status'] == 'Completed')
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(tr('Match completed', 'ম্যাচ শেষ হয়েছে'), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)))),
        if (batting.isEmpty || bowling.isEmpty)
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(tr('Add players to both team squads to use player-by-player scoring. You can still view the match score here.', 'প্লেয়ারভিত্তিক স্কোরিংয়ের জন্য দুই দলের স্কোয়াডে খেলোয়াড় যোগ করুন। এখানে ম্যাচের স্কোর দেখা যাবে।')))),
        if (batting.isNotEmpty) ...[
          Text(tr('Batting', 'ব্যাটিং'), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _playerSelect(tr('Striker', 'স্ট্রাইকার'), 'strikerId', batting)),
            const SizedBox(width: 8),
            Expanded(child: _playerSelect(tr('Non-striker', 'নন-স্ট্রাইকার'), 'nonStrikerId', batting)),
          ]),
        ],
        if (bowling.isNotEmpty) ...[
          const SizedBox(height: 10),
          _playerSelect(tr('Bowler', 'বোলার'), 'bowlerId', bowling),
        ],
        const SizedBox(height: 16),
        Text(tr('Runs', 'রান'), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 4, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.45,
          children: List.generate(7, (n) => _scoreButton(n.toString(),
            () => _addBall(runs: n, batterRuns: n))),
        ),
        const SizedBox(height: 14),
        Text(tr('Extras & Wicket', 'অতিরিক্ত রান ও উইকেট'), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.2,
          children: [
            _scoreButton('Wide +1', () => _addBall(runs: 1, extras: 1, legal: false)),
            _scoreButton('No-ball +1', () => _addBall(runs: 1, extras: 1, legal: false)),
            _scoreButton('Bye +1', () => _addBall(runs: 1, extras: 1)),
            _scoreButton('Leg-bye +1', () => _addBall(runs: 1, extras: 1)),
            _scoreButton(tr('Wicket', 'উইকেট'), () => _addBall(legal: true, wicket: true), color: Colors.red.shade800),
          ],
        ),
        if (ended && currentIndex == 0 && match['status'] != 'Completed') ...[
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: _startSecondInnings,
            icon: const Icon(Icons.swap_horiz), label: Text(tr('Start 2nd Innings', '২য় ইনিংস শুরু করুন'))),
        ],
        const SizedBox(height: 18),
        Text(tr('Recent Balls', 'সাম্প্রতিক বল'), style: const TextStyle(fontWeight: FontWeight.bold)),
        if (events.isEmpty) Text(tr('No balls recorded yet.', 'এখনো কোনো বল রেকর্ড হয়নি।'), style: TextStyle(color: Colors.grey.shade500))
        else ...events.reversed.take(12).map((e) {
          final batter = _playerName(e['strikerId']?.toString() ?? '');
          final label = e['wicket'] == true ? tr('WICKET', 'উইকেট') :
            (e['extras'] == 1 ? tr('EXTRA', 'অতিরিক্ত') : (e['batterRuns'] ?? 0).toString() + ' ' + tr('run(s)', 'রান'));
          return ListTile(dense: true, leading: Icon(e['wicket'] == true ? Icons.sports_cricket : Icons.circle, size: 14,
            color: e['wicket'] == true ? Colors.redAccent : const Color(0xFF00E676)),
            title: Text(label), subtitle: Text(batter.isEmpty ? '—' : batter));
        }),
        const SizedBox(height: 18),
        Text(tr('Scorecard summary', 'স্কোরকার্ড সারাংশ'), style: const TextStyle(fontWeight: FontWeight.bold)),
        ...innings.asMap().entries.map((entry) {
          final inn = entry.value;
          return ListTile(
            dense: true,
            title: Text(_teamName(inn['battingTeamId'].toString())),
            trailing: Text(inn['runs'].toString() + '/' + inn['wickets'].toString() + '  (' +
              ((inn['balls'] as num? ?? 0) ~/ 6).toString() + '.' + ((inn['balls'] as num? ?? 0) % 6).toString() + ')'),
          );
        }),
      ]),
    );
  }
}
