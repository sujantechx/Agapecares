import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/user_repository.dart';
import 'admin_user_event.dart';
import 'admin_user_state.dart';

class AdminUserBloc extends Bloc<AdminUserEvent, AdminUserState> {
  final AdminUserRepository repo;
  AdminUserBloc({required this.repo}) : super(AdminUserInitial()) {
    on<LoadUsers>((event, emit) async {
      emit(AdminUserLoading());
      try {
        final users = await repo.getAllUsers();
        emit(AdminUserLoaded(users));
      } catch (e) {
        emit(AdminUserError(e.toString()));
      }
    });
    on<UpdateUserRoleEvent>((event, emit) async {
      try {
        await repo.updateUserRole(uid: event.uid, role: event.role);
        add(LoadUsers());
      } catch (e) {
        emit(AdminUserError(e.toString()));
      }
    });
    on<SetUserVerificationEvent>((event, emit) async {
      try {
        await repo.setUserVerification(uid: event.uid, isVerified: event.isVerified);
        add(LoadUsers());
      } catch (e) {
        emit(AdminUserError(e.toString()));
      }
    });
    on<SetUserDisabledEvent>((event, emit) async {
      try {
        await repo.setUserDisabled(uid: event.uid, disabled: event.disabled);
        add(LoadUsers());
      } catch (e) {
        emit(AdminUserError(e.toString()));
      }
    });
    on<DeleteUserEvent>((event, emit) async {
      try {
        await repo.deleteUser(event.uid);
        add(LoadUsers());
      } catch (e) {
        emit(AdminUserError(e.toString()));
      }
    });
  }
}

