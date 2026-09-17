import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_controller.dart';

/// Authentication actions and platform redirect configuration for the auth view.
class AuthController {
  AuthController(this.store);

  final AppController store;

  String get email => store.client?.auth.currentUser?.email ?? '';

  String get redirectUrl {
    const configured = String.fromEnvironment('AUTH_REDIRECT_URL');
    if (configured.isNotEmpty) return configured;
    if (!kIsWeb) return 'moulatkeskes://auth-callback/';
    return Uri(
      scheme: Uri.base.scheme,
      host: Uri.base.host,
      port: Uri.base.hasPort ? Uri.base.port : null,
      path: Uri.base.path,
    ).toString();
  }

  GoTrueClient get _auth {
    if (store.client == null) {
      throw StateError('هذه نسخة تجريبية. يلزم ربط Supabase لتفعيل الحسابات.');
    }
    return store.client!.auth;
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithPassword(email: email.trim(), password: password);
    await store.refresh();
  }

  /// Returns true when email confirmation is needed before signing in.
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    if (role != 'customer' && role != 'seller') {
      throw StateError('اختر نوع حساب صحيحاً.');
    }
    final response = await _auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: redirectUrl,
      data: {'name': name.trim(), 'role': role},
    );
    if (response.session != null) await store.refresh();
    return response.session == null;
  }

  Future<void> requestPasswordReset(String email) =>
      _auth.resetPasswordForEmail(email.trim(), redirectTo: redirectUrl);

  Future<void> updatePassword(String password) async {
    await _auth.updateUser(UserAttributes(password: password));
    store.recovering = false;
    await store.refresh();
  }

  Future<void> cancelRecovery() async {
    store.recovering = false;
    await store.signOut();
    await store.refresh();
  }

  static String errorMessage(Object error) {
    if (error is StateError) return error.message;
    if (error is AuthException) {
      return switch (error.code) {
        'invalid_credentials' => 'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
        'email_not_confirmed' => 'افتح رسالة التأكيد في بريدك ثم سجّل الدخول.',
        'user_already_exists' ||
        'email_exists' => 'يوجد حساب بهذا البريد. جرّب تسجيل الدخول.',
        'weak_password' => 'اختر كلمة مرور أقوى، من ٨ أحرف على الأقل.',
        'over_email_send_rate_limit' || 'over_request_rate_limit' =>
          'طلبات كثيرة خلال وقت قصير. انتظر قليلاً ثم حاول مجدداً.',
        'same_password' => 'اختر كلمة مرور مختلفة عن كلمة المرور الحالية.',
        'otp_expired' ||
        'session_expired' ||
        'session_not_found' => 'انتهت صلاحية الرابط. اطلب رابط استعادة جديداً.',
        _ => 'تعذر إتمام العملية. تحقق من البيانات والاتصال ثم حاول مجدداً.',
      };
    }
    return 'تعذر الاتصال. تحقق من الإنترنت ثم حاول مجدداً.';
  }
}
