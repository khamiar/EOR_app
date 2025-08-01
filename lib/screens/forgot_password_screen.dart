import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  String step = 'email';
  String email = '';
  String otp = '';
  String newPassword = '';
  String confirmPassword = '';
  bool isLoading = false;

  final _formKey = GlobalKey<FormState>();

  void showToast(String msg, {Color? bgColor}) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: bgColor ?? Colors.black87,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  void requestOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { isLoading = true; });
    final result = await AuthService.requestPasswordReset(email);
    setState(() {
      isLoading = false;
      if (result == 'OTP sent to email') {
        step = 'otp';
        otp = '';
        newPassword = '';
        confirmPassword = '';
      }
      showToast(result!, bgColor: result == 'OTP sent to email' ? Colors.green : Colors.red);
    });
  }

  void verifyOtp() async {
    if (otp.isEmpty) {
      showToast('Enter OTP', bgColor: Colors.red);
      return;
    }
    setState(() { isLoading = true; });
    final result = await AuthService.verifyOtp(email, otp);
    setState(() {
      isLoading = false;
      if (result == 'OTP verified') {
        step = 'reset';
        newPassword = '';
        confirmPassword = '';
      }
      showToast(result!, bgColor: result == 'OTP verified' ? Colors.green : Colors.red);
    });
  }

  void resetPassword() async {
    if (newPassword != confirmPassword || newPassword.isEmpty) {
      showToast('Passwords do not match', bgColor: Colors.red);
      return;
    }
    setState(() { isLoading = true; });
    final result = await AuthService.resetPassword(email, otp, newPassword);
    setState(() {
      isLoading = false;
      if (result == 'Password reset successful') {
        // Clear all fields and return to email step after success
        step = 'email';
        email = '';
        otp = '';
        newPassword = '';
        confirmPassword = '';
        showToast(result!, bgColor: Colors.green);
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.of(context).pop();
        });
      } else {
        showToast(result!, bgColor: Colors.red);
      }
    });
  }

  void goBackToEmailStep() {
    setState(() {
      step = 'email';
      otp = '';
      newPassword = '';
      confirmPassword = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (step == 'email') ...[
                      const Text(
                        'Reset your password',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                        onChanged: (v) => email = v,
                        validator: (v) => v == null || v.isEmpty ? 'Enter email' : null,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : requestOtp,
                          child: isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Send OTP'),
                        ),
                      ),
                    ] else if (step == 'otp') ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Email: $email',
                          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'OTP',
                          prefixIcon: Icon(Icons.vpn_key),
                        ),
                        onChanged: (v) => otp = v,
                        validator: (v) => v == null || v.isEmpty ? 'Enter OTP' : null,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : verifyOtp,
                          child: isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Verify OTP'),
                        ),
                      ),
                    ] else if (step == 'reset') ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Email: $email',
                          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'New Password',
                          prefixIcon: Icon(Icons.lock),
                        ),
                        obscureText: true,
                        onChanged: (v) => newPassword = v,
                        validator: (v) => v == null || v.isEmpty ? 'Enter new password' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        onChanged: (v) => confirmPassword = v,
                        validator: (v) => v == null || v.isEmpty ? 'Confirm password' : null,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : resetPassword,
                          child: isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Reset Password'),
                        ),
                      ),
                    ],
                    if (step == 'otp' || step == 'reset') ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: goBackToEmailStep,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Change Email'),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
