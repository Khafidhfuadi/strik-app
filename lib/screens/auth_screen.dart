import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strik_app/main.dart';
import 'package:strik_app/widgets/primary_button.dart';
import 'package:strik_app/widgets/custom_text_field.dart';
import 'package:strik_app/screens/registration_success_screen.dart';

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
  bool _isPasswordVisible = false;
  String? _selectedGender;

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    final email = _emailController.text;
    final password = _passwordController.text;

    try {
      if (_isSignUp) {
        if (_selectedGender == null) {
          throw const AuthException('Pilih gender dulu dong! 🙏');
        }

        await supabase.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': email.split('@')[0], 'gender': _selectedGender},
          emailRedirectTo: 'strikapp://auth/callback',
        );

        // Try to update profiles table directly just in case trigger doesn't map it
        try {
          final user = supabase.auth.currentUser;
          if (user != null) {
            await supabase
                .from('profiles')
                .update({'gender': _selectedGender})
                .eq('id', user.id);
          }
        } catch (_) {
          // Ignore error here, as typical flow might rely on trigger or user not confirmed yet
        }

        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => RegistrationSuccessScreen(email: email),
            ),
          );
          // Don't flip _isSignUp since we want to stay in sign-up mode if they come back,
          // or we just navigated away anyway.
        }
      } else {
        // Sign In Logic
        String finalEmail = email;

        // If input doesn't contain '@', treat it as username
        if (!email.contains('@')) {
          try {
            final data = await supabase.rpc(
              'get_email_by_username',
              params: {'username_input': email},
            );

            if (data == null) {
              throw const AuthException('Username tidak ditemukan! 🧐');
            }
            finalEmail = data as String;
          } catch (e) {
            // If RPC fails or returns null handled above
            if (e is AuthException) rethrow; // Pass our custom error
            throw const AuthException('Gagal ngecek username. Coba lagi!');
          }
        }

        await supabase.auth.signInWithPassword(
          email: finalEmail,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Yah, ada error nih...')));
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
                _isSignUp ? 'Gabung Strik, Yuk!' : 'Welcome Back, Coy!',
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              CustomTextField(
                controller: _emailController,
                label: 'Username / Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _passwordController,
                label: 'Sandi',
                obscureText: !_isPasswordVisible,
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.white70,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
              if (_isSignUp) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedGender,
                  decoration: InputDecoration(
                    labelText: 'Gender (buat personalisasi AI)',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: Colors.white70,
                    ),
                    labelStyle: const TextStyle(color: Colors.white70),
                  ),
                  dropdownColor: const Color(0xFF1E1E1E),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(
                      value: 'Laki-laki',
                      child: Text('Laki-laki (Bro)'),
                    ),
                    DropdownMenuItem(
                      value: 'Perempuan',
                      child: Text('Perempuan (Sis)'),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedGender = val),
                  validator: (val) =>
                      val == null && _isSignUp ? 'Wajib diisi ya' : null,
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                text: _isSignUp ? 'Daftar Kuy' : 'Masuk Sini',
                isLoading: _isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(
                  _isSignUp
                      ? 'Udah punya akun? Masuk dong'
                      : 'Belum punya akun? Bikin dulu lahh',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
