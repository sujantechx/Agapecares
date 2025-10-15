import 'package:equatable/equatable.dart';

import '../../../../../core/models/service_model.dart';

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final List<ServiceModel> services;
  final List<String> bannerImages;

  const HomeLoaded({required this.services, required this.bannerImages});

  @override
  List<Object> get props => [services, bannerImages];
}

class HomeError extends HomeState {
  final String message;

  const HomeError({required this.message});

  @override
  List<Object> get props => [message];
}