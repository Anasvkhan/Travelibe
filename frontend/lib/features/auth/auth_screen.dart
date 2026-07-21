import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/theme/theme_tokens.dart';
import '../../core/api/api_client.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _isSignUp = false;
  bool _isOtpVerification = false; // Controls display of verification step
  bool _isLoading = false;
  final ApiClient _apiClient = ApiClient();

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required';
    }
    if (value.trim().length < 3) {
      return 'Username must be at least 3 characters long';
    }
    final usernameRegex = RegExp(r"^[a-zA-Z0-9_]+$");
    if (!usernameRegex.hasMatch(value.trim())) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isSignUp) {
        // Signup call - now returns no token, requires OTP validation next
        await _apiClient.dio.post('/auth/signup', data: {
          'email': _emailController.text.trim(),
          'username': _usernameController.text.trim(),
          'password': _passwordController.text,
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account registered! Verification code sent to your email.')),
          );
          setState(() {
            _isOtpVerification = true; // Switch view to OTP input
          });
        }
      } else {
        // Login call
        final response = await _apiClient.dio.post('/auth/login', data: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        });

        final token = response.data['token'];
        if (token != null) {
          await _apiClient.saveToken(token);
          if (mounted) {
            context.go('/feed');
          }
        }
      }
    } on DioException catch (e) {
      String errorMessage = 'An error occurred. Please try again.';
      if (e.response != null && e.response?.data != null && e.response?.data['error'] != null) {
        errorMessage = e.response?.data['error'];
      } else if (e.message != null) {
        errorMessage = e.message!;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.isEmpty || code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid OTP code'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiClient.dio.post('/auth/verify-otp', data: {
        'email': _emailController.text.trim(),
        'code': code,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified successfully! You can now log in.'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isOtpVerification = false;
          _isSignUp = false; // Move to Login tab
          _passwordController.clear();
          _confirmPasswordController.clear();
          _otpController.clear();
        });
      }
    } on DioException catch (e) {
      String errorMessage = 'Verification failed. Try again.';
      if (e.response != null && e.response?.data != null && e.response?.data['error'] != null) {
        errorMessage = e.response?.data['error'];
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _apiClient.dio.post('/auth/send-otp', data: {
        'email': _emailController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new OTP code has been sent to your email.'), backgroundColor: Color(0xFF0F766E)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to resend OTP. Try again.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: const BoxDecoration(
          color: ThemeTokens.sandCream,
        ),
        child: Center(
          child: SingleChildScrollView(
            child: _isOtpVerification ? _buildOtpView() : _buildLoginRegisterView(),
          ),
        ),
      ),
    );
  }

  // OTP Verification view
  Widget _buildOtpView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_unread_outlined, size: 80, color: ThemeTokens.travelTeal),
        const SizedBox(height: 16),
        Text(
          'Email Verification',
          textAlign: TextAlign.center,
          style: ThemeTokens.heading1.copyWith(color: ThemeTokens.travelTeal, fontSize: 28),
        ),
        const SizedBox(height: 12),
        Text(
          'We have sent a verification code to ${_emailController.text.trim()}. Please enter it below to activate your account.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.45),
        ),
        const SizedBox(height: 36),
        // OTP input field
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
          decoration: const InputDecoration(
            hintText: '000000',
            hintStyle: TextStyle(color: Colors.grey, letterSpacing: 8),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 24),
        // Verify Button
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: ThemeTokens.warmCoral,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Verify Code', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),
        // Resend / Back Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _isLoading ? null : _resendOtp,
              child: const Text('Resend Code', style: TextStyle(color: ThemeTokens.travelTeal, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isOtpVerification = false;
                  _isSignUp = false; // Return to login
                });
              },
              child: const Text('Back to Login', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  // Standard Login / Register form view
  Widget _buildLoginRegisterView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.explore,
            size: 80,
            color: ThemeTokens.travelTeal,
          ),
          const SizedBox(height: 16),
          Text(
            'Travelibe',
            textAlign: TextAlign.center,
            style: ThemeTokens.heading1.copyWith(
              color: ThemeTokens.travelTeal,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Find your people. Plan the trip. Live the story.',
            textAlign: TextAlign.center,
            style: ThemeTokens.caption,
          ),
          const SizedBox(height: 48),
          // Email Field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email, color: ThemeTokens.travelTeal),
            ),
            validator: _validateEmail,
          ),
          const SizedBox(height: 16),
          // Username Field (only in Sign Up mode)
          if (_isSignUp) ...[
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person, color: ThemeTokens.travelTeal),
              ),
              validator: _validateUsername,
            ),
            const SizedBox(height: 16),
          ],
          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock, color: ThemeTokens.travelTeal),
            ),
            validator: _validatePassword,
          ),
          const SizedBox(height: 16),
          // Confirm Password Field (only in Sign Up mode)
          if (_isSignUp) ...[
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline, color: ThemeTokens.travelTeal),
              ),
              validator: _validateConfirmPassword,
            ),
            const SizedBox(height: 24),
          ],
          if (!_isSignUp) const SizedBox(height: 8),
          // Submit Button
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeTokens.warmCoral,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              disabledBackgroundColor: ThemeTokens.warmCoral.withOpacity(0.6),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(_isSignUp ? 'Create Account' : 'Sign In'),
          ),
          const SizedBox(height: 16),
          // Toggle Mode Button
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    setState(() {
                      _isSignUp = !_isSignUp;
                      _formKey.currentState?.reset();
                    });
                  },
            child: Text(
              _isSignUp ? 'Already have an account? Sign In' : 'New to Travelibe? Create Account',
              style: const TextStyle(color: ThemeTokens.travelTeal, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
