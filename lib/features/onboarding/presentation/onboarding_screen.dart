import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/models.dart';
import '../../../core/services/alarm_coordinator.dart';
import '../../../core/services/account_service.dart';
import '../../../core/services/app_session_controller.dart';
import '../../../core/services/demo_session_controller.dart';
import '../../../core/services/invite_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/prayer_schedule_sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.requestNotificationPermission});

  /// Injects permission outcomes for tests without Firebase or a native prompt.
  final Future<bool> Function()? requestNotificationPermission;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController(text: 'İstanbul');
  int _page = 0;
  Gender _gender = Gender.male;
  Madhhab _madhhab = Madhhab.hanafi;
  bool _useLocation = true;
  bool _acceptedPrivacy = false;
  bool _submitting = false;
  bool _notificationsEnabled = true;
  bool? _notificationPermissionGranted;
  bool _requestingNotifications = false;
  String? _nameError;
  String? _cityError;

  Future<void> _requestNotificationPermission() async {
    if (!mounted ||
        _requestingNotifications ||
        (Firebase.apps.isEmpty &&
            widget.requestNotificationPermission == null)) {
      return;
    }
    setState(() => _requestingNotifications = true);
    try {
      final granted =
          await (widget.requestNotificationPermission?.call() ??
              PushNotificationService.instance.requestPermission());
      if (mounted) setState(() => _notificationPermissionGranted = granted);
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      if (mounted) {
        await _showMessage(
          'Bildirim izni kontrol edilemedi. Tekrar deneyebilirsin.',
        );
      }
    } finally {
      if (mounted) setState(() => _requestingNotifications = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_page == 0 && _nameController.text.trim().isEmpty) {
      setState(() {
        _nameError = 'Devam etmek için görünen adını yaz.';
      });
      return;
    }
    if (_page == 1 && _cityController.text.trim().isEmpty) {
      setState(() => _cityError = 'Namaz vakitleri için bir şehir yaz.');
      return;
    }
    if (_page < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _nameError = 'Devam etmek için görünen adını yaz.';
      });
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      if (Firebase.apps.isNotEmpty) {
        final router = GoRouter.of(context);
        final user = FirebaseAuth.instance.currentUser;
        final displayName = _nameController.text.trim();
        if (user == null) {
          throw StateError('Aktif kullanıcı oturumu bulunamadı.');
        }
        // Ask while onboarding is still visible, before routing to home.
        if (_notificationsEnabled && _notificationPermissionGranted == null) {
          await _requestNotificationPermission();
        }
        await FirebaseFirestore.instance.doc('users/${user.uid}').set({
          'displayName': displayName,
          'displayInitial': displayName.characters.first.toUpperCase(),
          'gender': _gender.name,
          'madhhab': _madhhab.name,
          'city': _cityController.text.trim(),
          'privacyNoticeVersion': '2026-09-05',
          'privacyNoticeAcceptedAt': FieldValue.serverTimestamp(),
          'specialCategoryConsent': true,
          'specialCategoryConsentAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'notificationPreferences': <String, bool>{
            'enabled':
                _notificationsEnabled && _notificationPermissionGranted == true,
          },
        }, SetOptions(merge: true));
        try {
          await PushNotificationService.instance.syncEnabledPreference(
            _notificationsEnabled && _notificationPermissionGranted == true,
          );
        } catch (error) {
          debugPrint(
            'Notification device preference synchronization failed: $error',
          );
        }
        // Do not finish onboarding with missing or silently incorrect prayer
        // coordinates. The service can resolve a typed city when location is
        // unavailable and returns a user-facing error when it cannot.
        await PrayerScheduleSyncService.instance.sync(
          requestLocation: _useLocation,
          fallbackCity: _cityController.text.trim(),
          force: true,
        );
        await AppSessionController.instance.markOnboardingComplete();
        try {
          await AlarmCoordinator.instance.initialize(
            onOpenGroup: (groupId) => router.go('/home/groups/$groupId'),
          );
        } catch (error) {
          debugPrint('Prayer alarm initialization failed: $error');
        }
        if (_notificationsEnabled && _notificationPermissionGranted == true) {
          try {
            await PushNotificationService.instance
                .requestPermissionAndRegister();
          } catch (error) {
            debugPrint('Push notification registration failed: $error');
          }
          try {
            await AlarmCoordinator.instance.requestPermissionAndSchedule();
          } catch (error) {
            debugPrint('Prayer alarm scheduling failed: $error');
          }
        }
      }
      if (Firebase.apps.isEmpty) {
        await DemoSessionController.instance.completeOnboarding(
          displayName: _nameController.text.trim(),
          city: _cityController.text.trim(),
          madhhab: _madhhab,
          notificationsEnabled: _notificationsEnabled,
        );
        await AppSessionController.instance.markOnboardingComplete();
      }
      if (mounted) {
        final pendingGroupId = InviteService.instance.takePendingGroupId();
        if (pendingGroupId != null && pendingGroupId.isNotEmpty) {
          context.go('/home/groups/$pendingGroupId');
        } else {
          context.go('/home');
        }
      }
    } catch (error) {
      debugPrint('Onboarding completion failed: $error');
      if (mounted) {
        final message = error is PrayerScheduleSyncException
            ? error.message
            : 'Kurulum tamamlanamadı. Bağlantını kontrol edip tekrar dene.';
        await _showMessage(message);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(message),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _signIn() async {
    final email = TextEditingController();
    final password = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabına giriş yap'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'E-posta'),
            ),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Şifre'),
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
            child: const Text('Giriş yap'),
          ),
        ],
      ),
    );
    final emailValue = email.text.trim();
    final passwordValue = password.text;
    email.dispose();
    password.dispose();
    if (accepted != true || !mounted) return;
    try {
      await _requestNotificationPermission();
      await AccountService.instance.signIn(
        email: emailValue,
        password: passwordValue,
      );
      await AppSessionController.instance.refreshForCurrentUser();
      if (mounted) {
        final pendingGroupId = InviteService.instance.takePendingGroupId();
        if (pendingGroupId != null && pendingGroupId.isNotEmpty) {
          context.go('/home/groups/$pendingGroupId');
        } else {
          context.go('/home');
        }
      }
    } on FirebaseAuthException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-posta veya şifre hatalı.')),
        );
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Şifreni yenile'),
        content: TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'E-posta'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sıfırlama bağlantısı gönder'),
          ),
        ],
      ),
    );
    final emailValue = email.text.trim();
    email.dispose();
    if (accepted != true || !mounted || !emailValue.contains('@')) return;
    try {
      await AccountService.instance.sendPasswordReset(emailValue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Şifre sıfırlama e-postası gönderildi.'),
          ),
        );
      }
    } on FirebaseAuthException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sıfırlama e-postası gönderilemedi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptivePage(
      body: Column(
        children: <Widget>[
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (value) => setState(() => _page = value),
              children: <Widget>[
                _WelcomeStep(
                  nameController: _nameController,
                  nameError: _nameError,
                  onNameChanged: (_) {
                    if (_nameError != null) {
                      setState(() => _nameError = null);
                    }
                  },
                  gender: _gender,
                  onGenderChanged: (value) => setState(() => _gender = value),
                ),
                _PreferencesStep(
                  madhhab: _madhhab,
                  cityController: _cityController,
                  cityError: _cityError,
                  onCityChanged: (_) {
                    if (_cityError != null) {
                      setState(() => _cityError = null);
                    }
                  },
                  onMadhhabChanged: (value) => setState(() => _madhhab = value),
                ),
                _PermissionsStep(
                  notificationsEnabled: _notificationsEnabled,
                  onNotificationsChanged: (value) =>
                      setState(() => _notificationsEnabled = value),
                  permissionGranted: _notificationPermissionGranted,
                  requestingPermission: _requestingNotifications,
                  onRequestPermission: _requestNotificationPermission,
                  useLocation: _useLocation,
                  onLocationChanged: (value) =>
                      setState(() => _useLocation = value),
                  acceptedPrivacy: _acceptedPrivacy,
                  onPrivacyChanged: (value) =>
                      setState(() => _acceptedPrivacy = value),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    SizedBox(
                      width: 44,
                      child: _page == 0
                          ? null
                          : IconButton(
                              tooltip: 'Geri',
                              onPressed: _submitting
                                  ? null
                                  : () => _pageController.previousPage(
                                      duration: const Duration(
                                        milliseconds: 280,
                                      ),
                                      curve: Curves.easeOutCubic,
                                    ),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List<Widget>.generate(
                          3,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: index == _page ? 28 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: index == _page
                                  ? AppColors.green
                                  : AppColors.brownPale,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${_page + 1}/3',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AdaptivePrimaryButton(
                  label: _submitting
                      ? 'Hazırlanıyor…'
                      : _page == 2
                      ? 'Başla'
                      : 'Devam Et',
                  onPressed:
                      _submitting ||
                          _requestingNotifications ||
                          (_page == 2 && !_acceptedPrivacy)
                      ? null
                      : _continue,
                ),
                if (_page == 0) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      const Text(
                        'Hesabın var mı?',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                      TextButton(
                        onPressed: Firebase.apps.isNotEmpty ? _signIn : null,
                        child: const Text('Giriş yap'),
                      ),
                      TextButton(
                        onPressed: Firebase.apps.isNotEmpty
                            ? _resetPassword
                            : null,
                        child: const Text('Şifremi unuttum'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLayout extends StatelessWidget {
  const _StepLayout({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.children,
    required this.icon,
  });

  final String eyebrow;
  final String title;
  final String body;
  final List<Widget> children;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 750;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, compact ? 12 : 30, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: compact ? 44 : 50,
            height: compact ? 44 : 50,
            decoration: BoxDecoration(
              color: AppColors.greenPale,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.green, size: 24),
          ),
          SizedBox(height: compact ? 12 : 24),
          Text(
            eyebrow.toUpperCase(),
            style: const TextStyle(
              color: AppColors.green,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: compact ? 6 : 10),
          Text(
            title,
            style: TextStyle(
              color: AppColors.brown,
              fontSize: compact ? 29 : 32,
              height: 1.16,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
            ),
          ),
          SizedBox(height: compact ? 8 : 12),
          Text(
            body,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: compact ? 15 : 16,
              height: 1.38,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: compact ? 14 : 22),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.warmWhite,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.line),
              ),
              child: Padding(
                padding: EdgeInsets.all(compact ? 14 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({
    required this.nameController,
    required this.nameError,
    required this.onNameChanged,
    required this.gender,
    required this.onGenderChanged,
  });

  final TextEditingController nameController;
  final String? nameError;
  final ValueChanged<String> onNameChanged;
  final Gender gender;
  final ValueChanged<Gender> onGenderChanged;

  @override
  Widget build(BuildContext context) => _StepLayout(
    icon: Icons.groups_2_outlined,
    eyebrow: 'Seni tanıyalım',
    title: 'Namaza birlikte hazırlan.',
    body: 'Adını belirle; sana uygun grupları ve deneyimi hazırlayalım.',
    children: <Widget>[
      const _FieldLabel('İsmin'),
      AdaptiveTextField(
        controller: nameController,
        placeholder: 'Görünen adın',
        onChanged: onNameChanged,
      ),
      if (nameError != null) ...<Widget>[
        const SizedBox(height: 7),
        Text(
          nameError!,
          style: const TextStyle(
            color: CupertinoColors.systemRed,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
      const SizedBox(height: 22),
      const _FieldLabel('Cinsiyet'),
      Row(
        children: <Widget>[
          Expanded(
            child: _ChoiceTile(
              label: 'Kadın',
              selected: gender == Gender.female,
              onTap: () => onGenderChanged(Gender.female),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ChoiceTile(
              label: 'Erkek',
              selected: gender == Gender.male,
              onTap: () => onGenderChanged(Gender.male),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      const Text(
        'Yalnızca sana uygun grupları göstermek için kullanılır.',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    ],
  );
}

class _PreferencesStep extends StatelessWidget {
  const _PreferencesStep({
    required this.madhhab,
    required this.cityController,
    required this.cityError,
    required this.onCityChanged,
    required this.onMadhhabChanged,
  });

  final Madhhab madhhab;
  final TextEditingController cityController;
  final String? cityError;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<Madhhab> onMadhhabChanged;

  @override
  Widget build(BuildContext context) => _StepLayout(
    icon: Icons.schedule_rounded,
    eyebrow: 'Vakitlerini hazırlayalım',
    title: 'Doğru vakit, bulunduğun yerde.',
    body:
        'Namaz vakitlerini bulunduğun şehre ve tercihine göre hazırlayacağız.',
    children: <Widget>[
      const _FieldLabel('Mezhep'),
      Row(
        children: <Widget>[
          Expanded(
            child: _ChoiceTile(
              label: 'Hanefi',
              selected: madhhab == Madhhab.hanafi,
              onTap: () => onMadhhabChanged(Madhhab.hanafi),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ChoiceTile(
              label: 'Şafii',
              selected: madhhab == Madhhab.shafii,
              onTap: () => onMadhhabChanged(Madhhab.shafii),
            ),
          ),
        ],
      ),
      const SizedBox(height: 22),
      const _FieldLabel('Şehir'),
      AdaptiveTextField(
        controller: cityController,
        placeholder: 'Şehir ara',
        prefixIcon: Icons.location_city_outlined,
        onChanged: onCityChanged,
      ),
      if (cityError != null) ...<Widget>[
        const SizedBox(height: 7),
        Text(
          cityError!,
          style: const TextStyle(
            color: CupertinoColors.systemRed,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ],
  );
}

class _PermissionsStep extends StatelessWidget {
  const _PermissionsStep({
    required this.notificationsEnabled,
    required this.onNotificationsChanged,
    required this.permissionGranted,
    required this.requestingPermission,
    required this.onRequestPermission,
    required this.useLocation,
    required this.onLocationChanged,
    required this.acceptedPrivacy,
    required this.onPrivacyChanged,
  });

  final bool useLocation;
  final bool notificationsEnabled;
  final ValueChanged<bool> onNotificationsChanged;
  final bool? permissionGranted;
  final bool requestingPermission;
  final VoidCallback onRequestPermission;
  final ValueChanged<bool> onLocationChanged;
  final bool acceptedPrivacy;
  final ValueChanged<bool> onPrivacyChanged;

  @override
  Widget build(BuildContext context) => _StepLayout(
    icon: Icons.notifications_active_outlined,
    eyebrow: 'Kontrol sende',
    title: 'Hatırlatmaları sen yönet.',
    body: 'İzinleri şimdi seçebilir, daha sonra Ayarlar’dan değiştirebilirsin.',
    children: <Widget>[
      _PermissionRow(
        icon: Icons.notifications_none_rounded,
        title: 'Bildirimler',
        description: 'Vakit öncesi ve vakit sırasında namaz hatırlatmaları',
        enabled: notificationsEnabled,
        onChanged: onNotificationsChanged,
      ),
      if (notificationsEnabled) ...<Widget>[
        const SizedBox(height: 8),
        Text(
          permissionGranted == true
              ? 'Bildirim izni verildi. Sesli namaz hatırlatmaları hazırlanacak.'
              : permissionGranted == false
              ? 'İzin kapalı. iPhone/telefon Ayarları → Namaz Grubum → Bildirimler bölümünden açabilirsin. İzin vermeden de devam edebilirsin.'
              : 'Hatırlatma alabilmek için sistem bildirim iznini aç. İzin vermeden de kurulumu tamamlayabilirsin.',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        if (permissionGranted != true)
          TextButton.icon(
            onPressed: requestingPermission ? null : onRequestPermission,
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(
              requestingPermission
                  ? 'İzin kontrol ediliyor…'
                  : 'Bildirimlere izin ver',
            ),
          ),
        const Text(
          'Seslerin açık olduğundan emin ol. iOS Odak ve sessiz mod ayarları sesli uyarıyı sınırlayabilir.',
          style: TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
      const SizedBox(height: 12),
      _PermissionRow(
        icon: Icons.location_on_outlined,
        title: 'Konum',
        description: 'Seyahatte vakitleri otomatik güncelle',
        enabled: useLocation,
        onChanged: onLocationChanged,
      ),
      const SizedBox(height: 14),
      Material(
        color: Colors.transparent,
        child: CheckboxListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: acceptedPrivacy,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (value) => onPrivacyChanged(value == true),
          title: const Text(
            'İbadet ve katılım verilerimin hizmet için işlenmesine açık rıza veriyorum.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          subtitle: TextButton(
            onPressed: () => context.push('/legal/privacy'),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text('KVKK Aydınlatma Metni ve ayrıntılar'),
            ),
          ),
        ),
      ),
    ],
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.brown,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    ),
  );
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
        decoration: BoxDecoration(
          color: selected ? AppColors.greenPale : AppColors.warmWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.green : AppColors.line,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.brown,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            if (selected) ...<Widget>[
              const SizedBox(width: 6),
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.green,
                size: 19,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.enabled,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String description;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.warmWhite,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: AppColors.greenPale,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.green, size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.brown,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        CupertinoSwitch(
          value: enabled,
          activeTrackColor: AppColors.green,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}
