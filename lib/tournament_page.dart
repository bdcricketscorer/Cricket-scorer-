import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'match_scoring_page.dart';

class TournamentPage extends StatefulWidget {
  const TournamentPage({super.key, required this.isBangla});
  final bool isBangla;
  @override
  State<TournamentPage> createState() => _TournamentPageState();
}

class _TournamentPageState extends State<TournamentPage> {
  List<Map<String, dynamic>> tournaments = [];
  List<Map<String, dynamic>> teams = [];
  bool loading = true;
  String search = '';
  String tr(String en, String bn) => widget.isBangla ? bn : en;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> ts = [];
    final raw = prefs.getString('tournament_profiles_v1');
    if (raw != null) {
      try { ts = (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)).toList(); } catch (_) {}
    } else {
      ts = (prefs.getStringList('tournaments') ?? []).map((name) => <String, dynamic>{
        'id': DateTime.now().microsecondsSinceEpoch.toString() + name,
        'name': name, 'overs': 10, 'format': 'League', 'groupCount': 2,
        'teamIds': <String>[], 'fixtureGenerated': false,
      }).toList();
      if (ts.isNotEmpty) await prefs.setString('tournament_profiles_v1', jsonEncode(ts));
    }
    List<Map<String, dynamic>> loadedTeams = [];
    final teamRaw = prefs.getString('team_profiles_v1');
    if (teamRaw != null) {
      try { loadedTeams = (jsonDecode(teamRaw) as List).map((e) => Map<String, dynamic>.from(e)).toList(); } catch (_) {}
    }
    if (mounted) setState(() { tournaments = ts; teams = loadedTeams; loading = false; });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tournament_profiles_v1', jsonEncode(tournaments));
    await prefs.setStringList('tournaments', tournaments.map((e) => e['name'].toString()).toList());
  }

  String _teamName(String id) {
    for (final t in teams) { if (t['id'].toString() == id) return t['name'].toString(); }
    return tr('Unknown team', 'অজানা দল');
  }

  Future<void> _form({Map<String, dynamic>? old}) async {
    final name = TextEditingController(text: old?['name']?.toString() ?? '');
    final overs = TextEditingController(text: (old?['overs'] ?? 10).toString());
    String format = old?['format']?.toString() ?? 'League';
    int groupCount = (old?['groupCount'] as num?)?.toInt() ?? 2;
    final selected = <String>{...List<String>.from(old?['teamIds'] ?? <String>[])};
    final key = GlobalKey<FormState>();
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) =>
      StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
        title: Text(old == null ? tr('Create Tournament', 'টুর্নামেন্ট তৈরি করুন') : tr('Edit Tournament', 'টুর্নামেন্ট সম্পাদনা')),
        content: SizedBox(width: 440, child: Form(key: key, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: name, decoration: InputDecoration(labelText: tr('Tournament name *', 'টুর্নামেন্টের নাম *'), border: const OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? tr('Enter a name', 'নাম লিখুন') : null),
            const SizedBox(height: 12),
            TextFormField(controller: overs, keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr('Overs per innings', 'প্রতি ইনিংসে ওভার'), border: const OutlineInputBorder()),
              validator: (v) { final n = int.tryParse(v ?? ''); return n == null || n < 1 || n > 50 ? tr('Enter 1–50 overs', '১–৫০ ওভার লিখুন') : null; }),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(value: format,
              decoration: InputDecoration(labelText: tr('Tournament format', 'টুর্নামেন্ট ফরম্যাট'), border: const OutlineInputBorder()),
              items: [
                DropdownMenuItem(value: 'League', child: Text(tr('League (Round Robin)', 'লিগ (রাউন্ড রবিন)'))),
                DropdownMenuItem(value: 'Group + Knockout', child: Text(tr('Group + Knockout', 'গ্রুপ + নকআউট'))),
                DropdownMenuItem(value: 'Knockout', child: Text(tr('Knockout', 'নকআউট'))),
              ], onChanged: (v) => refresh(() => format = v ?? 'League')),
            if (format == 'Group + Knockout') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(value: groupCount.clamp(2, 8),
                decoration: InputDecoration(labelText: tr('Number of groups', 'গ্রুপ সংখ্যা'), border: const OutlineInputBorder()),
                items: List.generate(7, (i) => i + 2).map((n) => DropdownMenuItem(value: n, child: Text(n.toString()))).toList(),
                onChanged: (v) => refresh(() => groupCount = v ?? 2)),
            ],
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerLeft, child: Text(tr('Register teams', 'দল নিবন্ধন করুন'), style: const TextStyle(fontWeight: FontWeight.bold))),
            if (teams.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(tr('Create teams in Teams & Squads first.', 'আগে Teams & Squads থেকে দল তৈরি করুন।')))
            else ...teams.map((team) {
              final id = team['id'].toString();
              return CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero,
                value: selected.contains(id), title: Text(team['name'].toString()),
                onChanged: (v) => refresh(() { if (v == true) { selected.add(id); } else { selected.remove(id); } }));
            }),
            Text(tr('Select at least 2 teams to generate fixtures.', 'ফিক্সচার তৈরির জন্য কমপক্ষে ২টি দল নির্বাচন করুন।'), style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          ],
        )))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel', 'বাতিল'))),
          FilledButton(onPressed: () {
            if (!key.currentState!.validate()) return;
            Navigator.pop(ctx, {'name': name.text.trim(), 'overs': int.parse(overs.text.trim()),
              'format': format, 'groupCount': groupCount, 'teamIds': selected.toList()});
          }, child: Text(tr('Save', 'সংরক্ষণ'))),
        ],
      )));
    name.dispose(); overs.dispose();
    if (result == null) return;
    final registeredPlayers = <String, String>{};
    for (final teamId in (result['teamIds'] as List).map((e) => e.toString())) {
      final team = teams.where((x) => x['id'].toString() == teamId).toList();
      if (team.isEmpty) continue;
      for (final playerId in (team.first['playerIds'] as List? ?? []).map((e) => e.toString())) {
        if (registeredPlayers.containsKey(playerId)) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('A player is already included in another selected team. Remove the duplicate before saving.', 'একজন খেলোয়াড় নির্বাচিত অন্য একটি দলের স্কোয়াডেও আছে। সংরক্ষণের আগে ডুপ্লিকেট সরান।')),
          ));
          return;
        }
        registeredPlayers[playerId] = teamId;
      }
    }
    final id = old?['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString();
    final index = tournaments.indexWhere((t) => t['id'] == id);
    final updated = <String, dynamic>{'id': id, ...result, 'fixtureGenerated': old?['fixtureGenerated'] == true};
    setState(() { if (index < 0) { tournaments.add(updated); } else { tournaments[index] = updated; } });
    await _save();
  }

  List<List<String>> _roundRobin(List<String> ids) {
    final list = [...ids];
    if (list.length.isOdd) list.add('');
    final rounds = <List<String>>[];
    final n = list.length;
    for (int r = 0; r < n - 1; r++) {
      for (int i = 0; i < n ~/ 2; i++) {
        final a = list[i], b = list[n - 1 - i];
        if (a.isNotEmpty && b.isNotEmpty) rounds.add([a, b]);
      }
      final last = list.removeLast();
      list.insert(1, last);
    }
    return rounds;
  }

  Future<void> _generate(Map<String, dynamic> tournament) async {
    final ids = List<String>.from(tournament['teamIds'] ?? <String>[]);
    if (ids.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Register at least 2 teams first.', 'আগে কমপক্ষে ২টি দল নিবন্ধন করুন।'))));
      return;
    }
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(tr('Generate fixtures?', 'ফিক্সচার তৈরি করবেন?')),
      content: Text(tr('Existing fixtures for this tournament will be replaced.', 'এই টুর্নামেন্টের আগের ফিক্সচার প্রতিস্থাপিত হবে।')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancel', 'বাতিল'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Generate', 'তৈরি করুন'))),
      ],
    ));
    if (yes != true) return;
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> matches = [];
    final raw = prefs.getString('tournament_fixtures_v1');
    if (raw != null) { try { matches = (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)).toList(); } catch (_) {} }
    final tid = tournament['id'].toString();
    matches.removeWhere((m) => m['tournamentId'] == tid);
    final overs = (tournament['overs'] as num?)?.toInt() ?? 10;
    final format = tournament['format']?.toString() ?? 'League';
    void addMatch(String a, String b, String stage) {
      matches.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString() + matches.length.toString(),
        'tournamentId': tid, 'tournament': tournament['name'],
        'teamAId': a, 'teamBId': b, 'teamA': _teamName(a), 'teamB': _teamName(b),
        'overs': overs, 'stage': stage, 'status': 'Scheduled',
        'runsA': 0, 'runsB': 0, 'wicketsA': 0, 'wicketsB': 0,
      });
    }
    if (format == 'League') {
      for (final pair in _roundRobin(ids)) { addMatch(pair[0], pair[1], 'League'); }
    } else if (format == 'Group + Knockout') {
      final count = (tournament['groupCount'] as num?)?.toInt() ?? 2;
      final groups = List.generate(count, (_) => <String>[]);
      for (int i = 0; i < ids.length; i++) { groups[i % count].add(ids[i]); }
      for (int g = 0; g < groups.length; g++) {
        for (final pair in _roundRobin(groups[g])) { addMatch(pair[0], pair[1], 'Group ' + String.fromCharCode(65 + g)); }
      }
    } else {
      for (int i = 0; i + 1 < ids.length; i += 2) { addMatch(ids[i], ids[i + 1], 'Knockout - Round 1'); }
      if (ids.length.isOdd) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('One team receives a bye in the first round.', 'প্রথম রাউন্ডে একটি দল বাই পাবে।'))));
      }
    }
    await prefs.setString('tournament_fixtures_v1', jsonEncode(matches));
    final i = tournaments.indexWhere((t) => t['id'] == tid);
    if (i >= 0) { tournaments[i]['fixtureGenerated'] = true; await _save(); }
    if (!mounted) return;
    final count = matches.where((m) => m['tournamentId'] == tid).length;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(count.toString() + ' ' + tr('fixtures generated', 'টি ফিক্সচার তৈরি হয়েছে'))));
    setState(() {});
  }

  Future<void> _openTournamentMatches(Map<String, dynamic> tournament) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentDetailsPage(
      tournament: Map<String, dynamic>.from(tournament),
      isBangla: widget.isBangla,
      teams: teams,
    )));
    await _load();
  }

  Future<void> _delete(Map<String, dynamic> tournament) async {
    final confirmName = TextEditingController();
    final name = tournament['name'].toString();
    final yes = await showDialog<bool>(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      title: Text(tr('Delete tournament?', 'টুর্নামেন্ট মুছবেন?')),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('This action cannot be undone. To confirm, type the tournament name exactly:', 'এই কাজটি আর ফিরিয়ে আনা যাবে না। নিশ্চিত করতে টুর্নামেন্টের নাম হুবহু লিখুন:')),
        const SizedBox(height: 12),
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
        const SizedBox(height: 8),
        TextField(controller: confirmName, autofocus: true, decoration: InputDecoration(labelText: tr('Tournament name', 'টুর্নামেন্টের নাম'))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancel', 'বাতিল'))),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, confirmName.text.trim() == name),
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
          child: Text(tr('Delete permanently', 'স্থায়ীভাবে মুছুন')),
        ),
      ],
    ));
    confirmName.dispose();
    if (yes != true) return;
    setState(() => tournaments.removeWhere((t) => t['id'] == tournament['id']));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final shown = tournaments.where((t) => t['name'].toString().toLowerCase().contains(search.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Tournament Management', 'টুর্নামেন্ট ব্যবস্থাপনা'))),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _form(),
        icon: const Icon(Icons.add), label: Text(tr('Create Tournament', 'টুর্নামেন্ট তৈরি করুন'))),
      body: loading ? const Center(child: CircularProgressIndicator()) : Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(onChanged: (v) => setState(() => search = v),
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: tr('Search tournaments', 'টুর্নামেন্ট খুঁজুন'), border: const OutlineInputBorder()))),
        Expanded(child: shown.isEmpty
          ? Center(child: Text(tr('No tournaments yet. Create your first tournament.', 'এখনো কোনো টুর্নামেন্ট নেই। প্রথম টুর্নামেন্ট তৈরি করুন।')))
          : ListView.builder(padding: const EdgeInsets.fromLTRB(12, 0, 12, 88), itemCount: shown.length, itemBuilder: (_, i) {
            final t = shown[i];
            final ids = List<String>.from(t['teamIds'] ?? <String>[]);
            return Card(color: const Color(0xFF102019), child: ExpansionTile(
              leading: const CircleAvatar(child: Icon(Icons.emoji_events, color: Color(0xFF00E676))),
              title: InkWell(onTap: () => _openTournamentMatches(t), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(t['name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)))),
              subtitle: Text(t['format'].toString() + ' • ' + t['overs'].toString() + ' ' + tr('overs', 'ওভার') + ' • ' + ids.length.toString() + ' ' + tr('teams', 'দল')),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                Align(alignment: Alignment.centerLeft, child: Text(ids.isEmpty ? tr('No teams registered', 'কোনো দল নিবন্ধিত নেই') : ids.map(_teamName).join(', '))),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: FilledButton.icon(
                  onPressed: () => _openTournamentMatches(t),
                  icon: const Icon(Icons.calendar_month),
                  label: Text(tr('View Match Schedule & Live Scoring', 'ম্যাচ শিডিউল ও লাইভ স্কোর দেখুন')),
                )),
                if (t['fixtureGenerated'] == true) Align(alignment: Alignment.centerLeft, child: Padding(
                  padding: const EdgeInsets.only(top: 6), child: Text(tr('Fixtures generated', 'ফিক্সচার তৈরি হয়েছে'), style: const TextStyle(color: Color(0xFF00E676))))),
                Wrap(alignment: WrapAlignment.end, children: [
                  TextButton.icon(onPressed: () => _generate(t), icon: const Icon(Icons.event_note), label: Text(tr('Generate Fixtures', 'ফিক্সচার তৈরি'))),
                  IconButton(onPressed: () => _form(old: t), icon: const Icon(Icons.edit)),
                  PopupMenuButton<String>(
                    tooltip: tr('More options', 'আরও অপশন'),
                    onSelected: (value) { if (value == 'delete') _delete(t); },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'delete', child: ListTile(dense: true, leading: const Icon(Icons.delete_outline, color: Colors.redAccent), title: Text(tr('Delete tournament', 'টুর্নামেন্ট মুছুন')))),
                    ],
                  ),
                ]),
              ],
            ));
          })),
      ]),
    );
  }
}


class TournamentDetailsPage extends StatefulWidget {
  const TournamentDetailsPage({super.key, required this.tournament, required this.isBangla, required this.teams});
  final Map<String, dynamic> tournament;
  final bool isBangla;
  final List<Map<String, dynamic>> teams;
  @override
  State<TournamentDetailsPage> createState() => _TournamentDetailsPageState();
}

class _TournamentDetailsPageState extends State<TournamentDetailsPage> with SingleTickerProviderStateMixin {
  late final TabController tabs = TabController(length: 2, vsync: this);
  List<Map<String, dynamic>> fixtures = [];
  bool loading = true;
  String tr(String en, String bn) => widget.isBangla ? bn : en;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> data = [];
    try {
      data = (jsonDecode(prefs.getString('tournament_fixtures_v1') ?? '[]') as List)
        .map((e) => Map<String, dynamic>.from(e))
        .where((m) => m['tournamentId']?.toString() == widget.tournament['id'].toString())
        .toList();
    } catch (_) {}
    if (mounted) setState(() { fixtures = data; loading = false; });
  }

  String _teamName(String id) {
    final found = widget.teams.where((t) => t['id'].toString() == id).toList();
    return found.isEmpty ? tr('Unknown team', 'অজানা দল') : found.first['name'].toString();
  }

  List<Map<String, dynamic>> _pointsRows() {
    final ids = (widget.tournament['teamIds'] as List? ?? []).map((e) => e.toString()).toList();
    final rows = <String, Map<String, dynamic>>{};
    for (final id in ids) {
      rows[id] = {'team': _teamName(id), 'played': 0, 'won': 0, 'lost': 0, 'tied': 0, 'points': 0, 'rf': 0, 'bf': 0, 'ra': 0, 'ba': 0};
    }
    for (final m in fixtures.where((m) => m['status'] == 'Completed')) {
      final inns = (m['innings'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
      if (inns.length < 2) continue;
      final aId = inns[0]['battingTeamId']?.toString() ?? '';
      final bId = inns[1]['battingTeamId']?.toString() ?? '';
      if (!rows.containsKey(aId) || !rows.containsKey(bId)) continue;
      int runs(Map<String, dynamic> inn) {
        final ev = inn['events'] as List? ?? [];
        return ev.isEmpty ? (inn['runs'] as num? ?? 0).toInt() : ev.fold<int>(0, (s, e) => s + (((e as Map)['runs'] as num?)?.toInt() ?? 0));
      }
      int balls(Map<String, dynamic> inn) => (inn['events'] as List? ?? []).where((e) => (e as Map)['legal'] == true).length;
      int wickets(Map<String, dynamic> inn) => (inn['wickets'] as num? ?? 0).toInt();
      final quota = ((m['overs'] as num?)?.toInt() ?? 10) * 6;
      final ar = runs(inns[0]), br = runs(inns[1]);
      final ab = wickets(inns[0]) >= 10 ? quota : balls(inns[0]);
      final bb = wickets(inns[1]) >= 10 ? quota : balls(inns[1]);
      final a = rows[aId]!, b = rows[bId]!;
      a['played'] = (a['played'] as int) + 1; b['played'] = (b['played'] as int) + 1;
      a['rf'] = (a['rf'] as int) + ar; a['bf'] = (a['bf'] as int) + ab; a['ra'] = (a['ra'] as int) + br; a['ba'] = (a['ba'] as int) + bb;
      b['rf'] = (b['rf'] as int) + br; b['bf'] = (b['bf'] as int) + bb; b['ra'] = (b['ra'] as int) + ar; b['ba'] = (b['ba'] as int) + ab;
      if (ar > br) { a['won'] = (a['won'] as int) + 1; a['points'] = (a['points'] as int) + 2; b['lost'] = (b['lost'] as int) + 1; }
      else if (br > ar) { b['won'] = (b['won'] as int) + 1; b['points'] = (b['points'] as int) + 2; a['lost'] = (a['lost'] as int) + 1; }
      else { a['tied'] = (a['tied'] as int) + 1; b['tied'] = (b['tied'] as int) + 1; a['points'] = (a['points'] as int) + 1; b['points'] = (b['points'] as int) + 1; }
    }
    final result = rows.values.toList();
    for (final r in result) {
      final bf = r['bf'] as int, ba = r['ba'] as int;
      r['nrr'] = bf == 0 || ba == 0 ? 0.0 : (r['rf'] as int) * 6 / bf - (r['ra'] as int) * 6 / ba;
    }
    result.sort((a, b) {
      final p = (b['points'] as int).compareTo(a['points'] as int);
      return p != 0 ? p : (b['nrr'] as double).compareTo(a['nrr'] as double);
    });
    return result;
  }

  Widget _overview() {
    final ids = (widget.tournament['teamIds'] as List? ?? []).map((e) => e.toString()).toList();
    final completed = fixtures.where((m) => m['status'] == 'Completed').length;
    return ListView(padding: const EdgeInsets.all(14), children: [
      Card(color: const Color(0xFF102019), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.tournament['name'].toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(tr('Format: ', 'ফরম্যাট: ') + (widget.tournament['format'] ?? 'League').toString()),
        Text(tr('Overs per innings: ', 'প্রতি ইনিংসে ওভার: ') + (widget.tournament['overs'] ?? 10).toString()),
        Text(tr('Registered teams: ', 'নিবন্ধিত দল: ') + ids.length.toString()),
        if (widget.tournament['format'] == 'Group + Knockout')
          Text(tr('Groups: ', 'গ্রুপ: ') + (widget.tournament['groupCount'] ?? 2).toString()),
        Text(tr('Fixtures: ', 'ম্যাচ: ') + fixtures.length.toString() + ' • ' + tr('Completed: ', 'শেষ: ') + completed.toString()),
      ]))),
      Text(tr('Registered Teams', 'নিবন্ধিত দল'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      ...ids.map((id) => Card(color: const Color(0xFF102019), child: ListTile(leading: const Icon(Icons.groups, color: Color(0xFF00E676)), title: Text(_teamName(id))))),
      const SizedBox(height: 8),
      Text(tr('Match Schedule', 'ম্যাচ সূচি'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      if (fixtures.isEmpty) Text(tr('No fixtures generated yet.', 'এখনো ফিক্সচার তৈরি হয়নি।')),
      ...fixtures.map((m) {
        final inns = m['innings'] as List? ?? [];
        final score = inns.isEmpty ? tr('Not started', 'শুরু হয়নি') : inns.map((raw) {
          final inn = Map<String, dynamic>.from(raw);
          return inn['runs'].toString() + '/' + inn['wickets'].toString();
        }).join(' - ');
        return Card(color: const Color(0xFF102019), child: ListTile(
          leading: const Icon(Icons.sports_cricket, color: Color(0xFF00E676)),
          title: Text(_teamName(m['teamAId'].toString()) + ' vs ' + _teamName(m['teamBId'].toString())),
          subtitle: Text((m['stage'] ?? 'League').toString() + ' • ' + score + ' • ' + (m['status'] ?? 'Scheduled').toString() +
            ((m['manOfTheMatch'] ?? '').toString().isEmpty ? '' : '\\nMOM: ' + m['manOfTheMatch'].toString())),
        ));
      }),
      const SizedBox(height: 10),
      FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchCenterPage(
        isBangla: widget.isBangla, tournamentId: widget.tournament['id'].toString(),
      ))), icon: const Icon(Icons.calendar_month), label: Text(tr('Open Match Schedule & Live Scoring', 'ম্যাচ সূচি ও লাইভ স্কোরিং খুলুন'))),
    ]);
  }

  Widget _pointsTable() {
    final rows = _pointsRows();
    if (rows.isEmpty) return Center(child: Text(tr('No teams registered.', 'কোনো দল নিবন্ধিত নেই।')));
    return ListView(padding: const EdgeInsets.all(12), children: [
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: [
        DataColumn(label: Text(tr('Team', 'দল'))), DataColumn(label: Text(tr('P', 'ম্যাচ'))),
        DataColumn(label: Text(tr('W', 'জয়'))), DataColumn(label: Text(tr('L', 'হার'))),
        DataColumn(label: Text(tr('Pts', 'পয়েন্ট'))), DataColumn(label: Text('NRR')),
      ], rows: rows.map((r) => DataRow(cells: [
        DataCell(Text(r['team'].toString())), DataCell(Text(r['played'].toString())),
        DataCell(Text(r['won'].toString())), DataCell(Text(r['lost'].toString())),
        DataCell(Text(r['points'].toString())), DataCell(Text((r['nrr'] as double).toStringAsFixed(3))),
      ])).toList())),
      const SizedBox(height: 8),
      Text(tr('Points: 2 for a win, 1 for a tie.', 'জয়ে ২ পয়েন্ট, টাই হলে ১ পয়েন্ট।'), style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.tournament['name'].toString()), bottom: TabBar(controller: tabs, tabs: [
      Tab(text: tr('Overview & Fixtures', 'বিস্তারিত ও ম্যাচ সূচি')),
      Tab(text: tr('Points Table', 'পয়েন্ট টেবিল')),
    ])),
    body: loading ? const Center(child: CircularProgressIndicator()) : TabBarView(controller: tabs, children: [_overview(), _pointsTable()]),
  );
}
