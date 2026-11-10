import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scheda_prelievo/presentation/screens/credits_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CreditsScreen Widget Tests', () {
    testWidgets('Rendering completo della schermata Credits con loghi e contatti sviluppatore', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CreditsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica titolo AppBar
      expect(find.text('Info & Credits'), findsOneWidget);

      // Verifica intestazione app
      expect(find.text('Magazzino Speleo Club Roma'), findsOneWidget);
      expect(find.text('Gestione Prelievi e Rientri Attrezzature'), findsOneWidget);
      expect(find.text('Versione ${CreditsScreen.appVersion}'), findsOneWidget);
      expect(find.text('Offline-First'), findsOneWidget);

      // Verifica sezione sviluppatore
      expect(find.text('IDEATORE E SVILUPPATORE'), findsOneWidget);
      expect(find.text('Massimiliano Re'), findsOneWidget);
      expect(find.text(CreditsScreen.developerEmail), findsOneWidget);
      expect(find.text('DeepZner / scheda_prelievo'), findsOneWidget);
      expect(find.text('Repo Privata'), findsOneWidget);
      expect(find.text(CreditsScreen.repoUrl), findsOneWidget);

      // Verifica sezione Speleo Club Roma
      expect(find.text('Speleo Club Roma'), findsWidgets);
      expect(find.text(CreditsScreen.scrWebsiteUrl), findsOneWidget);

      // Verifica caratteristiche tecnologiche
      expect(find.text('Single Source of Truth locale (SQLite)'), findsOneWidget);
      expect(find.text('Sincronizzazione Cloud (Google Sheets & Drive)'), findsOneWidget);
      expect(find.text('Esportazione PDF & Relazioni'), findsOneWidget);

      // Verifica presenza icone interattive
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      expect(find.byIcon(Icons.terminal_rounded), findsOneWidget);
      expect(find.byIcon(Icons.language_rounded), findsOneWidget);
    });

    testWidgets('Tap su copia email inserisce il testo negli appunti e mostra SnackBar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CreditsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trova il pulsante copia per l'email
      final copyEmailButton = find.byTooltip('Copia email');
      expect(copyEmailButton, findsOneWidget);

      await tester.tap(copyEmailButton);
      await tester.pump();

      // Verifica SnackBar
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Copiato negli appunti: ${CreditsScreen.developerEmail}'), findsOneWidget);
    });
  });
}
