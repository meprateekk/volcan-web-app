import 'package:flutter/material.dart';
import 'package:visionvolcan_site_app/screens/site_list_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:visionvolcan_site_app/main.dart';

class LoginScreen extends StatefulWidget{
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordObscured = true;


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
                  height: 120,
                ),
                const SizedBox(height: 24),
                Image.asset('assets/images/loginpagevv.jpg', height: 200,),
                const SizedBox(height: 32),
                TextFormField(
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
                SizedBox(height: 16),
                TextFormField(
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
                SizedBox(height: 18),
                SizedBox(
                  width:double.infinity,
                  height: 40,
                  child: ElevatedButton(
                      onPressed: () async {
                        try {
            
                          final email = _usernameController.text.trim();
                          final password = _passwordController.text.trim();
            
                          final authResponse = await supabase.auth.signInWithPassword(
                            email: email,
                            password: password,
                          );
            
                          if (authResponse.user != null) {
            
                            if (context.mounted) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (context) => const SiteListScreen()),
                              );
                            }
                          }
                        } catch (error) {
            
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: ${error.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        shadowColor: const Color(0x802196F3),
                        elevation: 20,
                        backgroundColor: Colors.blue.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)
                        )
                      ),
                      child: Text("Login", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),)
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