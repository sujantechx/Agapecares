enum OfferType { percentage, flat }

class Offer {
  final String code;
  final OfferType type;
  final double value;
  final String description;
  final double? minimumSpend; // Optional: minimum amount to apply the offer

  const Offer({
    required this.code,
    required this.type,
    required this.value,
    required this.description,
    this.minimumSpend,
  });
}