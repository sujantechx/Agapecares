import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:agapecares/core/services/session_service.dart';
import 'package:agapecares/core/models/user_model.dart';
import 'package:agapecares/app/routes/app_routes.dart';

/// UserProfilePage - shows user info and provides entry points for editing.
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  bool _initialized = false;
  UserModel? _user;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadInitialData();
    }
  }

  /// Loads initial data from session and then fetches fresh data from Firestore
  Future<void> _loadInitialData() async {
    // 1. Load from session immediately for initial build
    try {
      final session = context.read<SessionService>();
      final u = session.getUser();
      if (u != null && mounted) {
        setState(() => _user = u);
      }
    } catch (_) {}

    // 2. Fetch from Firestore for latest data
    try {
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      uid ??= context.read<SessionService>().getUser()?.uid;
      if (uid == null) return;

      final doc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists || !doc.exists) return;
      final data = doc.data();
      if (data == null) return;

      // Get session data *again* to merge
      UserModel? cur;
      try {
        cur = context.read<SessionService>().getUser();
      } catch (_) {}

      final updated = UserModel(
        uid: uid,
        name: (data['name'] as String?) ?? cur?.name,
        email: (data['email'] as String?) ?? cur?.email,
        phoneNumber:
        (data['phoneNumber'] ?? data['phone']) as String? ?? cur?.phoneNumber,
        role: cur?.role ?? UserRole.user, // Role is kept internally, just not shown
        photoUrl: cur?.photoUrl,
        addresses: (data['addresses'] is List)
            ? List<Map<String, dynamic>>.from(data['addresses'] as List)
            : cur?.addresses,
        createdAt: cur?.createdAt ?? Timestamp.now(),
      );

      // Update SessionService
      await context.read<SessionService>().saveUser(updated);

      // Update local state to trigger rebuild
      if (mounted) {
        setState(() => _user = updated);
      }
    } catch (e) {
      debugPrint("Error loading profile data: $e");
    }
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await context.read<SessionService>().clear();
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      // ignore errors
    }
    if (context.mounted) GoRouter.of(context).go(AppRoutes.login);
  }

  /// Opens the modal bottom sheet to edit profile details
  void _openEditProfileSheet(UserModel user) {
    showModalBottomSheet(
      context: context,
      // isScrollControlled allows the sheet to be taller and avoids keyboard
      isScrollControlled: true,
      builder: (ctx) {
        // We pass the user and the reload function to the sheet

        return _EditProfileSheet(
          user: user,
          onSave: (String newName, String newPhone) async {
            // Normalize phone: keep only digits, require exactly 10 digits and store with +91 prefix
            final uid = user.uid;
            final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);

            String digits = newPhone.replaceAll(RegExp(r'\D'), '');
            if (digits.length == 10) {
              final phoneToSave = '$digits';
              await userDoc.set(
                {'name': newName, 'phoneNumber': phoneToSave},
                SetOptions(merge: true),
              );
            } else {
              throw Exception('Enter 10 digit number only');
            }
            // Refresh main page data
            await _loadInitialData();
          },
        );
      },
    );
  }

  /// Opens the modal bottom sheet to edit the address
  void _openEditAddressSheet(UserModel user) {
    final currentAddress = _getPrimaryAddressMap(user);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return _EditAddressSheet(
          initialAddress: currentAddress,
          onSave: (Map<String, dynamic> newAddress) async {
            final uid = user.uid;
            final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);

            // Read existing addresses array, keep it as List<dynamic>
            final doc = await userDoc.get();
            List<dynamic> addresses = [];
            if (doc.exists && doc.data()?['addresses'] is List) {
              addresses = List<dynamic>.from(doc.data()!['addresses']);
            }

            // Remove any identical address (by address string or matching fields)
            addresses.removeWhere((e) {
              if (e is String) return e == newAddress['address'];
              if (e is Map) {
                // compare flattened address string if available
                final existing = (e['address'] ?? '') as String;
                final incoming = (newAddress['address'] ?? '') as String;
                return existing.isNotEmpty && incoming.isNotEmpty && existing == incoming;
              }
              return false;
            });

            // Insert new address at front
            addresses.insert(0, newAddress);

            await userDoc.set({'addresses': addresses}, SetOptions(merge: true));

            // Refresh main page data
            await _loadInitialData();
          },
        );
      },
    );
  }

  /// Helper to get the first address as a Map (if possible)
  Map<String, dynamic>? _getPrimaryAddressMap(UserModel? user) {
    final addresses = user?.addresses;
    if (addresses == null || addresses.isEmpty) return null;
    final dynamic addr = addresses.first;
    if (addr is Map<String, dynamic>) return addr;
    if (addr is String) return {'address': addr};
    return null;
  }

  /// Helper that returns a single-line display string for an address map
  String _formatAddressForDisplay(Map<String, dynamic>? addr) {
    if (addr == null) return '';
    if (addr.containsKey('address') && (addr['address'] as String).isNotEmpty) {
      return addr['address'] as String;
    }

    final parts = <String>[];
    void addIf(String? s) { if (s != null && s.trim().isNotEmpty) parts.add(s.trim()); }

    addIf(addr['house']?.toString());
    addIf(addr['landmark']?.toString());
    addIf(addr['village']?.toString());
    addIf(addr['city']?.toString());
    addIf(addr['state']?.toString());
    addIf(addr['pincode']?.toString());

    return parts.join(', ');
  }

  /// Helper to safely get the first address string (backwards compatible)
  String _getPrimaryAddress(UserModel? user) {
    final map = _getPrimaryAddressMap(user);
    if (map == null) return '';
    return _formatAddressForDisplay(map);
  }

  // --- Main Build Method ---

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // Use local state _user, which is loaded from session/firestore
    final UserModel? u = _user;

    final displayName = u?.name ?? 'Guest User';
    final email = u?.email ?? 'Not provided';
    final phone = u?.phoneNumber ?? 'Not provided';
    final primaryAddress = _getPrimaryAddress(u);

    // Generate initials for CircleAvatar
    String initials = 'G';
    if (displayName.isNotEmpty && displayName != 'Guest User') {
      initials = displayName
          .split(' ')
          .map((e) => e.isNotEmpty ? e[0] : '')
          .take(2)
          .join()
          .toUpperCase();
    }

    return Scaffold(
      appBar: AppBar(
        title: Center(child: const Text('My Profile')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. Profile Header Card
          Card(
            elevation: 2.0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        child: Text(
                          initials,
                          style: textTheme.headlineMedium?.copyWith(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            _ProfileInfoRow(
                              icon: Icons.email_outlined,
                              text: email,
                            ),
                            const SizedBox(height: 4),
                            _ProfileInfoRow(
                              icon: Icons.phone_outlined,
                              text: phone,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  TextButton.icon(
                    onPressed: u == null ? null : () => _openEditProfileSheet(u),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    label: const Text('Edit Profile'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Address Card
          Card(
            child: ListTile(
              leading: Icon(Icons.home_outlined, color: colorScheme.primary),
              title: const Text('Primary Address'),
              subtitle: Text(
                primaryAddress.isNotEmpty ? primaryAddress : 'No address saved',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: TextButton(
                onPressed: u == null ? null : () => _openEditAddressSheet(u),
                child: const Text('Manage'),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Navigation to Orders
          Card(
            child: ListTile(
              leading: Icon(Icons.history_edu_outlined, color: colorScheme.primary),
              title: const Text('My Orders'),
              subtitle: const Text('View your past orders'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                GoRouter.of(context).go(AppRoutes.orders);
              },
            ),
          ),
          const SizedBox(height: 32),

          // 4. Logout Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _signOut(context),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                textStyle: textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// A small helper widget for the profile card
class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ProfileInfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).textTheme.bodySmall?.color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------
// EDIT PROFILE BOTTOM SHEET WIDGET
// -----------------------------------------------------------------
class _EditProfileSheet extends StatefulWidget {
  final UserModel user;
  final Future<void> Function(String newName, String newPhone) onSave;

  const _EditProfileSheet({required this.user, required this.onSave});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _phoneCtrl = TextEditingController(text: widget.user.phoneNumber);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.onSave(_nameCtrl.text.trim(), _phoneCtrl.text.trim());
      if (mounted) Navigator.pop(context); // Close sheet on success
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Padding to avoid keyboard
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Profile',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) =>
              v == null || v.isEmpty ? 'Phone is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: widget.user.email,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
                filled: true,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Save Changes'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------
// EDIT ADDRESS BOTTOM SHEET WIDGET
// -----------------------------------------------------------------
class _EditAddressSheet extends StatefulWidget {
  final Map<String, dynamic>? initialAddress;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _EditAddressSheet({required this.initialAddress, required this.onSave});

  @override
  State<_EditAddressSheet> createState() => _EditAddressSheetState();
}

class _EditAddressSheetState extends State<_EditAddressSheet> {
  late final TextEditingController _houseCtrl;
  late final TextEditingController _pincodeCtrl;
  late final TextEditingController _villageCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _landmarkCtrl;
  late String _label;

  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initialAddress ?? <String, dynamic>{};
    _houseCtrl = TextEditingController(text: init['house']?.toString() ?? init['address']?.toString() ?? '');
    _pincodeCtrl = TextEditingController(text: init['pincode']?.toString() ?? '');
    _villageCtrl = TextEditingController(text: init['village']?.toString() ?? '');
    _cityCtrl = TextEditingController(text: init['city']?.toString() ?? '');
    _stateCtrl = TextEditingController(text: init['state']?.toString() ?? '');
    _landmarkCtrl = TextEditingController(text: init['landmark']?.toString() ?? '');
    _label = init['label']?.toString() ?? 'home';
  }

  @override
  void dispose() {
    _houseCtrl.dispose();
    _pincodeCtrl.dispose();
    _villageCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _landmarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    try {
      final map = <String, dynamic>{
        'label': _label,
        'house': _houseCtrl.text.trim(),
        'pincode': _pincodeCtrl.text.trim(),
        'village': _villageCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'landmark': _landmarkCtrl.text.trim(),
      };

      // Build a single-line 'address' field for backwards compatibility and ease of display
      final components = <String>[];
      void addIf(String? s) { if (s != null && s.trim().isNotEmpty) components.add(s.trim()); }
      addIf(map['house']);
      addIf(map['landmark']);
      addIf(map['village']);
      addIf(map['city']);
      addIf(map['state']);
      addIf(map['pincode']);
      map['address'] = components.join(', ');

      await widget.onSave(map);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save address: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Manage Primary Address', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),

              // Label selector
              DropdownButtonFormField<String>(
                initialValue: _label,
                items: const [
                  DropdownMenuItem(value: 'home', child: Text('Home')),
                  DropdownMenuItem(value: 'work', child: Text('Work')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _label = v ?? 'home'),
                decoration: const InputDecoration(labelText: 'Label', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _houseCtrl,
                decoration: const InputDecoration(
                  labelText: 'House / Flat / Building',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.house_outlined),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'House / building is required' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _landmarkCtrl,
                decoration: const InputDecoration(
                  labelText: 'Landmark',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 12),

              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _villageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Village / Locality',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'City is required' : null,
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _stateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'State',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'State is required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 140,
                  child: TextFormField(
                    controller: _pincodeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Pincode',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Pincode is required';
                      if (!RegExp(r'^\d{4,6}$').hasMatch(v.trim())) return 'Enter valid pincode';
                      return null;
                    },
                  ),
                ),
              ]),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Address'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}


// Backwards-compatible alias
class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const UserProfilePage();
}
