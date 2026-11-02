import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'app/app.dart';
import 'core/services/app_session_controller.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/invite_service.dart';
import 'core/services/telemetry_service.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: _BootstrapGate()));

  // Render a Flutter frame immediately. Firebase, App Check, authentication,
  // and the remote session decision can then initialize without extending the
  // native launch-screen wait.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_bootstrap());
  });
}

Future<void> _bootstrap() async {
  tz_data.initializeTimeZones();
  const useFirebase = bool.fromEnvironment('USE_FIREBASE', defaultValue: true);
  if (useFirebase) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
    await TelemetryService.instance.initialize();
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }
  await AppSessionController.instance.initialize(
    onOpenGroup: (groupId) => appRouter.go('/home/groups/$groupId'),
  );
  unawaited(InviteService.instance.initialize());
  InviteService.instance.startNavigation(
    (groupId) => appRouter.go('/home/groups/$groupId'),
  );
  if (useFirebase) {
    final groupId = PushNotificationService.instance.takeInitialGroupId();
    if (groupId != null) appRouter.go('/home/groups/$groupId');
  }
}

class _BootstrapGate extends StatelessWidget {
  const _BootstrapGate();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSessionController.instance,
      builder: (context, _) {
        if (AppSessionController.instance.initialized) {
          return const NamazGrubumApp();
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.materialLight,
          home: const _BootstrapScreen(),
        );
      },
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.warmWhite,
      body: Center(
        child: Image(
          image: AssetImage('assets/branding/launch_logo_master.png'),
          width: 168,
          height: 168,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
