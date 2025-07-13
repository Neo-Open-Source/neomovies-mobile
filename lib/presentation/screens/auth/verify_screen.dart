import 'dart:async';

import 'package:flutter/material.dart';
import 'package:neomovies_mobile/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class VerifyScreen extends StatefulWidget {
  final String email;
  const VerifyScreen({super.key, required this.email});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  String _code = '';

  Timer? _timer;
  int _resendCooldown = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _canResend = false;
    _resendCooldown = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        setState(() {
          _resendCooldown--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  void _resendCode() {
    if (_canResend) {
      // Here you would call the provider to resend the code
      // For now, just restart the timer
      _startCooldown();
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      Provider.of<AuthProvider>(context, listen: false)
          .verifyEmail(widget.email, _code)
          .then((_) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        if (auth.state != AuthState.error) {
          Navigator.of(context).pop(); // Go back to LoginScreen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email verified. You can now login.')),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          return Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('We sent a verification code to ${widget.email}. Enter it below.'),
                  const SizedBox(height: 20),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Verification code'),
                    keyboardType: TextInputType.number,
                    validator: (value) => value!.isEmpty ? 'Enter code' : null,
                    onSaved: (value) => _code = value!,
                  ),
                  const SizedBox(height: 20),
                  if (auth.state == AuthState.loading)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Verify'),
                    ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: _canResend ? _resendCode : null,
                    child: Text(
                      _canResend
                          ? 'Resend code'
                          : 'Resend code in $_resendCooldown seconds',
                    ),
                  ),
                  if (auth.state == AuthState.error && auth.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(auth.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
