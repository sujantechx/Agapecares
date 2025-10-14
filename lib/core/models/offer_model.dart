enum OfferType { percentage, flat }

class Offer {
  final String code;
  final OfferType type;
  final double value;
  final String? description;
  final double? minimumSpend;

  const Offer({
    required this.code,
    required this.type,
    required this.value,
    this.description,
    this.minimumSpend,
  });

  @override
  String toString() => 'Offer(code: $code, type: $type, value: $value)';
}

// Existing Firestore-backed model kept for persistence use.
class OfferModel {
  final String id;
  final String code;
  final double discount;
  final double minOrderValue;
  final DateTime expiry;

  OfferModel({
    required this.id,
    required this.code,
    required this.discount,
    required this.minOrderValue,
    required this.expiry,
  });

  factory OfferModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return OfferModel(
      id: documentId,
      code: data['code'] ?? '',
      discount: (data['discount'] ?? 0.0).toDouble(),
      minOrderValue: (data['minOrderValue'] ?? 0.0).toDouble(),
      expiry: data['expiry'].toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'discount': discount,
      'minOrderValue': minOrderValue,
      'expiry': expiry,
    };
  }
}
