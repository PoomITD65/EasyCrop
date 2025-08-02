import 'dart:async';
import 'package:easycrop_e1/model/student_model.dart';
import 'package:easycrop_e1/providers/school_provider.dart';
import 'package:easycrop_e1/providers/user_provider.dart';
import 'package:easycrop_e1/screen/login_screen.dart';
import 'package:easycrop_e1/widgets/app_drawer.dart';
import 'package:easycrop_e1/widgets/home_filter_panel.dart';
import 'package:easycrop_e1/widgets/home_speed_dial_fab.dart';
import 'package:easycrop_e1/widgets/student_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _fabAnimationController;
  StreamSubscription<User?>? _authSubscription;
  late SchoolProvider _schoolProvider;

  // --- UI State ---
  bool _isFabMenuOpen = false;
  String? _selectedSchool;
  bool _instructionsShown = false; // ✅ 1. ตัวแปรสำหรับจำว่าเคยแสดง Popup แล้วหรือยัง

  List<String> _gradeLevels = ['ทั้งหมด'];
  List<String> _classNames = ['ทั้งหมด'];
  final List<String> _photoStatuses = ['ทั้งหมด', 'มีรูป (สมบูรณ์)', 'กำลังประมวลผล', 'ไม่มีรูป', 'ผิดพลาด'];
  String _selectedGradeLevel = 'ทั้งหมด';
  String _selectedClassName = 'ทั้งหมด';
  String _selectedPhotoStatus = 'ทั้งหมด';

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _searchController.addListener(() => setState(() {})); 

    _schoolProvider = context.read<SchoolProvider>();
    _schoolProvider.addListener(_schoolProviderListener);

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _initializeData();
      } else {
        if (mounted) {
          context.read<UserProvider>().clearUserData();
          _schoolProvider.clearMessages();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (ctx) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _schoolProvider.removeListener(_schoolProviderListener);
    _fabAnimationController.dispose();
    _searchController.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }
  
  void _schoolProviderListener() {
    if (!mounted) return;
    final schoolProvider = context.read<SchoolProvider>();
    
    if (schoolProvider.successMessage != null) {
      // Logic for success message
      schoolProvider.clearMessages();
    }
    if (schoolProvider.errorMessage != null) {
      // Logic for error message
      schoolProvider.clearMessages();
    }
  }

  // ✅ 2. สร้างฟังก์ชันสำหรับแสดง Popup คำแนะนำ
  Future<void> _showInitialInstructions() async {
    // ตรวจสอบก่อนว่าเคยแสดงไปแล้วหรือยัง
    if (_instructionsShown || !mounted) return;

    // ตั้งค่าว่าแสดงแล้ว เพื่อไม่ให้แสดงอีกในครั้งต่อไป
    setState(() {
      _instructionsShown = true;
    });

    // ใช้ Future.delayed เล็กน้อยเพื่อให้แน่ใจว่าหน้าจอ Home สร้างเสร็จสมบูรณ์ก่อนแสดง Dialog
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              const Text('ข้อแนะนำก่อนถ่ายภาพ',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'เพื่อให้การประมวลผลภาพมีประสิทธิภาพสูงสุด กรุณาปฏิบัติตามนี้:',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              ListTile(
                leading: Text('1.', style: TextStyle(fontWeight: FontWeight.bold)),
                title: Text('กรุณาเก็บผมและหน้าม้าให้เรียบร้อย ไม่ให้บดบังใบหน้า'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: Text('2.', style: TextStyle(fontWeight: FontWeight.bold)),
                title: Text('ถ่ายภาพโดยใช้พื้นหลังสีฟ้าหรือสีเขียวล้วน'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: <Widget>[
            ElevatedButton(
              child: const Text('รับทราบ'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<String?> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  Future<void> _initializeData() async {
    final token = await _getToken();
    if (token == null || !mounted) return;
    
    await Future.wait([
      context.read<UserProvider>().fetchUserData(),
      context.read<SchoolProvider>().fetchSchools(token: token),
    ]);

    // ✅ 3. เรียกใช้ฟังก์ชันแสดง Popup หลังจากดึงข้อมูลครั้งแรกเสร็จ
    _showInitialInstructions();
  }

  Future<void> _fetchStudents() async {
    if (_selectedSchool == null) return;
    final token = await _getToken();
    if (token == null || !mounted) return;

    await context.read<SchoolProvider>().fetchStudents(
      schoolName: _selectedSchool!, 
      token: token
    );

    if (mounted) {
      _updateFilterOptions();
    }
  }

  void _onSchoolSelected(String? schoolName) {
    if (schoolName != null && schoolName != _selectedSchool) {
      setState(() {
        _selectedSchool = schoolName;
        _resetFiltersAndStudents();
      });
      _fetchStudents();
    }
  }

  void _updateFilterOptions() {
    final allStudents = context.read<SchoolProvider>().allStudents;
    final gradeLevelSet = <String>{};
    final classNameSet = <String>{};
    for (var student in allStudents) {
      if(student.gradeLevel.isNotEmpty) gradeLevelSet.add(student.gradeLevel);
      if(student.className.isNotEmpty) classNameSet.add(student.className);
    }
    setState(() {
      _gradeLevels = ['ทั้งหมด', ...gradeLevelSet.toList()..sort()];
      _classNames = ['ทั้งหมด', ...classNameSet.toList()..sort()];
    });
  }
  
  void _resetFiltersAndStudents() {
    _gradeLevels = ['ทั้งหมด'];
    _classNames = ['ทั้งหมด'];
    _selectedGradeLevel = 'ทั้งหมด';
    _selectedClassName = 'ทั้งหมด';
    _selectedPhotoStatus = 'ทั้งหมด';
    _searchController.clear();
  }

  List<Student> _getFilteredStudents(List<Student> allStudents) {
    List<Student> tempStudents = List.from(allStudents);
    if (_selectedGradeLevel != 'ทั้งหมด') {
      tempStudents = tempStudents.where((s) => s.gradeLevel == _selectedGradeLevel).toList();
    }
    if (_selectedClassName != 'ทั้งหมด') {
      tempStudents = tempStudents.where((s) => s.className == _selectedClassName).toList();
    }
    if (_selectedPhotoStatus != 'ทั้งหมด') {
        final statusMap = {
            'มีรูป (สมบูรณ์)': 'finish',
            'กำลังประมวลผล': 'processed',
            'ไม่มีรูป': 'no_photo',
            'ผิดพลาด': 'error'
        };
        final targetStatus = statusMap[_selectedPhotoStatus];
        if (targetStatus != null) {
            tempStudents = tempStudents.where((s) => s.photoStatus == targetStatus).toList();
        }
    }
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      tempStudents = tempStudents.where((s) {
        return s.firstName.toLowerCase().contains(query) ||
               s.lastName.toLowerCase().contains(query) ||
               s.id.toLowerCase().contains(query);
      }).toList();
    }
    return tempStudents;
  }

  void _toggleFabMenu() {
    setState(() => _isFabMenuOpen = !_isFabMenuOpen);
    if (_isFabMenuOpen) {
      _fabAnimationController.forward();
    } else {
      _fabAnimationController.reverse();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final schoolProvider = context.watch<SchoolProvider>();
    final userProvider = context.watch<UserProvider>();
    final schoolNames = schoolProvider.schools.map((s) => s.name).toList();
    final allStudents = schoolProvider.allStudents;
    final filteredStudents = _getFilteredStudents(allStudents);

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedSchool ?? 'ระบบจัดการข้อมูลนักเรียน'),
      ),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          Column(
            children: [
              HomeFilterPanel(
                selectedSchool: _selectedSchool,
                schoolNames: schoolNames,
                onSchoolSelected: _onSchoolSelected,
                selectedGradeLevel: _selectedGradeLevel,
                gradeLevels: _gradeLevels,
                onGradeLevelChanged: (val) => setState(() { _selectedGradeLevel = val!; }),
                selectedClassName: _selectedClassName,
                classNames: _classNames,
                onClassNameChanged: (val) => setState(() { _selectedClassName = val!; }),
                selectedPhotoStatus: _selectedPhotoStatus,
                photoStatuses: _photoStatuses,
                onPhotoStatusChanged: (val) => setState(() { _selectedPhotoStatus = val!; }),
                searchController: _searchController
              ),
              
              if (schoolProvider.isLoading && allStudents.isEmpty)
                const LinearProgressIndicator(),

              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('รายการนักเรียน', style: Theme.of(context).textTheme.titleLarge),
                    Text('${filteredStudents.length} คน', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600)),
                  ],
                ),
              ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchStudents,
                  child: _selectedSchool == null
                      ? _buildEmptyState('โปรดเลือกโรงเรียน', Icons.school_outlined)
                      : allStudents.isEmpty && schoolProvider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : filteredStudents.isEmpty && (allStudents.isNotEmpty || _searchController.text.isNotEmpty)
                          ? _buildEmptyState('ไม่พบข้อมูลที่ตรงกัน', Icons.search_off)
                          : allStudents.isEmpty && !schoolProvider.isLoading
                            ? _buildEmptyState('ยังไม่มีข้อมูลนักเรียนในโรงเรียนนี้', Icons.person_off_outlined)
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 80),
                                itemCount: filteredStudents.length,
                                itemBuilder: (context, index) => StudentCard(student: filteredStudents[index]),
                              ),
                ),
              ),
            ],
          ),
          HomeSpeedDialFab(
            isFabMenuOpen: _isFabMenuOpen,
            fabAnimationController: _fabAnimationController,
            toggleFabMenu: _toggleFabMenu,
            selectedSchool: _selectedSchool,
            currentFilters: {
              "search": _searchController.text,
              "gradeLevel": _selectedGradeLevel,
              "className": _selectedClassName,
              "photoStatus": _selectedPhotoStatus,
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 18, color: Colors.grey.shade600), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
