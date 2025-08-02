import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import 'package:easycrop_e1/model/school_model.dart';
import 'package:easycrop_e1/model/student_model.dart';

class ApiService {
  final String _baseUrl = "http://192.168.1.32:8000/api";

  // --- School Endpoints ---
  Future<List<School>> getSchools({required String token}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/schools'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((dynamic item) => School.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load schools. Status: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> createSchool(String schoolName, {required String token}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/schools'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'name': schoolName}),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(errorBody['detail'] ?? 'Failed to create school');
    }
  }

  Future<void> deleteSchool(String schoolName, String token) async {
    final uri = Uri.parse('$_baseUrl/schools/$schoolName');
    final response = await http.delete(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete school');
    }
  }

  // --- Student Endpoints ---
  Future<List<Student>> getStudents({
    required String schoolName,
    required String token,
    String? search,
    String? gradeLevel,
    String? className,
    String? photoStatus,
  }) async {
    final queryParameters = <String, String>{};
    if (search != null && search.isNotEmpty) queryParameters['search'] = search;
    if (gradeLevel != null && gradeLevel != 'ทั้งหมด') queryParameters['gradeLevel'] = gradeLevel;
    if (className != null && className != 'ทั้งหมด') queryParameters['className'] = className;
    if (photoStatus != null && photoStatus != 'ทั้งหมด') {
      final statusMap = {
        'มีรูป (สมบูรณ์)': 'finish',
        'กำลังประมวลผล': 'processed',
        'ไม่มีรูป': 'no_photo',
        'ผิดพลาด': 'error'
      };
      queryParameters['photoStatus'] = statusMap[photoStatus] ?? '';
    }

    final uri = Uri.parse('$_baseUrl/schools/$schoolName/students').replace(
      queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
    );

    final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((dynamic item) => Student.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load students. Status: ${response.statusCode}, Body: ${response.body}');
    }
  }
  
  Future<Student> getStudentById({
    required String schoolName,
    required String studentId,
    required String token
  }) async {
    final uri = Uri.parse('$_baseUrl/schools/$schoolName/students/$studentId');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return Student.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Failed to load student details. Status: ${response.statusCode}, Body: ${response.body}');
    }
  }

  Future<Student> createStudent(String schoolName, Student student, String token) async {
    final uri = Uri.parse('$_baseUrl/schools/$schoolName/students/');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode(student.toJson()),
    );
    if (response.statusCode == 201) {
      return Student.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Failed to create student: ${response.body}');
    }
  }

  Future<Student> updateStudent(String schoolName, String studentId, Student student, String token) async {
    final uri = Uri.parse('$_baseUrl/schools/$schoolName/students/$studentId');
    final response = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode(student.toJson()),
    );
    if (response.statusCode == 200) {
      return Student.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Failed to update student: ${response.body}');
    }
  }

  Future<void> deleteStudent(String schoolName, String studentId, String token) async {
    final uri = Uri.parse('$_baseUrl/schools/$schoolName/students/$studentId');
    final response = await http.delete(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete student');
    }
  }

  Future<Map<String, dynamic>> uploadStudentPhoto({
    required String schoolName,
    required String studentId,
    required XFile imageFile,
    required String token,
  }) async {
    final uri = Uri.parse('$_baseUrl/schools/$schoolName/students/$studentId/photo');
    var request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: MediaType('image', 'jpeg'),
      ),
    );
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(errorBody['detail'] ?? 'Failed to upload photo');
    }
  }

  Future<Map<String, dynamic>> uploadStudentsCsv({
    required String schoolName,
    required PlatformFile csvFile,
    required String token,
  }) async {
    final uri = Uri.parse('$_baseUrl/schools/$schoolName/students/upload-csv');
    var request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        csvFile.bytes!,
        filename: csvFile.name,
        contentType: MediaType('text', 'csv'),
      ),
    );
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(errorBody['detail'] ?? 'Failed to upload CSV');
    }
  }

  Future<Uint8List> exportStudentsAsZip(String schoolName, Map<String, dynamic> filters, String token) async {
    final uri = Uri.parse('$_baseUrl/schools/$schoolName/students/export-zip');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode(filters),
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      try {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['detail'] ?? 'Failed to export students');
      } catch (_) {
        throw Exception('Failed to export students. Status code: ${response.statusCode}');
      }
    }
  }

  // --- Auth & User Endpoints ---
  Future<Map<String, dynamic>> login(String emailOrUsername, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'emailOrUsername': emailOrUsername, 'password': password}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorBody['detail'] ?? 'Failed to login');
    }
  }

  Future<void> signup({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'username': username, 'email': email, 'password': password}),
    );
    if (response.statusCode != 201) {
      final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorBody['detail'] ?? 'Failed to sign up');
    }
  }

  Future<Map<String, dynamic>> getUserData(String uid, {required String token}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/$uid'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to load user data. Status: ${response.statusCode}, Body: ${response.body}');
    }
  }
  
  Future<void> updateUserProfile({
    required String newUsername,
    required String token,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/users/me'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(<String, String>{
        'username': newUsername,
      }),
    );
    if (response.statusCode != 200) {
      final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorBody['detail'] ?? 'Failed to update profile');
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/change-password'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'current_password': currentPassword, 'new_password': newPassword}),
    );
    if (response.statusCode != 200) {
      final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorBody['detail'] ?? 'Failed to change password');
    }
  }
}
