import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scheda_prelievo/presentation/providers/prelievi_provider.dart';
import 'package:scheda_prelievo/presentation/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HomeScreen 3-destinations NavigationBar and no floating FAB', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storicoRaggruppatoProvider.overrideWith((ref) => {}),
          prelieviInAttesaProvider.overrideWith((ref) => []),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 1. Verifica che non esista alcun FloatingActionButton sopra le liste
    expect(find.byType(FloatingActionButton), findsNothing);

    // 2. Verifica che la NavigationBar contenga le 3 destinazioni
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Storico'), findsOneWidget);
    expect(find.text('Nuovo'), findsOneWidget);
    expect(find.text('Spunta Rientro'), findsOneWidget);

    // 3. Tocco su Spunta Rientro cambia la scheda visualizzata
    await tester.tap(find.text('Spunta Rientro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Spunta Rientro'), findsWidgets); // Nel titolo e nella navigation bar

    // 4. Tocco su Storico torna allo storico
    await tester.tap(find.text('Storico'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Storico Prelievi'), findsOneWidget);
  });
}
