import 'package:flutter_bloc/flutter_bloc.dart';
import 'service_event.dart';
import 'service_state.dart';
import '../data/repositories/service_repository.dart';

/// ServiceBloc coordinates fetching service data from the repository and
/// exposes a simple state machine the UI can listen to:
///
/// - ServiceLoading: initial loading state while data is fetched from Firestore
/// - ServiceLoaded: contains the list of ServiceModel returned by the repository
/// - ServiceError: emitted if the repository throws or fetching fails
///
/// The UI (for example `ServiceList` widget) dispatches a `LoadServices` event
/// which triggers `_onLoadServices` to call the repository. Keeping this logic
/// inside the BLoC keeps UI code declarative and focused on rendering states.
class ServiceBloc extends Bloc<ServiceEvent, ServiceState> {
  final ServiceRepository _serviceRepository;

  ServiceBloc({required ServiceRepository serviceRepository})
      : _serviceRepository = serviceRepository,
        super(ServiceLoading()) {
    // Map the LoadServices event to the handler which performs the async fetch.
    on<LoadServices>(_onLoadServices);
  }

  /// Handles `LoadServices` events by calling the repository's `fetchServices()`
  /// method. We emit `ServiceLoading` at the beginning (already the default),
  /// then either `ServiceLoaded` with the fetched list or `ServiceError` on
  /// any exception.
  ///
  /// Note: repository exceptions bubble up here; we catch them and convert to
  /// a simple error state so the UI can show a retry button.
  void _onLoadServices(LoadServices event, Emitter<ServiceState> emit) async {
    try {
      final services = await _serviceRepository.fetchServices();
      emit(ServiceLoaded(services));
    } catch (_) {
      // In production you may want to log the exception and provide more
      // contextual error messages. For now we emit a generic error state.
      emit(ServiceError());
    }
  }
}
