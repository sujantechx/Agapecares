import 'package:equatable/equatable.dart';
import 'package:agapecares/core/models/user_model.dart';

abstract class AdminUserState extends Equatable {
  @override
  List<Object?> get props => [];
}
class AdminUserInitial extends AdminUserState {}
class AdminUserLoading extends AdminUserState {}
class AdminUserLoaded extends AdminUserState {
  final List<UserModel> users;
  AdminUserLoaded(this.users);
  @override
  List<Object?> get props => [users];
}
class AdminUserError extends AdminUserState {
  final String message;
  AdminUserError(this.message);
  @override
  List<Object?> get props => [message];
}

