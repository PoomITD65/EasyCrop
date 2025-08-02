import 'package:easycrop_e1/providers/user_provider.dart';
import 'package:easycrop_e1/screen/home_screen.dart';
import 'package:easycrop_e1/screen/signup_screen.dart';
import 'package:flutter/material.dart';
import 'dart:async'; // ✅ แก้ไขบรรทัดนี้
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easycrop_e1/services/api_service.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailOrUsernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  final ApiService _apiService = ApiService();

  @override
  void dispose() {
    _emailOrUsernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showErrorPopup(String message) {
    if (!mounted) return Future.value();
    return showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                const Text('เกิดข้อผิดพลาด', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final identifier = _emailOrUsernameController.text.trim();
      final password = _passwordController.text.trim();

      // 1. เรียก API เพื่อรับ Custom Token
      final Map<String, dynamic> response = await _apiService.login(identifier, password);
      print("🔑 LOGIN RESPONSE: $response");
      final String? customToken = response['access_token'] as String?;

      if (customToken == null || customToken.isEmpty) {
        throw Exception('ไม่ได้รับ Token จากเซิร์ฟเวอร์');
      }
      

      
      // 2. สั่งให้ Firebase Sign in แล้วจบเลย
      // AuthWrapper จะทำหน้าที่เปลี่ยนหน้าจอให้เองโดยอัตโนมัติ
      var res = await FirebaseAuth.instance.signInWithCustomToken(customToken);
      print(res);

      if (res.user != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        throw Exception('ไม่สามารถล็อกอินได้');
      }

    } catch (error) {
      if (mounted) {
        String errorMessage = 'เกิดข้อผิดพลาดในการเชื่อมต่อ';
        if (error is FirebaseAuthException) {
          errorMessage = 'Token ไม่ถูกต้องหรือหมดอายุ (${error.code})';
        } else if (error.toString().contains('Exception: ')) {
          errorMessage = error.toString().replaceFirst('Exception: ', '');
        }
        _showErrorPopup(errorMessage);
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/BG-main.png', fit: BoxFit.cover),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 75,
                        backgroundColor: Colors.white.withOpacity(0.9),
                        child: ClipOval(child: Image.asset('assets/mylogo.png', width: 130, height: 130, fit: BoxFit.contain)),
                      ),
                      const SizedBox(height: 16.0),
                      const Text('ระบบจัดการข้อมูลนักเรียน', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 8.0, color: Colors.black54, offset: Offset(2.0, 2.0))])),
                      const SizedBox(height: 32.0),
                      TextFormField(
                        controller: _emailOrUsernameController,
                        keyboardType: TextInputType.text,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'อีเมล หรือ ชื่อผู้ใช้',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          prefixIcon: const Icon(Icons.person_outline, color: Colors.white),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.3),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide.none),
                          errorStyle: const TextStyle(color: Colors.yellowAccent, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'กรุณากรอกอีเมลหรือชื่อผู้ใช้';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16.0),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'รหัสผ่าน',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          prefixIcon: const Icon(Icons.lock_outline, color: Colors.white),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.3),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide.none),
                          errorStyle: const TextStyle(color: Colors.yellowAccent, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty || value.length < 6) {
                            return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32.0),
                      if (_isLoading)
                        const CircularProgressIndicator(color: Colors.white)
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                              backgroundColor: Colors.black,
                            ),
                            child: const Text(
                              'เข้าสู่ระบบ',
                              style: TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16.0),
                      if (!_isLoading)
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (ctx) => const SignupScreen(),
                            ));
                          },
                          child: const Text(
                            'ยังไม่มีบัญชี? สมัครสมาชิก',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
