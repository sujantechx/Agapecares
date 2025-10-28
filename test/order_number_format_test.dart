import 'package:flutter_test/flutter_test.dart';
import 'package:agapecares/features/user_app/features/data/repositories/order_repository.dart';

void main() {
  test('formatOrderNumberFromDateAndSeq produces expected YYYYMMDDxxxxx values', () {
    final dt = DateTime(2025, 10, 27);
    // seq=1 -> suffix 10000
    expect(formatOrderNumberFromDateAndSeq(dt, 1), equals('2025102710000'));
    // seq=2 -> suffix 10001
    expect(formatOrderNumberFromDateAndSeq(dt, 2), equals('2025102710001'));
    // a higher seq -> verifies arithmetic and padding
    expect(formatOrderNumberFromDateAndSeq(dt, 10000), equals('2025102719999'));
  });
}

