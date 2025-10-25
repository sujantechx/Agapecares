Purpose
-------
This file provides a ready-to-use Firestore Rules Playground / Emulator test payload for the worker-side update that was failing with PERMISSION_DENIED in your logs.

Goal
----
Simulate an authenticated worker (uid: Q3ASypIEwjdw5fPLtqz4ZATn0Cx1) attempting to update the user's order document at:

users/znpUWLdkOkSPtqHtpuMz1Vb9ihx2/orders/9mSbqrJopQVV4vc8pQxJ

The update should only change safe fields: status, orderStatus, workerId and updatedAt (server time).

Step-by-step (Rules Playground in Firebase Console)
-------------------------------------------------
1. Open Firebase Console → Firestore → Rules. Click "Rules Playground" at the top-right of the rules editor.
2. Set the Target Resource (the existing document) using the JSON below in the "Existing resource (resource)" area.
3. For the Request (the update), set the Method to `update` and paste the Request Resource JSON shown below.
4. Set the Auth object to include the worker's uid (see Auth JSON below).
5. Click "Run". The simulator will tell you if the operation is ALLOWED or DENIED and highlight which rule path matched.

If you prefer the Emulator: run `firebase emulators:start --only firestore` from the project root and use the Playground UI or run the same checks via REST/curl against the emulator.

Existing resource (document currently in Firestore)
--------------------------------------------------
Use this JSON for the existing document (resource). Timestamps are shown as ISO strings but the Simulator understands them as server times; you can replace with the Playground's request.time checkbox where available.

{
  "workerId": "Q3ASypIEwjdw5fPLtqz4ZATn0Cx1",
  "addressSnapshot": { "address": "bzbbxn" },
  "orderStatus": "assigned",
  "discount": 0.0,
  "tax": 0.0,
  "userId": "znpUWLdkOkSPtqHtpuMz1Vb9ihx2",
  "mirroredFromUserSubcollection": true,
  "remoteId": "9mSbqrJopQVV4vc8pQxJ",
  "orderOwner": "znpUWLdkOkSPtqHtpuMz1Vb9ihx2",
  "totalAmount": 12416.4,
  "createdAt": "2025-09-01T12:12:14.183Z",    // sample ISO
  "total": 12416.4,
  "subtotal": 12416.4,
  "workerName": "ashis",
  "items": [
    {
      "unitPrice": 12416.4,
      "quantity": 1,
      "optionName": "2Home BHK - 15Days-8 visits",
      "serviceName": "Full Home Cleaning",
      "serviceId": "IweyggQX7DYLfpdGIIul"
    }
  ],
  "scheduledAt": "2025-09-01T12:11:44.140Z",
  "paymentStatus": "paid",
  "updatedAt": "2025-09-01T12:15:30.901Z",
  "status": "assigned"
}

Request.auth (worker identity)
------------------------------
Set this in the Playground so request.auth.uid equals the worker uid:

{
  "uid": "Q3ASypIEwjdw5fPLtqz4ZATn0Cx1",
  "token": {
    "role": "worker"
  }
}

Request resource (what the worker is trying to write)
----------------------------------------------------
Use this JSON as the incoming request.resource data for an update operation. In the Rules Playground you can check the box to set request.time to the current time which the rules treat as server timestamp.

{
  "status": "completed",
  "orderStatus": "completed",
  "workerId": "Q3ASypIEwjdw5fPLtqz4ZATn0Cx1",
  "updatedAt": "__request.time__"
}

Notes for the Playground:
- Replace "__request.time__" by using the Playground's "Use current time for request.time" option — some rule functions compare updatedAt to request.time.
- Make sure the operation is set to `update` and the path is users/znpUWLdkOkSPtqHtpuMz1Vb9ihx2/orders/9mSbqrJopQVV4vc8pQxJ.

If the simulation DENIES the request
----------------------------------
1. Check that resource.workerId == request.auth.uid in the existing resource. If the existing doc doesn't have workerId set to the worker's uid, rules will deny.
2. Ensure the incoming request only writes the allowed keys (status, orderStatus, workerId, updatedAt). Any extra key will cause denial when rules restrict keys.
3. If you required updatedAt to equal request.time in rules, ensure you're using the Playground checkbox to set request.time or use Emulator with server timestamp.
4. If DENIED and you want me to debug, paste the exact Playground simulation output here (it contains the rule path and failing condition) and I'll advise a minimal rule tweak.

Emulator quick-run (Windows cmd.exe):
-------------------------------------
From project root (where firebase.json lives):

```cmd
firebase emulators:start --only firestore
```

Then open the Emulator UI (http://localhost:4000 by default) → Firestore → Rules Playground, and run the same simulation.

Conclusion
----------
This file gives you the exact resource and request payloads to reproduce the failing worker update locally. Run the Playground/emulator test; if it still denies, copy the simulation output here and I'll propose a minimal rules change to allow this strict update while keeping your data safe.

