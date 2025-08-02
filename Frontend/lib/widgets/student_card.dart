import 'dart:convert';
import 'dart:typed_data';

import 'package:easycrop_e1/model/student_model.dart';
import 'package:easycrop_e1/screen/student_detail_screen.dart';
import 'package:flutter/material.dart';

// --- Widget for displaying student avatar safely ---
class StudentAvatar extends StatelessWidget {
  // ✅ แก้ไข: รับทั้ง 2 ขนาด
  final String? base64String;
  final String? thumbnailBase64String;
  final String fallbackText;
  final double radius;

  const StudentAvatar({
    super.key,
    this.base64String,
    this.thumbnailBase64String,
    required this.fallbackText,
    this.radius = 24.0,
  });

  Uint8List? _decodeBase64(String? b64) {
    if (b64 == null || b64.isEmpty || b64.contains('placeholder')) {
      return null;
    }
    try {
      String pureBase64 = b64.split(',').last.trim();
      int missingPadding = pureBase64.length % 4;
      if (missingPadding != 0) {
        pureBase64 += '=' * (4 - missingPadding);
      }
      return base64.decode(pureBase64);
    } catch (e) {
      print('Could not decode base64 string for $fallbackText: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ แก้ไข: ใช้ Thumbnail ก่อน ถ้าไม่มีก็ใช้รูปเต็ม
    final imageBytes = _decodeBase64(thumbnailBase64String ?? base64String);
    ImageProvider? backgroundImage;
    if (imageBytes != null) {
      backgroundImage = MemoryImage(imageBytes);
    }
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
      backgroundImage: backgroundImage,
      child: backgroundImage == null
          ? Text(
              fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.8,
                color: theme.colorScheme.primary,
              ),
            )
          : null,
    );
  }
}

// --- Widget for a styled student card ---
class StudentCard extends StatelessWidget {
  final Student student;

  const StudentCard({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.cardColor,
      shadowColor: Colors.black.withOpacity(0.1),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => StudentDetailScreen(student: student),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              StudentAvatar(
                // ✅ แก้ไข: ส่ง thumbnail ไปแสดงในหน้า List
                thumbnailBase64String: student.photoData.photoThumbnailBase64,
                fallbackText: student.firstName,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${student.firstName} ${student.lastName}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'รหัส: ${student.id} | ชั้น: ${student.className}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (student.photoStatus == 'processed')
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            Icon(Icons.hourglass_top_rounded,
                                size: 14, color: Colors.orange.shade700),
                            const SizedBox(width: 4),
                            Text(
                              'กำลังประมวลผล',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.orange.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  color: Colors.grey.shade400, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
