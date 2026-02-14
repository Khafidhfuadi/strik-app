import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:strik_app/screens/auth_screen.dart';
import 'package:strik_app/widgets/primary_button.dart';

class EmailConfirmationErrorScreen extends StatelessWidget {
  const EmailConfirmationErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons
                    .mark_email_read_outlined, // Use email icon as positive reinforcement
                size: 80,
                color: Colors.orangeAccent,
              ),
              const SizedBox(height: 32),
              Text(
                'Link Kadaluarsa? Santai!',
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontSize: 24),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Biasanya ini karena link verifikasi udah otomatis dicek sama sistem email lo. Jadi kemungkian besar akun lo udah aktif kok!',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Coba login aja langsung ya 👇',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              PrimaryButton(
                text: 'Login Sekarang',
                onPressed: () {
                  // Navigate to AuthScreen and clear stack
                  Get.offAll(() => const AuthScreen());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
