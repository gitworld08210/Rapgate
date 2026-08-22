import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _codeSent = false;
  String? _verificationId;
  int? _resendToken;
  String? _errorMessage;
  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Please enter phone number');
      return;
    }

    // Ensure country code
    final formattedPhone = phone.startsWith('+') ? phone : '+91$phone';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.sendPhoneOTP(
      phoneNumber: formattedPhone,
      resendToken: _resendToken,
      onCodeSent: (verificationId, resendToken) {
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _codeSent = true;
          _isLoading = false;
          _countdown = 60;
        });
        _startCountdown();
      },
      onAutoVerified: (credential) async {
        // Auto-verified on Android
        try {
          await authService.signInWithPhoneCredential(credential);
          if (mounted) Navigator.pop(context);
        } catch (e) {
          setState(() {
            _errorMessage = e.toString();
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        setState(() {
          _errorMessage = error;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter 6-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.verifyPhoneOTP(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Verification'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Icon(
                _codeSent ? Icons.sms_outlined : Icons.phone_android,
                size: 64,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                _codeSent
                    ? 'Enter the OTP sent to your phone'
                    : 'Enter your phone number',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 32),

              if (!_codeSent) ...[
                // Phone number input
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone),
                    prefixText: '+91 ',
                    hintText: '9876543210',
                  ),
                  maxLength: 10,
                ),
              ] else ...[
                // OTP input
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '6-digit OTP',
                    prefixIcon: Icon(Icons.lock_clock),
                    hintText: '123456',
                  ),
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                  ),
                ),
              ],

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (_codeSent ? _verifyOTP : _sendOTP),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _codeSent ? 'Verify OTP' : 'Send OTP',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),

              if (_codeSent) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _countdown > 0 ? null : _sendOTP,
                  child: Text(
                    _countdown > 0
                        ? 'Resend OTP in ${_countdown}s'
                        : 'Resend OTP',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
