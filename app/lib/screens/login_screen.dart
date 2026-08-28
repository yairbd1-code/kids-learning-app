import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config.dart';
import '../platform/web_wrapper.dart' as google_web;
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onAuthenticated;

  const LoginScreen({super.key, required this.authService, required this.onAuthenticated});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _AuthMode { login, register, join }

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _familyNameController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _joinCodeController = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool _googleReady = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleAuthSubscription;

  bool get _googleSignInEnabled => googleClientId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_googleSignInEnabled) {
      _initGoogleSignIn();
    }
  }

  Future<void> _initGoogleSignIn() async {
    // אם האתחול נכשל (למשל אין Google Play Services, או סביבת בדיקות בלי
    // תמיכה בפלטפורמה) - פשוט לא מציגים את אפשרות ה-Google, בלי לקרוס.
    try {
      final signIn = GoogleSignIn.instance;
      // clientId משמש ב-Web; serverClientId משמש באנדרואיד כדי לקבל idToken
      // שאפשר לאמת מול השרת שלנו. שני הפרמטרים מצביעים על אותו Web Client ID.
      await signIn.initialize(clientId: googleClientId, serverClientId: googleClientId);
      _googleAuthSubscription = signIn.authenticationEvents.listen(
        _handleGoogleAuthEvent,
        onError: (Object e) => setState(() => _errorMessage = 'שגיאה בהתחברות עם Google: $e'),
      );
      if (mounted) setState(() => _googleReady = true);
    } catch (_) {
      // Google Sign-In לא זמין בסביבה הזו - ממשיכים בלי האפשרות הזו.
    }
  }

  Future<void> _signInWithGoogleNative() async {
    try {
      await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      setState(() => _errorMessage = 'שגיאה בהתחברות עם Google: ${e.description ?? e.code}');
    }
  }

  Future<void> _handleGoogleAuthEvent(GoogleSignInAuthenticationEvent event) async {
    if (event is! GoogleSignInAuthenticationEventSignIn) return;

    final idToken = event.user.authentication.idToken;
    if (idToken == null) {
      setState(() => _errorMessage = 'לא התקבל טוקן מ-Google');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.loginWithGoogle(idToken);
      widget.onAuthenticated();
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _googleAuthSubscription?.cancel();
    _familyNameController.dispose();
    _parentNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      switch (_mode) {
        case _AuthMode.register:
          await widget.authService.register(
            familyName: _familyNameController.text.trim(),
            parentName: _parentNameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
        case _AuthMode.join:
          await widget.authService.joinFamily(
            joinCode: _joinCodeController.text.trim(),
            parentName: _parentNameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
        case _AuthMode.login:
          await widget.authService.login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      }
      widget.onAuthenticated();
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_mode) {
      _AuthMode.login => 'התחברות',
      _AuthMode.register => 'הרשמה',
      _AuthMode.join => 'הצטרפות למשפחה',
    };
    final submitLabel = switch (_mode) {
      _AuthMode.login => 'התחברות',
      _AuthMode.register => 'הרשמה',
      _AuthMode.join => 'הצטרפות',
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_mode == _AuthMode.register) ...[
                    TextFormField(
                      controller: _familyNameController,
                      decoration: const InputDecoration(labelText: 'שם המשפחה'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'שדה חובה' : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_mode == _AuthMode.join) ...[
                    TextFormField(
                      controller: _joinCodeController,
                      decoration: const InputDecoration(
                        labelText: 'קוד משפחה',
                        helperText: 'תקבלו את זה מבן/בת הזוג, במסך ההגדרות שלהם',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'שדה חובה' : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_mode == _AuthMode.register || _mode == _AuthMode.join) ...[
                    TextFormField(
                      controller: _parentNameController,
                      decoration: const InputDecoration(labelText: 'השם שלך'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'שדה חובה' : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'אימייל'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || !v.contains('@')) return 'אימייל לא תקין';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'סיסמה'),
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.length < 8) return 'סיסמה חייבת להיות באורך 8 תווים לפחות';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_errorMessage != null) ...[
                    Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(submitLabel),
                  ),
                  if (_mode == _AuthMode.login)
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() {
                                _mode = _AuthMode.register;
                                _errorMessage = null;
                              }),
                      child: const Text('משפחה חדשה? הרשמה'),
                    )
                  else
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() {
                                _mode = _AuthMode.login;
                                _errorMessage = null;
                              }),
                      child: const Text('כבר יש לך חשבון? התחברות'),
                    ),
                  if (_mode != _AuthMode.join)
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() {
                                _mode = _AuthMode.join;
                                _errorMessage = null;
                              }),
                      child: const Text('קיבלת קוד משפחה? הצטרפות'),
                  ),
                  if (_googleSignInEnabled && _googleReady) ...[
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('או')),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: GoogleSignIn.instance.supportsAuthenticate()
                          ? OutlinedButton.icon(
                              onPressed: _isSubmitting ? null : _signInWithGoogleNative,
                              icon: const Icon(Icons.login),
                              label: const Text('התחברות עם Google'),
                            )
                          : google_web.renderButton(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
