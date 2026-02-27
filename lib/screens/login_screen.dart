import 'package:flutter/material.dart';
import 'package:visionvolcan_site_app/screens/site_list_screen.dart';
import 'package:visionvolcan_site_app/main.dart';
import 'package:gotrue/gotrue.dart';
import 'dart:async';
import 'dart:io';

class LoginScreen extends StatefulWidget{
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordObscured = true;
  bool _isLoggingIn = false;

  String _getLoginErrorMessage(Object error) {
    if (error is TimeoutException) {
      return 'Login timed out. Please check your internet connection and try again.';
    }

    if (error is SocketException) {
      return 'You are offline. Please check your internet connection.';
    }

    if (error is AuthException) {
      final msg = (error.message).toLowerCase();
      if (msg.contains('invalid login credentials') || msg.contains('invalid') || msg.contains('credentials')) {
        return 'Wrong credentials. Please check email and password.';
      }
      return error.message;
    }

    final raw = error.toString().toLowerCase();
    if (raw.contains('socketexception') || raw.contains('failed host lookup') || raw.contains('network')) {
      return 'You are offline. Please check your internet connection.';
    }
    if (raw.contains('invalid login credentials') || raw.contains('invalid') && raw.contains('credential')) {
      return 'Wrong credentials. Please check email and password.';
    }

    return 'Something went wrong. Please try again.';
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/loginpage.jpg',
                  height: 200,
                ),
                const SizedBox(height: 25),
                Image.asset('assets/images/loginpagevv.jpg', height: 35,),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                        fillColor: Colors.grey.shade200,
                        filled: true,
                      labelText: "User Id",
                        hintText: "Enter Your UserID",
                        border: OutlineInputBorder(
                          borderRadius:BorderRadius.circular(8)
                        )
                    )
                  ),
                ),
                SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: TextFormField(
                    controller: _passwordController,
                      obscureText: _isPasswordObscured,
                      decoration: InputDecoration(
                          fillColor: Colors.grey.shade200,
                          filled: true,
                          labelText: "Password",
                          hintText: "Enter Your Password",
                          border: OutlineInputBorder(
                          borderRadius:BorderRadius.circular(8)
                          ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordObscured ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordObscured = !_isPasswordObscured;
                            });
                          },
                        ),
                      ),
                  ),
                ),
                SizedBox(height: 18),
                SizedBox(
                  width:double.infinity,
                  height: 40,
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 10),
                    child: ElevatedButton(
                        onPressed: _isLoggingIn
                            ? null
                            : () async {
                                final email = _usernameController.text.trim();
                                final password = _passwordController.text.trim();

                                if (email.isEmpty || password.isEmpty) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please enter User Id and Password.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                setState(() => _isLoggingIn = true);
                                FocusScope.of(context).unfocus();

                                try {
                                  // Quick connectivity check (socket to Supabase)
                                  await Socket.connect('nxxrobftgkkqybbvilub.supabase.co', 443).timeout(const Duration(seconds: 8));

                                  final authResponse = await supabase.auth
                                      .signInWithPassword(
                                        email: email,
                                        password: password,
                                      )
                                      .timeout(const Duration(seconds: 20));

                                  if (!context.mounted) return;
                                  if (authResponse.user != null) {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(builder: (context) => const SiteListScreen()),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Login failed. Please try again.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } catch (error) {
                                  if (!context.mounted) return;
                                  final msg = _getLoginErrorMessage(error);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(msg),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                } finally {
                                  if (mounted) {
                                    setState(() => _isLoggingIn = false);
                                  }
                                }
                              },

                        style: ElevatedButton.styleFrom(
                          shadowColor: const Color(0x802196F3),
                          elevation: 20,
                          backgroundColor: Colors.blue.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)
                          ),
                        ),
                        child: _isLoggingIn
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                "Login",
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              )
                    ),
                  ),
                )

              ]
            ),
          ),
        ),
      )
    );
  }
}