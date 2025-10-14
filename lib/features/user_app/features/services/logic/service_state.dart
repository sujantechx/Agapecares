import 'package:equatable/equatable.dart';
import 'package:agapecares/core/models/service_list_model.dart';


abstract class ServiceState extends Equatable {
  const ServiceState();

  @override
  List<Object> get props => [];
}

class ServiceLoading extends ServiceState {}

class ServiceLoaded extends ServiceState {
  final List<ServiceModel> services;

  const ServiceLoaded([this.services = const []]);

  @override
  List<Object> get props => [services];
}

class ServiceError extends ServiceState {}
