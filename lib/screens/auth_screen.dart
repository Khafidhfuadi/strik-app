import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strik_app/main.dart';
import 'package:strik_app/widgets/primary_button.dart';
import 'package:strik_app/widgets/custom_text_field.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    final email = _emailController.text;
    final password = _passwordController.text;

    try {
      if (_isSignUp) {
        await supabase.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': email.split('@')[0]}, // Simple default name
          emailRedirectTo: 'strikapp://auth/callback',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created! Please sign in.')),
          );
          setState(() => _isSignUp = false);
        }
      } else {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An unexpected error occurred')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isSignUp ? 'Join Strik' : 'Welcome Back',
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              CustomTextField(
                controller: _emailController,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _passwordController,
                label: 'Password',
                obscureText: true,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                text: _isSignUp ? 'Sign Up' : 'Sign In',
                isLoading: _isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(
                  _isSignUp
                      ? 'Already have an account? Sign In'
                      : 'New to Strik? Sign Up',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
