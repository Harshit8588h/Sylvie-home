import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import 'otp_verification_screen.dart';

/// Phone-number sign-in. Collects a +91 number, kicks off Firebase phone
/// verification, and hands off to the OTP screen. Auto-retrieval on
/// Android fills the code without the user typing it when the SMS arrives.
class PhoneSignInScreen extends ConsumerStatefulWidget {
  const PhoneSignInScreen({super.key});

  @override
  ConsumerState<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends ConsumerState<PhoneSignInScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? v) {
    final raw = (v ?? '').replaceAll(RegExp(r'\s+'), '');
    if (raw.isEmpty) return 'Phone number daalo';
    if (!RegExp(r'^\d{10}$').hasMatch(raw)) return '10 digit ka Indian number';
    return null;
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });

    final phone = '+91${_phoneController.text.replaceAll(RegExp(r'\s+'), '')}';
    final auth = ref.read(firebaseAuthProvider);

    await auth.verifyPhoneNumber(
      phoneNumber: phone,
      // Android instant verification — succeeds without the user typing.
      verificationCompleted: (credential) async {
        try {
          await auth.signInWithCredential(credential);
          // authStateProvider will flip and the router will take us home.
        } on FirebaseAuthException catch (e) {
          if (mounted) setState(() => _error = e.message);
        }
      },
      verificationFailed: (e) {
        if (mounted) {
          setState(() {
            _sending = false;
            _error = e.message ?? 'Verification failed';
          });
        }
      },
      codeSent: (verificationId, _) {
        if (!mounted) return;
        setState(() => _sending = false);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              verificationId: verificationId,
              phoneNumber: phone,
            ),
          ),
        );
      },
      codeAutoRetrievalTimeout: (_) {},
      timeout: const Duration(seconds: 60),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text(
                'Apna phone number daalo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Family mein add hone ke liye OTP aayega.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                autofocus: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  prefixText: '+91  ',
                  labelText: 'Phone number',
                  border: OutlineInputBorder(),
                ),
                validator: _validatePhone,
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              FilledButton(
                onPressed: _sending ? null : _sendCode,
                child: _sending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send OTP'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
