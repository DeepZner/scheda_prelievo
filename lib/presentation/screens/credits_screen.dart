import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Schermata Credits e Informazioni dell'applicazione Magazzino Speleo Club Roma.
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  static const String appVersion = '0.1.4';
  static const String developerEmail = 'massimiliano.re@speleoclubroma.org';
  static const String scrWebsiteUrl = 'https://www.speleoclubroma.org';
  static const String repoUrl = 'https://github.com/DeepZner/scheda_prelievo';

  Future<void> _openLink(BuildContext context, String urlString, {bool isEmail = false}) async {
    final uri = Uri.parse(isEmail ? 'mailto:$urlString' : urlString);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        _copyToClipboard(context, urlString, 'Impossibile aprire il link. Indirizzo copiato negli appunti:');
      }
    } catch (_) {
      if (context.mounted) {
        _copyToClipboard(context, urlString, 'Indirizzo copiato negli appunti:');
      }
    }
  }

  void _copyToClipboard(BuildContext context, String text, [String? message]) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message != null ? '$message $text' : 'Copiato negli appunti: $text',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Info & Credits',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- HEADER LOGHI ---
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Column(
                  children: [
                    // Riga Loghi
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo App
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            height: 76,
                            width: 76,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 76,
                              width: 76,
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(Icons.inventory_2_rounded, size: 40, color: colorScheme.primary),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '×',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w300,
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        // Logo Speleo Club Roma
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/images/logo_scr.png',
                              height: 68,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 68,
                                width: 68,
                                color: Colors.white,
                                child: Icon(Icons.landscape_rounded, size: 40, color: colorScheme.primary),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Nome App
                    Text(
                      'Magazzino Speleo Club Roma',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gestione Prelievi e Rientri Attrezzature',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Chip Versione & Offline-First
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Versione $appVersion',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.teal.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi_off_rounded, size: 14, color: Colors.teal.shade800),
                              const SizedBox(width: 4),
                              Text(
                                'Offline-First',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- SEZIONE SVILUPPATORE & IDEATORE ---
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                          child: Icon(Icons.code_rounded, color: colorScheme.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'IDEATORE E SVILUPPATORE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Massimiliano Re',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 8),

                    // Email
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.email_outlined, color: colorScheme.primary),
                      title: const Text('Email', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      subtitle: Text(
                        developerEmail,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 20),
                            tooltip: 'Copia email',
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                            onPressed: () => _copyToClipboard(context, developerEmail),
                          ),
                          IconButton(
                            icon: const Icon(Icons.open_in_new_rounded, size: 20),
                            tooltip: 'Invia email',
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                            onPressed: () => _openLink(context, developerEmail, isEmail: true),
                          ),
                        ],
                      ),
                      onTap: () => _openLink(context, developerEmail, isEmail: true),
                    ),

                    const Divider(height: 1),
                    const SizedBox(height: 8),

                    // GitHub
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.terminal_rounded, color: colorScheme.primary),
                      title: Row(
                        children: [
                          const Text('GitHub', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.amber.shade400, width: 0.8),
                            ),
                            child: Text(
                              'Repo Privata',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.brown.shade900),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DeepZner / scheda_prelievo',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          Text(
                            repoUrl,
                            style: TextStyle(fontSize: 11, color: colorScheme.outline),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 20),
                            tooltip: 'Copia link repository',
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                            onPressed: () => _copyToClipboard(context, repoUrl),
                          ),
                          IconButton(
                            icon: const Icon(Icons.open_in_new_rounded, size: 20),
                            tooltip: 'Apri repository',
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                            onPressed: () => _openLink(context, repoUrl),
                          ),
                        ],
                      ),
                      onTap: () => _openLink(context, repoUrl),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- SEZIONE SPELEO CLUB ROMA ---
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.deepOrange.withValues(alpha: 0.12),
                          child: const Icon(Icons.explore_rounded, color: Colors.deepOrange, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ORGANIZZAZIONE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: Colors.deepOrange.shade800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Speleo Club Roma',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Associazione speleologica fondata nel 1957. Esplorazione, rilievo topografico, documentazione e tutela del mondo ipogeo.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.language_rounded, color: Colors.deepOrange),
                      title: const Text('Sito Ufficiale', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      subtitle: Text(
                        scrWebsiteUrl,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 20),
                            tooltip: 'Copia link sito',
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                            onPressed: () => _copyToClipboard(context, scrWebsiteUrl),
                          ),
                          IconButton(
                            icon: const Icon(Icons.open_in_new_rounded, size: 20),
                            tooltip: 'Apri sito',
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                            onPressed: () => _openLink(context, scrWebsiteUrl),
                          ),
                        ],
                      ),
                      onTap: () => _openLink(context, scrWebsiteUrl),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- CARATTERISTICHE APP ---
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CARATTERISTICHE & TECNOLOGIA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      icon: Icons.storage_rounded,
                      title: 'Single Source of Truth locale (SQLite)',
                      description: 'Operatività garantita al 100% senza connessione internet nei magazzini sotterranei.',
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 10),
                    _buildFeatureItem(
                      icon: Icons.sync_rounded,
                      title: 'Sincronizzazione Cloud (Google Sheets & Drive)',
                      description: 'Aggiornamento catalogo da remoto, upload schede e backup allegati PDF/foto.',
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(height: 10),
                    _buildFeatureItem(
                      icon: Icons.picture_as_pdf_rounded,
                      title: 'Esportazione PDF & Relazioni',
                      description: 'Creazione automatica del report di missione con dettagli, note e fotografie.',
                      color: Colors.red.shade700,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Footer
            Center(
              child: Text(
                'Realizzato con passione per lo Speleo Club Roma',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
