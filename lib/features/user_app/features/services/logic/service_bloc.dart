import 'package:flutter_bloc/flutter_bloc.dart';
import 'service_event.dart';
import 'service_state.dart';
import '../data/repositories/service_repository.dart';

class ServiceBloc extends Bloc<ServiceEvent, ServiceState> {
  final ServiceRepository _serviceRepository;

  ServiceBloc({required ServiceRepository serviceRepository})
      : _serviceRepository = serviceRepository,
        super(ServiceLoading()) {
    on<LoadServices>(_onLoadServices);
  }

  void _onLoadServices(LoadServices event, Emitter<ServiceState> emit) async {
    try {
      final services = await _serviceRepository.fetchServices();
      emit(ServiceLoaded(services));
    } catch (_) {
      emit(ServiceError());
    }
  }
}

