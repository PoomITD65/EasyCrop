import 'package:easycrop_e1/model/student_model.dart';
import 'package:easycrop_e1/providers/school_provider.dart';
import 'package:easycrop_e1/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditStudentScreen extends StatefulWidget {
  final Student? student;
  final String? schoolName; // Required when adding a new student

  const EditStudentScreen({super.key, this.student, this.schoolName});

  @override
  State<EditStudentScreen> createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends State<EditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _idController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _gradeLevelController;
  late TextEditingController _classNameController;

  bool get _isEditing => widget.student != null;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.student?.id ?? '');
    _firstNameController = TextEditingController(text: widget.student?.firstName ?? '');
    _lastNameController = TextEditingController(text: widget.student?.lastName ?? '');
    _gradeLevelController = TextEditingController(text: widget.student?.gradeLevel ?? '');
    _classNameController = TextEditingController(text: widget.student?.className ?? '');
  }

  @override
  void dispose() {
    _idController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _gradeLevelController.dispose();
    _classNameController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final token = context.read<UserProvider>().token;
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถยืนยันตัวตนได้'), backgroundColor: Colors.red),
        );
        return;
      }

      final schoolProvider = context.read<SchoolProvider>();
      
      // ✅ แก้ไข: สร้าง Student object ให้ถูกต้องตามโครงสร้างใหม่
      final studentData = Student(
        id: _idController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        schoolName: widget.student?.schoolName ?? widget.schoolName!,
        gradeLevel: _gradeLevelController.text.trim(),
        className: _classNameController.text.trim(),
        // สร้าง photoData object เริ่มต้น หรือใช้ของเดิมถ้ามี
        photoData: widget.student?.photoData ?? PhotoData(photoStatus: 'no_photo'),
      );

      bool success = false;
      if (_isEditing) {
        success = await schoolProvider.editStudent(studentData, token);
      } else {
        success = await schoolProvider.addStudent(studentData, token);
      }

      if (mounted && success) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'แก้ไขข้อมูลนักเรียน' : 'เพิ่มนักเรียนใหม่'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: context.watch<SchoolProvider>().isLoading ? null : _submitForm,
            tooltip: 'บันทึก',
          ),
        ],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                TextFormField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    labelText: 'รหัสนักเรียน',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  enabled: !_isEditing, // Disable ID field when editing
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'กรุณากรอกรหัสนักเรียน' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อจริง',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'กรุณากรอกชื่อจริง' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'นามสกุล',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'กรุณากรอกนามสกุล' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _gradeLevelController,
                  decoration: const InputDecoration(
                    labelText: 'ระดับชั้น',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.layers_outlined),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'กรุณากรอกระดับชั้น' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _classNameController,
                  decoration: const InputDecoration(
                    labelText: 'ห้อง',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.class_outlined),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'กรุณากรอกชื่อห้อง' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(fontSize: 18)
                  ),
                  icon: const Icon(Icons.save),
                  onPressed: context.watch<SchoolProvider>().isLoading ? null : _submitForm,
                  label: Text(_isEditing ? 'บันทึกการเปลี่ยนแปลง' : 'เพิ่มนักเรียน'),
                ),
              ],
            ),
          ),
          if (context.watch<SchoolProvider>().isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
