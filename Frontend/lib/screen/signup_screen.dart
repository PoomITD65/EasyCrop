import 'package:flutter/material.dart';
import 'dart:async';

// Import Firebase Packages
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
// Import intl package
import 'package:intl/intl.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  // --- ฟังก์ชันสำหรับแสดง Popup ---
  Future<void> _showPopup(BuildContext ctx, String title, String message, IconData icon, Color iconColor) {
    if (!mounted) return Future.value();
    
    return showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) {
        Timer(const Duration(seconds: 3), () {
          Navigator.of(dialogCtx).pop();
        });

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
                Icon(icon, color: iconColor, size: 48),
                const SizedBox(height: 16),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- ฟังก์ชันสำหรับสมัครสมาชิก (ที่อัปเดตแล้ว) ---
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    try {
      final username = _usernameController.text.trim();
      final usernameQuery = FirebaseDatabase.instance.ref('accounts').orderByChild('username').equalTo(username);
      final snapshot = await usernameQuery.get();

      if (snapshot.exists) {
        throw Exception('ชื่อผู้ใช้งานนี้มีคนใช้แล้ว');
      }

      final today = DateTime.now();
      final dateKey = DateFormat('yyyyMMdd').format(today); 
      final counterRef = FirebaseDatabase.instance.ref('counters/$dateKey');
      
      String customFormatId = '';

      final TransactionResult transactionResult = await counterRef.runTransaction((Object? data) {
        int currentCount = (data as int?) ?? 0;
        currentCount++;
        return Transaction.success(currentCount);
      });

      if (transactionResult.committed) {
        final newCount = transactionResult.snapshot.value as int;
        final displayDate = DateFormat('ddMMyyyy').format(today);
        final paddedCount = newCount.toString().padLeft(3, '0');
        customFormatId = '$displayDate$paddedCount';
      } else {
         throw Exception('ไม่สามารถสร้างรหัสผู้ใช้ได้ กรุณาลองใหม่อีกครั้ง');
      }

      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userId = userCredential.user!.uid;
      final userRef = FirebaseDatabase.instance.ref('accounts/$userId');
      await userRef.set({
        'customId': customFormatId,
        'username': username,
        'email': _emailController.text.trim(),
        'createdAt': ServerValue.timestamp,
        // *** เพิ่มข้อมูลสำหรับจัดการการ Lock ***
        'loginAttempts': {
          'failedCount': 0,
          'isPermanentlyLocked': false,
        }
      });

      if (userCredential.user != null) {
        await userCredential.user!.sendEmailVerification();
      }
      
      if(mounted) {
        await _showPopup(context, 'สำเร็จ!', 'สมัครสมาชิกเรียบร้อย กรุณายืนยันอีเมลของท่าน', Icons.check_circle_outline, Colors.greenAccent);
      }
      
      if(mounted) {
        Navigator.of(context).pop();
      }
    
    } on FirebaseAuthException catch (error) {
      _showPopup(context, 'เกิดข้อผิดพลาด', error.message ?? 'ไม่สามารถสมัครสมาชิกได้', Icons.error_outline, Colors.redAccent);
    } catch (error) {
       _showPopup(context, 'เกิดข้อผิดพลาด', error.toString(), Icons.error_outline, Colors.redAccent);
    }

    if(mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // UI part remains the same
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/BG-main.png', fit: BoxFit.cover),
        
        Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
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
                    const Text(
                      'สมัครสมาชิก',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32.0),

                    TextFormField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'ชื่อผู้ใช้ (Username)',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        prefixIcon: const Icon(Icons.person_outline, color: Colors.white),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.3),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide.none),
                        errorStyle: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณากรอกชื่อผู้ใช้';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'อีเมล',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.white),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.3),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide.none),
                        errorStyle: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty || !value.contains('@')) {
                          return 'รูปแบบอีเมลไม่ถูกต้อง';
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
                        errorStyle: const TextStyle(color: Colors.white, fontSize: 14),
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
                            'ยืนยันการสมัคร',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16.0),
                    
                    if (!_isLoading)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'มีบัญชีอยู่แล้ว? เข้าสู่ระบบ',
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
    );
  }
}
