import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive_page.dart';

class AccountSuspendedScreen extends StatelessWidget {
  const AccountSuspendedScreen({super.key});

  @override
  Widget build(BuildContext context) => AdaptivePage(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.gpp_maybe_outlined,
              size: 58,
              color: AppColors.orange,
            ),
            const SizedBox(height: 22),
            const Text(
              'Hesabın inceleme nedeniyle askıya alındı',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.brown,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Karara itiraz etmek veya ayrıntı istemek için muhammetcalis@gmail.com adresine hesap e-postanla başvurabilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 22),
            AdaptiveSecondaryButton(
              label: 'Topluluk kurallarını oku',
              onPressed: () => context.push('/legal/community'),
            ),
          ],
        ),
      ),
    ),
  );
}
