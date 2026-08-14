import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/providers/auth_provider.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/app_glow_background.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  String? _selectedAvatar;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authProvider).valueOrNull;
    _selectedAvatar = profile?.avatarUrl;
  }

  List<String> get _avatarOptions {
    final gender = ref.read(authProvider).valueOrNull?.gender;
    if (gender == 'male') return ['L1', 'L2', 'L3'];
    if (gender == 'female') return ['W1', 'W2', 'W3'];
    return ['L1', 'L2', 'L3', 'W1', 'W2', 'W3'];
  }

  Future<void> _save() async {
    try {
      final profile = ref.read(authProvider).valueOrNull;
      await ref.read(authProvider.notifier).updateProfile(
        fullName: profile?.fullName ?? '',
        email: profile?.email ?? '',
        gender: profile?.gender,
        avatarAsset: _selectedAvatar != null ? 'assets/profiles/$_selectedAvatar.gif' : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated'), backgroundColor: Color(0xFF7C3AED)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e'), backgroundColor: const Color(0xFFFF453A)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(CupertinoIcons.chevron_back, color: const Color(0xFFFFFFFF), size: 24),
                  ),
                  const Text('Edit Profile', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF), decoration: TextDecoration.none)),
                  const SizedBox(width: 24),
                ],
              ),
              const SizedBox(height: 20),
              Text('Choose Profile', style: ClayTokens.darkBodySmall.copyWith(color: ClayTokens.clayDarkTextSecondary)),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: _avatarOptions.map((asset) {
                  final selected = _selectedAvatar == asset;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedAvatar = asset),
                    child: AnimatedContainer(
                      duration: ClayTokens.normal,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: selected ? ClayTokens.clayPrimary : Colors.transparent, width: 3),
                      ),
                      child: CircleAvatar(
                        radius: 36,
                        backgroundImage: AssetImage('assets/profiles/$asset.gif'),
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => context.pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: ClayTokens.clayDarkTextSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF38383A))),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ClayTokens.clayPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
