import 'package:flutter_test/flutter_test.dart';
import 'package:agapecares/shared/models/service_list_model.dart';
import 'package:agapecares/features/user_app/cart/data/models/cart_item_model.dart';

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
    expect(item.service.id, '');
    expect(item.selectedOption.id, '');
  });
}

