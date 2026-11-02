import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive_page.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({required this.document, super.key});

  final String document;

  static const _documents = <String, ({String title, String asset})>{
    'privacy': (
      title: 'KVKK Aydınlatma Metni',
      asset: 'docs/PRIVACY_NOTICE_TR.md',
    ),
    'terms': (title: 'Kullanım Koşulları', asset: 'docs/TERMS_TR.md'),
    'community': (
      title: 'Topluluk Kuralları',
      asset: 'docs/COMMUNITY_GUIDELINES_TR.md',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final selected = _documents[document] ?? _documents['privacy']!;
    return AdaptivePage(
      title: selected.title,
      body: FutureBuilder<String>(
        future: rootBundle.loadString(selected.asset),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 80),
            child: SelectableText(
              snapshot.data!,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 15,
                height: 1.55,
              ),
            ),
          );
        },
      ),
    );
  }
}
