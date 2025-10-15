// Admin User Management - State definitions
// Purpose: Defines states used by the AdminUserBloc for listing/searching/updating users.
// Notes: These states model the UI's needs and are compatible with `UserModel` in `core/models/user_model.dart`.

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
