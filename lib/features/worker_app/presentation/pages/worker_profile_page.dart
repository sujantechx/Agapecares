// filepath: c:\FlutterDev\agapecares\lib\features\worker_app\presentation\pages\worker_profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agapecares/features/worker_app/data/repositories/worker_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WorkerProfilePage extends StatefulWidget {
  const WorkerProfilePage({Key? key}) : super(key: key);

  @override
  State<WorkerProfilePage> createState() => _WorkerProfilePageState();
}

class _WorkerProfilePageState extends State<WorkerProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtr = TextEditingController();
  final _emailCtr = TextEditingController();
  final _phoneCtr = TextEditingController();
  bool _loading = true;
  String? _workerId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not signed in')));
        setState(() => _loading = false);
        return;
      }
      _workerId = user.uid;
      final repo = context.read<WorkerRepository>();
      final profile = await repo.fetchWorkerProfile(_workerId!);
      if (profile != null) {
        _nameCtr.text = profile.name ?? '';
        _emailCtr.text = profile.email ?? '';
        // user_model stores phone as `phoneNumber`
        _phoneCtr.text = profile.phoneNumber;
      } else {
        // fallback to Firebase profile
        _nameCtr.text = user.displayName ?? '';
        _emailCtr.text = user.email ?? '';
        _phoneCtr.text = user.phoneNumber ?? '';
      }
    } catch (e) {
      debugPrint('[WorkerProfilePage] load error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_workerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Worker id missing')));
      return;
    }
    setState(() => _loading = true);
    try {
      final updates = <String, dynamic>{
        'name': _nameCtr.text.trim(),
        'email': _emailCtr.text.trim(),
        // store phone under `phoneNumber` to match UserModel
        'phoneNumber': _phoneCtr.text.trim(),
        'role': 'worker',
      };
      final repo = context.read<WorkerRepository>();
      final ok = await repo.updateWorkerProfile(_workerId!, updates);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update profile')));
      }
    } catch (e) {
      debugPrint('[WorkerProfilePage] save error: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error saving profile')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtr.dispose();
    _emailCtr.dispose();
    _phoneCtr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Worker Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtr,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailCtr,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter email' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneCtr,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter phone' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: _save,
                          child: const Text('Save'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
