// Developer helper: configure Firebase emulators for local testing.
// Set `useFirebaseEmulator = true` while running `firebase emulators:start`.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

// Toggle this to `true` when testing against the local Firebase emulators.
// Keep `false` for production and CI.
const bool useFirebaseEmulator = false;

void configureFirebaseEmulators({String host = 'localhost', int firestorePort = 8080, int functionsPort = 5001}) {
  if (!useFirebaseEmulator) return;

  // Firestore emulator
  try {
    FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);
  } catch (e) {
    // ignore: avoid_print
    print('Failed to configure Firestore emulator: $e');
  }

  // Functions emulator
  try {
    FirebaseFunctions.instance.useFunctionsEmulator(host, functionsPort);
  } catch (e) {
    // ignore: avoid_print
    print('Failed to configure Functions emulator: $e');
  }
}

