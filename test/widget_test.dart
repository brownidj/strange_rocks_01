import 'package:flutter_test/flutter_test.dart';
import 'package:strange_rocks_01/app/app.dart';

void main() {
  testWidgets('Field pack screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const StrangeRocksApp());
    await tester.pump();

    expect(find.text('Field Packs'), findsOneWidget);
    expect(
      find.text(
        'No field packs yet. Tap "Define Area" to import GeoJSON and download one.',
      ),
      findsOneWidget,
    );
  });
}
