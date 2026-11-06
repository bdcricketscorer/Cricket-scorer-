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
    await Navigator.push(context, MaterialPageRoute(builder: (_) => MatchCenterPage(
      isBangla: widget.isBangla, tournamentId: tournament['id'].toString(),
    )));
    await _load();
  }

  Future<void> _delete(Map<String, dynamic> tournament) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(tr('Delete tournament?', 'টুর্নামেন্ট মুছবেন?')),
      content: Text(tr('The tournament will be removed. Its saved fixtures are not deleted.', 'টুর্নামেন্টটি মুছে যাবে। সংরক্ষিত ফিক্সচার মুছবে না।')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancel', 'বাতিল'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Delete', 'মুছুন'))),
      ],
    ));
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
              title: Text(t['name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  IconButton(onPressed: () => _delete(t), icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
                ]),
              ],
            ));
          })),
      ]),
    );
  }
}
