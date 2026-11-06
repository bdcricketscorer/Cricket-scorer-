import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeamSquadsPage extends StatefulWidget {
  const TeamSquadsPage({super.key, required this.isBangla});
  final bool isBangla;
  @override
  State<TeamSquadsPage> createState() => _TeamSquadsPageState();
}

class _TeamSquadsPageState extends State<TeamSquadsPage> {
  List<Map<String, dynamic>> teams = [];
  List<Map<String, dynamic>> players = [];
  List<Map<String, dynamic>> tournaments = [];
  bool loading = true;
  String search = '';
  String tr(String en, String bn) => widget.isBangla ? bn : en;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> loadedTeams = [];
    final rawTeams = prefs.getString('team_profiles_v1');
    if (rawTeams != null) {
      try {
        loadedTeams = (jsonDecode(rawTeams) as List)
            .map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    } else {
      loadedTeams = (prefs.getStringList('teams') ?? []).map((name) => <String, dynamic>{
        'id': DateTime.now().microsecondsSinceEpoch.toString() + name,
        'name': name, 'shortName': '', 'playerIds': <String>[],
        'captainId': '', 'viceCaptainId': '',
      }).toList();
      if (loadedTeams.isNotEmpty) {
        await prefs.setString('team_profiles_v1', jsonEncode(loadedTeams));
      }
    }
    List<Map<String, dynamic>> loadedPlayers = [];
    final rawPlayers = prefs.getString('player_profiles_v1');
    if (rawPlayers != null) {
      try {
        loadedPlayers = (jsonDecode(rawPlayers) as List)
            .map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }
    List<Map<String, dynamic>> loadedTournaments = [];
    try { loadedTournaments = (jsonDecode(prefs.getString('tournament_profiles_v1') ?? '[]') as List).map((e) => Map<String, dynamic>.from(e)).toList(); } catch (_) {}
    if (!mounted) return;
    setState(() { teams = loadedTeams; players = loadedPlayers; tournaments = loadedTournaments; loading = false; });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('team_profiles_v1', jsonEncode(teams));
    await prefs.setStringList('teams', teams.map((e) => e['name'].toString()).toList());
  }

  Future<void> _teamForm({Map<String, dynamic>? old}) async {
    final name = TextEditingController(text: old?['name']?.toString() ?? '');
    final short = TextEditingController(text: old?['shortName']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<Map<String, String>>(context: context, builder: (ctx) => AlertDialog(
      title: Text(old == null ? tr('Create Team', 'দল তৈরি করুন') : tr('Edit Team', 'দল সম্পাদনা')),
      content: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: name, autofocus: true,
          decoration: InputDecoration(labelText: tr('Team name *', 'দলের নাম *'), border: const OutlineInputBorder()),
          validator: (v) => v == null || v.trim().isEmpty ? tr('Enter team name', 'দলের নাম লিখুন') : null),
        const SizedBox(height: 12),
        TextField(controller: short, decoration: InputDecoration(labelText: tr('Short name (optional)', 'সংক্ষিপ্ত নাম (ঐচ্ছিক)'), border: const OutlineInputBorder())),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel', 'বাতিল'))),
        FilledButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, {'name': name.text.trim(), 'shortName': short.text.trim()}); }, child: Text(tr('Save', 'সংরক্ষণ'))),
      ],
    ));
    name.dispose(); short.dispose();
    if (result == null) return;
    final id = old?['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString();
    final index = teams.indexWhere((t) => t['id'] == id);
    final updated = <String, dynamic>{
      'id': id, 'name': result['name'], 'shortName': result['shortName'],
      'playerIds': List<String>.from(old?['playerIds'] ?? <String>[]),
      'captainId': old?['captainId']?.toString() ?? '',
      'viceCaptainId': old?['viceCaptainId']?.toString() ?? '',
    };
    setState(() { if (index < 0) { teams.add(updated); } else { teams[index] = updated; } });
    await _save();
  }

  bool _conflictsInTournament(String teamId, String playerId) {
    final candidate = players.where((p) => p['id'].toString() == playerId).toList();
    final candidateName = candidate.isEmpty ? '' : candidate.first['name'].toString().trim().toLowerCase();
    for (final tournament in tournaments) {
      final registered = (tournament['teamIds'] as List? ?? []).map((e) => e.toString()).toSet();
      if (!registered.contains(teamId)) continue;
      for (final other in teams) {
        final otherId = other['id'].toString();
        if (otherId == teamId || !registered.contains(otherId)) continue;
        final ids = (other['playerIds'] as List? ?? []).map((e) => e.toString()).toSet();
        if (ids.contains(playerId)) return true;
        if (candidateName.isNotEmpty) {
          for (final otherPlayer in players) {
            if (ids.contains(otherPlayer['id'].toString()) && otherPlayer['name'].toString().trim().toLowerCase() == candidateName) return true;
          }
        }
      }
    }
    return false;
  }

  Future<void> _manageSquad(Map<String, dynamic> team) async {
    final selected = <String>{...List<String>.from(team['playerIds'] ?? <String>[])};
    String captain = team['captainId']?.toString() ?? '';
    String vice = team['viceCaptainId']?.toString() ?? '';
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) =>
      StatefulBuilder(builder: (ctx, refresh) {
        final squad = players.where((p) => selected.contains(p['id'].toString())).toList();
        return AlertDialog(
          title: Text(tr('Manage Squad', 'স্কোয়াড সাজান')),
          content: SizedBox(width: 440, height: 440, child: Column(children: [
            Text(tr('Select players for this team', 'এই দলের খেলোয়াড় নির্বাচন করুন')),
            const SizedBox(height: 8),
            Expanded(child: players.isEmpty
              ? Center(child: Text(tr('Add player profiles first.', 'আগে প্লেয়ার প্রোফাইল যোগ করুন।')))
              : ListView(children: players.map((p) {
                final id = p['id'].toString();
                return CheckboxListTile(dense: true, value: selected.contains(id),
                  title: Text(p['name'].toString()), subtitle: Text(p['role']?.toString() ?? ''),
                  onChanged: (v) {
                    if (v == true && _conflictsInTournament(team['id'].toString(), id)) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('This player is already registered with another team in the same tournament.', 'এই খেলোয়াড় একই টুর্নামেন্টের অন্য দলে নিবন্ধিত আছে।'))));
                      return;
                    }
                    refresh(() {
                    if (v == true) { selected.add(id); } else {
                      selected.remove(id);
                      if (captain == id) captain = '';
                      if (vice == id) vice = '';
                    }
                  });
                  });
              }).toList())),
            const Divider(),
            DropdownButtonFormField<String>(
              initialValue: selected.contains(captain) ? captain : '',
              decoration: InputDecoration(labelText: tr('Captain', 'অধিনায়ক')),
              items: [DropdownMenuItem(value: '', child: Text(tr('Not assigned', 'নির্ধারিত নয়'))),
                ...squad.map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text(p['name'].toString())))],
              onChanged: (v) => refresh(() => captain = v ?? '')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selected.contains(vice) ? vice : '',
              decoration: InputDecoration(labelText: tr('Vice-captain', 'সহ-অধিনায়ক')),
              items: [DropdownMenuItem(value: '', child: Text(tr('Not assigned', 'নির্ধারিত নয়'))),
                ...squad.map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text(p['name'].toString())))],
              onChanged: (v) => refresh(() => vice = v ?? '')),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel', 'বাতিল'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, {
              'playerIds': selected.toList(), 'captainId': captain, 'viceCaptainId': vice,
            }), child: Text(tr('Save Squad', 'স্কোয়াড সংরক্ষণ'))),
          ],
        );
      }));
    if (result == null) return;
    setState(() {
      final i = teams.indexWhere((t) => t['id'] == team['id']);
      if (i >= 0) {
        teams[i]['playerIds'] = result['playerIds'];
        teams[i]['captainId'] = result['captainId'];
        teams[i]['viceCaptainId'] = result['viceCaptainId'];
      }
    });
    await _save();
  }

  Future<void> _delete(Map<String, dynamic> team) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(tr('Delete team?', 'দল মুছবেন?')),
      content: Text(team['name'].toString()),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancel', 'বাতিল'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Delete', 'মুছুন'))),
      ],
    ));
    if (yes != true) return;
    setState(() => teams.removeWhere((t) => t['id'] == team['id']));
    await _save();
  }

  String _playerName(String id) {
    for (final p in players) {
      if (p['id'].toString() == id) return p['name'].toString();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final shown = teams.where((t) => t['name'].toString().toLowerCase().contains(search.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Teams & Squads', 'দল ও স্কোয়াড'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _teamForm(), icon: const Icon(Icons.add),
        label: Text(tr('Create Team', 'দল তৈরি করুন'))),
      body: loading ? const Center(child: CircularProgressIndicator()) : Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(
          onChanged: (v) => setState(() => search = v),
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search),
            hintText: tr('Search teams', 'দল খুঁজুন'), border: const OutlineInputBorder()))),
        Expanded(child: shown.isEmpty
          ? Center(child: Text(tr('No teams yet. Create your first team.', 'এখনো কোনো দল নেই। প্রথম দল তৈরি করুন।')))
          : ListView.builder(padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
            itemCount: shown.length, itemBuilder: (_, i) {
              final team = shown[i];
              final ids = List<String>.from(team['playerIds'] ?? <String>[]);
              final cap = _playerName(team['captainId']?.toString() ?? '');
              return Card(color: const Color(0xFF102019), child: ExpansionTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFF07552D),
                  child: Icon(Icons.groups, color: Color(0xFFB9F6CA))),
                title: Text(team['name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${ids.length} ${tr('players', 'জন খেলোয়াড়')}${cap.isEmpty ? '' : ' • ${tr('Captain', 'অধিনায়ক')}: $cap'}'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  if (ids.isEmpty) Align(alignment: Alignment.centerLeft,
                    child: Text(tr('No players in this squad yet.', 'এই স্কোয়াডে এখনো খেলোয়াড় নেই।')))
                  else ...ids.map((id) => ListTile(dense: true,
                    leading: const Icon(Icons.person_outline),
                    title: Text(_playerName(id).isEmpty ? tr('Player unavailable', 'প্লেয়ার পাওয়া যায়নি') : _playerName(id)),
                    subtitle: id == team['captainId'] ? Text(tr('Captain', 'অধিনায়ক')) :
                      (id == team['viceCaptainId'] ? Text(tr('Vice-captain', 'সহ-অধিনায়ক')) : null))),
                  Wrap(alignment: WrapAlignment.end, children: [
                    TextButton.icon(onPressed: () => _manageSquad(team),
                      icon: const Icon(Icons.playlist_add), label: Text(tr('Manage Squad', 'স্কোয়াড সাজান'))),
                    IconButton(onPressed: () => _teamForm(old: team), icon: const Icon(Icons.edit)),
                    IconButton(onPressed: () => _delete(team),
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
                  ]),
                ],
              ));
            })),
      ]),
    );
  }
}
