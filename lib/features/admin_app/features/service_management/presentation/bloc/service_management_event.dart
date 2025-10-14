import 'package:equatable/equatable.dart';

import '../../../../../../core/models/service_model.dart';


abstract class ServiceManagementEvent extends Equatable {
  const ServiceManagementEvent();
  @override
  List<Object> get props => [];
}

class LoadServices extends ServiceManagementEvent {}
class AddService extends ServiceManagementEvent {
  final ServiceModel service;
  const AddService(this.service);
  @override
  List<Object> get props => [service];
}
class UpdateService extends ServiceManagementEvent {
  final ServiceModel service;
  const UpdateService(this.service);
  @override
  List<Object> get props => [service];
}
class DeleteService extends ServiceManagementEvent {
  final String serviceId;
  const DeleteService(this.serviceId);
  @override
  List<Object> get props => [serviceId];
}