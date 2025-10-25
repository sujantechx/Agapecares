// Minimal WorkerProfilePage implementation to satisfy router references
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

import 'package:agapecares/core/services/session_service.dart';
import 'package:agapecares/core/models/user_model.dart';

class WorkerProfilePage extends StatefulWidget {
  const WorkerProfilePage({Key? key}) : super(key: key);

  @override
  State<WorkerProfilePage> createState() => _WorkerProfilePageState();
}

class _WorkerProfilePageState extends State<WorkerProfilePage> {
  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _profileUrlCtl = TextEditingController();
  final _idUrlCtl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  UserModel? _sessionUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

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
      } else {
        // Fallback: read from Firestore using FirebaseAuth
        final fb = FirebaseAuth.instance.currentUser;
        if (fb != null) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(fb.uid).get();
          if (doc.exists) {
            final data = doc.data()!;
            _nameCtl.text = (data['name'] as String?) ?? '';
            _phoneCtl.text = (data['phoneNumber'] as String?) ?? fb.phoneNumber ?? '';
            _profileUrlCtl.text = (data['profilePhotoUrl'] as String?) ?? (data['photoUrl'] as String?) ?? '';
            _idUrlCtl.text = (data['idPhotoUrl'] as String?) ?? (data['idUrl'] as String?) ?? '';
          }
        }
      }
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

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _profileUrlCtl.dispose();
    _idUrlCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Worker Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundImage: _profileUrlCtl.text.trim().isNotEmpty ? NetworkImage(_profileUrlCtl.text.trim()) : null,
                          child: _profileUrlCtl.text.trim().isEmpty ? Text((_nameCtl.text.trim().isNotEmpty ? _nameCtl.text.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').join() : 'W')) : null,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              onPressed: () => _pickAndUploadImage(forProfile: true),
                              icon: const Icon(Icons.photo),
                              label: const Text('Upload Photo'),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => _pickAndUploadImage(forProfile: false),
                              icon: const Icon(Icons.badge_outlined),
                              label: const Text('Upload ID'),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameCtl,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneCtl,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _profileUrlCtl,
                    decoration: const InputDecoration(labelText: 'Profile Photo URL'),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _idUrlCtl,
                    decoration: const InputDecoration(labelText: 'ID / Verification Photo URL'),
                    keyboardType: TextInputType.url,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _saveProfile,
                          icon: const Icon(Icons.save),
                          label: Text(_saving ? 'Saving...' : 'Save Profile'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
