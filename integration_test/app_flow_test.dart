import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:strange_rocks_01/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows splash entry options', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('I think I found a fossil!'), findsOneWidget);
    expect(find.text('Plan and execute a fossil finding trip'), findsOneWidget);
  });
}
