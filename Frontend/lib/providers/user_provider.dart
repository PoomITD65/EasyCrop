import 'dart:async';
import 'package:easycrop_e1/screen/home_screen.dart';
import 'package:easycrop_e1/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription? _authSubscription;

  // State ที่ AuthWrapper จะใช้ในการสลับหน้าจอ
  User? _user;

  Map<String, dynamic>? _userData;
  String? _token;
  bool _isLoading = false;

  // Getters สำหรับให้ UI นำไปใช้
  User? get user => _user;
  Map<String, dynamic>? get userData => _userData;
  String? get token => _token;
  bool get isLoading => _isLoading;

  // Constructor: เริ่มดักฟังการเปลี่ยนแปลงทันทีที่ Provider ถูกสร้าง
  UserProvider() {
    print("🔑 USER PROVIDEoooooooo");
    _authSubscription = _auth.authStateChanges().listen(_handleAuthStateChanged);
    print("🔑 USER PROVIDER INITIALIZED");
  }

  // ฟังก์ชันที่ทำงานอัตโนมัติเมื่อสถานะ Login หรือ Logout เปลี่ยน
  void _handleAuthStateChanged(User? firebaseUser) {
    _user = firebaseUser;
    print("hhhhhhhhhhhh firebaseUser: $firebaseUser");
    if (firebaseUser != null) {
      // ถ้ามีการ login ให้ไปดึงข้อมูลผู้ใช้
      fetchUserData();
      
    } else {
      // ถ้ามีการ logout ให้เคลียร์ข้อมูล
      clearUserData();
    }
    // แจ้งเตือน UI (โดยเฉพาะ AuthWrapper) ว่าสถานะ User เปลี่ยนแล้ว
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel(); // ยกเลิกการดักฟังเมื่อไม่ใช้แล้ว
    super.dispose();
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    print("🔑 USER PROVIDER NOTIFY LISTENERS");
  }
  @override
  void setState(VoidCallback fn) {
    print("🔑 USER PROVIDER SET STATE");
  }

  // ฟังก์ชันนี้จะถูกเรียกโดยอัตโนมัติจาก _handleAuthStateChanged
  Future<void> fetchUserData() async {
    _isLoading = true;
    notifyListeners();
    print("🔑 USER DATA===: $_userData");
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in");
      
      final token = await user.getIdToken();
      _token = token;
      _userData = await _apiService.getUserData(user.uid, token: token!);
      print("🔑 USER DATA: $_userData");
    } catch (e, stackTrace) {
      print("‼️ FETCH USER DATA FAILED: $e");
      print("STACK TRACE: $stackTrace");
      _userData = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearUserData() {
    _userData = null;
    _token = null;
    // ไม่ต้อง notifyListeners() ที่นี่ เพราะ _handleAuthStateChanged ทำแล้ว
  }
}
