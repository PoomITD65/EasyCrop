// 1. สร้างคลาสสำหรับ photoData object ที่ซ้อนอยู่ข้างใน
class PhotoData {
  final String photoStatus;
  final String? photoBase64;
  final String? photoThumbnailBase64;

  PhotoData({
    required this.photoStatus,
    this.photoBase64,
    this.photoThumbnailBase64,
  });

  factory PhotoData.fromJson(Map<String, dynamic> json) {
    return PhotoData(
      photoStatus: json['photoStatus'] as String? ?? 'no_photo',
      photoBase64: json['photoBase64'] as String?,
      photoThumbnailBase64: json['photoThumbnailBase64'] as String?,
    );
  }

  PhotoData copyWith({
    String? photoStatus,
    String? photoBase64,
    String? photoThumbnailBase64,
  }) {
    return PhotoData(
      photoStatus: photoStatus ?? this.photoStatus,
      photoBase64: photoBase64 ?? this.photoBase64,
      photoThumbnailBase64: photoThumbnailBase64 ?? this.photoThumbnailBase64,
    );
  }
}

// 2. แก้ไข Student model หลัก
class Student {
  final String id;
  final String firstName;
  final String lastName;
  final String schoolName;
  final String gradeLevel;
  final String className;
  final PhotoData photoData;

  Student({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.schoolName,
    required this.gradeLevel,
    required this.className,
    required this.photoData, // ✅ ลบ 'required String photoStatus' ที่ซ้ำซ้อนออกไป
  });

  String get photoStatus => photoData.photoStatus;

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as String? ?? json['studentId'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      schoolName: json['schoolName'] as String? ?? '',
      gradeLevel: json['gradeLevel'] as String? ?? '',
      className: json['className'] as String? ?? '',
      photoData: json['photoData'] != null && json['photoData'] is Map
          ? PhotoData.fromJson(json['photoData'])
          : PhotoData(photoStatus: 'no_photo'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'schoolName': schoolName,
      'gradeLevel': gradeLevel,
      'className': className,
    };
  }

  Student copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? schoolName,
    String? gradeLevel,
    String? className,
    PhotoData? photoData,
  }) {
    return Student(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      schoolName: schoolName ?? this.schoolName,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      className: className ?? this.className,
      photoData: photoData ?? this.photoData,
    );
  }
}
