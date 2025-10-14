import '../../../../../../core/models/service_model.dart';
import 'package:equatable/equatable.dart';
abstract class ServiceManagementState extends Equatable {
  const ServiceManagementState();
  @override
  List<Object> get props => [];
}

class ServiceManagementInitial extends ServiceManagementState {}
class ServiceManagementLoading extends ServiceManagementState {}
class ServiceManagementLoaded extends ServiceManagementState {
  final List<ServiceModel> services;
  const ServiceManagementLoaded(this.services);
  @override
  List<Object> get props => [services];
}
class ServiceManagementError extends ServiceManagementState {
  final String message;
  const ServiceManagementError(this.message);
  @override
  List<Object> get props => [message];
}