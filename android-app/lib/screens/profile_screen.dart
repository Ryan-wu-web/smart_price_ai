import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _nickname = 'User';
  String? _avatarPath;
  int _scanCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nickname = prefs.getString('profile_nickname') ?? 'User';
      _avatarPath = prefs.getString('profile_avatar');
      _scanCount = prefs.getInt('scan_count') ?? 0;
    });
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 400);
    if (picked == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_avatar', picked.path);
    if (!mounted) return;
    setState(() => _avatarPath = picked.path);
  }

  Future<void> _editNickname() async {
    final controller = TextEditingController(text: _nickname);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 16,
          decoration: const InputDecoration(
            hintText: '请输入昵称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存', style: TextStyle(color: Constants.brandColor)),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_nickname', result);
    if (!mounted) return;
    setState(() => _nickname = result);
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除所有缓存数据吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除', style: TextStyle(color: Constants.errorColor)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    setState(() {
      _nickname = 'User';
      _avatarPath = null;
      _scanCount = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('缓存已清除')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildStats(),
              const SizedBox(height: 24),
              _buildMenu(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Constants.radiusXLarge),
        boxShadow: const [Constants.shadowCard],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickAvatar,
            child: Stack(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Constants.brandColor.withOpacity(0.12),
                    border: Border.all(color: Constants.brandColor.withOpacity(0.3), width: 2),
                    image: _avatarPath != null && File(_avatarPath!).existsSync()
                        ? DecorationImage(image: FileImage(File(_avatarPath!)), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _avatarPath == null || !File(_avatarPath!).existsSync()
                      ? const Icon(Icons.person, color: Constants.brandColor, size: 36)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Constants.brandColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _editNickname,
                  child: Row(
                    children: [
                      Text(
                        _nickname,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Constants.primaryTextColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit, size: 16, color: Constants.tertiaryTextColor),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '点击头像或昵称可修改',
                  style: TextStyle(fontSize: 12, color: Constants.tertiaryTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Constants.radiusXLarge),
        boxShadow: const [Constants.shadowCard],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('$_scanCount', '识别次数', Icons.camera_alt),
          Container(width: 1, height: 40, color: Constants.borderColor),
          _buildStatItem('0', '收藏商品', Icons.favorite_border),
          Container(width: 1, height: 40, color: Constants.borderColor),
          _buildStatItem('0', '比价报告', Icons.assignment_outlined),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Constants.brandColor, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Constants.primaryTextColor),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Constants.secondaryTextColor)),
      ],
    );
  }

  Widget _buildMenu() {
    final items = [
      _MenuItem(Icons.settings_outlined, '设置', () {}),
      _MenuItem(Icons.notifications_outlined, '消息通知', () {}),
      _MenuItem(Icons.help_outline, '帮助与反馈', () {}),
      _MenuItem(Icons.info_outline, '关于', () => _showAbout()),
      _MenuItem(Icons.delete_outline, '清除缓存', _clearCache, color: Constants.errorColor),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Constants.radiusXLarge),
        boxShadow: const [Constants.shadowCard],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              ListTile(
                leading: Icon(item.icon, color: item.color ?? Constants.primaryTextColor, size: 22),
                title: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: item.color ?? Constants.primaryTextColor,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, color: Constants.tertiaryTextColor, size: 20),
                onTap: item.onTap,
              ),
              if (i < items.length - 1)
                const Divider(height: 1, indent: 56, endIndent: 16, color: Constants.borderColor),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('关于 Smart Price AI'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本: 1.0.0', style: TextStyle(fontSize: 14)),
            SizedBox(height: 8),
            Text('基于 Flutter + FastAPI 构建', style: TextStyle(fontSize: 14)),
            SizedBox(height: 8),
            Text('AI 引擎: 火山引擎 Doubao', style: TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定')),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;
  _MenuItem(this.icon, this.title, this.onTap, {this.color});
}
