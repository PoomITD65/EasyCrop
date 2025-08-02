import 'package:easycrop_e1/model/school_model.dart';
import 'package:easycrop_e1/providers/school_provider.dart';
import 'package:easycrop_e1/providers/user_provider.dart';
import 'package:easycrop_e1/screen/manage_students_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ManageSchoolsScreen extends StatefulWidget {
  const ManageSchoolsScreen({super.key});

  @override
  State<ManageSchoolsScreen> createState() => _ManageSchoolsScreenState();
}

class _ManageSchoolsScreenState extends State<ManageSchoolsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInitialData();
    });
  }

  Future<void> _fetchInitialData() async {
    final token = context.read<UserProvider>().token;
    if (token != null && mounted) {
      // Use listen: false in methods outside of build
      await context.read<SchoolProvider>().fetchSchools(token: token);
    }
  }

  // ✅ --- เพิ่มฟังก์ชันสำหรับแสดง Dialog ยืนยันการลบ ---
  Future<void> _confirmDelete(BuildContext context, School school) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text(
            'คุณต้องการลบโรงเรียน "${school.name}" ใช่หรือไม่? ข้อมูลนักเรียนทั้งหมดในโรงเรียนนี้จะถูกลบอย่างถาวร'),
        actions: [
          TextButton(
            child: const Text('ยกเลิก'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final token = context.read<UserProvider>().token;
      if (token != null) {
        // Use listen: false here as well
        await context.read<SchoolProvider>().removeSchool(school.name, token);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolProvider = context.watch<SchoolProvider>();
    final schools = schoolProvider.schools;

    return Scaffold(
      appBar: AppBar(
        title: const Text('เลือกโรงเรียนเพื่อจัดการ'),
      ),
      body: schoolProvider.isLoading && schools.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchInitialData,
              child: ListView.builder(
                itemCount: schools.length,
                itemBuilder: (ctx, index) {
                  final school = schools[index];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        child: Icon(
                          Icons.school_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(school.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      
                      // ✅ --- แก้ไข Trailing ให้มีปุ่มลบ ---
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                        onPressed: () => _confirmDelete(context, school),
                        tooltip: 'ลบโรงเรียน',
                      ),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (ctx) =>
                              ManageStudentsScreen(school: school),
                        ));
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}