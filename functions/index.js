const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// Aggregate service rating when a new rating doc is created under services/{serviceId}/ratings/{ratingId}
exports.aggregateServiceRating = functions.firestore
  .document('services/{serviceId}/ratings/{ratingId}')
  .onCreate(async (snap, context) => {
    const serviceId = context.params.serviceId;
    const rating = snap.data()?.rating;
    if (typeof rating !== 'number') return null;

    const serviceRef = db.collection('services').doc(serviceId);
    return db.runTransaction(async (tx) => {
      const doc = await tx.get(serviceRef);
      if (!doc.exists) {
        tx.set(serviceRef, { ratingAvg: rating, ratingCount: 1, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
        return;
      }
      const data = doc.data() || {};
      const currentAvg = (data.ratingAvg || 0);
      const currentCount = (data.ratingCount || 0);
      const newCount = currentCount + 1;
      const newAvg = ((currentAvg * currentCount) + rating) / newCount;
      tx.set(serviceRef, { ratingAvg: newAvg, ratingCount: newCount, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    });
  });

// Aggregate worker rating when a new rating doc is created under workers/{workerId}/ratings
exports.aggregateWorkerRating = functions.firestore
  .document('workers/{workerId}/ratings/{ratingId}')
  .onCreate(async (snap, context) => {
    const workerId = context.params.workerId;
    const rating = snap.data()?.rating;
    if (typeof rating !== 'number') return null;

    const workerRef = db.collection('workers').doc(workerId);
    const usersRef = db.collection('users').doc(workerId); // fallback if worker stored under users
    return db.runTransaction(async (tx) => {
      const doc = await tx.get(workerRef);
      if (doc.exists) {
        const data = doc.data() || {};
        const currentAvg = (data.ratingAvg || 0);
        const currentCount = (data.ratingCount || 0);
        const newCount = currentCount + 1;
        const newAvg = ((currentAvg * currentCount) + rating) / newCount;
        tx.set(workerRef, { ratingAvg: newAvg, ratingCount: newCount, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
        return;
      }
      // Fallback to users/{workerId}
      const udoc = await tx.get(usersRef);
      if (udoc.exists) {
        const udata = udoc.data() || {};
        const currentAvg = (udata.ratingAvg || 0);
        const currentCount = (udata.ratingCount || 0);
        const newCount = currentCount + 1;
        const newAvg = ((currentAvg * currentCount) + rating) / newCount;
        tx.set(usersRef, { ratingAvg: newAvg, ratingCount: newCount, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
        return;
      }
      // If neither exists, create workers/{workerId} doc with initial rating
      tx.set(workerRef, { ratingAvg: rating, ratingCount: 1, createdAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    });
  });

// Callable function to submit a rating atomically with admin privileges
exports.submitRating = functions.https.onCall(async (data, context) => {
  // Authentication
  const auth = context.auth;
  if (!auth || !auth.uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to submit ratings');
  }
  const uid = auth.uid;

  // Validate input
  const orderId = (data.orderId || '').toString();
  const serviceRating = Number(data.serviceRating);
  const workerRating = data.workerRating != null ? Number(data.workerRating) : null;
  const review = (data.review || '').toString();

  if (!orderId) throw new functions.https.HttpsError('invalid-argument', 'orderId is required');
  if (isNaN(serviceRating) || serviceRating < 1 || serviceRating > 5) throw new functions.https.HttpsError('invalid-argument', 'serviceRating must be a number between 1 and 5');
  if (workerRating != null && (isNaN(workerRating) || workerRating < 1 || workerRating > 5)) throw new functions.https.HttpsError('invalid-argument', 'workerRating must be a number between 1 and 5');

  // Attempt to find the order document.
  // Preference: users/{uid}/orders/{orderId}, then top-level orders/{orderId}, then collectionGroup by remoteId.
  let orderRef = db.collection('users').doc(uid).collection('orders').doc(orderId);
  let orderSnap = await orderRef.get();
  if (!orderSnap.exists) {
    // Try top-level orders
    const topRef = db.collection('orders').doc(orderId);
    const topSnap = await topRef.get();
    if (topSnap.exists) {
      orderRef = topRef;
      orderSnap = topSnap;
    } else {
      // Try collectionGroup by remoteId
      const cg = await db.collectionGroup('orders').where('remoteId', '==', orderId).limit(1).get();
      if (!cg.empty) {
        orderRef = cg.docs[0].ref;
        orderSnap = cg.docs[0];
      }
    }
  }

  if (!orderSnap || !orderSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Order not found');
  }

  const orderData = orderSnap.data() || {};
  // Verify the caller is the order owner (or admin). Admins can submit ratings on behalf but we require owner here.
  const orderOwner = orderData.orderOwner || orderData.userId || orderData.orderOwner;
  if (orderOwner && orderOwner !== uid) {
    throw new functions.https.HttpsError('permission-denied', 'You are not the owner of this order');
  }

  // Ensure order status is completed
  const status = (orderData.orderStatus || orderData.status || '').toString().toLowerCase();
  if (status !== 'completed') {
    throw new functions.https.HttpsError('failed-precondition', 'Order is not completed');
  }

  // Check for existing rating on the order (prevent duplicates)
  if (orderData.serviceRating != null) {
    throw new functions.https.HttpsError('already-exists', 'Order already has a service rating');
  }

  // Prepare to write rating docs and update aggregates atomically using a transaction
  const items = Array.isArray(orderData.items) ? orderData.items : [];
  const serviceIds = new Set(items.map(it => (it && it.serviceId) ? it.serviceId : null).filter(Boolean));
  const workerId = orderData.workerId || null;

  try {
    await db.runTransaction(async (tx) => {
      // Update user's order doc (if it exists under users/{uid}/orders)
      // We must find the users/{uid}/orders doc path if the current orderRef is not under users/{uid}/orders
      let userOrderRef = null;
      if (orderRef.path.startsWith(`users/${uid}/orders`)) {
        userOrderRef = orderRef;
      } else {
        // try to find a users/{uid}/orders doc with remoteId == orderRef.id
        const cg = await db.collectionGroup('orders').where('remoteId', '==', orderRef.id).where('orderOwner', '==', uid).limit(1).get();
        if (!cg.empty) userOrderRef = cg.docs[0].ref;
      }

      const now = admin.firestore.FieldValue.serverTimestamp();

      if (userOrderRef) {
        tx.set(userOrderRef, { serviceRating: serviceRating, workerRating: workerRating, review: review || '', updatedAt: now }, { merge: true });
      }

      // Update top-level order if present
      const topOrderRef = db.collection('orders').doc(orderRef.id);
      const topOrderSnap = await tx.get(topOrderRef);
      if (topOrderSnap.exists) {
        tx.set(topOrderRef, { serviceRating: serviceRating, workerRating: workerRating, review: review || '', updatedAt: now }, { merge: true });
      }

      // Create service rating docs
      for (const sid of serviceIds) {
        const ratingsCol = db.collection('services').doc(sid).collection('ratings');
        const newDocRef = ratingsCol.doc();
        tx.set(newDocRef, {
          serviceId: sid,
          orderId: orderRef.id,
          orderNumber: orderData.orderNumber || '',
          userId: uid,
          rating: serviceRating,
          review: review || '',
          createdAt: now,
          remoteId: newDocRef.id
        });

        // Update aggregate for service
        const serviceRef = db.collection('services').doc(sid);
        const sSnap = await tx.get(serviceRef);
        if (sSnap.exists) {
          const sData = sSnap.data() || {};
          const currentAvg = Number(sData.ratingAvg || 0);
          const currentCount = Number(sData.ratingCount || 0);
          const newCount = currentCount + 1;
          const newAvg = ((currentAvg * currentCount) + serviceRating) / newCount;
          tx.set(serviceRef, { ratingAvg: newAvg, ratingCount: newCount, updatedAt: now }, { merge: true });
        } else {
          tx.set(serviceRef, { ratingAvg: serviceRating, ratingCount: 1, createdAt: now, updatedAt: now }, { merge: true });
        }
      }

      // Create worker rating doc and update aggregate (if worker assigned)
      if (workerId) {
        const ratingsCol = db.collection('workers').doc(workerId).collection('ratings');
        const newDocRef = ratingsCol.doc();
        const valueForWorker = (workerRating != null) ? workerRating : serviceRating;
        tx.set(newDocRef, {
          workerId: workerId,
          orderId: orderRef.id,
          orderNumber: orderData.orderNumber || '',
          userId: uid,
          rating: valueForWorker,
          review: review || '',
          createdAt: now,
          remoteId: newDocRef.id
        });

        const workerRef = db.collection('workers').doc(workerId);
        const wSnap = await tx.get(workerRef);
        if (wSnap.exists) {
          const wData = wSnap.data() || {};
          const currentAvg = Number(wData.ratingAvg || 0);
          const currentCount = Number(wData.ratingCount || 0);
          const newCount = currentCount + 1;
          const newAvg = ((currentAvg * currentCount) + valueForWorker) / newCount;
          tx.set(workerRef, { ratingAvg: newAvg, ratingCount: newCount, updatedAt: now }, { merge: true });
        } else {
          // try users/{workerId} fallback
          const usersRef = db.collection('users').doc(workerId);
          const uSnap = await tx.get(usersRef);
          if (uSnap.exists) {
            const uData = uSnap.data() || {};
            const currentAvg = Number(uData.ratingAvg || 0);
            const currentCount = Number(uData.ratingCount || 0);
            const newCount = currentCount + 1;
            const newAvg = ((currentAvg * currentCount) + valueForWorker) / newCount;
            tx.set(usersRef, { ratingAvg: newAvg, ratingCount: newCount, updatedAt: now }, { merge: true });
          } else {
            tx.set(workerRef, { ratingAvg: valueForWorker, ratingCount: 1, createdAt: now, updatedAt: now }, { merge: true });
          }
        }
      }

      // Finally, set a flag on the order to indicate rating submitted (already set above) — covered.
    });

    return { success: true };
  } catch (err) {
    console.error('submitRating failed:', err);
    throw new functions.https.HttpsError('internal', 'Failed to submit rating', { message: err.message });
  }
});
