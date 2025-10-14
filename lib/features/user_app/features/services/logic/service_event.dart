import 'package:equatable/equatable.dart';
import 'package:agapecares/core/models/service_list_model.dart';


abstract class ServiceEvent extends Equatable {
  const ServiceEvent();

  @override
  List<Object> get props => [];
}

class LoadServices extends ServiceEvent {}

class AddService extends ServiceEvent {
  final ServiceModel service;

  const AddService(this.service);

  @override
  List<Object> get props => [service];
}

class UpdateService extends ServiceEvent {
  final ServiceModel service;

  const UpdateService(this.service);

  @override
  List<Object> get props => [service];
}

class DeleteService extends ServiceEvent {
  final String id;

  const DeleteService(this.id);

  @override
  List<Object> get props => [id];
}
