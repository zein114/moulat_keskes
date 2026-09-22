import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_repository.dart';
import 'app_controller.dart';

/// Authentication actions and platform redirect configuration for the auth view.
class AuthController {
  AuthController(this.store);

  final AppController store;
  late final AuthRepository? _repository = store.client == null
      ? null
      : AuthRepository(store.client!);

  String get email => _repository?.email ?? '';

  AuthRepository get _auth {
    final repository = _repository;
    if (repository == null) {
      throw StateError('هذه نسخة تجريبية. يلزم ربط Supabase لتفعيل الحسابات.');
    }
    return repository;
  }

  Future<void> signIn(String email, String password) async {
    await _auth.login(email: email, password: password);
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
      throw StateError('اختر نوع حساب صحيحا.');
    }
    final response = await _auth.signUp(
      name: name,
      email: email,
      password: password,
      isSeller: role == 'seller',
    );
    if (response.session != null) await store.refresh();
    return response.session == null;
  }

  Future<void> requestPasswordReset(String email) =>
      _auth.requestPasswordReset(email);

  Future<void> resendConfirmation(String email) =>
      _auth.resendConfirmation(email);

  Future<void> updatePassword(String password) async {
    await _auth.updatePassword(password);
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
        'email_not_confirmed' => 'افتح رسالة التأكيد في بريدك ثم سجل الدخول.',
        'user_already_exists' ||
        'email_exists' => 'يوجد حساب بهذا البريد. جرب تسجيل الدخول.',
        'weak_password' => 'اختر كلمة مرور أقوى، من 8 أحرف على الأقل.',
        'over_email_send_rate_limit' || 'over_request_rate_limit' =>
          'طلبات كثيرة خلال وقت قصير. انتظر قليلا ثم حاول مجددا.',
        'same_password' => 'اختر كلمة مرور مختلفة عن كلمة المرور الحالية.',
        'otp_expired' ||
        'session_expired' ||
        'session_not_found' => 'انتهت صلاحية الرابط. اطلب رابط استعادة جديدا.',
        _ => 'تعذر إتمام العملية. تحقق من البيانات والاتصال ثم حاول مجددا.',
      };
    }
    if (error is PostgrestException) {
      if (error.code == '42501') {
        return 'تم تسجيل الدخول، لكن صلاحيات قاعدة البيانات تمنع الوصول. طبّق migration وRLS من Supabase.';
      }
      if (error.code == 'PGRST116') {
        return 'الحساب موجود لكن ملفه غير موجود في profiles. شغّل trigger/migration ثم أعد المحاولة.';
      }
      return 'خطأ قاعدة البيانات (${error.code}): ${error.message}';
    }
    return 'تعذر الاتصال. تحقق من الإنترنت ثم حاول مجددا.';
  }
}
