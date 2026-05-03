import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:strange_rocks_01/app/app.dart';

void main() {
  patrolTest('splash screen shows entry points', ($) async {
    await $.pumpWidgetAndSettle(const StrangeRocksApp());

    expect(find.text('I think I found a fossil!'), findsOneWidget);
    expect(find.text('Plan and execute a fossil finding trip'), findsOneWidget);
  });
}
