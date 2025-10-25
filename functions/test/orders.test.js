import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { collectionGroup, query, where, getDocs } from 'firebase/firestore';
import fs from 'fs';
import { expect } from 'chai';

let testEnv;

before(async () => {
  const rules = fs.readFileSync('../firestore.rules', 'utf8');
  testEnv = await initializeTestEnvironment({
    projectId: 'agapecares-test',
    firestore: { rules }
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  // Seed some documents as an admin (security rules disabled)
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();

    // top-level order assigned to worker1
    await adminDb.collection('orders').doc('order1').set({
      workerId: 'worker1',
      orderOwner: 'owner1',
      userId: 'user1',
      status: 'assigned'
    });

    // user docs (worker1 marked as worker)
    await adminDb.collection('users').doc('user1').set({ role: 'user' });
    await adminDb.collection('users').doc('worker1').set({ role: 'worker' });

    // per-user orders
    await adminDb.collection('users').doc('user1').collection('orders').doc('order2').set({
      workerId: 'worker1',
      orderOwner: 'owner1',
      userId: 'user1',
      status: 'assigned'
    });

    await adminDb.collection('users').doc('user2').collection('orders').doc('order3').set({
      workerId: 'other',
      orderOwner: 'owner2',
      userId: 'user2',
      status: 'assigned'
    });
  });
});

it('allows worker to run collectionGroup orders query filtered by workerId', async () => {
  const workerDb = testEnv.authenticatedContext({ uid: 'worker1' }).firestore();
  await assertSucceeds(getDocs(query(collectionGroup(workerDb, 'orders'), where('workerId', '==', 'worker1'))));
});

it('denies other worker from querying worker1 orders by workerId', async () => {
  const otherDb = testEnv.authenticatedContext({ uid: 'other' }).firestore();
  await assertFails(getDocs(query(collectionGroup(otherDb, 'orders'), where('workerId', '==', 'worker1'))));
});

it('allows admin to list collectionGroup orders', async () => {
  const adminDb = testEnv.authenticatedContext({ uid: 'admin', token: { admin: true } }).firestore();
  await assertSucceeds(getDocs(collectionGroup(adminDb, 'orders')));
});

