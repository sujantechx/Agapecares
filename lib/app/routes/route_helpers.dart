class RouteHelper {
  // Admin user/worker routes
  static String adminUserDetail(String id) => '/admin/users/$id';
  static String adminWorkerDetail(String id) => '/admin/workers/$id';
  static String adminUserOrders(String id) => '/admin/users/$id/orders';
  static String adminWorkerOrders(String id) => '/admin/workers/$id/orders';
  static String adminOrderDetail(String id) => '/admin/orders/$id';

  // Other helpers (if needed) can be added here
}
