// This file previously defined a feature-local CartItemModel which caused a
// duplicate type issue (two different CartItemModel types in the app). To
// avoid type mismatches we re-export the canonical CartItemModel from
// `core/models/cart_item_model.dart` so all imports see the same symbol.

export 'package:agapecares/core/models/cart_item_model.dart';
