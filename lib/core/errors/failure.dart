// lib/core/errors/failure.dart

import 'package:equatable/equatable.dart';

/// A base class for handling different types of failures in the application.
/// This allows for consistent error handling across the app.
abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

/// Represents a failure from a server or remote data source.
class ServerFailure extends Failure {
  const ServerFailure(String message) : super(message);
}

/// Represents a failure when there is no internet connection.
class NetworkFailure extends Failure {
  const NetworkFailure(String message) : super(message);
}