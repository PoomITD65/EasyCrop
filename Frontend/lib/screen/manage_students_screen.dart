import 'package:easycrop_e1/model/school_model.dart';
import 'package:easycrop_e1/model/student_model.dart';
import 'package:easycrop_e1/providers/school_provider.dart';
import 'package:easycrop_e1/providers/user_provider.dart';
import 'package:easycrop_e1/screen/edit_student_screen.dart';
import 'package:easycrop_e1/widgets/student_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ManageStudentsScreen extends StatefulWidget {
  final School school;
  const ManageStudentsScreen({super.key, required this.school});

  @override
  State<ManageStudentsScreen> createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen> {
  // --- State สำหรับการกรอง ---
  final TextEditingController _searchController = TextEditingController();
  List<String> _gradeLevels = ['ทั้งหมด'];
  List<String> _classNames = ['ทั้งหมด'];
  final List<String> _photoStatuses = ['ทั้งหมด', 'มีรูป (สมบูรณ์)', 'กำลังประมวลผล', 'ไม่มีรูป', 'ผิดพลาด'];
  String _selectedGradeLevel = 'ทั้งหมด';
  String _selectedClassName = 'ทั้งหมด';
  String _selectedPhotoStatus = 'ทั้งหมด';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchStudents();
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    final token = context.read<UserProvider>().token;
    if (token != null && mounted) {
      await context.read<SchoolProvider>().fetchStudents(
        schoolName: widget.school.name,
        token: token,
      );
      if(mounted) {
        _updateFilterOptions();
      }
    }
  }

  void _updateFilterOptions() {
    final allStudents = context.read<SchoolProvider>().allStudents;
    final gradeLevelSet = <String>{};
    final classNameSet = <String>{};
    for (var student in allStudents) {
      if (student.gradeLevel.isNotEmpty) gradeLevelSet.add(student.gradeLevel);
      if (student.className.isNotEmpty) classNameSet.add(student.className);
    }
    setState(() {
      _gradeLevels = ['ทั้งหมด', ...gradeLevelSet.toList()..sort()];
      _classNames = ['ทั้งหมด', ...classNameSet.toList()..sort()];
    });
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
  
  void _showDeleteConfirmation(Student student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('คุณต้องการลบข้อมูลของ ${student.firstName} ${student.lastName} ใช่หรือไม่?'),
        actions: [
          TextButton(
            child: const Text('ยกเลิก'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteStudent(student);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStudent(Student student) async {
    final token = context.read<UserProvider>().token;
    if (token != null && mounted) {
      await context.read<SchoolProvider>().removeStudent(
        student.schoolName,
        student.id,
        token
      );
    }
  }

  // ✅ --- เพิ่มฟังก์ชัน Popup ---
  Future<void> _showSuccessPopup(String message) async {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.green, size: 54),
                const SizedBox(height: 16),
                Text('สำเร็จ', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
        );
      },
    );

    await Future.delayed(const Duration(seconds: 2));
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showErrorPopup(String message) async {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 54),
                const SizedBox(height: 16),
                Text('เกิดข้อผิดพลาด', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
        );
      },
    );
    
    await Future.delayed(const Duration(seconds: 2));
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleExport() async {
    final provider = context.read<SchoolProvider>();
    final token = context.read<UserProvider>().token;
    if (token == null) {
      _showErrorPopup('กรุณาลองใหม่อีกครั้ง');
      return;
    }

    final filters = {
      "search": _searchController.text,
      "gradeLevel": _selectedGradeLevel,
      "className": _selectedClassName,
      "photoStatus": _selectedPhotoStatus,
    };

    final String? resultMessage = await provider.exportFilteredStudents(
      schoolName: widget.school.name,
      token: token,
      filters: filters
    );
    
    if (mounted) {
      if (resultMessage != null) {
        _showSuccessPopup(resultMessage);
      } else {
        _showErrorPopup(provider.errorMessage ?? 'เกิดข้อผิดพลาดที่ไม่รู้จัก');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolProvider = context.watch<SchoolProvider>();
    final students = schoolProvider.allStudents;
    final filteredStudents = _getFilteredStudents(students);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการข้อมูลนักเรียน'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              widget.school.name,
              style: TextStyle(color: Colors.white.withOpacity(0.8)),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            onPressed: schoolProvider.isLoading ? null : _handleExport,
            tooltip: 'Export รูปภาพเป็น ZIP',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterPanel(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('รายชื่อนักเรียน', style: theme.textTheme.titleMedium),
                Text('${filteredStudents.length} คน', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Expanded(
            child: schoolProvider.isLoading && students.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchStudents,
                    child: students.isEmpty
                      ? _buildEmptyState('ไม่มีข้อมูลนักเรียน', Icons.people_outline)
                      : filteredStudents.isEmpty
                        ? _buildEmptyState('ไม่พบข้อมูลที่ตรงกัน', Icons.search_off)
                        : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: filteredStudents.length,
                          itemBuilder: (ctx, index) {
                            final student = filteredStudents[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: StudentAvatar(
                                  thumbnailBase64String: student.photoData.photoThumbnailBase64,
                                  fallbackText: student.firstName,
                                  radius: 22,
                                ),
                                title: Text('${student.firstName} ${student.lastName}'),
                                subtitle: Text('ID: ${student.id} | ห้อง: ${student.className}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit_outlined, color: theme.colorScheme.secondary.withOpacity(0.7)),
                                      onPressed: () async {
                                        final result = await Navigator.of(context).push(MaterialPageRoute(
                                          builder: (ctx) => EditStudentScreen(student: student),
                                        ));
                                        if (result == true && mounted) {
                                          _fetchStudents();
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error.withOpacity(0.7)),
                                      onPressed: () => _showDeleteConfirmation(student),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มนักเรียน'),
        onPressed: () async {
          final result = await Navigator.of(context).push(MaterialPageRoute(
            builder: (ctx) => EditStudentScreen(schoolName: widget.school.name),
          ));
          if (result == true && mounted) {
            _fetchStudents();
          }
        },
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหา (ชื่อ, นามสกุล, รหัส)',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                _buildDropdown('ระดับชั้น', _gradeLevels, _selectedGradeLevel, (val) => setState(() => _selectedGradeLevel = val!)),
                _buildDropdown('ห้อง', _classNames, _selectedClassName, (val) => setState(() => _selectedClassName = val!)),
                _buildDropdown('สถานะรูป', _photoStatuses, _selectedPhotoStatus, (val) => setState(() => _selectedPhotoStatus = val!)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String hint, List<String> items, String value, ValueChanged<String?> onChanged) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
