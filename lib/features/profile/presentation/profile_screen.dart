import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/account_service.dart';
import '../../../core/services/app_session_controller.dart';
import '../../../core/services/prayer_schedule_sync_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/telemetry_service.dart';
import '../../../core/widgets/adaptive_page.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = 'Muhammet A.', _city = 'İstanbul', _madhhab = 'Hanefi';
  bool _notifications = true;
  bool _diagnostics = false;
  int _streak = 0, _sevenCompleted = 0, _thirtyCompleted = 0;
  bool _anonymous = true;
  bool _emailVerified = false;
  bool _moderator = false;
  String? _email;
  bool get _firebase =>
      Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null;

  @override
  void initState() {
    super.initState();
    final user = Firebase.apps.isNotEmpty
        ? FirebaseAuth.instance.currentUser
        : null;
    _anonymous = user?.isAnonymous ?? true;
    _emailVerified = user?.emailVerified ?? false;
    _email = user?.email;
    _diagnostics = TelemetryService.instance.enabled;
    if (_firebase) _load();
    if (_firebase) _loadClaims();
  }

  Future<void> _loadClaims() async {
    final claims = await FirebaseAuth.instance.currentUser?.getIdTokenResult();
    if (!mounted) return;
    setState(() {
      _moderator =
          claims?.claims?['admin'] == true ||
          claims?.claims?['moderator'] == true;
    });
  }

  Future<void> _load() async {
    final data =
        (await FirebaseFirestore.instance
                .doc('users/${FirebaseAuth.instance.currentUser!.uid}')
                .get())
            .data();
    if (data == null || !mounted) return;
    setState(() {
      final stats = data['stats'] as Map?;
      _name = data['displayName'] as String? ?? _name;
      _city = data['city'] as String? ?? _city;
      _madhhab = data['madhhab'] == 'shafii' ? 'Şafii' : 'Hanefi';
      _notifications =
          (data['notificationPreferences'] as Map?)?['enabled'] as bool? ??
          true;
      _streak = (stats?['currentStreak'] as num?)?.toInt() ?? 0;
      _sevenCompleted = (stats?['sevenDayCompleted'] as num?)?.toInt() ?? 0;
      _thirtyCompleted = (stats?['thirtyDayCompleted'] as num?)?.toInt() ?? 0;
    });
  }

  Future<void> _makePermanent() async {
    final email = TextEditingController();
    final password = TextEditingController();
    final confirmation = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabını kalıcılaştır'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'E-posta ve şifre eklediğinde hesabına başka bir cihazdan da erişebilirsin.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'E-posta'),
            ),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Şifre (en az 8 karakter)',
              ),
            ),
            TextField(
              controller: confirmation,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Şifreyi tekrar yaz',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kalıcılaştır'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) {
      email.dispose();
      password.dispose();
      confirmation.dispose();
      return;
    }
    final emailValue = email.text.trim();
    final passwordValue = password.text;
    final confirmationValue = confirmation.text;
    email.dispose();
    password.dispose();
    confirmation.dispose();
    if (!emailValue.contains('@') ||
        passwordValue.length < 8 ||
        passwordValue != confirmationValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('E-posta ve şifre bilgilerini kontrol et.'),
        ),
      );
      return;
    }
    try {
      await AccountService.instance.makePermanent(
        email: emailValue,
        password: passwordValue,
      );
      if (!mounted) return;
      setState(() {
        _anonymous = false;
        _email = emailValue;
        _emailVerified = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doğrulama e-postası gönderildi.')),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'email-already-in-use' => 'Bu e-posta başka bir hesapta kullanılıyor.',
        'invalid-email' => 'Geçerli bir e-posta yaz.',
        'weak-password' => 'Daha güçlü bir şifre seç.',
        _ => 'Hesap kalıcılaştırılamadı. Tekrar dene.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _resendVerification() async {
    await AccountService.instance.resendVerification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Doğrulama e-postası yeniden gönderildi.'),
        ),
      );
    }
  }

  Future<void> _edit() async {
    final name = TextEditingController(text: _name),
        city = TextEditingController(text: _city);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profil bilgileri'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Görünen ad'),
            ),
            TextField(
              controller: city,
              decoration: const InputDecoration(labelText: 'Şehir'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (result == true && name.text.trim().isNotEmpty) {
      final previousName = _name;
      final previousCity = _city;
      final nextName = name.text.trim();
      final nextCity = city.text.trim();
      try {
        setState(() {
          _name = nextName;
          _city = nextCity;
        });
        if (_firebase) {
          final reference = FirebaseFirestore.instance.doc(
            'users/${FirebaseAuth.instance.currentUser!.uid}',
          );
          await reference.update({
            'displayName': _name,
            'displayInitial': _name.characters.first.toUpperCase(),
            'city': _city,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          await PrayerScheduleSyncService.instance.sync(
            fallbackCity: _city,
            force: true,
          );
        }
      } catch (error) {
        if (mounted) {
          setState(() {
            _name = previousName;
            _city = previousCity;
          });
          final message = error is PrayerScheduleSyncException
              ? error.message
              : 'Profil ve namaz vakitleri güncellenemedi.';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
        if (_firebase) {
          await FirebaseFirestore.instance
              .doc('users/${FirebaseAuth.instance.currentUser!.uid}')
              .update({
                'displayName': previousName,
                'displayInitial': previousName.characters.first.toUpperCase(),
                'city': previousCity,
                'updatedAt': FieldValue.serverTimestamp(),
              });
        }
      }
    }
    name.dispose();
    city.dispose();
  }

  Future<void> _toggle(bool value) async {
    setState(() => _notifications = value);
    if (_firebase) {
      try {
        await PushNotificationService.instance.setEnabled(value);
      } catch (_) {
        if (mounted) setState(() => _notifications = !value);
      }
    }
  }

  Future<void> _toggleDiagnostics(bool value) async {
    setState(() => _diagnostics = value);
    try {
      await TelemetryService.instance.setEnabled(value);
    } catch (_) {
      if (mounted) setState(() => _diagnostics = !value);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabı kalıcı olarak sil'),
        content: const Text(
          'Profilin, üyeliklerin ve aktif fotoğrafların silinir. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hesabı sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final deletedUserId = FirebaseAuth.instance.currentUser?.uid;
    try {
      if (_firebase) {
        await FirebaseFunctions.instanceFor(
          region: 'europe-west1',
        ).httpsCallable('deleteMyAccount').call();
        await FirebaseAuth.instance.signOut();
      }
      if (!mounted) return;
      await AppSessionController.instance.clearCompletion(
        forUserId: deletedUserId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hesabın silindi.')));
      context.go('/onboarding');
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.code == 'failed-precondition'
                  ? 'Önce sahibi olduğun grupların sahipliğini devretmelisin.'
                  : 'Hesap silinemedi. Lütfen tekrar dene.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _restartOnboarding() async {
    if (_firebase) {
      await AppSessionController.instance.restartOnboarding();
    }
    if (mounted) context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) => AdaptivePage(
    title: 'Profil',
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 120),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.brown,
              child: Text(
                _name.characters.take(2).toString().toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name,
                    style: const TextStyle(
                      color: AppColors.brown,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$_city · $_madhhab',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _edit,
              tooltip: 'Profili düzenle',
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _StreakPanel(days: _streak),
        const SizedBox(height: 22),
        const SectionTitle('Son dönem'),
        const SizedBox(height: 6),
        _MetricRow(label: 'Son 7 günde tamamlanan', value: _sevenCompleted),
        _MetricRow(label: 'Son 30 günde tamamlanan', value: _thirtyCompleted),
        const SizedBox(height: 28),
        const SectionTitle('Hesap'),
        const SizedBox(height: 6),
        if (_anonymous)
          _SettingsRow(
            icon: Icons.lock_outline_rounded,
            label: 'Hesabını kalıcılaştır',
            onTap: _makePermanent,
          )
        else ...[
          _AccountIdentity(email: _email ?? 'Kalıcı hesap'),
          if (!_emailVerified)
            _SettingsRow(
              icon: Icons.mark_email_unread_outlined,
              label: 'Doğrulama e-postasını yeniden gönder',
              onTap: _resendVerification,
            ),
        ],
        const SizedBox(height: 28),
        const SectionTitle('Ayarlar'),
        const SizedBox(height: 6),
        _SettingsRow(
          icon: Icons.person_outline_rounded,
          label: 'Profil bilgileri',
          onTap: _edit,
        ),
        _NotificationRow(value: _notifications, onChanged: _toggle),
        _DiagnosticsRow(value: _diagnostics, onChanged: _toggleDiagnostics),
        if (_moderator)
          _SettingsRow(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Moderasyon kuyruğu',
            onTap: () => context.push('/moderation'),
          ),
        _SettingsRow(
          icon: Icons.shield_outlined,
          label: 'KVKK ve gizlilik',
          onTap: () => context.push('/legal/privacy'),
        ),
        _SettingsRow(
          icon: Icons.description_outlined,
          label: 'Kullanım koşulları',
          onTap: () => context.push('/legal/terms'),
        ),
        _SettingsRow(
          icon: Icons.groups_outlined,
          label: 'Topluluk kuralları',
          onTap: () => context.push('/legal/community'),
        ),
        const SizedBox(height: 18),
        OutlinedButton(
          onPressed: _restartOnboarding,
          child: const Text('Onboarding’i tekrar göster'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _delete,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Hesabı sil'),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
        ),
      ],
    ),
  );
}

class _StreakPanel extends StatelessWidget {
  const _StreakPanel({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.local_fire_department_outlined,
          color: AppColors.amber,
          size: 30,
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sabah serisi',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              Text(
                '$days gün',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Text(
          'Devamlılık',
          style: TextStyle(
            color: AppColors.green,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          '$value',
          style: const TextStyle(
            color: AppColors.brown,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _AccountIdentity extends StatelessWidget {
  const _AccountIdentity({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        const Icon(Icons.verified_user_outlined, color: AppColors.green),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kalıcı hesap'),
              Text(
                email,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      children: [
        const Icon(Icons.notifications_none_rounded, color: AppColors.muted),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bildirimler'),
              SizedBox(height: 2),
              Text(
                'Namaz vakti ve grup hatırlatmaları',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        CupertinoSwitch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class _DiagnosticsRow extends StatelessWidget {
  const _DiagnosticsRow({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      children: [
        const Icon(Icons.monitor_heart_outlined, color: AppColors.muted),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tanılama verileri'),
              SizedBox(height: 2),
              Text(
                'Çökme ve anonim kullanım verilerini paylaş',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        CupertinoSwitch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.muted),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    ),
  );
}
