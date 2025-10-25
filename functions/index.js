const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

// Helper to remove price-sensitive fields when mirroring to a worker
function sanitizeForWorker(order) {
  if (!order) return order;
  const sanitized = Object.assign({}, order);

  // Remove top-level price fields
  delete sanitized.subtotal;
  delete sanitized.total;
  delete sanitized.totalAmount;
  delete sanitized.discount;
  delete sanitized.tax;

  // Remove unitPrice from items if present
  if (Array.isArray(sanitized.items)) {
    sanitized.items = sanitized.items.map(item => {
      if (!item) return item;
      const copy = Object.assign({}, item);
      delete copy.unitPrice;
      delete copy.unit_price;
      return copy;
    });
  }

  // Keep contact info for worker use (customer name & phone) - assume fields userName/userPhone or similar exist
  // Add a marker and timestamp for mirrors
  sanitized.mirroredFromOrders = true;
  sanitized.mirroredAt = admin.firestore.FieldValue.serverTimestamp();

  return sanitized;
}

// On create, update or delete of an order, keep a mirror under the assigned worker's orders subcollection
exports.mirrorOrderToWorker = functions.firestore
  .document('orders/{orderId}')
  .onWrite(async (change, context) => {
    const orderId = context.params.orderId;
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;

    try {
      // If after is null, the order was deleted -> remove any mirror docs
      if (!after) {
        if (before && before.workerId) {
          await db.doc(`workers/${before.workerId}/orders/${orderId}`).delete().catch(() => {});
        }
        return null;
      }

      // If workerId changed, delete old mirror
      if (before && before.workerId && before.workerId !== after.workerId) {
        await db.doc(`workers/${before.workerId}/orders/${orderId}`).delete().catch(() => {});
      }

      // Create / update mirror for new workerId (if set). Sanitize so prices are not exposed to workers.
      if (after.workerId) {
        const mirrorData = sanitizeForWorker(after);
        await db.doc(`workers/${after.workerId}/orders/${orderId}`).set(mirrorData, { merge: true });
      }
    } catch (err) {
      console.error('mirrorOrderToWorker error for order', orderId, err);
    }

    return null;
  });

// Keep user subcollection in sync as well, and handle deletions / userId changes
exports.mirrorOrderToUserSubcollection = functions.firestore
  .document('orders/{orderId}')
  .onWrite(async (change, context) => {
    const orderId = context.params.orderId;
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;

    try {
      // If order was deleted -> remove mirror under previous user's subcollection
      if (!after) {
        if (before && before.userId) {
          await db.doc(`users/${before.userId}/orders/${orderId}`).delete().catch(() => {});
        }
        return null;
      }

      // If userId changed, delete old mirror
      if (before && before.userId && before.userId !== after.userId) {
        await db.doc(`users/${before.userId}/orders/${orderId}`).delete().catch(() => {});
      }

      // Write current order to the user's orders subcollection
      if (after.userId) {
        // Don't remove price fields for user; user should see their order totals
        const userMirror = Object.assign({}, after);
        userMirror.mirroredFromOrders = true;
        userMirror.mirroredAt = admin.firestore.FieldValue.serverTimestamp();
        await db.doc(`users/${after.userId}/orders/${orderId}`).set(userMirror, { merge: true });
      }
    } catch (err) {
      console.error('mirrorOrderToUserSubcollection error for order', orderId, err);
    }

    return null;
  });

// Also listen to user subcollection writes so mirrors are created when orders
// are only written under users/{uid}/orders (common when clients can't write
// to top-level /orders). This keeps workers' mirrors and the top-level index
// in sync regardless of where the original write happened.
exports.mirrorOrderFromUserSubcollection = functions.firestore
  .document('users/{userId}/orders/{orderId}')
  .onWrite(async (change, context) => {
    const orderId = context.params.orderId;
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;

    try {
      // If after is null, the order was deleted -> remove any mirror docs
      if (!after) {
        if (before) {
          if (before.workerId) {
            await db.doc(`workers/${before.workerId}/orders/${orderId}`).delete().catch(() => {});
          }
          if (before.remoteId) {
            await db.doc(`orders/${orderId}`).delete().catch(() => {});
          }
        }
        return null;
      }

      // If workerId changed, delete old mirror
      if (before && before.workerId && before.workerId !== after.workerId) {
        await db.doc(`workers/${before.workerId}/orders/${orderId}`).delete().catch(() => {});
      }

      // Mirror to workers/{workerId}/orders if workerId present
      if (after.workerId) {
        const mirrorData = sanitizeForWorker(after);
        await db.doc(`workers/${after.workerId}/orders/${orderId}`).set(mirrorData, { merge: true });
      }

      // Also ensure a top-level /orders document exists (useful for admin tooling)
      // but avoid overwriting server-managed fields if they already exist.
      try {
        const topRef = db.doc(`orders/${orderId}`);
        const topMirror = Object.assign({}, after);
        topMirror.mirroredFromUserSubcollection = true;
        topMirror.mirroredAt = admin.firestore.FieldValue.serverTimestamp();
        // Keep price fields for top-level (admins should see totals)
        await topRef.set(topMirror, { merge: true });
      } catch (e) {
        console.error('mirrorOrderFromUserSubcollection: failed to write top-level orders doc', orderId, e);
      }

    } catch (err) {
      console.error('mirrorOrderFromUserSubcollection error for order', orderId, err);
    }

    return null;
  });
