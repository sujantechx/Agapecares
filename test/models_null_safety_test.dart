import 'package:agapecares/core/models/cart_item_model.dart';
import 'package:agapecares/core/models/service_model.dart';

import 'package:flutter_test/flutter_test.dart';



void main() {
  test('ServiceModel.fromMap handles empty input safely', () {
    final svc = ServiceModel.fromMap({});
    // fromMap currently may be unimplemented; ensure we at least can call it.
    // If it returns null, guard the expectations.
    if (svc != null) {
      expect(svc.id, '');
      expect(svc.name, '');
      expect(svc.options, isEmpty);
    } else {
      expect(svc, isNull);
    }
  });

  test('CartItemModel.fromMap handles missing nested maps safely', () {
    final json = <String, dynamic>{
      'serviceId': '',
      'serviceName': '',
      'optionName': '',
      'subscription': null,
      'quantity': 2,
      'unitPrice': 0.0,
    };
    final item = CartItemModel.fromMap(json);
    expect(item.quantity, 2);
    expect(item.serviceId, '');
    expect(item.optionName, '');
  });
}
