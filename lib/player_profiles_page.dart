import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlayerProfilesPage extends StatefulWidget {
  const PlayerProfilesPage({super.key, required this.isBangla});
  final bool isBangla;
  @override
  State<PlayerProfilesPage> createState() => _PlayerProfilesPageState();
}

class _PlayerProfilesPageState extends State<PlayerProfilesPage> {
  List<Map<String, dynamic>> players = [];
  bool loading = true;
  String search = '';
  String tr(String en, String bn) => widget.isBangla ? bn : en;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('player_profiles_v1');
    List<Map<String, dynamic>> data = [];
    if (raw != null) {
      try { data = (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)).toList(); } catch (_) {}
    } else {
      data = (prefs.getStringList('players') ?? []).map((n) => <String, dynamic>{
        'id': DateTime.now().microsecondsSinceEpoch.toString() + n,
        'name': n, 'jersey': '', 'role': 'All-rounder', 'team': '',
        'batting': '', 'bowling': '', 'matches': 0, 'runs': 0, 'wickets': 0,
      }).toList();
      if (data.isNotEmpty) await prefs.setString('player_profiles_v1', jsonEncode(data));
    }
    if (mounted) setState(() { players = data; loading = false; });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('player_profiles_v1', jsonEncode(players));
  }

  Future<void> _form({Map<String, dynamic>? old}) async {
    final fields = <String, TextEditingController>{
      'name': TextEditingController(text: old?['name']?.toString() ?? ''),
      'jersey': TextEditingController(text: old?['jersey']?.toString() ?? ''),
      'team': TextEditingController(text: old?['team']?.toString() ?? ''),
      'batting': TextEditingController(text: old?['batting']?.toString() ?? ''),
      'bowling': TextEditingController(text: old?['bowling']?.toString() ?? ''),
      'matches': TextEditingController(text: (old?['matches'] ?? 0).toString()),
      'runs': TextEditingController(text: (old?['runs'] ?? 0).toString()),
      'wickets': TextEditingController(text: (old?['wickets'] ?? 0).toString()),
    };
    String role = old?['role']?.toString() ?? 'All-rounder';
    final key = GlobalKey<FormState>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
        title: Text(old == null ? tr('Add Player Profile', 'প্লেয়ার যোগ করুন') : tr('Edit Player Profile', 'প্রোফাইল সম্পাদনা')),
        content: SizedBox(width: 420, child: Form(key: key, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _input(fields['name']!, tr('Player name *', 'প্লেয়ারের নাম *'), required: true),
            _input(fields['jersey']!, tr('Jersey number', 'জার্সি নম্বর'), number: true),
            DropdownButtonFormField<String>(
              value: role,
              decoration: InputDecoration(labelText: tr('Player role', 'প্লেয়ারের ভূমিকা'), border: const OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Batsman', child: Text('Batsman')),
                DropdownMenuItem(value: 'Bowler', child: Text('Bowler')),
                DropdownMenuItem(value: 'All-rounder', child: Text('All-rounder')),
                DropdownMenuItem(value: 'Wicketkeeper', child: Text('Wicketkeeper')),
              ],
              onChanged: (v) => refresh(() => role = v ?? 'All-rounder'),
            ),
            _input(fields['team']!, tr('Team / Club', 'দল / ক্লাব')),
            _input(fields['batting']!, tr('Batting style', 'ব্যাটিং স্টাইল'), hint: 'Right-hand / Left-hand'),
            _input(fields['bowling']!, tr('Bowling style', 'বোলিং স্টাইল'), hint: 'Fast / Spin'),
            const Divider(height: 24),
            Align(alignment: Alignment.centerLeft, child: Text(tr('Career statistics', 'ক্যারিয়ার পরিসংখ্যান'), style: const TextStyle(fontWeight: FontWeight.bold))),
            _input(fields['matches']!, tr('Matches', 'ম্যাচ'), number: true),
            _input(fields['runs']!, tr('Runs', 'রান'), number: true),
            _input(fields['wickets']!, tr('Wickets', 'উইকেট'), number: true),
            const SizedBox(height: 8),
            Text(tr('Player photo upload is not available.', 'প্লেয়ারের ছবি আপলোডের অপশন নেই।'), style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        )))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel', 'বাতিল'))),
          FilledButton(onPressed: () {
            if (!key.currentState!.validate()) return;
            int n(String k) => int.tryParse(fields[k]!.text.trim()) ?? 0;
            Navigator.pop(ctx, <String, dynamic>{
              'id': old?['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
              'name': fields['name']!.text.trim(), 'jersey': fields['jersey']!.text.trim(),
              'role': role, 'team': fields['team']!.text.trim(),
              'batting': fields['batting']!.text.trim(), 'bowling': fields['bowling']!.text.trim(),
              'matches': n('matches'), 'runs': n('runs'), 'wickets': n('wickets'),
            });
          }, child: Text(tr('Save', 'সংরক্ষণ'))),
        ],
      )),
    );
    for (final c in fields.values) { c.dispose(); }
    if (result == null) return;
    setState(() {
      final i = players.indexWhere((p) => p['id'] == result['id']);
      if (i < 0) { players.add(result); } else { players[i] = result; }
    });
    await _save();
  }

  Widget _input(TextEditingController c, String label, {bool number = false, bool required = false, String? hint}) =>
    Padding(padding: const EdgeInsets.only(top: 10), child: TextFormField(
      controller: c, keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
      validator: required ? (v) => v == null || v.trim().isEmpty ? tr('Required', 'এই ঘরটি পূরণ করুন') : null : null,
    ));

  Future<void> _delete(Map<String, dynamic> p) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(tr('Delete player?', 'প্লেয়ার মুছবেন?')),
      content: Text(p['name'].toString()),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancel', 'বাতিল'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Delete', 'মুছুন'))),
      ],
    ));
    if (yes != true) return;
    setState(() => players.removeWhere((x) => x['id'] == p['id']));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final shown = players.where((p) =>
      p['name'].toString().toLowerCase().contains(search.toLowerCase()) ||
      p['team'].toString().toLowerCase().contains(search.toLowerCase()) ||
      p['role'].toString().toLowerCase().contains(search.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Player Profiles', 'প্লেয়ার প্রোফাইল'))),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _form(), icon: const Icon(Icons.add), label: Text(tr('Add Player', 'প্লেয়ার যোগ করুন'))),
      body: loading ? const Center(child: CircularProgressIndicator()) : Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(
          onChanged: (v) => setState(() => search = v),
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: tr('Search players', 'প্লেয়ার খুঁজুন'), border: const OutlineInputBorder()),
        )),
        Expanded(child: shown.isEmpty
          ? Center(child: Text(tr('No players yet. Add your first player.', 'এখনো কোনো প্লেয়ার নেই। প্রথম প্লেয়ার যোগ করুন।')))
          : ListView.builder(padding: const EdgeInsets.only(bottom: 88), itemCount: shown.length, itemBuilder: (ctx, i) {
            final p = shown[i];
            return Card(color: const Color(0xFF102019), child: ExpansionTile(
              leading: CircleAvatar(backgroundColor: const Color(0xFF07552D), child: Text(p['jersey'].toString().isEmpty ? '🏏' : p['jersey'].toString())),
              title: Text(p['name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text([p['role'], if (p['team'].toString().isNotEmpty) p['team']].join(' • ')),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                _row(tr('Batting', 'ব্যাটিং'), p['batting'].toString()),
                _row(tr('Bowling', 'বোলিং'), p['bowling'].toString()),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _stat(tr('Matches', 'ম্যাচ'), p['matches'].toString()),
                  _stat(tr('Runs', 'রান'), p['runs'].toString()),
                  _stat(tr('Wickets', 'উইকেট'), p['wickets'].toString()),
                ]),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton.icon(onPressed: () => _form(old: p), icon: const Icon(Icons.edit), label: Text(tr('Edit', 'সম্পাদনা'))),
                  TextButton.icon(onPressed: () => _delete(p), icon: const Icon(Icons.delete_outline, color: Colors.redAccent), label: Text(tr('Delete', 'মুছুন'), style: const TextStyle(color: Colors.redAccent))),
                ]),
              ],
            ));
          })),
      ]),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [SizedBox(width: 85, child: Text(label, style: TextStyle(color: Colors.grey.shade400))), Expanded(child: Text(value.isEmpty ? '—' : value))]),
  );

  Widget _stat(String label, String value) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
    Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
  ]);
}
