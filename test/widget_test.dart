import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quran_flutter_app/main.dart';
import 'package:quran_flutter_app/providers/settings_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: const MyApp(),
      ),
    );

    expect(find.byType(MyApp), findsOneWidget);
  });
}
