import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';

import 'core/constants/app_strings.dart';
import 'login_screen.dart';
import 'reset_password_screen.dart';
import 'services/auth_service.dart';

enum OtpFlow { signup, forgotPassword }

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final OtpFlow flow;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.flow,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();

  Timer? _timer;
  int _secondsLeft = 60;
  bool _isLoading = false;
  bool _isResending = false;
  bool _hasOtpError = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _otpFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _showMessage(String message, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_secondsLeft > 0 || _isResending) return;

    setState(() => _isResending = true);
    try {
      if (widget.flow == OtpFlow.signup) {
        await AuthService.resendSignupOtp(widget.email);
      } else {
        await AuthService.forgotPassword(widget.email);
      }
      _showMessage(AppStrings.otpResendSuccess, color: Colors.green);
      _startCountdown();
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();

    if (otp.length != 6) {
      setState(() => _hasOtpError = true);
      HapticFeedback.heavyImpact();
      _showMessage(AppStrings.otpRequired);
      return;
    }

    setState(() {
      _isLoading = true;
      _hasOtpError = false;
    });

    try {
      if (widget.flow == OtpFlow.signup) {
        await AuthService.verifySignupOtp(widget.email, otp);
        if (!mounted) return;

        await AuthService.markPendingOnboarding(widget.email);

        _showMessage(AppStrings.otpVerifySuccessSignup, color: Colors.green);
        await Future.delayed(const Duration(milliseconds: 220));
        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 460),
            pageBuilder: (_, animation, secondaryAnimation) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.06),
                    end: Offset.zero,
                  ).animate(curved),
                  child: LoginScreen(initialEmail: widget.email),
                ),
              );
            },
          ),
          (_) => false,
        );
        return;
      }

      await AuthService.verifyForgotPasswordOtp(widget.email, otp);
      if (!mounted) return;

      _showMessage(AppStrings.otpVerifySuccessForgot, color: Colors.green);
      Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (_, animation, secondaryAnimation) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: ResetPasswordScreen(email: widget.email, otpCode: otp),
          ),
        ),
      );
    } catch (e) {
      setState(() => _hasOtpError = true);
      HapticFeedback.heavyImpact();
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final defaultPinTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: const Color(0xFF4CAF50), width: 2),
    );

    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: Colors.red.shade500, width: 2),
      color: const Color(0xFFFFF4F4),
    );

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.otpTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${AppStrings.otpInstructionPrefix}${widget.email}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Pinput(
                  controller: _otpController,
                  focusNode: _otpFocusNode,
                  autofocus: true,
                  length: 6,
                  keyboardType: TextInputType.number,
                  forceErrorState: _hasOtpError,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  errorPinTheme: errorPinTheme,
                  onChanged: (value) {
                    if (_hasOtpError) {
                      setState(() => _hasOtpError = false);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _secondsLeft == 0 ? 1 : 0.75,
                child: Row(
                  children: [
                    Text(
                      _secondsLeft > 0
                          ? '${AppStrings.otpCountdownPrefix}$_secondsLeft${AppStrings.otpCountdownSuffix}'
                          : AppStrings.otpResendReady,
                      style: TextStyle(
                        color: _secondsLeft > 0
                            ? Colors.grey.shade700
                            : Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: (_secondsLeft == 0 && !_isResending)
                          ? _resendOtp
                          : null,
                      child: _isResending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(AppStrings.otpResendButton),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleVerifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _isLoading
                        ? const SizedBox(
                            key: ValueKey('loading-submit'),
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.3,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            key: const ValueKey('label-submit'),
                            widget.flow == OtpFlow.signup
                                ? AppStrings.otpSubmitSignup
                                : AppStrings.otpSubmitForgotPassword,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
