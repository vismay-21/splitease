import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _mobileAuthRedirectUrl = 'splitease://login-callback';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSigningIn = false;
  bool _isSigningUp = false;
  bool _isSendingResetLink = false;
  bool _showActionAnimations = false;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (mounted) {
        setState(() {
          _showActionAnimations = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim();

  bool get _hasValidEmail => _email.isNotEmpty && _email.contains('@');

  Future<void> _signIn() async {
    if (!_hasValidEmail || _passwordController.text.isEmpty) {
      _showMessage('Please enter a valid email and password.');
      return;
    }

    setState(() => _isSigningIn = true);

    try {
      await _client.auth.signInWithPassword(
        email: _email,
        password: _passwordController.text,
      );

      _showMessage('Sign in successful. Welcome back!');
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Something went wrong while signing in.');
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  Future<void> _createAccount() async {
    if (!_hasValidEmail || _passwordController.text.length < 6) {
      _showMessage('Use a valid email and a password with at least 6 characters.');
      return;
    }

    setState(() => _isSigningUp = true);

    try {
      await _client.auth.signUp(
        email: _email,
        password: _passwordController.text,
        emailRedirectTo: kIsWeb ? null : _mobileAuthRedirectUrl,
      );

      _showMessage('Account created. Check your email for verification if required.');
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Something went wrong while creating your account.');
    } finally {
      if (mounted) {
        setState(() => _isSigningUp = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    if (!_hasValidEmail) {
      _showMessage('Enter your email first, then tap Forgot password.');
      return;
    }

    setState(() => _isSendingResetLink = true);

    try {
      await _client.auth.resetPasswordForEmail(
        _email,
        redirectTo: kIsWeb ? null : _mobileAuthRedirectUrl,
      );
      _showMessage('Password reset email sent. Please check your inbox.');
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to send reset email right now.');
    } finally {
      if (mounted) {
        setState(() => _isSendingResetLink = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE7F3FF), Color(0xFFF7FBFF)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    children: [
                      SizedBox(
                        height: constraints.maxHeight / 3,
                        child: const _HeaderLogoArea(),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(28),
                            topRight: Radius.circular(28),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF17324D),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sign in to continue splitting expenses with your friends.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF5A6E82),
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email ID',
                                prefixIcon: Icon(Icons.mail_outline),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock_outline),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isSendingResetLink ? null : _forgotPassword,
                                child: _isSendingResetLink
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Forgot password?'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            AnimatedSlide(
                              offset: _showActionAnimations
                                  ? Offset.zero
                                  : const Offset(0, 0.25),
                              duration: const Duration(milliseconds: 550),
                              curve: Curves.easeOutBack,
                              child: AnimatedOpacity(
                                opacity: _showActionAnimations ? 1 : 0,
                                duration: const Duration(milliseconds: 450),
                                child: _AnimatedActionButton(
                                  label: 'Sign In',
                                  icon: Icons.login,
                                  loading: _isSigningIn,
                                  onPressed: _isSigningIn || _isSigningUp ? null : _signIn,
                                  primary: true,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            AnimatedSlide(
                              offset: _showActionAnimations
                                  ? Offset.zero
                                  : const Offset(0, 0.35),
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOutBack,
                              child: AnimatedOpacity(
                                opacity: _showActionAnimations ? 1 : 0,
                                duration: const Duration(milliseconds: 650),
                                child: _AnimatedActionButton(
                                  label: 'Create New Account',
                                  icon: Icons.person_add_alt_1,
                                  loading: _isSigningUp,
                                  onPressed:
                                      _isSigningIn || _isSigningUp ? null : _createAccount,
                                  primary: false,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeaderLogoArea extends StatelessWidget {
  const _HeaderLogoArea();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.wallet_rounded,
              size: 42,
              color: Color(0xFF1D6CAB),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'SpliTease',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Color(0xFF17324D),
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedActionButton extends StatefulWidget {
  const _AnimatedActionButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.primary,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  State<_AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<_AnimatedActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.loading;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = 1 + (math.sin(_controller.value * 2 * math.pi) * 0.015);

        return Transform.scale(
          scale: widget.loading ? 1 : pulse,
          child: Opacity(
            opacity: isEnabled ? 1 : 0.65,
            child: SizedBox(
              height: 54,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onPressed,
                style: ElevatedButton.styleFrom(
                  elevation: widget.primary ? 8 : 1,
                  backgroundColor:
                      widget.primary ? const Color(0xFF1D6CAB) : Colors.white,
                  foregroundColor:
                      widget.primary ? Colors.white : const Color(0xFF1D6CAB),
                  side: widget.primary
                      ? BorderSide.none
                      : const BorderSide(color: Color(0xFF1D6CAB), width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: widget.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(widget.icon),
                label: Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}