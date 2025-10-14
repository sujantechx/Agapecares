import 'package:equatable/equatable.dart';

abstract class AdminUserEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadUsers extends AdminUserEvent {}
class UpdateUserRoleEvent extends AdminUserEvent {
  final String uid;
  final String role;
  UpdateUserRoleEvent({required this.uid, required this.role});
  @override
  List<Object?> get props => [uid, role];
}
class SetUserVerificationEvent extends AdminUserEvent {
  final String uid;
  final bool isVerified;
  SetUserVerificationEvent({required this.uid, required this.isVerified});
  @override
  List<Object?> get props => [uid, isVerified];
}
class SetUserDisabledEvent extends AdminUserEvent {
  final String uid;
  final bool disabled;
  SetUserDisabledEvent({required this.uid, required this.disabled});
  @override
  List<Object?> get props => [uid, disabled];
}
class DeleteUserEvent extends AdminUserEvent {
  final String uid;
  DeleteUserEvent(this.uid);
  @override
  List<Object?> get props => [uid];
}

