import '../../../../shared/models/offer_model.dart';


class OfferRepository {
  // A dummy list of available offers in our system
  static final List<Offer> _availableOffers = [
    const Offer(
      code: 'AGAPE10',
      type: OfferType.percentage,
      value: 10, // 10%
      description: 'Get 10% off your total order.',
      minimumSpend: 500,
    ),
    const Offer(
      code: 'FLAT150',
      type: OfferType.flat,
      value: 150, // ₹150
      description: 'Get a flat ₹150 off.',
      minimumSpend: 1000,
    ),
  ];

  // Finds an offer by its code
  Future<Offer?> getOfferByCode(String code) async {
    await Future.delayed(const Duration(milliseconds: 300)); // Simulate network latency
    try {
      return _availableOffers.firstWhere(
            (offer) => offer.code.toUpperCase() == code.toUpperCase(),
      );
    } catch (e) {
      return null; // Offer not found
    }
  }

  // Gets an automatic "extra" offer based on the current total
  Offer? getExtraOffer(double currentTotal) {
    if (currentTotal >= 2000) {
      return const Offer(
        code: 'EXTRA5',
        type: OfferType.percentage,
        value: 5, // 5%
        description: 'Extra 5% off for orders\n above ₹2000!',
      );
    }
    return null;
  }
}