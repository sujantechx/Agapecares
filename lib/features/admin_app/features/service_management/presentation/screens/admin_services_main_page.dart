// filepath: c:\FlutterDev\agapecares\lib\features\admin_app\features\service_management\presentation\screens\admin_services_main_page.dart
import 'package:agapecares/core/models/coupon_model.dart';
import 'package:agapecares/features/admin_app/features/service_management/presentation/bloc/service_management_event.dart';
import 'package:agapecares/features/admin_app/features/service_management/presentation/bloc/service_management_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agapecares/features/admin_app/features/service_management/presentation/widgets/service_list_item.dart';
import 'package:agapecares/features/user_app/features/data/repositories/offer_repository.dart';
import 'package:agapecares/features/admin_app/features/service_management/presentation/widgets/admin_add_edit_coupon_dialog.dart';
import '../bloc/service_management_bloc.dart';
import 'admin_add_edit_service_screen.dart';

/// Admin Services main page with two tabs:
/// - Services: grid/list of services with CRUD (uses ServiceManagementBloc)
/// - Offers: list & CRUD for coupons (uses OfferRepository)
class AdminServicesMainPage extends StatefulWidget {
  const AdminServicesMainPage({Key? key}) : super(key: key);

  @override
  State<AdminServicesMainPage> createState() => _AdminServicesMainPageState();
}

class _AdminServicesMainPageState extends State<AdminServicesMainPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<CouponModel> _coupons = [];
  bool _loadingCoupons = true;
  String? _errorCoupons;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCoupons());
    // Load services via bloc
    context.read<ServiceManagementBloc>().add(LoadServices());
  }

  Future<void> _loadCoupons() async {
    setState(() {
      _loadingCoupons = true;
      _errorCoupons = null;
    });
    try {
      final repo = context.read<OfferRepository>();
      final list = await repo.listCoupons();
      setState(() {
        _coupons = list;
      });
    } catch (e) {
      setState(() {
        _errorCoupons = e.toString();
      });
    } finally {
      setState(() {
        _loadingCoupons = false;
      });
    }
  }

  Future<void> _showAddEditCoupon([CouponModel? coupon]) async {
    // show dialog and await result
    final changed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AdminAddEditCouponDialog(coupon: coupon),
    );
    if (changed == true) await _loadCoupons();
  }

  Future<void> _deleteCoupon(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete coupon'),
        content: Text('Delete coupon "$id"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final repo = context.read<OfferRepository>();
        await repo.deleteCoupon(id);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coupon deleted')));
        await _loadCoupons();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Services & Offers'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Services'), Tab(text: 'Offers')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Services tab
          BlocBuilder<ServiceManagementBloc, ServiceManagementState>(
            builder: (context, state) {
              if (state is ServiceManagementLoading) return const Center(child: CircularProgressIndicator());
              if (state is ServiceManagementLoaded) {
                final services = state.services;
                // Provide a responsive grid if width allows
                return LayoutBuilder(builder: (ctx, constraints) {
                  final crossAxis = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxis,
                      childAspectRatio: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: services.length,
                    itemBuilder: (ctx, index) {
                      final s = services[index];
                      // Reuse ServiceListItem for consistent admin actions
                      return Material(
                        elevation: 1,
                        child: ServiceListItem(service: s),
                      );
                    },
                  );
                });
              }
              if (state is ServiceManagementError) return Center(child: Text('Error: ${state.message}'));
              return const Center(child: Text('No services found.'));
            },
          ),

          // Offers tab
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Coupons & Offers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Row(children: [
                      IconButton(onPressed: _loadCoupons, icon: const Icon(Icons.refresh)),
                      ElevatedButton.icon(
                        onPressed: () => _showAddEditCoupon(null),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Coupon'),
                      ),
                    ])
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _loadingCoupons
                      ? const Center(child: CircularProgressIndicator())
                      : _errorCoupons != null
                          ? Center(child: Text('Failed to load coupons: $_errorCoupons'))
                          : _coupons.isEmpty
                              ? const Center(child: Text('No coupons available'))
                              : ListView.separated(
                                  itemCount: _coupons.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (ctx, i) {
                                    final c = _coupons[i];
                                    return ListTile(
                                      title: Text(c.id),
                                      subtitle: Text('${c.description}\nType: ${c.type.name} • Value: ${c.value} • Min: ${c.minOrderValue ?? '-'}'),
                                      isThreeLine: true,
                                      trailing: PopupMenuButton<String>(
                                        onSelected: (v) async {
                                          if (v == 'edit') await _showAddEditCoupon(c);
                                          if (v == 'delete') await _deleteCoupon(c.id);
                                        },
                                        itemBuilder: (ctx) => const [
                                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                )
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminAddEditServiceScreen())),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
