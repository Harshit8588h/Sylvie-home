import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/preferences_provider.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpVerificationScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  /// Verifies the OTP without blocking on the Firebase SDK's returned
  /// Future. On Realme / Oppo / Vivo the Play Integrity token exchange
  /// often leaves signInWithCredential hanging even though the auth
  /// session is already established, so we additionally watch
  /// authStateChanges() and consider ourselves done the moment a user
  /// appears. A 30-second timeout surfaces a retry message instead of a
  /// forever-spinning dot.
  Future<void> _verify() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _error = '6 digit ka OTP daalo');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    final auth = ref.read(firebaseAuthProvider);
    final credential = PhoneAuthProvider.credential(
      verificationId: widget.verificationId,
      smsCode: code,
    );

    // Fire the sign-in; only use its result for error surfacing. If it
    // succeeds silently we still find out via the auth-state stream.
    unawaited(
      auth.signInWithCredential(credential).catchError((Object e) {
        if (!mounted) return null;
        setState(() {
          _verifying = false;
          if (e is FirebaseAuthException) {
            _error = e.code == 'invalid-verification-code'
                ? 'Galat OTP. Dubara check karo.'
                : (e.message ?? 'Verification failed');
          } else {
            _error = e.toString();
          }
        });
        return null;
      }),
    );

    try {
      await auth
          .authStateChanges()
          .firstWhere((u) => u != null)
          .timeout(const Duration(seconds: 30));
      // Remember we're signed in so the auth gate waits patiently for
      // cache restore on the next cold start instead of flashing sign-in.
      await ref.read(hasSignedInBeforeProvider.notifier).set(true);
      // AuthGate's home swap doesn't auto-pop routes that were pushed
      // on top of it, so we clear the stack back to the AuthGate root
      // ourselves — otherwise this OTP screen keeps showing on top of
      // HomeShell with its spinner spinning forever.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _verifying = false;
          _error =
              'Verification 30 sec se zyada le raha. App band karke dubara kholo — likely sign-in ho chuka hai.';
        });
      }
    } catch (_) {
      // Already handled by the signInWithCredential error path above.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OTP verify')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Text(
              'OTP daalo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.phoneNumber} par SMS bheja hai.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                counterText: '',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                if (v.length == 6) _verify();
              },
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
              onPressed: _verifying ? null : _verify,
              child: _verifying
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }
}
