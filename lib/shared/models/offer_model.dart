import 'dart:convert';

enum OfferType { percentage, flat }

extension OfferTypeX on OfferType {
  String get name => toString().split('.').last;
  static OfferType fromString(String? s) {
    if (s == null) return OfferType.percentage;
    return OfferType.values.firstWhere(
          (e) => e.name == s,
      orElse: () => OfferType.percentage,
    );
  }
}

class Offer {
  final String code;
  final OfferType type;
  final double value;
  final String description;
  final double? minimumSpend;

  const Offer({
    required this.code,
    required this.type,
    required this.value,
    required this.description,
    this.minimumSpend,
  });

  factory Offer.fromMap(Map<String, dynamic> map) {
    return Offer(
      code: map['code'] as String? ?? '',
      type: OfferTypeX.fromString(map['type'] as String?),
      value: (map['value'] is int)
          ? (map['value'] as int).toDouble()
          : (map['value'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String? ?? '',
      minimumSpend: map['minimumSpend'] == null
          ? null
          : ((map['minimumSpend'] is int)
          ? (map['minimumSpend'] as int).toDouble()
          : (map['minimumSpend'] as num).toDouble()),
    );
  }

  factory Offer.fromFirebase(Map<String, dynamic> map) => Offer.fromMap(map);

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'type': type.name,
      'value': value,
      'description': description,
      'minimumSpend': minimumSpend,
    };
  }

  Map<String, dynamic> toStore() => toMap();

  String toJson() => jsonEncode(toMap());

  factory Offer.fromJson(String source) =>
      Offer.fromMap(jsonDecode(source) as Map<String, dynamic>);
}