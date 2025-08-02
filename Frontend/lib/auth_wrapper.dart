import 'package:easycrop_e1/providers/user_provider.dart';
import 'package:easycrop_e1/screen/home_screen.dart';
import 'package:easycrop_e1/screen/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // ใช้ context.watch เพื่อ "ฟัง" การเปลี่ยนแปลงจาก UserProvider
    final userProvider = context.watch<UserProvider>();
    
    // Provider จะทำการเช็คสถานะเบื้องหลัง
    // ถ้ามีข้อมูล user ใน provider (แปลว่าล็อกอินอยู่)
    if (userProvider.user != null) {
      return const HomeScreen();
    }

    // ถ้าไม่มีข้อมูล user
    return const LoginScreen();
  }
}