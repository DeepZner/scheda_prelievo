import 'package:go_router/go_router.dart';
import '../screens/dettaglio_prelievo_screen.dart';
import '../screens/home_screen.dart';
import '../screens/nuovo_prelievo_screen.dart';
import '../screens/relazione_screen.dart';
import '../screens/rientro_materiale_screen.dart';
import '../screens/storico_prelievi_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'nuovo-prelievo',
          builder: (context, state) => const NuovoPrelievoScreen(),
        ),
        GoRoute(
          path: 'modifica-prelievo/:id',
          builder: (context, state) {
            final prelievoId = state.pathParameters['id']!;
            return NuovoPrelievoScreen(editPrelievoId: prelievoId);
          },
        ),
        GoRoute(
          path: 'prelievo/:id',
          builder: (context, state) {
            final prelievoId = state.pathParameters['id']!;
            return DettaglioPrelievoScreen(prelievoId: prelievoId);
          },
        ),
        GoRoute(
          path: 'prelievo/:id/relazione',
          builder: (context, state) {
            final prelievoId = state.pathParameters['id']!;
            return RelazioneScreen(prelievoId: prelievoId);
          },
        ),
        GoRoute(
          path: 'rientro',
          builder: (context, state) {
            final prelievoId = state.uri.queryParameters['id'];
            return RientroMaterialeScreen(initialPrelievoId: prelievoId);
          },
        ),
        GoRoute(
          path: 'rientro/:id',
          builder: (context, state) {
            final prelievoId = state.pathParameters['id'];
            return RientroMaterialeScreen(initialPrelievoId: prelievoId);
          },
        ),
        GoRoute(
          path: 'storico',
          builder: (context, state) => const StoricoPrelieviScreen(),
        ),
      ],
    ),
  ],
);
