import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'player_profiles_page.dart';
import 'team_squads_page.dart';
import 'tournament_page.dart';
import 'match_scoring_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BDCricketScorer());
}

class BDCricketScorer extends StatelessWidget {
  const BDCricketScorer({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BD Cricket Scorer',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF07110D),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00C853), brightness: Brightness.dark),
      useMaterial3: true,
    ),
    home: const DashboardPage(),
  );
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool isBangla = false;
  int playerCount = 0;
  List<String> teams = [];
  List<String> tournaments = [];
  String tr(String en, String bn) => isBangla ? bn : en;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    int count = 0;
    final raw = prefs.getString('player_profiles_v1');
    if (raw != null) {
      try { count = (jsonDecode(raw) as List).length; } catch (_) {}
    } else {
      count = (prefs.getStringList('players') ?? []).length;
    }
    if (!mounted) return;
    setState(() {
      playerCount = count;
      teams = prefs.getStringList('teams') ?? [];
      tournaments = prefs.getStringList('tournaments') ?? [];
    });
  }

  Future<void> _openTeams() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => TeamSquadsPage(isBangla: isBangla),
    ));
    await _loadData();
  }

  Future<void> _openTournaments() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => TournamentPage(isBangla: isBangla),
    ));
    await _loadData();
  }

  Future<void> _openPlayers() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => PlayerProfilesPage(isBangla: isBangla),
    ));
    await _loadData();
  }

  Future<void> _openMatches() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => MatchCenterPage(isBangla: isBangla),
    ));
    await _loadData();
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required int count,
    required VoidCallback onAdd,
    required VoidCallback onOpen,
  }) => Card(
    color: const Color(0xFF102019),
    child: ListTile(
      onTap: onOpen,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF00C853).withValues(alpha: 0.16),
        child: Icon(icon, color: const Color(0xFF00E676)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('$subtitle • $count'),
      trailing: IconButton(
        onPressed: onAdd,
        icon: const Icon(Icons.add_circle, color: Color(0xFF00E676), size: 30),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('🏏 BD Cricket Scorer'),
      actions: [TextButton(onPressed: () => setState(() => isBangla = !isBangla), child: Text(isBangla ? 'EN' : 'বাং'))],
    ),
    body: RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(colors: [Color(0xFF07552D), Color(0xFF102019)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('CRICKET CONTROL CENTRE', 'ক্রিকেট পরিচালনা কেন্দ্র'), style: const TextStyle(color: Color(0xFFB9F6CA), letterSpacing: 1.1)),
              const SizedBox(height: 10),
              Text(tr('Manage your game.', 'আপনার খেলা পরিচালনা করুন।'), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(tr('Players • Teams • Tournaments • Matches', 'খেলোয়াড় • দল • টুর্নামেন্ট • ম্যাচ')),
            ]),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            icon: Icons.person,
            title: tr('Player Profiles', 'প্লেয়ার প্রোফাইল'),
            subtitle: tr('No photo upload', 'ছবি আপলোড নেই'),
            count: playerCount,
            onAdd: _openPlayers,
            onOpen: _openPlayers,
          ),
          _sectionCard(
            icon: Icons.groups,
            title: tr('Teams & Squads', 'দল ও স্কোয়াড'),
            subtitle: tr('Registered teams', 'নিবন্ধিত দল'),
            count: teams.length,
            onAdd: _openTeams,
            onOpen: _openTeams,
          ),
          _sectionCard(
            icon: Icons.emoji_events,
            title: tr('Tournaments', 'টুর্নামেন্ট'),
            subtitle: tr('Competitions', 'প্রতিযোগিতা'),
            count: tournaments.length,
            onAdd: _openTournaments,
            onOpen: _openTournaments,
          ),
          Card(
            color: const Color(0xFF102019),
            child: ListTile(
              onTap: _openMatches,
              leading: const CircleAvatar(child: Icon(Icons.sports_cricket, color: Color(0xFF00E676))),
              title: Text(tr('Matches & Live Scoring', 'ম্যাচ ও লাইভ স্কোরিং')),
              subtitle: Text(tr('Start matches and record every ball', 'ম্যাচ শুরু করুন এবং প্রতি বলের স্কোর রাখুন')),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text(
            tr('Local device storage • No account required', 'মোবাইলে ডাটা সংরক্ষণ • লগইন লাগবে না'),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12), textAlign: TextAlign.center,
          )),
        ],
      ),
    ),
  );
}
