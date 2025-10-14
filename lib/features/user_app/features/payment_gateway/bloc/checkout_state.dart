// File: lib/features/user_app/payment_gateway/bloc/checkout_state.dart
import 'package:equatable/equatable.dart';

class CheckoutState extends Equatable {
  final bool isInProgress;
  final String? successMessage;
  final String? errorMessage;

  const CheckoutState({this.isInProgress = false, this.successMessage, this.errorMessage});

  CheckoutState copyWith({bool? isInProgress, String? successMessage, String? errorMessage}) {
    return CheckoutState(
      isInProgress: isInProgress ?? this.isInProgress,
      successMessage: successMessage ?? this.successMessage,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [isInProgress, successMessage, errorMessage];
}
