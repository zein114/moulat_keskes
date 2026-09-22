import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../controllers/auth_controller.dart';
import 'shared.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.store, this.recovery = false});

  final AppController store;
  final bool recovery;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late final AuthController _auth = AuthController(widget.store);
  bool _signup = false;
  bool _reset = false;
  bool _busy = false;
  bool _obscure = true;
  bool _confirmationPending = false;
  String _confirmationEmail = '';
  String _role = 'customer';
  String? _error;
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      if (widget.recovery) {
        await _auth.updatePassword(_password.text);
        if (!mounted) return;
        toast(context, 'تم تغيير كلمة المرور بنجاح.');
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      } else if (_reset) {
        await _auth.requestPasswordReset(_email.text);
        if (!mounted) return;
        setState(() {
          _message =
              'إذا كان البريد مرتبطاً بحساب، ستصلك رسالة لاستعادة كلمة المرور. تحقّق من البريد غير المرغوب أيضاً.';
        });
      } else if (_signup) {
        final needsConfirmation = await _auth.signUp(
          name: _name.text,
          email: _email.text,
          password: _password.text,
          role: _role,
        );
        if (!mounted) return;
        if (needsConfirmation) {
          setState(() {
            _signup = false;
            _confirmationPending = true;
            _confirmationEmail = _email.text.trim();
            _password.clear();
            _message =
                'تحقّق من بريدك لتأكيد الحساب، ثم عد لتسجيل الدخول. إذا كان لديك حساب بالفعل، استخدم تسجيل الدخول أو استعادة كلمة المرور.';
          });
        } else {
          Navigator.of(context).maybePop();
        }
      } else {
        await _auth.signIn(_email.text, _password.text);
        if (!mounted) return;
        Navigator.of(context).maybePop();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = AuthController.errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendConfirmation() async {
    if (_busy || _confirmationEmail.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await _auth.resendConfirmation(_confirmationEmail);
      if (mounted) {
        setState(() {
          _message = 'تم إرسال رسالة تأكيد جديدة. افتح آخر رسالة فقط.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = AuthController.errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changeMode({bool signup = false, bool reset = false}) {
    setState(() {
      _signup = signup;
      _reset = reset;
      _error = null;
      _message = null;
      _password.clear();
      _confirm.clear();
      _form.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.recovery
        ? 'كلمة مرور جديدة'
        : _reset
        ? 'استعادة كلمة المرور'
        : _signup
        ? 'إنشاء حساب'
        : 'أهلاً بعودتك';
    return PageFrame(
      title: widget.recovery ? 'استعادة الحساب' : 'حساب مولات كسكس',
      child: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          children: [
            const Brand(large: true),
            const SizedBox(height: 26),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: widget.store.demo
                    ? const EmptyState(
                        'أنت في النسخة التجريبية',
                        'يمكنك تجربة الطلبات ولوحة البائعة من حسابي. البيانات مؤقتة، ولا يتم إنشاء حسابات أو إرسال طلبات حقيقية. فعّل اتصال Supabase لتسجيل الدخول.',
                        icon: Icons.explore_outlined,
                      )
                    : Panel(
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 26,
                                  color: green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.recovery
                                    ? 'اختر كلمة مرور جديدة وآمنة لحسابك.'
                                    : _reset
                                    ? 'أدخل بريدك لنرسل رابط الاستعادة.'
                                    : 'أدخل بيانات حسابك للمتابعة.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: muted),
                              ),
                              const SizedBox(height: 26),
                              if (_signup && !widget.recovery) ...[
                                TextFormField(
                                  controller: _name,
                                  enabled: !_busy,
                                  autofillHints: const [AutofillHints.name],
                                  textInputAction: TextInputAction.next,
                                  maxLength: 80,
                                  decoration: const InputDecoration(
                                    labelText: 'الاسم',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (value) =>
                                      (value?.trim().length ?? 0) < 2
                                      ? 'أدخل الاسم من حرفين على الأقل.'
                                      : null,
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'نوع الحساب',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(
                                      value: 'customer',
                                      label: Text('زبون'),
                                      icon: Icon(Icons.shopping_bag_outlined),
                                    ),
                                    ButtonSegment(
                                      value: 'seller',
                                      label: Text('بائعة'),
                                      icon: Icon(Icons.storefront_outlined),
                                    ),
                                  ],
                                  selected: {_role},
                                  onSelectionChanged: _busy
                                      ? null
                                      : (value) =>
                                            setState(() => _role = value.first),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'يُحدد نوع الحساب عند الإنشاء ولا يمكن تغييره لاحقاً من التطبيق. حساب البائعة يتيح الشراء أيضاً.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: muted,
                                    height: 1.7,
                                  ),
                                ),
                                const SizedBox(height: 18),
                              ],
                              if (!widget.recovery) ...[
                                TextFormField(
                                  controller: _email,
                                  enabled: !_busy,
                                  keyboardType: TextInputType.emailAddress,
                                  textDirection: TextDirection.ltr,
                                  autocorrect: false,
                                  autofillHints: const [AutofillHints.email],
                                  textInputAction: _reset
                                      ? TextInputAction.done
                                      : TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'البريد الإلكتروني',
                                    prefixIcon: Icon(Icons.mail_outline),
                                  ),
                                  validator: (value) =>
                                      RegExp(
                                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                      ).hasMatch(value?.trim() ?? '')
                                      ? null
                                      : 'أدخل بريداً إلكترونياً صحيحاً.',
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (!_reset || widget.recovery) ...[
                                TextFormField(
                                  controller: _password,
                                  enabled: !_busy,
                                  obscureText: _obscure,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  textDirection: TextDirection.ltr,
                                  autofillHints: [
                                    _signup || widget.recovery
                                        ? AutofillHints.newPassword
                                        : AutofillHints.password,
                                  ],
                                  decoration: InputDecoration(
                                    labelText: widget.recovery
                                        ? 'كلمة المرور الجديدة'
                                        : 'كلمة المرور',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      tooltip: _obscure
                                          ? 'إظهار كلمة المرور'
                                          : 'إخفاء كلمة المرور',
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'أدخل كلمة المرور.';
                                    }
                                    if ((_signup || widget.recovery) &&
                                        value.length < 8) {
                                      return 'استخدم ٨ أحرف على الأقل.';
                                    }
                                    return null;
                                  },
                                ),
                                if (widget.recovery) ...[
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _confirm,
                                    enabled: !_busy,
                                    obscureText: true,
                                    textDirection: TextDirection.ltr,
                                    decoration: const InputDecoration(
                                      labelText: 'تأكيد كلمة المرور',
                                    ),
                                    validator: (value) =>
                                        value != _password.text
                                        ? 'كلمتا المرور غير متطابقتين.'
                                        : null,
                                  ),
                                ],
                              ],
                              if (_error != null || _message != null) ...[
                                const SizedBox(height: 18),
                                Semantics(
                                  liveRegion: true,
                                  child: Panel(
                                    color: _error == null
                                        ? sage
                                        : const Color(0xFFFFEDE6),
                                    child: Text(
                                      _error ?? _message!,
                                      style: TextStyle(
                                        color: _error == null
                                            ? green
                                            : const Color(0xFF9D3726),
                                        height: 1.7,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (_confirmationPending && !widget.recovery) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _busy ? null : _resendConfirmation,
                                  child: const Text('إعادة إرسال رسالة التأكيد'),
                                ),
                              ],
                              const SizedBox(height: 24),
                              FilledButton(
                                onPressed: _busy ? null : _submit,
                                child: _busy
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        widget.recovery
                                            ? 'حفظ كلمة المرور'
                                            : _reset
                                            ? 'إرسال رابط الاستعادة'
                                            : _signup
                                            ? 'إنشاء حساب'
                                            : 'دخول',
                                      ),
                              ),
                              if (!widget.recovery) ...[
                                const SizedBox(height: 8),
                                if (!_signup && !_reset)
                                  TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _changeMode(reset: true),
                                    child: const Text('نسيت كلمة المرور؟'),
                                  ),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _changeMode(
                                          signup: !_signup && !_reset,
                                        ),
                                  child: Text(
                                    _signup || _reset
                                        ? 'لديك حساب؟ تسجيل الدخول'
                                        : 'جديد هنا؟ أنشئ حسابك',
                                  ),
                                ),
                              ] else
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                          setState(() => _busy = true);
                                          try {
                                            await _auth.cancelRecovery();
                                          } catch (error) {
                                            if (mounted) {
                                              setState(() {
                                                _busy = false;
                                                _error =
                                                    AuthController.errorMessage(
                                                      error,
                                                    );
                                              });
                                            }
                                          }
                                        },
                                  child: const Text('إلغاء والعودة'),
                                ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
