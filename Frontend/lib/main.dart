import 'package:easycrop_e1/providers/theme_provider.dart';
import 'package:easycrop_e1/providers/user_provider.dart';
import 'package:easycrop_e1/providers/school_provider.dart'; 
import 'package:easycrop_e1/screen/home_screen.dart';
import 'package:easycrop_e1/screen/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyAppWrapper());

    // ✅ 2. เพิ่มโค้ดส่วนนี้เพื่อล็อคหน้าจอ
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}

class MyAppWrapper extends StatelessWidget {
  const MyAppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // 👇 2. เปลี่ยนเป็น MultiProvider เพื่อให้รองรับ Provider หลายตัว
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()), // 👈 3. เพิ่ม UserProvider เข้าไป
        ChangeNotifierProvider(create: (_) => SchoolProvider()),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // กำหนดชุดสีหลัก
    const Color primaryRed = Color(0xFFD32F2F);
    const Color primaryBlack = Color(0xFF212121);

    return MaterialApp(
      title: 'EasyCrop E1',
      themeMode: themeProvider.themeMode,
      
      // --- Theme สำหรับโหมดสว่าง (Light Mode) ---
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: primaryRed,
        scaffoldBackgroundColor: Colors.grey[100],
        colorScheme: const ColorScheme.light(
          primary: primaryRed,
          secondary: primaryBlack,
          onPrimary: Colors.white,
          background: Color(0xFFF5F5F5),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          elevation: 1,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),

      // --- Theme สำหรับโหมดมืด (Dark Mode) ---
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: primaryRed,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: primaryRed,
          secondary: primaryRed,
          background: Color(0xFF121212),
          surface: Color(0xFF1E1E1E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}

// AuthWrapper Widget สำหรับตรวจสอบสถานะการล็อกอิน
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // กำลังรอข้อมูล
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        // ล็อกอินอยู่
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        // ยังไม่ได้ล็อกอิน
        return const LoginScreen();
      },
    );
  }
}