import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:easycrop_e1/model/student_model.dart';
import 'package:easycrop_e1/providers/school_provider.dart';
import 'package:easycrop_e1/providers/user_provider.dart';
import 'package:easycrop_e1/screen/home_screen.dart';
import 'package:easycrop_e1/widgets/student_card.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class StudentDetailScreen extends StatefulWidget {
  final Student student;
  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchFullResolutionImage();
    });
  }

  Future<void> _fetchFullResolutionImage() async {
    final token = context.read<UserProvider>().token;
    if (token != null && mounted) {
      await context.read<SchoolProvider>().fetchSingleStudent(
            schoolName: widget.student.schoolName,
            studentId: widget.student.id,
            token: token,
          );
    }
  }

  Future<void> _takePicture() async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(
        source: ImageSource.camera, maxWidth: 800, imageQuality: 85);

    if (imageFile == null || !mounted) return;

    final token = context.read<UserProvider>().token;
    if (token == null) {
      _showErrorPopup('ไม่สามารถยืนยันตัวตนได้');
      return;
    }

    final provider = context.read<SchoolProvider>();
    final success = await provider.uploadStudentPhoto(
      schoolName: widget.student.schoolName,
      studentId: widget.student.id,
      imageFile: imageFile,
      token: token,
    );

    if (!mounted) return;
    if (success) {
      _showSuccessPopup(provider.successMessage ?? 'อัปเดตสำเร็จ!');
      await Future.delayed(const Duration(seconds: 1));

    } else {
      _showErrorPopup(provider.errorMessage ?? 'เกิดข้อผิดพลาด');
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Uint8List? _decodeBase64(String? b64) {
    if (b64 == null || b64.isEmpty || b64.contains('placeholder')) {
      return null;
    }
    try {
      String pureBase64 = b64.split(',').last.trim();
      return base64.decode(pureBase64);
    } catch (e) {
      debugPrint('Could not decode base64 string on detail screen: $e');
      return null;
    }
  }

  Future<void> _showErrorPopup(String message) async {
    if (!mounted) return;
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 200),
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
                    const Icon(Icons.error_outline, color: Colors.red, size: 54),
                    const SizedBox(height: 16),
                    Text(
                      'เกิดข้อผิดพลาด',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
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

  Future<void> _showSuccessPopup(String message) async {
    if (!mounted) return;
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 200),
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
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 54),
                    const SizedBox(height: 16),
                    Text(
                      'สำเร็จ',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
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

  @override
  Widget build(BuildContext context) {
    final schoolProvider = context.watch<SchoolProvider>();
    final student = schoolProvider.allStudents.firstWhere(
        (s) => s.id == widget.student.id,
        orElse: () => widget.student);
    
    final imageBytes = _decodeBase64(student.photoData.photoBase64 ?? student.photoData.photoThumbnailBase64);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      floatingActionButton: FloatingActionButton(
        onPressed: schoolProvider.isLoading ? null : _takePicture,
        backgroundColor: schoolProvider.isLoading
            ? Colors.grey.shade400
            : Theme.of(context).colorScheme.primary,
        child: schoolProvider.isLoading
            ? CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(
                    Theme.of(context).colorScheme.onPrimary))
            : Icon(Icons.camera_alt,
                color: Theme.of(context).colorScheme.onPrimary),
      ),
      // ✅ --- เพิ่ม RefreshIndicator ที่นี่ ---
      body: RefreshIndicator(
        onRefresh: _fetchFullResolutionImage,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: Theme.of(context).colorScheme.primary,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageBytes != null)
                      Image.memory(imageBytes, fit: BoxFit.cover),
                    if (imageBytes != null)
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(color: Colors.black.withOpacity(0.3)),
                      ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    width: 3),
                                image: imageBytes != null
                                    ? DecorationImage(
                                        image: MemoryImage(imageBytes),
                                        fit: BoxFit.cover)
                                    : null),
                            child: imageBytes == null
                                ? Icon(Icons.person_outline,
                                    size: 60,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary
                                        .withOpacity(0.7))
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${student.firstName} ${student.lastName}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall!
                                .copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                    shadows: const [
                                  Shadow(blurRadius: 2, color: Colors.black54)
                                ]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoCard(
                      context,
                      title: 'ข้อมูลนักเรียน',
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: _buildDetailItem(
                                    label: 'ชื่อ', value: student.firstName)),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildDetailItem(
                                    label: 'นามสกุล', value: student.lastName)),
                          ],
                        ),
                        _buildDetailItem(label: 'รหัส', value: student.id),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      context,
                      title: 'ข้อมูลการศึกษา',
                      children: [
                        _buildDetailItem(
                            label: 'โรงเรียน', value: student.schoolName),
                        _buildDetailItem(
                            label: 'ระดับชั้น', value: student.gradeLevel),
                        _buildDetailItem(
                            label: 'ห้อง', value: student.className),
                        _buildStatusItem(context, student),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context,
      {required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge!
                  .copyWith(fontWeight: FontWeight.bold)),
          Divider(
              height: 24,
              thickness: 1,
              color: Theme.of(context).colorScheme.outlineVariant),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailItem({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value.isNotEmpty ? value : '-',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge!
                  .copyWith(fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildStatusItem(BuildContext context, Student student) {
    String txt;
    Color c;
    switch (student.photoStatus) {
      case 'finish':
        txt = 'สมบูรณ์';
        c = Colors.green;
        break;
      case 'processed':
        txt = 'กำลังประมวลผล';
        c = Colors.orange;
        break;
      default:
        txt = 'ไม่มีรูปภาพ';
        c = Colors.grey.shade600;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Text('สถานะรูปภาพ',
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: c.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Text(txt,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: c, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}
