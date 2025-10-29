// filepath: lib/features/worker_app/presentation/pages/worker_profile_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

import 'package:agapecares/core/services/session_service.dart';
import 'package:agapecares/core/models/user_model.dart';
import 'package:agapecares/app/routes/app_routes.dart';

class WorkerProfilePage extends StatefulWidget {
  const WorkerProfilePage({Key? key}) : super(key: key);

  @override
  State<WorkerProfilePage> createState() => _WorkerProfilePageState();
}

class _WorkerProfilePageState extends State<WorkerProfilePage> {
  // Controllers
  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _bankNameCtl = TextEditingController();
  final _accountCtl = TextEditingController();
  final _ifscCtl = TextEditingController();
  // Hidden controllers (populated by upload)
  final _profileUrlCtl = TextEditingController();
  final _idUrlCtl = TextEditingController();

  // State
  bool _loading = true;
  bool _saving = false;
  UserModel? _sessionUser;
  String _verificationStatus = 'unknown'; // 'pending'|'verified'|'rejected'|'unknown'
  String _supportPhone = '';
  String _supportEmail = '';

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  String? _userId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _profileUrlCtl.dispose();
    _idUrlCtl.dispose();
    _bankNameCtl.dispose();
    _accountCtl.dispose();
    _ifscCtl.dispose();
    _userSub?.cancel();
    super.dispose();
  }

  // --- LOGIC METHODS (Unchanged) ---

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      UserModel? u;
      try {
        final session = context.read<SessionService>();
        u = session.getUser();
      } catch (_) {
        u = null;
      }

      // If we have a session user, prefill
      if (u != null) {
        _sessionUser = u;
        _nameCtl.text = u.name ?? '';
        _phoneCtl.text = u.phoneNumber ?? '';
        _profileUrlCtl.text = u.photoUrl ?? '';
        // session UserModel has no 'meta' field; id URL may not be available in session
        _idUrlCtl.text = '';
      }

      // Fallback / real-time: subscribe to user doc if we can resolve a uid
      try {
        String? resolvedUid = _sessionUser?.uid;
        final fb = FirebaseAuth.instance.currentUser;
        if ((resolvedUid == null || resolvedUid.isEmpty) && fb != null) resolvedUid = fb.uid;

        if (resolvedUid != null && resolvedUid.isNotEmpty) {
          _userId = resolvedUid;
          _userSub?.cancel();
          _userSub = FirebaseFirestore.instance.collection('users').doc(resolvedUid).snapshots().listen((doc) {
            if (!mounted) return;
            if (!doc.exists) return;
            final data = doc.data() ?? {};
            setState(() {
              _nameCtl.text = (data['name'] as String?) ?? _nameCtl.text;
              _phoneCtl.text = (data['phoneNumber'] as String?) ?? _phoneCtl.text;
              _profileUrlCtl.text = (data['profilePhotoUrl'] as String?) ?? (data['photoUrl'] as String?) ?? _profileUrlCtl.text;
              _idUrlCtl.text = (data['idPhotoUrl'] as String?) ?? (data['idUrl'] as String?) ?? _idUrlCtl.text;
              final vs = (data['verificationStatus'] as String?) ?? ((data['meta'] is Map && (data['meta'] as Map)['verification'] is Map) ? ((data['meta'] as Map)['verification']['status'] as String?) : null);
              if (vs != null && vs.isNotEmpty) _verificationStatus = vs;
              final bank = data['bankDetails'] as Map<String, dynamic>?;
              if (bank != null) {
                _bankNameCtl.text = (bank['bankName'] as String?) ?? _bankNameCtl.text;
                _accountCtl.text = (bank['accountNumber'] as String?) ?? _accountCtl.text;
                _ifscCtl.text = (bank['ifsc'] as String?) ?? _ifscCtl.text;
              }
            });
          }, onError: (e) {
            debugPrint('[WorkerProfilePage] userSub error: $e');
          });
        }
      } catch (e) {
        debugPrint('[WorkerProfilePage] subscribe user doc failed: $e');
      }

      // Load support contact from a well-known config document if present (best-effort)
      try {
        final cfg = await FirebaseFirestore.instance.collection('appConfig').doc('support').get();
        if (cfg.exists) {
          final d = cfg.data() ?? {};
          _supportPhone = (d['phone'] as String?) ?? _supportPhone;
          _supportEmail = (d['email'] as String?) ?? _supportEmail;
        }
      } catch (_) {}

      // if still empty, set sensible defaults (non-blocking)
      _supportPhone = _supportPhone.isNotEmpty ? _supportPhone : '+18001234567';
      _supportEmail = _supportEmail.isNotEmpty ? _supportEmail : 'support@example.com';
    } catch (e) {
      debugPrint('[WorkerProfilePage] loadProfile error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      final fb = FirebaseAuth.instance.currentUser;
      if (fb == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not signed in')));
        return;
      }
      final data = <String, dynamic>{
        'name': _nameCtl.text.trim(),
        'phoneNumber': _phoneCtl.text.trim(),
        'profilePhotoUrl': _profileUrlCtl.text.trim(),
        'idPhotoUrl': _idUrlCtl.text.trim(),
        // keep a simple meta field for other verification info
        'meta': {
          'idUrl': _idUrlCtl.text.trim(),
        }
      };
      // include bank details if provided
      final bank = {
        'bankName': _bankNameCtl.text.trim(),
        'accountNumber': _accountCtl.text.trim(),
        'ifsc': _ifscCtl.text.trim(),
      };
      if (bank.values.whereType<String>().any((s) => s.trim().isNotEmpty)) data['bankDetails'] = bank;

      await FirebaseFirestore.instance.collection('users').doc(fb.uid).set(data, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));

      // Optionally update session service if available
      try {
        if (_sessionUser != null) {
          final session = context.read<SessionService>();
          final updated = _sessionUser!.copyWith(
            name: _nameCtl.text.trim(),
            phoneNumber: _phoneCtl.text.trim(),
            photoUrl: _profileUrlCtl.text.trim(),
          );
          session.saveUser(updated);
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('[WorkerProfilePage] saveProfile error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save profile: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadImage({required bool forProfile}) async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;
      final file = File(picked.path);
      final fb = FirebaseAuth.instance.currentUser;
      if (fb == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not signed in')));
        return;
      }
      final storage = FirebaseStorage.instance;
      final dest = forProfile ? 'users/${fb.uid}/profile.jpg' : 'users/${fb.uid}/id.jpg';
      final ref = storage.ref().child(dest);
      final uploadTask = ref.putFile(file);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading image...')));
      final snapshot = await uploadTask.whenComplete(() {});
      final url = await snapshot.ref.getDownloadURL();
      if (forProfile) {
        _profileUrlCtl.text = url;
      } else {
        _idUrlCtl.text = url;
        // mark verification status as pending when a new ID is uploaded
        try {
          await FirebaseFirestore.instance.collection('users').doc(fb.uid).set({'verificationStatus': 'pending', 'idPhotoUrl': url}, SetOptions(merge: true));
          setState(() => _verificationStatus = 'pending');
        } catch (e) {
          debugPrint('[WorkerProfilePage] failed to mark verification pending: $e');
        }
      }
      // Persist immediately
      await FirebaseFirestore.instance.collection('users').doc(fb.uid).set({
        if (forProfile) 'profilePhotoUrl': url else 'idPhotoUrl': url,
        'meta': {'idUrl': _idUrlCtl.text.trim()},
      }, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image uploaded')));
    } catch (e) {
      debugPrint('[WorkerProfilePage] pick/upload error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _callSupport() async {
    final uri = Uri(scheme: 'tel', path: _supportPhone);
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot place call')));
    }
  }

  Future<void> _emailSupport() async {
    final uri = Uri(scheme: 'mailto', path: _supportEmail, queryParameters: {'subject': 'Support request from worker'});
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open email client')));
    }
  }

  Future<void> _logout() async {
    try {
      try {
        final session = context.read<SessionService>();
        await session.clear();
      } catch (_) {}
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('[WorkerProfilePage] logout failed: $e');
    }
    // Navigate to login
    try {
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    } catch (_) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  // --- UI HELPER WIDGETS ---

  Widget _buildVerificationBadge(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Text('🟢 Verified', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]);
      case 'pending':
        return Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Text('🟡 Pending', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))]);
      case 'rejected':
        return Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Text('🔴 Rejected', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]);
      default:
        return Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Text('⚪ Unknown', style: TextStyle(color: Colors.grey))]);
    }
  }

  Widget _buildVerificationBanner() {
    if (_verificationStatus.toLowerCase() == 'verified') return const SizedBox.shrink();

    final bool isRejected = _verificationStatus.toLowerCase() == 'rejected';
    final Color color = isRejected ? Colors.red : Colors.amber;
    final String text = isRejected
        ? 'Verification Rejected. Please re-upload your ID.'
        : 'Complete verification to receive jobs.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isRejected ? Colors.red.shade100 : Colors.amber.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isRejected ? Colors.red.shade600 : Colors.amber.shade600),
      ),
      child: Column(
        children: [
          Text(
            text,
            style: TextStyle(fontWeight: FontWeight.bold, color: isRejected ? Colors.red.shade900 : Colors.amber.shade900),
            textAlign: TextAlign.center,
          ),
          if (!isRejected) ...[
            const SizedBox(height: 4),
            _buildVerificationBadge(_verificationStatus),
          ]
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundImage: _profileUrlCtl.text.trim().isNotEmpty ? NetworkImage(_profileUrlCtl.text.trim()) : null,
          child: _profileUrlCtl.text.trim().isEmpty ? Text((_nameCtl.text.trim().isNotEmpty ? _nameCtl.text.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').join() : 'W')) : null,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () => _pickAndUploadImage(forProfile: true),
              icon: const Icon(Icons.photo_camera, size: 18),
              label: const Text('Upload Photo'),
            ),
            TextButton.icon(
              onPressed: () => _pickAndUploadImage(forProfile: false),
              icon: const Icon(Icons.badge_outlined, size: 18),
              label: const Text('Upload ID'),
            ),
          ],
        ),
        if (_verificationStatus.toLowerCase() == 'verified')
          _buildVerificationBadge(_verificationStatus)
        else
          const SizedBox(height: 8), // just for spacing
      ],
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSupportSection() {
    return Card(
      elevation: 0,
      color: Colors.blueGrey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Need Help?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: _callSupport, icon: const Icon(Icons.call_outlined), label: const Text('Call'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: _emailSupport, icon: const Icon(Icons.email_outlined), label: const Text('Email'))),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      try {
                        GoRouter.of(context).go(AppRoutes.messages);
                      } catch (_) {
                        Navigator.of(context).pushNamed(AppRoutes.messages);
                      }
                    },
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('Chat'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Worker Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildVerificationBanner(),

            _buildProfileHeader(),

            const SizedBox(height: 24),

            _buildSectionCard(
              title: 'Personal Details',
              children: [
                TextField(
                  controller: _nameCtl,
                  decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtl,
                  decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildSectionCard(
              title: 'Bank Details (for payouts)',
              children: [
                TextField(
                  controller: _bankNameCtl,
                  decoration: const InputDecoration(labelText: 'Bank Name', prefixIcon: Icon(Icons.account_balance_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _accountCtl,
                  decoration: const InputDecoration(labelText: 'Account Number', prefixIcon: Icon(Icons.pin_outlined)),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ifscCtl,
                  decoration: const InputDecoration(labelText: 'IFSC / Routing', prefixIcon: Icon(Icons.code_outlined)),
                ),
              ],
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveProfile,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save Profile'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 16),

            _buildSupportSection(),

            const SizedBox(height: 16),

            Center(
              child: TextButton.icon(
                onPressed: _logout,
                icon: Icon(Icons.logout, color: Colors.red[700]),
                label: Text('Logout', style: TextStyle(color: Colors.red[700])),
              ),
            ),
          ],
        ),
      ),
    );
  }
}