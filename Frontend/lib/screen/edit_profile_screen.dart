import 'dart:async';
import 'package:easycrop_e1/providers/user_provider.dart';
import 'package:easycrop_e1/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _initialUsername;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    // ทำให้ UI รู้ว่ากำลังโหลด
    if (!_isLoading) setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      // เรายังคงใช้การดึงข้อมูลโดยตรงจาก DB ในหน้านี้เพื่อความรวดเร็ว
      final userRef = FirebaseDatabase.instance.ref('accounts/${user.uid}');
      final snapshot = await userRef.get();

      if (mounted && snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          _initialUsername = data['username'];
          _usernameController.text = _initialUsername ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ไม่สามารถโหลดข้อมูลผู้ใช้ได้: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showSuccessDialog() {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false, // ไม่ให้ปิดเอง
      barrierLabel: 'Success Dialog',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return Transform.scale(
          scale: anim1.value,
          child: Opacity(
            opacity: anim1.value,
            child: Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 48),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'บันทึกสำเร็จ',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ข้อมูลของคุณถูกอัปเดตแล้ว',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ✅ แก้ไขฟังก์ชันนี้ทั้งหมด
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final newUsername = _usernameController.text.trim();
    if (newUsername == _initialUsername) {
      return; // ถ้าไม่มีอะไรเปลี่ยน ก็ไม่ต้องทำอะไร
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('กรุณาล็อกอินก่อน');
      final token = await user.getIdToken();
      if (token == null) throw Exception('ไม่สามารถยืนยันตัวตนได้');

      // 1. เรียก API เพื่ออัปเดตข้อมูลใน Backend
      await _apiService.updateUserProfile(
        newUsername: newUsername,
        token: token,
      );

      if (mounted) {
        // 2. สั่งให้ UserProvider ที่เป็นศูนย์กลางข้อมูล อัปเดตตัวเองทันที
        //    เพื่อให้ AppDrawer และหน้าอื่นๆ ได้ข้อมูลใหม่ไปใช้
        Provider.of<UserProvider>(context, listen: false).fetchUserData();

        // 3. แสดง Popup สำเร็จ
        _showSuccessDialog();

        // 4. รอ 2 วินาที
        await Future.delayed(const Duration(seconds: 2));

        // 5. ปิด Popup (ถ้ายังเปิดอยู่)
        if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        // 6. สั่งให้หน้านี้รีเฟรชข้อมูลของตัวเอง (เพื่ออัปเดต _initialUsername)
        if (mounted) {
          await _loadUserData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แก้ไขข้อมูลส่วนตัว'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อผู้ใช้ (Username)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'กรุณากรอกชื่อผู้ใช้';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                          )
                        : const Text(
                            'บันทึกการเปลี่ยนแปลง',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}