import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fitness_tracker/core/di/injection_container.dart' as di;
import 'package:fitness_tracker/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('FitnessApp login page smoke test', (WidgetTester tester) async {
    await di.initDependencies();
    await tester.pumpWidget(const FitnessApp());

    expect(find.text('Fitness Tracker'), findsOneWidget);
    expect(find.text('Autenticar con Huella'), findsOneWidget);
  });
}
