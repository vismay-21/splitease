import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const String _mobileAuthRedirectUrl = 'splitease://login-callback';

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _upiController = TextEditingController();

  bool _isSubmitting = false;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim();
  String get _name => _nameController.text.trim();
  String get _password => _passwordController.text;
  String get _upiId => _upiController.text.trim();

  bool get _isValidForm {
    return _name.isNotEmpty &&
        _email.contains('@') &&
        _password.length >= 6 &&
        _upiId.isNotEmpty;
  }

  Future<void> _createAccount() async {
    if (!_isValidForm) {
      _showMessage('Enter name, valid email, password (6+ chars), and UPI ID.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _client.auth.signUp(
        email: _email,
        password: _password,
        emailRedirectTo: kIsWeb ? null : _mobileAuthRedirectUrl,
        data: <String, dynamic>{'full_name': _name, 'upi_id': _upiId},
      );

      // Ensure user is returned to Sign In flow, even if auto-login happened.
      if (_client.auth.currentSession != null) {
        await _client.auth.signOut();
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(_email);
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not create account right now. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE7F3FF), Color(0xFFF7FBFF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F1D6CAB),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Set up your account',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF17324D),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'This will be used for login and your profile.',
                      style: TextStyle(color: Color(0xFF5A6E82)),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'User Name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _upiController,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'UPI ID',
                        hintText: 'name@bank',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _createAccount,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: const Color(0xFF1D6CAB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.person_add_alt_1),
                        label: Text(
                          _isSubmitting
                              ? 'Creating Account...'
                              : 'Create Account',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
