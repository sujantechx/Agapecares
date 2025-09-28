import 'package:equatable/equatable.dart';

class ServiceModel extends Equatable {
  final String title;
  final String imagePath;

  const ServiceModel({required this.title, required this.imagePath});

  @override
  List<Object?> get props => [title, imagePath];
}