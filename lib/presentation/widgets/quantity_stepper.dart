import 'package:flutter/material.dart';

/// Selettore di quantità ergonomico con touch target >= 48x48dp.
/// Supporta:
/// 1. Incremento (+) e decremento (-) con step intelligente (es. 5m per corde, 1 per pezzi)
/// 2. Toccare il valore centrale per digitazione numerica immediata da tastiera
/// 3. Chip di selezione rapida (es. per corde: 10m, 20m, 30m, 50m, 60m, 80m, 100m)
/// 4. Distinzione visiva e testuale dell'unità di misura ('m' per corde, 'pz' per pezzi)
class QuantityStepper extends StatelessWidget {
  final int value;
  final int minValue;
  final int maxValue;
  final ValueChanged<int> onChanged;
  final String unit; // 'pz' o 'm'
  final bool isMetri;
  final String? itemName;
  final int step;

  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.minValue = 0,
    this.maxValue = 999,
    this.unit = 'pz',
    this.isMetri = false,
    this.itemName,
    this.step = 1,
  });

  int get _effectiveStep => isMetri ? (step > 1 ? step : 5) : step;

  void _showDirectInputDialog(BuildContext context) {
    final controller = TextEditingController(text: value > 0 ? '$value' : '');
    final theme = Theme.of(context);
    final presets = isMetri
        ? [10, 20, 30, 40, 50, 60, 80, 100]
        : [1, 2, 5, 10, 15, 20, 30, 50];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    isMetri ? Icons.straighten : Icons.edit_note,
                    color: isMetri ? Colors.deepOrange : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      itemName != null
                          ? 'Quantità ($itemName)'
                          : 'Imposta Quantità',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMetri
                          ? 'Specifica la lunghezza in metri (m):'
                          : 'Specifica la quantità in pezzi (pz):',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        suffixText: unit,
                        suffixStyle: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isMetri
                              ? Colors.deepOrange
                              : theme.colorScheme.primary,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onSubmitted: (val) {
                        final parsed = int.tryParse(val.trim());
                        if (parsed != null) {
                          final clamped = parsed.clamp(minValue, maxValue);
                          onChanged(clamped);
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Selezioni rapide:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: presets.map((preset) {
                        if (preset < minValue || preset > maxValue) {
                          return const SizedBox.shrink();
                        }
                        final isCurrent =
                            int.tryParse(controller.text) == preset;
                        return ActionChip(
                          avatar: isCurrent
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.white)
                              : null,
                          backgroundColor: isCurrent
                              ? (isMetri
                                  ? Colors.deepOrange
                                  : theme.colorScheme.primary)
                              : null,
                          label: Text(
                            '$preset $unit',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? Colors.white : null,
                            ),
                          ),
                          onPressed: () {
                            controller.text = '$preset';
                            setDialogState(() {});
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: isMetri
                        ? Colors.deepOrange
                        : theme.colorScheme.primary,
                  ),
                  onPressed: () {
                    final parsed = int.tryParse(controller.text.trim());
                    if (parsed != null) {
                      final clamped = parsed.clamp(minValue, maxValue);
                      onChanged(clamped);
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('Conferma'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canDecrement = value > minValue;
    final canIncrement = value < maxValue;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsante Sottrai (48x48dp)
        SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: canDecrement
                ? (isMetri
                    ? Colors.orange.shade100
                    : theme.colorScheme.primaryContainer)
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: canDecrement
                  ? () {
                      final next = value - _effectiveStep;
                      onChanged(next < minValue ? minValue : next);
                    }
                  : null,
              child: Center(
                child: Icon(
                  Icons.remove,
                  size: 24,
                  color: canDecrement
                      ? (isMetri
                          ? Colors.deepOrange.shade900
                          : theme.colorScheme.onPrimaryContainer)
                      : Colors.grey.shade400,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),

        // Visualizzazione Valore Cliccabile (Pill con valore + unità + icona edit)
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showDirectInputDialog(context),
          child: Container(
            constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isMetri
                  ? Colors.orange.shade50
                  : theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMetri
                    ? Colors.deepOrange.shade300
                    : Colors.grey.shade400,
                width: isMetri ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$value',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  unit,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isMetri
                        ? Colors.deepOrange.shade800
                        : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.edit_note,
                  size: 16,
                  color: isMetri
                      ? Colors.deepOrange.shade700
                      : Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),

        // Pulsante Aggiungi (48x48dp)
        SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: canIncrement
                ? (isMetri ? Colors.deepOrange : theme.colorScheme.primary)
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: canIncrement
                  ? () {
                      final next = value + _effectiveStep;
                      onChanged(next > maxValue ? maxValue : next);
                    }
                  : null,
              child: Center(
                child: Icon(
                  Icons.add,
                  size: 24,
                  color: canIncrement ? Colors.white : Colors.grey.shade400,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
