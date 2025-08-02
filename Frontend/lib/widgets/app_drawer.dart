import 'package:easycrop_e1/providers/user_provider.dart';
import 'package:easycrop_e1/screen/home_screen.dart';
import 'package:easycrop_e1/screen/manage_schools_screen.dart'; // ✅ 1. Import หน้าใหม่
import 'package:easycrop_e1/screen/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    // ใช้ context.watch เพื่อให้ rebuild เมื่อข้อมูลเปลี่ยน (ดีกว่า Provider.of)
    final userProvider = context.watch<UserProvider>();
    final currentUserData = userProvider.userData;

    final theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;

    final String username = currentUserData?['username'] ?? 'กำลังโหลด...';
    final String email = currentUserData?['email'] ?? '';
    final String initial = username.isNotEmpty && username != 'กำลังโหลด...'
        ? username.substring(0, 1).toUpperCase()
        : '?';

    final isAtHomeScreen = ModalRoute.of(context)?.settings.name == null;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            accountEmail: Text(email, style: const TextStyle(color: Colors.white70)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                initial,
                style: TextStyle(fontSize: 40.0, color: primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
            decoration: BoxDecoration(color: primaryColor),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              children: [
                _buildDrawerItem(
                  context: context,
                  icon: Icons.home_outlined,
                  text: 'หน้าหลัก',
                  isSelected: isAtHomeScreen,
                  onTap: () {
                    Navigator.pop(context);
                    if (!isAtHomeScreen) {
                      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (ctx) => const HomeScreen()));
                    }
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.people_outline,
                  // ✅ 2. เปลี่ยนชื่อเมนูให้ถูกต้อง
                  text: 'จัดการข้อมูลนักเรียน', 
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    // ✅ 3. แก้ไขให้ไปที่หน้า ManageSchoolsScreen
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (ctx) => const ManageSchoolsScreen(),
                    ));
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.settings_outlined,
                  text: 'ตั้งค่า',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (ctx) => const SettingsScreen(),
                    ));
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.info_outline,
                  text: 'เกี่ยวกับแอป',
                  onTap: () {
                    Navigator.pop(context);
                    showAboutDialog(
                      context: context,
                      applicationName: 'EasyCrop E1',
                      applicationVersion: '1.0.0',
                      applicationLegalese: '© 2025 Your Company Name',
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildDrawerItem(
              context: context,
              icon: Icons.logout,
              text: 'ออกจากระบบ',
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                // AuthWrapper จะจัดการสลับหน้าไป LoginScreen ให้เอง
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String text,
    required GestureTapCallback onTap,
    bool isSelected = false,
  }) {
    final theme = Theme.of(context);
    final Color color = isSelected ? theme.colorScheme.primary : theme.textTheme.bodyLarge!.color!;
    
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}