import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/home_repository.dart';
import 'booking_event.dart';
import 'booking_state.dart';


class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final HomeRepository _homeRepository;

  HomeBloc(this._homeRepository) : super(HomeInitial()) {
    on<FetchHomeData>(_onFetchHomeData);
  }

  Future<void> _onFetchHomeData(FetchHomeData event, Emitter<HomeState> emit) async {
    emit(HomeLoading());
    try {
      final services = await _homeRepository.getServices();
      final banners = await _homeRepository.getBannerImages();
      emit(HomeLoaded(services: services, bannerImages: banners));
    } catch (e) {
      emit(HomeError(message: 'Failed to load data: $e'));
    }
  }
}