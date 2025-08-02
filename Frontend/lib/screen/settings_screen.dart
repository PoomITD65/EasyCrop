import 'package:easycrop_e1/providers/theme_provider.dart';
import 'package:easycrop_e1/screen/change_password_screen.dart';
import 'package:easycrop_e1/screen/edit_profile_screen.dart';
import 'package:easycrop_e1/screen/reauth_for_delete_screen.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = 'Loading...';

  @override
  void initState() {
    super.initState();
    _getAppVersion();
  }

  Future<void> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _appVersion = 'ไม่สามารถโหลดได้');
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถเปิดลิงก์ได้: $url')),
        );
      }
    }
  }
  
  Future<void> _showInfoDialog(String title, String content) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Text(content),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('ปิด'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ยืนยันการลบบัญชี'),
          content: const SingleChildScrollView(
            child: Text('คุณแน่ใจหรือไม่ว่าต้องการลบบัญชีของคุณ? การกระทำนี้ไม่สามารถย้อนกลับได้ และข้อมูลทั้งหมดของคุณจะถูกลบอย่างถาวร'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('ยกเลิก'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('ยืนยันการลบ'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (ctx) => const ReAuthForDeleteScreen(),
                ));
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    const String termsOfServiceContent = """
**ข้อตกลงการใช้งาน (Terms of Service)**
อัปเดตล่าสุด: 16 กรกฎาคม 2568

ยินดีต้อนรับสู่แอปพลิเคชัน EasyCrop E1 ("บริการ") โปรดอ่านข้อกำหนดและเงื่อนไขการใช้บริการเหล่านี้อย่างละเอียดก่อนใช้งาน

**1. การยอมรับข้อกำหนด**
การเข้าถึงหรือใช้งานบริการของเรา แสดงว่าคุณตกลงที่จะผูกพันตามข้อกำหนดและเงื่อนไขเหล่านี้ หากคุณไม่ยอมรับส่วนใดส่วนหนึ่งของข้อกำหนด คุณจะไม่สามารถเข้าถึงบริการได้

**2. บัญชีผู้ใช้**
- คุณมีหน้าที่รับผิดชอบในการให้ข้อมูลที่ถูกต้องและเป็นปัจจุบันในการสมัครสมาชิก
- คุณมีหน้าที่รับผิดชอบในการรักษากิจกรรมทั้งหมดที่เกิดขึ้นภายใต้บัญชีของคุณ และรับผิดชอบในการรักษารหัสผ่านของคุณให้ปลอดภัย
- คุณตกลงที่จะแจ้งให้เราทราบทันทีเมื่อมีการใช้งานบัญชีของคุณโดยไม่ได้รับอนุญาต

**3. การใช้งานบริการ**
คุณตกลงที่จะไม่ใช้บริการเพื่อวัตถุประสงค์ต่อไปนี้:
- กระทำการใดๆ ที่ผิดกฎหมาย หรือส่งเสริมกิจกรรมที่ผิดกฎหมาย
- แอบอ้างเป็นบุคคลหรือหน่วยงานอื่น
- พยายามเข้าถึงระบบคอมพิวเตอร์หรือเครือข่ายที่เชื่อมต่อกับบริการโดยไม่ได้รับอนุญาต
- ใช้บริการในลักษณะที่อาจสร้างความเสียหาย, ขัดขวาง, หรือเป็นภาระต่อเซิร์ฟเวอร์ของเรา

**4. การระงับหรือยกเลิกบัญชี**
เราขอสงวนสิทธิ์ในการระงับหรือยกเลิกบัญชีของคุณได้ทุกเมื่อ โดยไม่ต้องแจ้งให้ทราบล่วงหน้า หากเราเชื่อว่าคุณได้ละเมิดข้อกำหนดเหล่านี้
""";

    const String privacyPolicyContent = """
**นโยบายความเป็นส่วนตัว (Privacy Policy)**
อัปเดตล่าสุด: 16 กรกฎาคม 2568

เราให้ความสำคัญกับความเป็นส่วนตัวของคุณ นโยบายนี้อธิบายถึงวิธีที่เรารวบรวม, ใช้, และปกป้องข้อมูลของคุณเมื่อคุณใช้บริการของเรา

**1. ข้อมูลที่เรารวบรวม**
- ข้อมูลส่วนบุคคล: เช่น ชื่อผู้ใช้, อีเมล ที่คุณให้ไว้เมื่อทำการสมัครสมาชิก
- ข้อมูลการใช้งาน: ข้อมูลเกี่ยวกับวิธีที่คุณโต้ตอบกับบริการของเรา
- ข้อมูลนักเรียน: ข้อมูลต่างๆ ที่คุณอัปโหลดผ่านไฟล์ CSV

**2. เราใช้ข้อมูลของคุณอย่างไร**
- เพื่อให้บริการและบำรุงรักษาบริการของเรา
- เพื่อจัดการบัญชีผู้ใช้ของคุณ
- เพื่อปรับปรุงและพัฒนาแอปพลิเคชัน
- เพื่อตรวจสอบและป้องกันการฉ้อโกง

**3. ความปลอดภัยของข้อมูล**
เราใช้มาตรการรักษาความปลอดภัยที่เหมาะสมเพื่อป้องกันการเข้าถึงข้อมูลของคุณโดยไม่ได้รับอนุญาต แต่ไม่มีวิธีการใดที่ปลอดภัย 100%
""";

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่า'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('บัญชีผู้ใช้'),
          _buildSettingsTile(
            context: context,
            icon: Icons.person_outline,
            title: 'แก้ไขข้อมูลส่วนตัว',
            onTap: () async {
              // เรายังคงต้องรอรับผลลัพธ์ แต่จะไม่ทำอะไรกับมัน
              // เพื่อให้รู้ว่าควรจะ refresh ตอนที่ user กด back เอง
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (ctx) => const EditProfileScreen(),
              ));
              // ไม่มี Navigator.pop(true) อีกต่อไป
            },
          ),
          _buildSettingsTile(
            context: context,
            icon: Icons.lock_outline,
            title: 'เปลี่ยนรหัสผ่าน',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (ctx) => const ChangePasswordScreen(),
              ));
            },
          ),
          _buildSettingsTile(
            context: context,
            icon: Icons.delete_outline,
            title: 'ลบบัญชีผู้ใช้',
            color: theme.colorScheme.error,
            onTap: _showDeleteConfirmationDialog,
          ),
          
          const Divider(height: 20, indent: 16, endIndent: 16),

          _buildSectionHeader('การแสดงผล'),
          SwitchListTile(
            secondary: Icon(Icons.dark_mode_outlined, color: theme.textTheme.bodySmall?.color),
            title: const Text('โหมดสีเข้ม (Dark Mode)'),
            value: themeProvider.isDarkMode,
            onChanged: (bool value) {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme(value);
            },
            activeColor: theme.colorScheme.primary,
          ),
          
          const Divider(height: 20, indent: 16, endIndent: 16),

          _buildSectionHeader('เกี่ยวกับแอปพลิเคชัน'),
          _buildSettingsTile(
            context: context,
            icon: Icons.info_outline,
            title: 'เวอร์ชัน',
            trailing: Text(_appVersion, style: TextStyle(color: Colors.grey.shade600)),
          ),
          _buildSettingsTile(
            context: context,
            icon: Icons.description_outlined,
            title: 'ข้อตกลงการใช้งาน',
            onTap: () => _showInfoDialog('ข้อตกลงการใช้งาน', termsOfServiceContent),
          ),
           _buildSettingsTile(
            context: context,
            icon: Icons.privacy_tip_outlined,
            title: 'นโยบายความเป็นส่วนตัว',
            onTap: () => _showInfoDialog('นโยโยบายความเป็นส่วนตัว', privacyPolicyContent),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: color ?? theme.textTheme.bodyLarge?.color),
      title: Text(title, style: TextStyle(color: color, fontSize: 16)),
      trailing: (onTap != null && trailing == null) 
          ? Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400)
          : trailing,
      onTap: onTap,
    );
  }
}