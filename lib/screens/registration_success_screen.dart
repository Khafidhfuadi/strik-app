import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strik_app/screens/auth_screen.dart';
import 'package:strik_app/widgets/primary_button.dart';
import 'package:strik_app/main.dart';

class RegistrationSuccessScreen extends StatefulWidget {
  final String email;

  const RegistrationSuccessScreen({super.key, required this.email});

  @override
  State<RegistrationSuccessScreen> createState() =>
      _RegistrationSuccessScreenState();
}

class _RegistrationSuccessScreenState extends State<RegistrationSuccessScreen>
    with WidgetsBindingObserver {
  bool _isResending = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Listen to auth state changes (e.g. when deep link opens app)
    supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        if (mounted) {
          debugPrint('RegistrationSuccessScreen: Session found! Popping...');
          // Pop everything to restart from AuthGate which will show HomeScreen
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSession();
    }
  }

  Future<void> _checkSession() async {
    final session = supabase.auth.currentSession;
    if (session != null) {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else {
      // Reload session to key sure we get the latest state
      // supabase.auth.refreshSession(); // optional
    }
  }

  Future<void> _resendEmail() async {
    if (_cooldown > 0) return;

    setState(() => _isResending = true);
    try {
      debugPrint("Resending email to: ${widget.email}");
      final response = await supabase.auth.resend(
        type: OtpType.signup,
        email: widget.email,
        emailRedirectTo: 'strikapp://auth/callback',
      );
      debugPrint("Resend response messageId: ${response.messageId}");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email verifikasi udah dikirim ulang! Cek SPAM folder juga yaa.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        _startCooldown();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Gagal kirim ulang: $e';
        if (e is AuthException && e.message.contains('rate limit')) {
          errorMessage = 'Sabar dulu ya, tunggu sebentar sebelum kirim ulang.';
          _startCooldown(); // Start cooldown if hit rate limit
        } else if (e.toString().contains('429')) {
          errorMessage = 'Kebanyakan request nih. Tunggu semenit ya!';
          _startCooldown();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _startCooldown() {
    setState(() => _cooldown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldown > 0) {
        setState(() => _cooldown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.mark_email_read_outlined,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 32),
            Text(
              'Cek Email Lo!',
              style: Theme.of(context).textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Kita udah kirim link verifikasi ke ${widget.email}.\nKlik linknya biar lo bisa masuk ke Strik.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            PrimaryButton(
              text: 'Kembali ke Login',
              onPressed: () {
                // Navigate back to AuthScreen and remove all previous routes
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                  (route) => false,
                );
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                try {
                  await _checkSession();

                  if (!context.mounted) return;

                  if (supabase.auth.currentSession == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Belum terverifikasi nih, coba cek lagi emailnya.',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Udah Verifikasi? Cek status'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: (_isResending || _cooldown > 0) ? null : _resendEmail,
              child: _isResending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _cooldown > 0
                          ? 'Tunggu $_cooldown detik ya...'
                          : 'Link kadaluarsa? Kirim ulang',
                      style: TextStyle(
                        color: _cooldown > 0
                            ? Colors.grey
                            : Colors.orangeAccent,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
