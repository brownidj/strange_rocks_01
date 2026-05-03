import 'package:flutter_test/flutter_test.dart';
import 'package:strange_rocks_01/app/app.dart';

void main() {
  testWidgets('Splash screen renders entry choices', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const StrangeRocksApp());
    await tester.pump();

    expect(find.text('Strange Rocks'), findsOneWidget);
    expect(find.text('I think I found a fossil!'), findsOneWidget);
    expect(find.text('Plan and execute a fossil finding trip'), findsOneWidget);
  });
}
