Feature specification — Agape Cares
==================================

Last updated: 2025-10-14

Purpose
-------
A three-role cleaning-service platform (Admin, Worker, User).
This document is a single, consolidated, production-ready feature specification covering features, flows, Firestore data model, BLoC/repository contracts, UI screens, routing and acceptance criteria. It is written to be handed to product/design/QA and to drive engineering work (implementation tasks and acceptance tests).

1 — Overview / Purpose
----------------------
Roles:
- Admin: full business control (superuser).
- Worker: focused app to receive/complete jobs.
- User (Customer): browse, book, pay, track, rate services.

2 — Core feature set (role-by-role)
----------------------------------
A. Admin Panel (Full control)

Core capabilities
- Service Management (CRUD): services, packages, add-ons, durations, and prices.
- Offer & Coupon Management: create campaign codes, expiration, min order value, stackable rules.
- User & Worker Management: view profiles, approve/disable accounts, change roles, verification docs.
- Order Management: list/search/filter (status, date, worker, customer, location), view order details and timeline.
- Work Assignment: assign/reassign orders to workers (manual + simple auto-assign rules).
- Payment Management: view payment status (Razorpay success/failed/refund), mark manual COD collections, issue refunds.
- Ratings & Reviews Management: read/moderate reviews, respond, flag abusive content.
- Notifications Control: manual push/email/SMS to segments.
- Analytics Dashboard: revenue, orders, popular services, worker performance, refunds, cancellations.
- Activity & Audit Logs: admin action logs and critical system events.
- Settings: tax/GST, service areas, cancellation/reschedule policy, working hours, buffer times, auto-assign toggles.

Operational tools
- Worker availability override (force offline/online).
- Bulk actions (bulk assign, bulk update status, bulk messaging).
- CSV export/import (orders, users, workers, payouts).

B. Worker App (Simple & focused)

Core capabilities
- Assigned Jobs List: upcoming, today, past with time, address, customer name & phone.
- Job Details: service type, inclusions, scheduled start/end, special instructions, COD indicator.
- Status Buttons: Accept, On My Way, Arrived, Started, Paused, Completed.
- Availability Toggle: Online / Offline.
- Navigation: one-tap directions to customer address.
- Work History: completed jobs, date, rating.
- Profile Management: edit name, phone, photo, ID uploads.
- Notifications: push for new assignments, cancellations, reschedules.
- Basic In-App Contact: call/chat user or admin.

Optional / Advanced
- Notes & proof photo upload.
- OTP verification at job start/end.
- Offline cached job details.

C. User App (Smooth & transparent)

Core capabilities
- Browse Services: categories, service pages with descriptions, inclusions, duration, price, images.
- Search & Filters.
- Cart & Checkout: saved addresses, date/time slot, promo code, Razorpay + COD.
- Real-time Order Status: Pending → Assigned → On Way → In Progress → Completed.
- Order Tracking: assigned worker name, ETA, contact.
- Payment Details & Receipts: downloadable invoice.
- Order History: reorder quick-action.
- Ratings & Reviews: prompt after completion.
- Address Book: multiple saved addresses.
- Reschedule/Cancel: rules (e.g., no cancellation <24h) with admin approval/auto rules.
- Help & Support: FAQs, support contact, report order issues.
- Notifications: push/email/SMS for confirmations and updates.

Optional
- In-app chat with worker.
- Saved payment methods (Razorpay tokens).

3 — Acceptance criteria & order lifecycle
----------------------------------------
Order lifecycle states (minimum):
- paymentStatus: pending / success / failed
- orderStatus: pending / assigned / on_the_way / in_progress / completed / cancelled
- workerAssignment: unassigned / assigned (workerId) / acceptedAt / completedAt

Minimum acceptance criteria (examples):
- User can add services to cart and proceed to checkout.
- Checkout creates exactly one order (no duplicates) and stores it under `/users/{userId}/orders/{orderId}`.
- Order gets a stable human-friendly orderNumber in format YYYYMMDDxxxxx where suffix starts at 00100 per day.
- If paid via Razorpay, paymentStatus==success and paymentId saved; if COD, paymentStatus remains pending and admin/worker can mark manual collected.
- Worker “Accept” prevents other workers from accepting the same order (transactional guard in Firestore update / security rules).
- Admin can list and filter orders, assign/reassign workers, and the assignment updates both user and worker views in realtime.
- No Firestore writes occur with empty userId; auth must be awaited and validated before remote writes.

4 — Firestore data model (recommended)
--------------------------------------
Top-level collections (primary):
- users (docId = uid)
  - profile: (name, email, phone, role: 'user'|'worker'|'admin', photoUrl, addressBook[], isVerified, createdAt)
  - cart (subcollection) -> documents: cartItemId -> { serviceId, title, price, quantity, options }
  - orders (subcollection) -> documents: orderId -> Order document (see Order schema)
  - paymentHistory (subcollection) -> payments

- services (docId = serviceId) -> { title, description, category, price, duration, addOns[] }
- offers (docId = offerId) -> coupon codes, rules
- workers (optional separate collection) -> mirrors user IDs for worker-specific fields (rating, earnings)
- order_counters (docId = YYYYMMDD) -> { seq: int, updatedAt: Timestamp } // used to atomically reserve daily suffix

Order document schema (minimal):
{
  userId: string,
  items: [{ serviceId, title, quantity, unitPrice, options }],
  orderNumber: string, // YYYYMMDDxxxxx
  paymentStatus: 'pending'|'success'|'failed',
  paymentMethod: 'razorpay'|'cod',
  paymentId?: string,
  subtotal: number,
  discount: number,
  total: number,
  orderStatus: 'pending'|'assigned'|'on_the_way'|'in_progress'|'completed'|'cancelled',
  workerId?: string,
  workerName?: string,
  acceptedAt?: Timestamp,
  createdAt: Timestamp,
  updatedAt: Timestamp,
  localId?: int (optional, for in-memory fallback only)
}

Design notes:
- Orders must be created under `/users/{userId}/orders/{autoId}` to keep access control simple.
- Avoid creating orders with empty userId; the app must await auth and use currentUser.uid.
- Use `order_counters/{YYYYMMDD}` transaction to generate daily incrementing suffix (seq) atomically.

5 — Firestore security rules (high-level)
-----------------------------------------
- Allow read/write to users/{uid}/cart and users/{uid}/orders only if request.auth.uid == uid (or admin).
- Allow workers to read orders where orderStatus in ('assigned', 'on_the_way', 'in_progress') and workerId == request.auth.uid, or allow read of `orders` via admin/worker listing via cloud function plus admin role check.
- Admin identification: either maintain `admins` collection or allow a list of admin emails in rules (short term) — prefer `admins` collection for dynamic control.
- Prevent writes that set `userId` to an id different from the document parent (validate parentId == request.auth.uid).
- Use serverTimestamp for createdAt/updatedAt when possible; validate types.

6 — BLoC & repository contract map
----------------------------------
High-level: use feature-based folders; every feature has a `data` (repositories, datasources, models), `logic` (blocs/cubits), and `presentation` (widgets/pages).

Key repositories
- AuthRepository: signInWithPhone, sendOtp, verifyOtp, signOut, getCurrentUser
- UserRepository: getProfile, updateProfile, addresses
- CartRepository: getCartItems(), addCartItem(), removeCartItem(), clearCart(), syncCartFromRemote()
- OrderRepository: createOrder(order, uploadRemote: bool), generateOrderNumber(), uploadOrder(localOrder), fetchOrdersForUser(), fetchOrdersForWorker(), fetchOrdersForAdmin(filters)
- ServiceRepository: fetchServices(), fetchServiceById(), create/update/delete (admin)
- OfferRepository: fetchOffers(), validateCoupon(code)
- PaymentRepository (Razorpay & COD): createPaymentIntent(), verifyPayment(), handleWebhook (server), markCodCollected()
- WorkerRepository: fetchWorkerProfile(), updateAvailability(), fetchAssignedOrders()

Key BLoCs/Cubits
- AuthBloc (AuthState: initial, unauthenticated, authenticating, authenticated(user))
- CartBloc (CartState: loading, loaded, error)
- CheckoutBloc (CheckoutState: initial, placingOrder, success, failure)
- OrderBloc / OrderWatcherBloc (watches user orders)
- WorkerOrdersBloc (watches incoming/assigned orders for worker)
- AdminOrdersBloc (list/filter/manage orders)
- ServiceBloc (service list & CRUD)

Contracts
- Repositories should return typed models (e.g., OrderModel, CartItemModel). Use null-safety and throw typed exceptions or return Either/Result types.

7 — Presentation screens (file & route list)
--------------------------------------------
User App (routes):
- `/home` -> `UserHomePage` (service browse)
- `/service/:id` -> `ServiceDetailPage`
- `/cart` -> `CartPage`
- `/checkout` -> `CheckoutPage`
- `/orders` -> `OrderListPage`
- `/orders/:id` -> `OrderDetailPage`
- `/profile` -> `ProfilePage`
- `/auth/login` -> `LoginPage` (phone/email)
- `/auth/otp` -> `OtpPage`

Worker App (routes):
- `/worker/home` -> `WorkerHomePage` (incoming jobs)
- `/worker/orders` -> `WorkerOrdersPage`
- `/worker/orders/:id` -> `WorkerOrderDetailPage`
- `/worker/profile` -> `WorkerProfilePage`

Admin Panel (routes):
- `/admin/dashboard` -> `AdminDashboardPage`
- `/admin/services` -> `AdminServiceListPage`
- `/admin/orders` -> `AdminOrderListPage`
- `/admin/users` -> `AdminUserListPage`
- `/admin/assign` -> `AdminAssignWorkerPage`

Router notes
- Use lazy route creation after DI providers are mounted so route builder contexts can read repositories and blocs (example: create router inside `build()` after MultiRepositoryProvider and MultiBlocProvider are available).
- Expose route constants in `lib/routes/app_routes.dart` and grouped route lists in `lib/routes/{auth_routes.dart,dashboard_routes.dart,main_routes.dart}`.

8 — File & folder layout (recommended)
--------------------------------------
lib/
  features/
    auth/
      data/
      logic/
      presentation/
    user_app/
      cart/
      checkout/
      orders/
      services/
      presentation/
    worker_app/
    admin_app/
  shared/
    models/
    services/
    widgets/
  routes/
  injection_container.dart
  main.dart

9 — Order number generation / uniqueness
----------------------------------------
Primary approach (recommended):
- Use a Firestore `runTransaction` on `order_counters/{YYYYMMDD}` where `seq` is atomically incremented.
- Map seq to suffix: suffix = seq + 99 (so seq 1 -> 00100). Combine with date prefix: YYYYMMDD + suffix padded 5 digits.
- On failure of transaction, fallback to collectionGroup lookup + best effort increment or timestamp suffix.

10 — Preventing duplicate / random orders
----------------------------------------
- Ensure Checkout flow creates a single order document with uploadRemote=true semantics: reserve orderNumber via transaction, create doc under `/users/{userId}/orders/{newId}`, set `localId` only for in-memory fallback.
- Do not create local-only orders before remote is created (or if you do, mark them as temporary and replace them after remote success).
- Use dedup checks when uploading (collectionGroup lookup by `localId` and by `orderNumber + userId`).

11 — Worker assignment and concurrency
--------------------------------------
- When a worker accepts an order, perform a Firestore transaction to set `workerId`, `orderStatus: 'assigned'`, and `acceptedAt` only if `workerId` is null and `orderStatus` is still assignable. This prevents multiple workers from accepting the same job.
- Use security rules and server-side cloud functions if you require stronger guarantees.

12 — Payments & Razorpay
-------------------------
- Razorpay lifecycle: client requests backend to create an order (Razorpay order id and amount), client opens Razorpay checkout with the order id, on success verify signature server-side and call `OrderRepository.updateOrder(...)` to set paymentStatus=success and paymentId.
- COD: at checkout the order is created with paymentMethod='cod' and paymentStatus='pending'. When worker/admin marks cash collected, update paymentStatus and paymentId (or record a cashReceiptId).

13 — Edge cases & resilience
-----------------------------
- Auth not ready: always validate `FirebaseAuth.instance.currentUser` before remote write. If null, either force user to login or queue the action.
- Network flaps: keep retry logic in `SyncService` that uploads unsynced orders when connection is available.
- Nulls from Firestore: parse nested maps defensively; provide fallback values in model constructors.
- Duplicate orders: dedupe via `localId`, `remoteId`, and `orderNumber + userId` checks.

14 — Tests & QA acceptance
--------------------------
- Unit tests: repository logic (order number generation fallback), BLoC states transitions, parsing of Firestore maps.
- Integration tests: checkout flow with mocked payment success/failure; worker accept flow concurrency; admin assign flow.
- Manual QA checklist: end-to-end checkout (Razorpay & COD), worker accept & complete flow, admin assignment & reassign, order history visibility per role, profile updates.

15 — Implementation roadmap & developer tasks (prioritized)
-----------------------------------------------------------
Milestone 1 — Core user flows (MVP)
- [ ] Wire Firebase init early in `main.dart` and wait for `authStateChanges().first` (already present in main)
- [ ] Implement Firestore-backed Local DB (`FirestoreLocalDatabaseService`) — done (file created separately). If needed, move to production-ready with better fallback handling.
- [ ] Implement `AuthRepository` and `AuthBloc` flows (phone/email/OTP). Ensure `currentUser.uid` is used for DB writes.
- [ ] Implement `ServiceRepository` and `ServiceListPage`.
- [ ] Implement `CartRepository` and `CartBloc`.
- [ ] Implement `CheckoutBloc` and `OrderRepository.createOrder(uploadRemote=true)` that uses `order_counters` transaction.
- [ ] Razorpay integration wiring: repository + client checkout + server verify.

Milestone 2 — Worker & Admin flows
- [ ] Implement Worker UI (incoming jobs list, accept flow with transaction guard).
- [ ] Implement Admin Panel (order management, service CRUD, manual assignment).
- [ ] Add worker earnings/paymentHistory and profile updates.

Milestone 3 — Polishing, tests, rules
- [ ] Write Firestore security rules and test with the Firestore emulator.
- [ ] Add automated tests for critical flows.
- [ ] Add analytics & audit logs, notifications.

Developer task checklist (concrete file edits)
- Create `lib/shared/models/*` : `order_model.dart`, `cart_item_model.dart`, `service_model.dart`, `user_model.dart`.
- Create repositories: `lib/features/*/data/repositories/*.dart` (AuthRepository, OrderRepository, CartRepository, ServiceRepository, WorkerRepository, OfferRepository, Payment repositories).
- Create BLoCs: `lib/features/*/logic/blocs/*_bloc.dart` and wire into `lib/injection_container.dart`.
- Create presentation pages under `lib/features/*/presentation/pages/*_page.dart` and widgets.
- Update routes in `lib/routes/*` and ensure router is created after DI as already done in `main.dart`.
- Create cloud functions or backend endpoints to create Razorpay order and verify signatures.

16 — Models required (summary)
------------------------------
- UserModel (uid, name, email, phone, role, photoUrl, addresses[])
- CartItemModel (id, serviceId, title, unitPrice, quantity, options)
- OrderModel (see schema above)
- ServiceModel (id, title, description, category, price, duration, addOns[])
- OfferModel (id, code, discount, minOrderValue, expiry)
- WorkerModel (id, name, rating, earnings, isAvailable)

17 — Run & build notes
----------------------
- Ensure `firebase_core` is initialized before creating repositories that use Firestore (see `main.dart` initialization pattern).

Commands (local dev):

```bash
# fetch deps
flutter pub get
# run analyzer
flutter analyze
# run tests
flutter test
# run app on connected device/emulator
flutter run -d <device-id>
```

18 — Next steps I can implement for you (pick one or more)
-----------------------------------------------------------
- Scaffold the full feature folder structure + empty files for BLoCs, repositories and models (I can generate these skeletons).
- Implement `OrderRepository.generateOrderNumber()` with the Firestore transaction and tests.
- Implement the checkout flow (create order + Razorpay integration wiring) and add tests.
- Write Firestore security rules (emulator-ready) and test scenarios.
- Create Admin UI scaffolding (React/Vue/Flutter) — confirm which platform you want for admin (mobile inside app or web admin panel).

Appendix: rationale & gotchas
-----------------------------
- Use Firestore transactions for order counter to ensure unique sequences per day. Avoid client-side incrementing.
- Always guard writes with an authenticated UID. If using phone auth, prefer `uid` rather than phone string as stable id.
- Keep the app resilient to null/missing nested fields — models should parse defensively and use defaults.

---

If you want, I can now scaffold the repository & BLoC files (models, repository interfaces, empty page widgets, and route constants) so you can implement feature-by-feature. Tell me which milestone to start with or I can scaffold the entire project skeleton for Milestone 1.
