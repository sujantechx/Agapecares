import 'package:agapecares/features/admin_app/features/service_management/presentation/bloc/service_management_event.dart';
import 'package:agapecares/features/admin_app/features/service_management/presentation/bloc/service_management_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/service_repository.dart';

class ServiceManagementBloc extends Bloc<ServiceManagementEvent, ServiceManagementState> {
  final ServiceRepository _serviceRepository;

  ServiceManagementBloc({required ServiceRepository serviceRepository})
      : _serviceRepository = serviceRepository,
        super(ServiceManagementInitial()) {
    on<LoadServices>(_onLoadServices);
    on<AddService>(_onAddService);
    on<UpdateService>(_onUpdateService);
    on<DeleteService>(_onDeleteService);
  }

  Future<void> _onLoadServices(LoadServices event, Emitter<ServiceManagementState> emit) async {
    emit(ServiceManagementLoading());
    try {
      final services = await _serviceRepository.getAllServices();
      emit(ServiceManagementLoaded(services));
    } catch (e) {
      emit(ServiceManagementError(e.toString()));
    }
  }

  Future<void> _onAddService(AddService event, Emitter<ServiceManagementState> emit) async {
    try {
      await _serviceRepository.addService(event.service);
      add(LoadServices());
    } catch (e) {
      emit(ServiceManagementError(e.toString()));
    }
  }

  Future<void> _onUpdateService(UpdateService event, Emitter<ServiceManagementState> emit) async {
    try {
      await _serviceRepository.updateService(event.service);
      add(LoadServices());
    } catch (e) {
      emit(ServiceManagementError(e.toString()));
    }
  }

  Future<void> _onDeleteService(DeleteService event, Emitter<ServiceManagementState> emit) async {
    try {
      await _serviceRepository.deleteService(event.serviceId);
      add(LoadServices());
    } catch (e) {
      emit(ServiceManagementError(e.toString()));
    }
  }
}