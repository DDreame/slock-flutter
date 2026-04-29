import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/application/register_controller.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  String? _errorText;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorText != null) ...[
                Text(
                  _errorText!,
                  key: const ValueKey('register-error'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                key: const ValueKey('register-display-name'),
                controller: _displayNameController,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('register-email'),
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('register-password'),
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    key: const ValueKey('register-password-toggle'),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey('register-submit'),
                onPressed: state.isLoading ? null : _submit,
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Register'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final displayName = _displayNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (displayName.isEmpty) {
      setState(() => _errorText = 'Display name is required.');
      return;
    }
    if (email.isEmpty) {
      setState(() => _errorText = 'Email is required.');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _errorText = 'Enter a valid email address.');
      return;
    }
    if (password.length < 8) {
      setState(() => _errorText = 'Password must be at least 8 characters.');
      return;
    }

    setState(() => _errorText = null);

    await ref.read(registerControllerProvider.notifier).submit(
          email: email,
          password: password,
          displayName: displayName,
        );

    final state = ref.read(registerControllerProvider);
    if (!mounted) return;
    if (state.hasError) {
      final error = state.error;
      setState(() {
        _errorText = error is AppFailure
            ? (error.message ?? 'Registration failed. Please try again.')
            : 'Registration failed. Please try again.';
      });
    }
  }
}
