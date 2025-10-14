import 'package:agapecares/core/models/cart_item_model.dart';
import 'package:agapecares/core/models/service_list_model.dart';
import 'package:flutter_test/flutter_test.dart';



void main() {
  test('ServiceModel.fromMap handles null input safely', () {
    final svc = ServiceModel.fromMap(null);
    expect(svc.id, '');
    expect(svc.name, '');
    expect(svc.options, isEmpty);
    expect(svc.inclusions, isEmpty);
  });

  test('CartItemModel.fromJson handles missing nested maps safely', () {
    final json = <String, dynamic>{
      'id': 'test',
      'service': null,
      'selectedOption': null,
      'subscription': null,
      'quantity': 2,
    };
    final item = CartItemModel.fromJson(json);
    expect(item.id, 'test');
    expect(item.quantity, 2);
    expect(item.serviceId, '');
    expect(item.selectedOption.id, '');
  });
}

