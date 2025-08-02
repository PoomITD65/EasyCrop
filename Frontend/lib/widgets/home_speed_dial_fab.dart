import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easycrop_e1/providers/school_provider.dart';

class HomeSpeedDialFab extends StatelessWidget {
  final bool isFabMenuOpen;
  final AnimationController fabAnimationController;
  final VoidCallback toggleFabMenu;
  final String? selectedSchool;

  const HomeSpeedDialFab({
    super.key,
    required this.isFabMenuOpen,
    required this.fabAnimationController,
    required this.toggleFabMenu,
    required this.selectedSchool, required Map<String, String> currentFilters,
  });

  // ✅ --- เพิ่มฟังก์ชัน Success Popup ---
  Future<void> _showSuccessPopup(BuildContext context, String message) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
                ),
                const SizedBox(height: 24),
                Text(
                  'สำเร็จ',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('ตกลง'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ✅ --- เพิ่มฟังก์ชัน Error Popup ---
  Future<void> _showErrorPopup(BuildContext context, String message) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline, color: Colors.red, size: 48),
                ),
                const SizedBox(height: 24),
                Text(
                  'เกิดข้อผิดพลาด',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('รับทราบ'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _getToken(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorPopup(context, 'กรุณาเข้าสู่ระบบอีกครั้ง');
      return null;
    }
    return await user.getIdToken();
  }

  Future<void> _handleCreateNewSchool(BuildContext context) async {
    toggleFabMenu();
    final schoolNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final schoolName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('สร้างโรงเรียนใหม่'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: schoolNameController,
            decoration: const InputDecoration(hintText: "กรอกชื่อโรงเรียน (ภาษาอังกฤษ)"),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'กรุณากรอกชื่อโรงเรียน';
              if (RegExp(r'[\s./#$\[\]]').hasMatch(value)) return 'ชื่อห้ามมีอักขระพิเศษหรือเว้นวรรค';
              return null;
            },
          ),
        ),
        actions: <Widget>[
          TextButton(child: const Text('ยกเลิก'), onPressed: () => Navigator.of(dialogContext).pop()),
          ElevatedButton(
            child: const Text('สร้าง'),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(schoolNameController.text.trim());
              }
            },
          ),
        ],
      ),
    );

    if (schoolName != null && context.mounted) {
      final token = await _getToken(context);
      if (token == null) return;

      final provider = context.read<SchoolProvider>();
      final success = await provider.createNewSchool(schoolName: schoolName, token: token);
      
      if (context.mounted) {
        if (success) {
          _showSuccessPopup(context, provider.successMessage ?? 'สร้างโรงเรียนสำเร็จ!');
        } else {
          _showErrorPopup(context, provider.errorMessage ?? 'สร้างโรงเรียนล้มเหลว!');
        }
      }
    }
  }

  Future<void> _handleUploadCsv(BuildContext context) async {
    toggleFabMenu();
    if (selectedSchool == null) {
      _showErrorPopup(context, 'กรุณาเลือกโรงเรียนก่อน');
      return;
    }

    final token = await _getToken(context);
    if (token == null) return;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['csv'], withData: true,
      );

      if (result != null && result.files.single.bytes != null && context.mounted) {
        final provider = context.read<SchoolProvider>();
        final success = await provider.uploadCsv(
          schoolName: selectedSchool!,
          csvFile: result.files.single,
          token: token,
        );
        if (context.mounted) {
          if (success) {
            _showSuccessPopup(context, provider.successMessage ?? 'อัปโหลดสำเร็จ!');
          } else {
            _showErrorPopup(context, provider.errorMessage ?? 'อัปโหลดล้มเหลว!');
          }
        }
      }
    } catch (e) {
       if (context.mounted) {
        _showErrorPopup(context, 'เกิดข้อผิดพลาดในการเลือกไฟล์: $e');
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSchoolSelected = selectedSchool != null;

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        if (isFabMenuOpen)
          GestureDetector(
            onTap: toggleFabMenu,
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          bottom: isFabMenuOpen ? 140.0 : 16.0,
          right: 16.0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: isFabMenuOpen ? 1.0 : 0.0,
            child: _buildSmallFab(
              context: context,
              icon: Icons.business_outlined,
              label: 'สร้างโรงเรียน',
              onPressed: () => _handleCreateNewSchool(context),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          bottom: isFabMenuOpen ? 80.0 : 16.0,
          right: 16.0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: isFabMenuOpen ? 1.0 : 0.0,
            child: _buildSmallFab(
              context: context,
              icon: Icons.upload_file,
              label: 'อัปโหลด CSV',
              onPressed: isSchoolSelected ? () => _handleUploadCsv(context) : null,
            ),
          ),
        ),
        Positioned(
          bottom: 16.0,
          right: 16.0,
          child: FloatingActionButton(
            onPressed: toggleFabMenu,
            child: AnimatedBuilder(
              animation: fabAnimationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: fabAnimationController.value * (math.pi / 4),
                  child: const Icon(Icons.add),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallFab({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isFabMenuOpen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(label, style: const TextStyle(color: Colors.white)),
          ),
        FloatingActionButton.small(
          heroTag: null,
          onPressed: onPressed,
          backgroundColor: onPressed != null ? Theme.of(context).colorScheme.secondary : Colors.grey,
          child: Icon(icon, color: Colors.white),
        ),
      ],
    );
  }
}
