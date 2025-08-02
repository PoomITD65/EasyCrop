import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:easycrop_e1/services/api_service.dart';
import 'package:easycrop_e1/model/school_model.dart';
import 'package:easycrop_e1/model/student_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class SchoolProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  List<School> _schools = [];
  List<Student> _allStudents = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  List<School> get schools => _schools;
  List<Student> get allStudents => _allStudents;

  void _setLoading(bool loading, {String? error, String? success}) {
    _isLoading = loading;
    _errorMessage = error;
    _successMessage = success;
    notifyListeners();
  }
  
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }

  Future<void> fetchSchools({required String token}) async {
    _setLoading(true);
    try {
      _schools = await _apiService.getSchools(token: token);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchStudents({required String schoolName, required String token}) async {
    _setLoading(true);
    try {
      _allStudents = await _apiService.getStudents(schoolName: schoolName, token: token);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }
  
  Future<void> fetchSingleStudent({
    required String schoolName,
    required String studentId,
    required String token,
  }) async {
    try {
      final student = await _apiService.getStudentById(
        schoolName: schoolName,
        studentId: studentId,
        token: token
      );
      
      final index = _allStudents.indexWhere((s) => s.id == studentId);
      if (index != -1) {
        _allStudents[index] = student;
        notifyListeners();
      }
    } catch (e) {
      print("Failed to fetch single student details: $e");
    }
  }

  Future<bool> createNewSchool({required String schoolName, required String token}) async {
    _setLoading(true);
    try {
      final newSchoolData = await _apiService.createSchool(schoolName, token: token);
      final newSchool = School.fromJson(newSchoolData);
      _schools.add(newSchool);
      _schools.sort((a, b) => a.name.compareTo(b.name));
      _setLoading(false, success: 'สร้างโรงเรียน "$schoolName" สำเร็จ');
      return true;
    } catch (e) {
      _setLoading(false, error: e.toString());
      return false;
    }
  }

  Future<bool> removeSchool(String schoolName, String token) async {
    _setLoading(true);
    try {
      await _apiService.deleteSchool(schoolName, token);
      _schools.removeWhere((s) => s.name == schoolName);
      _setLoading(false, success: "ลบโรงเรียนสำเร็จ");
      return true;
    } catch (e) {
      _setLoading(false, error: e.toString());
      return false;
    }
  }

  Future<bool> uploadCsv({
    required String schoolName,
    required PlatformFile csvFile,
    required String token,
  }) async {
    _setLoading(true);
    try {
      final response = await _apiService.uploadStudentsCsv(
        schoolName: schoolName, csvFile: csvFile, token: token
      );
      await fetchStudents(schoolName: schoolName, token: token);
      _setLoading(false, success: response['message'] ?? 'อัปโหลดข้อมูลสำเร็จ');
      return true;
    } catch (e) {
      _setLoading(false, error: e.toString());
      return false;
    }
  }

  Future<bool> uploadStudentPhoto({
    required String schoolName,
    required String studentId,
    required XFile imageFile,
    required String token,
  }) async {
    _setLoading(true);
    try {
      final updatedStudentJson = await _apiService.uploadStudentPhoto(
        schoolName: schoolName, studentId: studentId, imageFile: imageFile, token: token,
      );
      final updatedStudent = Student.fromJson(updatedStudentJson);
      final index = _allStudents.indexWhere((s) => s.id == studentId);
      if (index != -1) {
        _allStudents[index] = updatedStudent;
      }
      _setLoading(false, success: 'อัปเดตรูปภาพสำเร็จ!');
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false, error: e.toString());
      return false;
    }
  }

  Future<bool> addStudent(Student student, String token) async {
    _setLoading(true);
    try {
      await _apiService.createStudent(student.schoolName, student, token);
      await fetchStudents(schoolName: student.schoolName, token: token);
      _setLoading(false, success: "เพิ่มข้อมูลนักเรียนสำเร็จ");
      return true;
    } catch (e) {
      _setLoading(false, error: e.toString());
      return false;
    }
  }

  Future<bool> editStudent(Student student, String token) async {
    _setLoading(true);
    try {
      final updatedStudent = await _apiService.updateStudent(student.schoolName, student.id, student, token);
      final index = _allStudents.indexWhere((s) => s.id == student.id);
      if (index != -1) {
        _allStudents[index] = updatedStudent;
      }
      _setLoading(false, success: "แก้ไขข้อมูลสำเร็จ");
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false, error: e.toString());
      return false;
    }
  }

  Future<bool> removeStudent(String schoolName, String studentId, String token) async {
    _setLoading(true);
    try {
      await _apiService.deleteStudent(schoolName, studentId, token);
      _allStudents.removeWhere((s) => s.id == studentId);
      _setLoading(false, success: "ลบนักเรียนสำเร็จ");
      return true;
    } catch (e) {
      _setLoading(false, error: e.toString());
      return false;
    }
  }

  Future<String?> exportFilteredStudents({
    required String schoolName,
    required String token,
    required Map<String, dynamic> filters,
  }) async {
    _setLoading(true);
    try {
      if (!kIsWeb) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            throw Exception("ไม่ได้รับอนุญาตให้เข้าถึงพื้นที่จัดเก็บข้อมูล");
          }
        }
      }

      final zipBytes = await _apiService.exportStudentsAsZip(schoolName, filters, token);
      
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      String fileName = "${schoolName}_export_$timestamp.zip";
      
      if (kIsWeb) {
        await FileSaver.instance.saveFile(
            name: fileName,
            bytes: zipBytes,
            ext: "zip",
            mimeType: MimeType.zip
        );
      } else {
        String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

        if (selectedDirectory == null) {
          _setLoading(false);
          return "ยกเลิกการ Export";
        }

        final filePath = '$selectedDirectory/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(zipBytes);
      }

      final successMessage = "Export สำเร็จ! บันทึกไฟล์แล้ว";
      _setLoading(false, success: successMessage);
      return successMessage;
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false, error: errorMessage);
      return null;
    }
  }
}
