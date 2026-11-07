import 'package:flutter/material.dart';
import '../widgets/storico_raggruppato_view.dart';

class StoricoPrelieviScreen extends StatelessWidget {
  const StoricoPrelieviScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo_scr.png',
              height: 22,
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Storico Prelievi',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: const StoricoRaggruppatoView(bottomPadding: 16.0),
    );
  }
}
