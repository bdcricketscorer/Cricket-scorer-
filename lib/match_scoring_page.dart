import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

class MatchCenterPage extends StatefulWidget {
  const MatchCenterPage({super.key, required this.isBangla, this.tournamentId});
  final bool isBangla;
  final String? tournamentId;
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
    final oversController = TextEditingController(text: '10');
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
          TextField(controller: oversController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('Overs per innings (1–100)', 'প্রতি ইনিংসে ওভার (১–১০০)')), onChanged: (v) => overs = int.tryParse(v) ?? 0),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel', 'বাতিল'))),
          FilledButton(onPressed: () { final v = int.tryParse(oversController.text.trim()) ?? 0; if (v < 1 || v > 100) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Enter overs from 1 to 100.', '১ থেকে ১০০ ওভারের মধ্যে লিখুন।')))); return; } overs = v; Navigator.pop(ctx, true); }, child: Text(tr('Create', 'তৈরি করুন'))),
        ],
      )));
    oversController.dispose();
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

  Future<void> _restartMatch(Map<String, dynamic> source) async {
    if (source['status'] == 'Completed') return;
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(tr('Restart this match?', 'ম্যাচটি আবার শুরু করবেন?')),
      content: Text(tr('All innings, scores, toss and ball records for this match will be reset.', 'এই ম্যাচের সব ইনিংস, স্কোর, টস ও বলের রেকর্ড মুছে নতুন করে শুরু হবে।')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancel', 'বাতিল'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Restart', 'রিস্টার্ট')))],
    ));
    if (yes != true) return;
    final isFriendly = (source['tournamentId']?.toString() ?? '').isEmpty;
    final list = isFriendly ? friendly : fixtures;
    final i = list.indexWhere((m) => m['id'] == source['id']);
    if (i < 0) return;
    list[i] = {...list[i], 'status': 'Scheduled', 'innings': <Map<String,dynamic>>[], 'currentInnings': 0,
      'tossDone': false, 'tossWinnerId': '', 'tossDecision': '', 'umpire': ''};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(isFriendly ? 'friendly_matches_v1' : 'tournament_fixtures_v1', jsonEncode(list));
    if (mounted) setState(() {});
  }

  Future<void> _deleteMatch(Map<String, dynamic> source) async {
    if (source['status'] == 'Completed') return;
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(tr('Delete match?', 'ম্যাচটি মুছে ফেলবেন?')),
      content: Text(tr('This match and its score records will be permanently deleted.', 'ম্যাচটি ও এর সব স্কোর রেকর্ড স্থায়ীভাবে মুছে যাবে।')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancel', 'বাতিল'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Delete', 'মুছুন')))],
    ));
    if (yes != true) return;
    final isFriendly = (source['tournamentId']?.toString() ?? '').isEmpty;
    final list = isFriendly ? friendly : fixtures;
    list.removeWhere((m) => m['id'] == source['id']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(isFriendly ? 'friendly_matches_v1' : 'tournament_fixtures_v1', jsonEncode(list));
    if (mounted) setState(() {});
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
        trailing: PopupMenuButton<String>(
          onSelected: (v) { if (v == 'restart') _restartMatch(match); if (v == 'delete') _deleteMatch(match); },
          itemBuilder: (_) => [
            if (status != 'Completed' && status != 'Scheduled') PopupMenuItem(value: 'restart', child: ListTile(dense: true, leading: const Icon(Icons.restart_alt), title: Text(tr('Restart match', 'ম্যাচ রিস্টার্ট')))),
            if (status != 'Completed') PopupMenuItem(value: 'delete', child: ListTile(dense: true, leading: const Icon(Icons.delete_outline, color: Colors.red), title: Text(tr('Delete match', 'ম্যাচ ডিলিট')))),
          ],
        ),
        onTap: () => _openMatch(match, isFriendly: isFriendly),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedFixtures = widget.tournamentId == null ? fixtures : fixtures.where((m) => m['tournamentId']?.toString() == widget.tournamentId).toList();
    final scheduled = selectedFixtures.where((m) => m['status'] != 'Completed').toList();
    final completed = selectedFixtures.where((m) => m['status'] == 'Completed').toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.tournamentId == null ? tr('Matches & Live Scoring', 'ম্যাচ ও লাইভ স্কোরিং') : (selectedFixtures.isNotEmpty ? selectedFixtures.first['tournament']?.toString() ?? tr('Tournament Schedule', 'টুর্নামেন্ট শিডিউল') : tr('Tournament Schedule', 'টুর্নামেন্ট শিডিউল')))),
      floatingActionButton: widget.tournamentId == null ? FloatingActionButton.extended(
        onPressed: _createMatch, icon: const Icon(Icons.add),
        label: Text(tr('Friendly Match', 'প্রীতি ম্যাচ'))) : null,
      body: loading ? const Center(child: CircularProgressIndicator()) :
        RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(12), children: [
          if (widget.tournamentId == null && friendly.isNotEmpty) ...[
            Text(tr('Friendly Matches', 'প্রীতি ম্যাচ'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ...friendly.map((m) => _matchCard(m, isFriendly: true)),
            const SizedBox(height: 12),
          ],
          Text(tr('Tournament Fixtures', 'টুর্নামেন্টের ফিক্সচার'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          if (scheduled.isEmpty) Padding(
            padding: const EdgeInsets.all(18),
            child: Text(tr('No matches in this tournament yet. Generate fixtures in Tournament Management.', 'এই টুর্নামেন্টে এখনো ম্যাচ নেই। Tournament Management থেকে ফিক্সচার তৈরি করুন।'))),
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
  bool _setupShown = false;
  bool showStats = false;
  String tr(String en, String bn) => widget.isBangla ? bn : en;

  @override
  void initState() { super.initState(); match = widget.match; _loadPlayers(); _ensureInnings(); WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && match['tossDone'] != true) _showMatchSetup(); }); }

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
    return raw.map((e) => e as Map<String, dynamic>).toList();
  }

  int get currentIndex => (match['currentInnings'] as num?)?.toInt() ?? 0;
  Map<String, dynamic> get current => innings[currentIndex];
  int get maxBalls => ((match['overs'] as num?)?.toInt() ?? 10) * 6;

  Future<void> _showMatchSetup() async {
    if (_setupShown || match['tossDone'] == true) return;
    final existingInnings = match['innings'] as List? ?? [];
    if (existingInnings.any((inn) => ((inn as Map)['events'] as List? ?? []).isNotEmpty)) { match['tossDone'] = true; return; }
    _setupShown = true;
    final a = match['teamAId'].toString();
    final b = match['teamBId'].toString();
    String tossWinner = a;
    String decision = 'Bat';
    final umpire = TextEditingController();
    final ok = await showDialog<bool>(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
      title: Text(tr('Match toss & officials', 'ম্যাচ টস ও আম্পায়ার')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: tossWinner, decoration: InputDecoration(labelText: tr('Toss won by', 'টস জিতেছে')),
          items: [DropdownMenuItem(value: a, child: Text(_teamName(a))), DropdownMenuItem(value: b, child: Text(_teamName(b)))],
          onChanged: (v) => refresh(() => tossWinner = v ?? a)),
        DropdownButtonFormField<String>(value: decision, decoration: InputDecoration(labelText: tr('Toss decision', 'টসের সিদ্ধান্ত')),
          items: [DropdownMenuItem(value: 'Bat', child: Text(tr('Bat first', 'আগে ব্যাটিং'))), DropdownMenuItem(value: 'Bowl', child: Text(tr('Bowl first', 'আগে বোলিং')))],
          onChanged: (v) => refresh(() => decision = v ?? 'Bat')),
        TextField(controller: umpire, decoration: InputDecoration(labelText: tr('Umpire name(s)', 'আম্পায়ারের নাম'))),
      ]),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Start Match', 'ম্যাচ শুরু করুন')))],
    )));
    if (ok == true && mounted) {
      final batFirst = decision == 'Bat' ? tossWinner : (tossWinner == a ? b : a);
      final bowlFirst = batFirst == a ? b : a;
      match['tossDone'] = true;
      match['tossWinnerId'] = tossWinner;
      match['tossDecision'] = decision;
      match['umpire'] = umpire.text.trim();
      match['innings'] = [{'battingTeamId': batFirst, 'bowlingTeamId': bowlFirst, 'runs': 0, 'wickets': 0, 'balls': 0, 'events': <Map<String, dynamic>>[], 'strikerId': '', 'nonStrikerId': '', 'bowlerId': ''}];
      match['currentInnings'] = 0;
      setState(() {});
      await _persist();
    }
    umpire.dispose();
  }

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
    final rawIds = team.first['playerIds'];
    final ids = (rawIds is List ? rawIds : const <dynamic>[])
        .map((id) => id.toString()).toSet();
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

  Future<void> _addBall({int runs = 0, int batterRuns = 0, int extras = 0, bool legal = true, bool wicket = false, String wicketType = '', String fielderId = '', String dismissedBatterId = ''}) async {
    if (_legalBalls() >= maxBalls || _wickets() >= 10 || match['status'] == 'Completed') return;
    final striker = current['strikerId']?.toString() ?? '';
    final battingSquad = _squad(current['battingTeamId'].toString());
    final bowlingSquad = _squad(current['bowlingTeamId'].toString());
    if (battingSquad.length >= 2 && (striker.isEmpty || (current['nonStrikerId']?.toString() ?? '').isEmpty)) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Select both batters first.', 'আগে দুইজন ব্যাটার নির্বাচন করুন।')))); return; }
    if (bowlingSquad.isNotEmpty && (current['bowlerId']?.toString() ?? '').isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Select the bowler first.', 'আগে বোলার নির্বাচন করুন।')))); return; }
    final events = _events();
    final beforeStriker = striker;
    final beforeNon = current['nonStrikerId']?.toString() ?? '';
    final beforeBowler = current['bowlerId']?.toString() ?? '';
    events.add({
      'runs': runs, 'batterRuns': batterRuns, 'extras': extras,
      'legal': legal, 'wicket': wicket, 'wicketType': wicketType, 'fielderId': fielderId,
      'bowlerCredited': wicket && !['Run out', 'Retired hurt', 'Obstructing the field'].contains(wicketType),
      'dismissedBatterId': wicket ? (dismissedBatterId.isNotEmpty ? dismissedBatterId : striker) : '', 'strikerId': striker,
      'bowlerId': beforeBowler, 'beforeStriker': beforeStriker,
      'beforeNonStriker': beforeNon, 'beforeBowler': beforeBowler,
    });
    current['events'] = events;
    if (wicket) {
      final dismissed = dismissedBatterId.isNotEmpty ? dismissedBatterId : striker;
      final dismissedSlot = dismissed == beforeNon ? 'nonStrikerId' : 'strikerId';
      current[dismissedSlot] = '';
      current['nextBatterSlot'] = dismissedSlot;
    } else {
      // Rotate strike only for runs completed by batters or running/byes/leg-byes.
      // A standalone no-ball or wide penalty does not change ends.
      final rotationRuns = legal ? runs : batterRuns;
      if (rotationRuns.isOdd) {
        current['strikerId'] = beforeNon;
        current['nonStrikerId'] = beforeStriker;
      }
    }
    if (legal && _legalBalls() > 0 && _legalBalls() % 6 == 0) {
      final s = current['strikerId'];
      current['strikerId'] = current['nonStrikerId'];
      current['nonStrikerId'] = s;
      current['bowlerId'] = '';
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
    if (match['status'] == 'Completed') await _chooseManOfTheMatch();
    if (legal && _legalBalls() > 0 && _legalBalls() % 6 == 0 && _legalBalls() < maxBalls && match['status'] != 'Completed') await _chooseNextBowler(beforeBowler);
  }

  Future<void> _shareScoreboard() async {
    final lines = <String>['BD Cricket Scorer', (match['teamA'] ?? _teamName(match['teamAId'].toString())).toString() + ' vs ' + (match['teamB'] ?? _teamName(match['teamBId'].toString())).toString(), 'Umpire: ' + (match['umpire'] ?? '—').toString()];
    for (final inn in innings) {
      final balls = (inn['balls'] as num? ?? 0).toInt();
      lines.add(_teamName(inn['battingTeamId'].toString()) + ': ' + inn['runs'].toString() + '/' + inn['wickets'].toString() + ' (' + (balls ~/ 6).toString() + '.' + (balls % 6).toString() + ')');
    }
    lines.add('Status: ' + (match['status'] ?? 'Live').toString());
    await Share.share(lines.join('\\n'), subject: 'Cricket scoreboard');
  }

  Future<void> _recordWicket() async {
    const types = ['Bowled', 'Caught', 'LBW', 'Stumped', 'Hit wicket', 'Run out', 'Retired hurt', 'Obstructing the field'];
    String kind = 'Bowled';
    String dismissed = current['strikerId']?.toString() ?? '';
    final strikerId = current['strikerId']?.toString() ?? '';
    final nonStrikerId = current['nonStrikerId']?.toString() ?? '';
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
      title: Text(tr('Wicket details', 'উইকেটের ধরন')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: kind, decoration: InputDecoration(labelText: tr('How out?', 'কীভাবে আউট?')),
          items: types.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => refresh(() => kind = v ?? 'Bowled')),
        const SizedBox(height: 10),
        if (strikerId.isNotEmpty && nonStrikerId.isNotEmpty) DropdownButtonFormField<String>(value: dismissed,
          decoration: InputDecoration(labelText: tr('Who is out?', 'কে আউট হয়েছে?')),
          items: [DropdownMenuItem(value: strikerId, child: Text(_playerName(strikerId))), DropdownMenuItem(value: nonStrikerId, child: Text(_playerName(nonStrikerId)))],
          onChanged: (v) => refresh(() => dismissed = v ?? strikerId)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancel', 'বাতিল'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Confirm', 'নিশ্চিত করুন')))],
    )));
    if (ok == true) {
      await _addBall(legal: true, wicket: true, wicketType: kind, dismissedBatterId: dismissed);
      if (mounted && _wickets() < 10 && match['status'] != 'Completed') await _chooseNewBatter();
    }
  }

  Future<void> _chooseNewBatter() async {
    final squad = _squad(current['battingTeamId'].toString());
    if (squad.isEmpty || _wickets() >= 10) return;
    final used = <String>{current['nonStrikerId']?.toString() ?? ''};
    for (final e in _events()) {
      if (e['wicket'] == true) {
        final dismissed = (e['dismissedBatterId'] ?? e['strikerId'] ?? '').toString();
        if (dismissed.isNotEmpty) used.add(dismissed);
      }
    }
    final options = squad.where((p) => !used.contains(p['id'].toString())).toList();
    if (options.isEmpty) return;
    String selected = '';
    final id = await showDialog<String>(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      title: Text(tr('Select incoming batter', 'নতুন ব্যাটার নির্বাচন করুন')),
      content: DropdownButtonFormField<String>(value: '', items: [const DropdownMenuItem(value: '', child: Text('Select player')), ...options.map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text(p['name'].toString())))], onChanged: (v) => selected = v ?? ''),
      actions: [FilledButton(onPressed: () { if (selected.isNotEmpty) Navigator.pop(ctx, selected); }, child: Text(tr('Confirm', 'নিশ্চিত করুন')))],
    ));
    if (id != null) {
      final slot = current['nextBatterSlot']?.toString() ?? 'strikerId';
      current[slot] = id;
      current.remove('nextBatterSlot');
      setState(() {});
      await _persist();
    }
  }

  Future<void> _chooseNextBowler(String previous) async {
    final options = _squad(current['bowlingTeamId'].toString()).where((p) => p['id'].toString() != previous).toList();
    if (options.isEmpty) return;
    String selected = '';
    final id = await showDialog<String>(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      title: Text(tr('Over complete — select next bowler', 'ওভার শেষ — পরের বোলার নির্বাচন করুন')),
      content: DropdownButtonFormField<String>(value: '', items: [const DropdownMenuItem(value: '', child: Text('Select bowler')), ...options.map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text(p['name'].toString())))], onChanged: (v) => selected = v ?? ''),
      actions: [FilledButton(onPressed: () { if (selected.isNotEmpty) Navigator.pop(ctx, selected); }, child: Text(tr('Continue', 'চালিয়ে যান')))],
    ));
    if (id != null) { current['bowlerId'] = id; setState(() {}); await _persist(); }
  }

  Future<void> _chooseManOfTheMatch() async {
    if ((match['manOfTheMatchId']?.toString() ?? '').isNotEmpty) return;
    final eligible = <String>{};
    for (final teamId in [match['teamAId']?.toString() ?? '', match['teamBId']?.toString() ?? '']) {
      eligible.addAll(_squad(teamId).map((p) => p['id'].toString()));
    }
    if (eligible.isEmpty) return;
    final performance = <String, Map<String, num>>{};
    for (final id in eligible) {
      performance[id] = {'runs': 0, 'batBalls': 0, 'wickets': 0, 'bowlBalls': 0, 'conceded': 0};
    }
    for (final inn in innings) {
      for (final raw in (inn['events'] as List? ?? [])) {
        final e = Map<String, dynamic>.from(raw);
        final batter = (e['strikerId'] ?? '').toString();
        final bowler = (e['bowlerId'] ?? '').toString();
        final batterRuns = (e['batterRuns'] as num?)?.toInt() ?? 0;
        final totalRuns = (e['runs'] as num?)?.toInt() ?? 0;
        final extras = (e['extras'] as num?)?.toInt() ?? 0;
        final legal = e['legal'] == true;
        if (performance.containsKey(batter)) {
          performance[batter]!['runs'] = performance[batter]!['runs']! + batterRuns;
          if (legal) performance[batter]!['batBalls'] = performance[batter]!['batBalls']! + 1;
        }
        if (performance.containsKey(bowler)) {
          final p = performance[bowler]!;
          if (legal) p['bowlBalls'] = p['bowlBalls']! + 1;
          final conceded = totalRuns - (legal ? extras : 0);
          p['conceded'] = p['conceded']! + (conceded < 0 ? 0 : conceded);
          if (e['wicket'] == true && e['bowlerCredited'] == true) p['wickets'] = p['wickets']! + 1;
        }
      }
    }
    String winner = '';
    double bestScore = -double.infinity;
    for (final entry in performance.entries) {
      final p = entry.value;
      final runs = p['runs']!.toDouble();
      final batBalls = p['batBalls']!.toDouble();
      final wickets = p['wickets']!.toDouble();
      final bowlBalls = p['bowlBalls']!.toDouble();
      final conceded = p['conceded']!.toDouble();
      final strikeRate = batBalls == 0 ? 0 : runs * 100 / batBalls;
      final economy = bowlBalls == 0 ? 0 : conceded * 6 / bowlBalls;
      final score = runs + wickets * 20 + (strikeRate > 100 ? (strikeRate - 100) * 0.10 : 0) +
        (wickets > 0 && bowlBalls > 0 ? (6 - economy) * 1.5 : 0);
      if (score > bestScore) { bestScore = score; winner = entry.key; }
    }
    if (winner.isEmpty || bestScore <= 0) return;
    match['manOfTheMatchId'] = winner;
    match['manOfTheMatch'] = _playerName(winner);
    await _persist();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('Man of the Match: ', 'ম্যান অব দ্য ম্যাচ: ') + _playerName(winner)),
      ));
    }
  }

  Future<void> _completeMatch() async {
    if (match['status'] == 'Completed') return;
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(tr('Complete match?', 'ম্যাচ সম্পন্ন করবেন?')),
      content: Text(tr('Scoring and undo will be locked after completion.', 'সম্পন্ন হলে স্কোরিং ও Undo বন্ধ হবে।')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancel', 'বাতিল'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Complete', 'সম্পন্ন করুন')))],
    ));
    if (yes == true) {
      match['status'] = 'Completed';
      setState(() {});
      await _persist();
      await _chooseManOfTheMatch();
    }
  }

  Future<void> _undo() async {
    if (match['status'] == 'Completed') return;
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
    final second = <String, dynamic>{
      'battingTeamId': current['bowlingTeamId'], 'bowlingTeamId': current['battingTeamId'],
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
    final otherKey = key == 'strikerId' ? 'nonStrikerId' : 'strikerId';
    final otherValue = current[otherKey]?.toString() ?? '';
    final valid = value.isNotEmpty && value != otherValue &&
        squad.any((p) => p['id'].toString() == value);
    final available = squad.where((p) => p['id'].toString() != otherValue).toList();
    return DropdownButtonFormField<String>(
      initialValue: valid ? value : '',
      isExpanded: true,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), isDense: true),
      items: [
        DropdownMenuItem(value: '', child: Text(tr('Select', 'নির্বাচন করুন'))),
        ...available.map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text(p['name'].toString(), overflow: TextOverflow.ellipsis))),
      ],
      onChanged: (v) async {
        final selected = v ?? '';
        if (selected.isNotEmpty && selected == (current[otherKey]?.toString() ?? '')) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('Striker and non-striker must be different players.', 'স্ট্রাইকার ও নন-স্ট্রাইকার অবশ্যই আলাদা খেলোয়াড় হতে হবে।')),
          ));
          return;
        }
        current[key] = selected;
        setState(() {});
        await _persist();
      },
    );
  }

  Widget _scoreButton(String label, VoidCallback action, {Color? color}) =>
    SizedBox(height: 54, child: FilledButton(
      style: FilledButton.styleFrom(backgroundColor: color ?? const Color(0xFF07552D)),
      onPressed: action, child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))));

  Map<String, int> _batterFigures(String playerId) {
    var runs = 0, balls = 0, fours = 0, sixes = 0;
    for (final e in _events()) {
      if ((e['strikerId'] ?? '').toString() != playerId) continue;
      final r = (e['batterRuns'] as num?)?.toInt() ?? 0;
      runs += r;
      if (e['legal'] == true) balls++;
      if (r == 4) fours++;
      if (r == 6) sixes++;
    }
    return {'runs': runs, 'balls': balls, 'fours': fours, 'sixes': sixes};
  }

  Map<String, int> _bowlerFigures(String playerId) {
    var runs = 0, balls = 0, wickets = 0;
    for (final e in _events()) {
      if ((e['bowlerId'] ?? '').toString() != playerId) continue;
      runs += (e['runs'] as num?)?.toInt() ?? 0;
      if (e['legal'] == true) balls++;
      if (e['wicket'] == true && e['bowlerCredited'] == true) wickets++;
    }
    return {'runs': runs, 'balls': balls, 'wickets': wickets};
  }

  String _strikeRate(Map<String, int> figures) {
    final balls = figures['balls'] ?? 0;
    if (balls == 0) return '0.0';
    return ((figures['runs'] ?? 0) * 100 / balls).toStringAsFixed(1);
  }

  Widget _scoreboardPlayerRow(String name, Map<String, int> figures, {bool highlighted = false}) {
    final color = highlighted ? const Color(0xFFB9F6CA) : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        if (highlighted) const Padding(
          padding: EdgeInsets.only(right: 6),
          child: Icon(Icons.circle, size: 7, color: Color(0xFF00E676))),
        Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontWeight: highlighted ? FontWeight.w800 : FontWeight.w500))),
        Text('${figures['runs']}  (${figures['balls']})',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(width: 10),
        SizedBox(width: 43, child: Text(_strikeRate(figures),
          textAlign: TextAlign.end, style: TextStyle(color: Colors.white70, fontSize: 12))),
      ]),
    );
  }

  Widget _compactScoreboard(String battingId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF123D2A), Color(0xFF071A12)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF26734A)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(Icons.circle, size: 7, color: Color(0xFF00E676)),
            const SizedBox(width: 5),
            Text(match['status'] == 'Completed' ? tr('FINAL', 'শেষ') : tr('LIVE', 'লাইভ'),
              style: const TextStyle(color: Color(0xFF9BE7B5), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          ]),
          const SizedBox(height: 3),
          Text(_teamName(battingId), maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text('${_runs()}/${_wickets()}',
              style: const TextStyle(color: Colors.white, fontSize: 42, height: 1, fontWeight: FontWeight.w900))),
        ])),
        const SizedBox(width: 10),
        Container(width: 1, height: 66, color: Colors.white24),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          Text(tr('OVERS', 'ওভার'), style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
          Text('${_oversText()} / ${match['overs'] ?? 10}',
            style: const TextStyle(color: Color(0xFFB9F6CA), fontSize: 19, fontWeight: FontWeight.w900)),
          Text(tr('Run scoring', 'রান যোগ করুন'), style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ]),
      ]),
    );
  }

  Widget _liveScoreboard(String battingId, String bowlingId) {
    final strikerId = current['strikerId']?.toString() ?? '';
    final nonStrikerId = current['nonStrikerId']?.toString() ?? '';
    final bowlerId = current['bowlerId']?.toString() ?? '';
    final striker = _batterFigures(strikerId);
    final nonStriker = _batterFigures(nonStrikerId);
    final bowler = _bowlerFigures(bowlerId);
    final balls = _legalBalls();
    final runRate = balls == 0 ? 0.0 : _runs() * 6 / balls;
    final target = currentIndex == 1 && innings.isNotEmpty
        ? ((innings[0]['runs'] as num?)?.toInt() ?? 0) + 1 : null;
    final remaining = target == null ? null : (target - _runs()).clamp(0, target);
    final ballsLeft = (maxBalls - balls).clamp(0, maxBalls);
    final requiredRate = target == null || ballsLeft == 0
        ? null : (remaining! * 6 / ballsLeft);
    final bowlerName = bowlerId.isEmpty ? tr('Select bowler', 'বোলার নির্বাচন করুন') : _playerName(bowlerId);
    final strikerName = strikerId.isEmpty ? tr('Select striker', 'স্ট্রাইকার নির্বাচন করুন') : _playerName(strikerId);
    final nonStrikerName = nonStrikerId.isEmpty ? tr('Select non-striker', 'নন-স্ট্রাইকার নির্বাচন করুন') : _playerName(nonStrikerId);
    final panel = const Color(0xFF10251D);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF123D2A), Color(0xFF071A12)]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF26734A).withOpacity(.65)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.22), blurRadius: 16, offset: const Offset(0, 7))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.circle, size: 8, color: Color(0xFF00E676)),
          const SizedBox(width: 7),
          Text(match['status'] == 'Completed' ? tr('FINAL SCORE', 'চূড়ান্ত স্কোর') : tr('LIVE SCORE', 'লাইভ স্কোর'),
            style: const TextStyle(color: Color(0xFF9BE7B5), fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 5),
        Text(_teamName(battingId), style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 1),
        FittedBox(fit: BoxFit.scaleDown, child: Text('${_runs()}/${_wickets()}',
          style: const TextStyle(color: Colors.white, fontSize: 56, height: 1.05, fontWeight: FontWeight.w900, letterSpacing: -1.5))),
        Text('${_oversText()} / ${match['overs'] ?? 10} ${tr('OVERS', 'ওভার')}',
          style: const TextStyle(color: Color(0xFFB9F6CA), fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 14),
        Container(height: 1, color: Colors.white.withOpacity(.13)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('BATTER', 'ব্যাটার'), style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.bold)),
            _scoreboardPlayerRow(strikerName, striker, highlighted: true),
            _scoreboardPlayerRow(nonStrikerName, nonStriker),
          ])),
          const SizedBox(width: 10),
          Container(width: 1, height: 74, color: Colors.white.withOpacity(.13)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('BOWLER', 'বোলার'), style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.bold)),
            const SizedBox(height: 9),
            Text(bowlerName, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 5),
            Text('${bowler['balls']! ~/ 6}.${bowler['balls']! % 6}  •  ${bowler['runs']} R',
              style: const TextStyle(color: Color(0xFFB9F6CA), fontSize: 16, fontWeight: FontWeight.bold)),
            Text('${bowler['wickets']} ${tr('WICKETS', 'উইকেট')}',
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ])),
        ]),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(13)),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(children: [
            _scoreMetric(tr('RUN RATE', 'রান রেট'), runRate.toStringAsFixed(2)),
            if (target != null) _scoreMetric(tr('TARGET', 'লক্ষ্য'), target.toString()),
            if (requiredRate != null) _scoreMetric(tr('REQ. RATE', 'প্রয়োজনীয়'), requiredRate.toStringAsFixed(2)),
            _scoreMetric(tr('PARTNERSHIP', 'জুটি'), '${striker['runs']! + nonStriker['runs']!}'),
          ]),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(tr('R  Runs   B  Balls   SR  Strike rate', 'R রান   B বল   SR স্ট্রাইক রেট'),
            style: const TextStyle(color: Colors.white54, fontSize: 9)),
          if (target != null)
            Text(tr('$remaining runs • $ballsLeft balls left', '$remaining রান • $ballsLeft বল বাকি'),
              style: const TextStyle(color: Color(0xFFB9F6CA), fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  Widget _scoreMetric(String label, String value) => Expanded(child: Column(children: [
    Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: .5)),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(color: Color(0xFFB9F6CA), fontSize: 14, fontWeight: FontWeight.w900)),
  ]));

  Widget _detailedInningsCard(int inningsNumber, Map<String, dynamic> inn) {
    final events = (inn['events'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
    final batting = <String, Map<String, int>>{};
    final bowling = <String, Map<String, int>>{};
    var extras = 0, total = 0, wickets = 0, legalBalls = 0;
    final fall = <String>[];
    for (final e in events) {
      final batter = (e['strikerId'] ?? '').toString();
      final bowler = (e['bowlerId'] ?? '').toString();
      final batterRuns = (e['batterRuns'] as num?)?.toInt() ?? 0;
      final runs = (e['runs'] as num?)?.toInt() ?? 0;
      final extraRuns = (e['extras'] as num?)?.toInt() ?? 0;
      final legal = e['legal'] == true;
      total += runs;
      extras += extraRuns;
      if (legal) legalBalls++;
      if (batter.isNotEmpty) {
        final s = batting.putIfAbsent(batter, () => {'runs': 0, 'balls': 0, 'fours': 0, 'sixes': 0});
        s['runs'] = s['runs']! + batterRuns;
        if (legal) s['balls'] = s['balls']! + 1;
        if (batterRuns == 4) s['fours'] = s['fours']! + 1;
        if (batterRuns == 6) s['sixes'] = s['sixes']! + 1;
      }
      if (bowler.isNotEmpty) {
        final s = bowling.putIfAbsent(bowler, () => {'runs': 0, 'balls': 0, 'wickets': 0});
        final conceded = runs - (legal ? extraRuns : 0);
        s['runs'] = s['runs']! + (conceded < 0 ? 0 : conceded);
        if (legal) s['balls'] = s['balls']! + 1;
        if (e['wicket'] == true && e['bowlerCredited'] == true) s['wickets'] = s['wickets']! + 1;
      }
      if (e['wicket'] == true) {
        wickets++;
        final dismissed = (e['dismissedBatterId'] ?? batter).toString();
        final over = '${legalBalls ~/ 6}.${legalBalls % 6}';
        final outName = _playerName(dismissed).isEmpty ? 'Batter' : _playerName(dismissed);
        fall.add('$wickets-$total ($outName, $over ov)');
      }
    }
    final overs = '${legalBalls ~/ 6}.${legalBalls % 6}';
    Widget heading(String value) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 5),
      child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9BE7B5))),
    );
    Widget row(List<String> values, {bool header = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(flex: 4, child: Text(values[0], style: TextStyle(fontSize: 12, fontWeight: header ? FontWeight.bold : FontWeight.normal))),
        ...values.skip(1).map((v) => Expanded(child: Text(v, textAlign: TextAlign.end, style: TextStyle(fontSize: 11, fontWeight: header ? FontWeight.bold : FontWeight.normal)))),
      ]),
    );
    return Card(
      color: const Color(0xFF102019),
      child: ExpansionTile(
        initiallyExpanded: match['status'] == 'Completed',
        title: Text('${tr('Innings', 'ইনিংস')} ${inningsNumber + 1}: ${_teamName((inn['battingTeamId'] ?? '').toString())}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$total/$wickets  ($overs ov)'),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          heading(tr('Batting', 'ব্যাটিং')),
          row([tr('Batter', 'ব্যাটার'), 'R', 'B', '4s', '6s', 'SR'], header: true),
          ...batting.entries.map((entry) {
            final s = entry.value;
            final balls = s['balls']!;
            final sr = balls == 0 ? '0.0' : (s['runs']! * 100 / balls).toStringAsFixed(1);
            final name = _playerName(entry.key);
            return row([name.isEmpty ? tr('Unknown', 'অজানা') : name, '${s['runs']}', '$balls', '${s['fours']}', '${s['sixes']}', sr]);
          }),
          row([tr('Extras', 'অতিরিক্ত'), '$extras', '', '', '', '']),
          row([tr('Total', 'মোট'), '$total/$wickets', overs, '', '', '']),
          heading(tr('Bowling', 'বোলিং')),
          row([tr('Bowler', 'বোলার'), 'O', 'R', 'W', 'Econ'], header: true),
          ...bowling.entries.map((entry) {
            final s = entry.value;
            final balls = s['balls']!;
            final econ = balls == 0 ? '0.00' : (s['runs']! * 6 / balls).toStringAsFixed(2);
            final name = _playerName(entry.key);
            return row([name.isEmpty ? tr('Unknown', 'অজানা') : name, '${balls ~/ 6}.${balls % 6}', '${s['runs']}', '${s['wickets']}', econ]);
          }),
          if (fall.isNotEmpty) ...[
            heading(tr('Fall of wickets', 'উইকেট পতন')),
            Align(alignment: Alignment.centerLeft, child: Text(fall.join('  •  '), style: const TextStyle(fontSize: 12))),
          ],
          if (events.isEmpty) Padding(padding: const EdgeInsets.all(10), child: Text(tr('No ball records available.', 'কোনো বলের রেকর্ড নেই।'))),
        ],
      ),
    );
  }

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
        title: Text(showStats ? tr('Match Statistics', 'ম্যাচ পরিসংখ্যান') : tr('Live Scoring', 'লাইভ স্কোরিং')),
        actions: [
          IconButton(
            onPressed: () => setState(() => showStats = !showStats),
            tooltip: showStats ? tr('Back to scoring', 'স্কোরিংয়ে ফিরুন') : tr('View statistics', 'পরিসংখ্যান দেখুন'),
            icon: Icon(showStats ? Icons.sports_cricket : Icons.analytics_outlined),
          ),
          IconButton(onPressed: _shareScoreboard, tooltip: tr('Share scoreboard', 'স্কোরবোর্ড শেয়ার'), icon: const Icon(Icons.share)),
          if (match['status'] != 'Completed') IconButton(onPressed: events.isEmpty ? null : _undo, tooltip: tr('Undo last ball', 'শেষ বল বাতিল'), icon: const Icon(Icons.undo)),
        ],
      ),
      body: SafeArea(
        child: showStats
          ? ListView(padding: const EdgeInsets.all(14), children: [
              _liveScoreboard(battingId, bowlingId),
              const SizedBox(height: 14),
              Text(tr('Recent Balls', 'সাম্প্রতিক বল'), style: const TextStyle(fontWeight: FontWeight.bold)),
              if (events.isEmpty) Text(tr('No balls recorded yet.', 'এখনো কোনো বল রেকর্ড হয়নি.'), style: TextStyle(color: Colors.grey.shade500))
              else ...events.reversed.take(12).map((e) {
                final batter = _playerName(e['strikerId']?.toString() ?? '');
                final batterRuns = (e['batterRuns'] as num?)?.toInt() ?? 0;
                final label = e['wicket'] == true ? tr('WICKET', 'উইকেট') :
                  (e['extras'] == 1 ? tr('EXTRA', 'অতিরিক্ত') :
                    (batterRuns == 0 ? '• ' + tr('DOT BALL', 'ডট বল') : batterRuns.toString() + ' ' + tr('run(s)', 'রান')));
                return ListTile(dense: true, leading: Icon(e['wicket'] == true ? Icons.sports_cricket : Icons.circle, size: 14,
                  color: e['wicket'] == true ? Colors.redAccent : const Color(0xFF00E676)),
                  title: Text(label), subtitle: Text(batter.isEmpty ? '—' : batter));
              }),
              const SizedBox(height: 12),
              Text(tr('Detailed Scorecard', 'বিস্তারিত স্কোরকার্ড'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ...innings.asMap().entries.map((entry) => _detailedInningsCard(entry.key, entry.value)),
            ])
          : Padding(
              padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
              child: Column(children: [
                _compactScoreboard(battingId),
                if (match['status'] == 'Completed')
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text(tr('Match completed', 'ম্যাচ শেষ হয়েছে'), style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold))),
                if (batting.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: _playerSelect(tr('Striker', 'স্ট্রাইকার'), 'strikerId', batting)),
                    const SizedBox(width: 7),
                    Expanded(child: _playerSelect(tr('Non-striker', 'নন-স্ট্রাইকার'), 'nonStrikerId', batting)),
                  ]),
                ],
                if (bowling.isNotEmpty) Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _playerSelect(tr('Bowler', 'বোলার'), 'bowlerId', bowling),
                ),
                if (batting.isEmpty || bowling.isEmpty)
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text(tr('Add players to both team squads for player-by-player scoring.', 'প্লেয়ারভিত্তিক স্কোরিংয়ের জন্য দুই দলের স্কোয়াডে খেলোয়াড় যোগ করুন।'), style: const TextStyle(fontSize: 11, color: Colors.white70))),
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerLeft, child: Text(tr('Runs', 'রান'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                Expanded(child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4, mainAxisSpacing: 5, crossAxisSpacing: 5,
                  childAspectRatio: 2.0,
                  children: List.generate(7, (n) => _scoreButton(n.toString(), () => _addBall(runs: n, batterRuns: n),
                    color: n == 4 ? Colors.blue.shade800 : (n == 6 ? Colors.purple.shade800 : ((n == 1 || n == 2) ? Colors.teal.shade800 : const Color(0xFF07552D))))),
                )),
                const SizedBox(height: 3),
                Align(alignment: Alignment.centerLeft, child: Text(tr('Extras & Wicket', 'অতিরিক্ত রান ও উইকেট'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                SizedBox(height: 40, child: Row(children: [
                  _compactAction(tr('Wide', 'ওয়াইড'), () => _addBall(runs: 1, extras: 1, legal: false), Colors.orange.shade800),
                  _compactAction(tr('No-ball', 'নো-বল'), () => _addBall(runs: 1, extras: 1, legal: false), Colors.deepOrange.shade800),
                  _compactAction(tr('Bye', 'বাই'), () => _addBall(runs: 1, extras: 1), Colors.indigo.shade700),
                  _compactAction(tr('Leg-bye', 'লেগ-বাই'), () => _addBall(runs: 1, extras: 1), Colors.cyan.shade800),
                  _compactAction(tr('Wicket', 'উইকেট'), _recordWicket, Colors.red.shade800),
                ])),
                if (ended && currentIndex == 0 && match['status'] != 'Completed')
                  SizedBox(height: 38, child: FilledButton.icon(onPressed: _startSecondInnings, icon: const Icon(Icons.swap_horiz, size: 17), label: Text(tr('Start 2nd Innings', '২য় ইনিংস শুরু করুন')))),
                if (match['status'] != 'Completed')
                  SizedBox(height: 38, child: FilledButton.icon(onPressed: _completeMatch, icon: const Icon(Icons.flag, size: 17), label: Text(tr('Complete Match', 'ম্যাচ সম্পন্ন করুন')), style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800))),
              ]),
            ),
      ),
    );
  }

  Widget _compactAction(String label, VoidCallback action, Color color) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox.expand(child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2)),
        onPressed: action,
        child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
      )),
    ),
  );
}
