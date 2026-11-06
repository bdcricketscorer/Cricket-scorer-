import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bd_cricket_scorer/main.dart';

void main() {
  testWidgets('BD Cricket Scorer dashboard loads', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BDCricketScorer());
    await tester.pumpAndSettle();

    expect(find.text('🏏 BD Cricket Scorer'), findsOneWidget);
    expect(find.text('Player Profiles'), findsOneWidget);
    expect(find.text('Teams & Squads'), findsOneWidget);
  });
}
