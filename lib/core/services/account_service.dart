import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountService {
  AccountService._();

  static final instance = AccountService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  User? get currentUser => _auth.currentUser;

  Future<void> makePermanent({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Oturum bulunamadı.');
    if (!user.isAnonymous) {
      throw StateError('Bu hesap zaten kalıcı.');
    }
    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    final result = await user.linkWithCredential(credential);
    await result.user?.sendEmailVerification();
    await result.user?.getIdToken(true);
    await _syncProfile();
  }

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _syncProfile();
  }

  Future<void> resendVerification() async {
    final user = _auth.currentUser;
    if (user == null || user.emailVerified) return;
    await user.sendEmailVerification();
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> refresh() async {
    await _auth.currentUser?.reload();
    await _auth.currentUser?.getIdToken(true);
    if (_auth.currentUser?.isAnonymous == false) await _syncProfile();
  }

  Future<void> _syncProfile() async {
    await _functions.httpsCallable('syncAccountProfile').call();
  }
}
