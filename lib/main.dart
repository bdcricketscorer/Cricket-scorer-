import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'player_profiles_page.dart';
import 'team_squads_page.dart';
import 'tournament_page.dart';
import 'match_scoring_page.dart';
import 'statistics_page.dart';

const Color _bg = Color(0xFF07110D);
const Color _panel = Color(0xFF102019);
const Color _green = Color(0xFF00E676);
const Color _muted = Color(0xFF9EAEA4);

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
      scaffoldBackgroundColor: _bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _green,
        brightness: Brightness.dark,
        surface: _panel,
      ),
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
  int teamCount = 0;
  int tournamentCount = 0;

  String tr(String en, String bn) => isBangla ? bn : en;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    int players = 0;
    final raw = prefs.getString('player_profiles_v1');
    if (raw != null) {
      try {
        players = (jsonDecode(raw) as List).length;
      } catch (_) {}
    } else {
      players = (prefs.getStringList('players') ?? []).length;
    }
    if (!mounted) return;
    setState(() {
      playerCount = players;
      teamCount = (prefs.getStringList('teams') ?? []).length;
      tournamentCount = (prefs.getStringList('tournaments') ?? []).length;
    });
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await _loadData();
  }

  void _openIndex(int index) {
    switch (index) {
      case 1:
        _open(MatchCenterPage(isBangla: isBangla));
        break;
      case 2:
        _open(TeamSquadsPage(isBangla: isBangla));
        break;
      case 3:
        _open(StatisticsPage(isBangla: isBangla));
        break;
      case 4:
        _open(PlayerProfilesPage(isBangla: isBangla));
        break;
    }
  }

  Widget _statPill(
    IconData icon,
    String value,
    String label,
    VoidCallback onTap,
  ) => Expanded(
    child: Material(
      color: Colors.white.withValues(alpha: 0.055),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFFB9F6CA), size: 19),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: _muted)),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _featureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
    String? count,
  }) => Material(
    color: _panel,
    borderRadius: BorderRadius.circular(19),
    child: InkWell(
      borderRadius: BorderRadius.circular(19),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: Colors.white.withValues(alpha: 0.065)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_panel, accent.withValues(alpha: 0.075)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent, size: 23),
                ),
                const Spacer(),
                if (count != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(count, style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
                  )
                else
                  Icon(Icons.arrow_outward_rounded, color: Colors.white.withValues(alpha: 0.45), size: 18),
              ],
            ),
            const Spacer(),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, height: 1.35, color: _muted)),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _loadData,
        color: _green,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    children: [
                      Container(
                        width: 43,
                        height: 43,
                        decoration: BoxDecoration(
                          color: const Color(0xFF123B25),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _green.withValues(alpha: 0.35)),
                        ),
                        child: const Icon(Icons.sports_cricket_rounded, color: _green, size: 25),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('BD CRICKET SCORER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.05, fontSize: 14)),
                            SizedBox(height: 2),
                            Text('YOUR CRICKET CONTROL CENTRE', style: TextStyle(color: _muted, fontSize: 9, letterSpacing: 1.1)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: isBangla ? 'Switch to English' : 'বাংলা',
                        onPressed: () => setState(() => isBangla = !isBangla),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.07),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                        ),
                        icon: Text(isBangla ? 'EN' : 'বাং', style: const TextStyle(color: _green, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Container(
                    height: 190,
                    padding: const EdgeInsets.all(21),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF08733B), Color(0xFF103B27), Color(0xFF102019)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: _green.withValues(alpha: 0.22)),
                      boxShadow: [
                        BoxShadow(color: _green.withValues(alpha: 0.08), blurRadius: 25, offset: const Offset(0, 9)),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(right: -12, top: -24,
                          child: Icon(Icons.sports_cricket, size: 155, color: Colors.white.withValues(alpha: 0.065))),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(30)),
                              child: Text(tr('CRICKET CONTROL CENTRE', 'ক্রিকেট পরিচালনা কেন্দ্র'),
                                style: const TextStyle(color: Color(0xFFB9F6CA), fontSize: 9, letterSpacing: 1.15, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 13),
                            Text(tr('Manage your game.', 'আপনার খেলা পরিচালনা করুন।'),
                              style: const TextStyle(fontSize: 25, height: 1.1, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 7),
                            Text(tr('Everything you need, in one place.', 'ক্রিকেট পরিচালনার সবকিছু এক জায়গায়।'),
                              style: const TextStyle(color: Color(0xFFD0E7D8), fontSize: 12)),
                            const Spacer(),
                            Row(
                              children: [
                                const Icon(Icons.circle, size: 7, color: Color(0xFF69F0AE)),
                                const SizedBox(width: 6),
                                Text(tr('READY TO PLAY', 'খেলা পরিচালনায় প্রস্তুত'),
                                  style: const TextStyle(color: Color(0xFFB9F6CA), fontSize: 9, letterSpacing: 1.1, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      _statPill(
                        Icons.person_rounded,
                        '$playerCount',
                        tr('Players', 'খেলোয়াড়'),
                        () => _open(PlayerProfilesPage(isBangla: isBangla)),
                      ),
                      const SizedBox(width: 9),
                      _statPill(
                        Icons.groups_rounded,
                        '$teamCount',
                        tr('Teams', 'দল'),
                        () => _open(TeamSquadsPage(isBangla: isBangla)),
                      ),
                      const SizedBox(width: 9),
                      _statPill(
                        Icons.emoji_events_rounded,
                        '$tournamentCount',
                        tr('Tournaments', 'টুর্নামেন্ট'),
                        () => _open(TournamentPage(isBangla: isBangla)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Text(tr('Quick Access', 'দ্রুত প্রবেশ'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const Spacer(),
                      Text(tr('5 FEATURES', '৫টি ফিচার'), style: const TextStyle(color: _muted, fontSize: 9, letterSpacing: 1)),
                    ],
                  ),
                  const SizedBox(height: 13),
                  SizedBox(
                    height: 150,
                    child: Row(
                      children: [
                        Expanded(child: _featureCard(
                          icon: Icons.person_rounded,
                          title: tr('Player Profiles', 'প্লেয়ার প্রোফাইল'),
                          subtitle: tr('Manage player details', 'খেলোয়াড়ের তথ্য পরিচালনা'),
                          accent: const Color(0xFF69F0AE),
                          count: '$playerCount',
                          onTap: () => _open(PlayerProfilesPage(isBangla: isBangla)),
                        )),
                        const SizedBox(width: 11),
                        Expanded(child: _featureCard(
                          icon: Icons.groups_rounded,
                          title: tr('Teams & Squads', 'দল ও স্কোয়াড'),
                          subtitle: tr('Build your team', 'আপনার দল তৈরি করুন'),
                          accent: const Color(0xFF80CBC4),
                          count: '$teamCount',
                          onTap: () => _open(TeamSquadsPage(isBangla: isBangla)),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 11),
                  SizedBox(
                    height: 150,
                    child: Row(
                      children: [
                        Expanded(child: _featureCard(
                          icon: Icons.emoji_events_rounded,
                          title: tr('Tournaments', 'টুর্নামেন্ট'),
                          subtitle: tr('Fixtures & standings', 'ফিক্সচার ও পয়েন্ট টেবিল'),
                          accent: const Color(0xFFFFD54F),
                          count: '$tournamentCount',
                          onTap: () => _open(TournamentPage(isBangla: isBangla)),
                        )),
                        const SizedBox(width: 11),
                        Expanded(child: _featureCard(
                          icon: Icons.sports_cricket_rounded,
                          title: tr('Live Scoring', 'লাইভ স্কোরিং'),
                          subtitle: tr('Score every ball', 'প্রতি বলের স্কোর রাখুন'),
                          accent: const Color(0xFFFF8A65),
                          onTap: () => _open(MatchCenterPage(isBangla: isBangla)),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 11),
                  SizedBox(
                    height: 132,
                    child: _featureCard(
                      icon: Icons.query_stats_rounded,
                      title: tr('Statistics & Points Table', 'পরিসংখ্যান ও পয়েন্ট টেবিল'),
                      subtitle: tr('Player performance, team standings and match insights', 'প্লেয়ারের পারফরম্যান্স, দলের অবস্থান ও ম্যাচের পরিসংখ্যান'),
                      accent: const Color(0xFF90CAF9),
                      onTap: () => _open(StatisticsPage(isBangla: isBangla)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(child: Text(
                    tr('BD CRICKET SCORER  •  PLAY • SCORE • WIN', 'বিডি ক্রিকেট স্কোরার  •  খেলুন • স্কোর রাখুন • জিতুন'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF617168), fontSize: 9, letterSpacing: 0.7),
                  )),
                ]),
              ),
            ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: NavigationBar(
      height: 68,
      backgroundColor: const Color(0xFF0B1711),
      indicatorColor: _green.withValues(alpha: 0.15),
      selectedIndex: 0,
      onDestinationSelected: _openIndex,
      destinations: [
        NavigationDestination(icon: const Icon(Icons.home_rounded), label: tr('Home', 'হোম')),
        NavigationDestination(icon: const Icon(Icons.sports_cricket_rounded), label: tr('Matches', 'ম্যাচ')),
        NavigationDestination(icon: const Icon(Icons.groups_rounded), label: tr('Teams', 'দল')),
        NavigationDestination(icon: const Icon(Icons.bar_chart_rounded), label: tr('Stats', 'পরিসংখ্যান')),
        NavigationDestination(icon: const Icon(Icons.person_rounded), label: tr('Profile', 'প্রোফাইল')),
      ],
    ),
  );
}
