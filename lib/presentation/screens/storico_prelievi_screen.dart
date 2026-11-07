import 'package:flutter/material.dart';
import '../widgets/storico_raggruppato_view.dart';

class StoricoPrelieviScreen extends StatelessWidget {
  const StoricoPrelieviScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storico Prelievi'),
        centerTitle: true,
      ),
      body: const StoricoRaggruppatoView(bottomPadding: 16.0),
    );
  }
}
