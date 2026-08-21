# Firebase backend

This backend powers the anonymous bottle exchange.

`exchangeBottle` stores a user's bottle in Cloud Firestore and returns one bottle from another client when one is available. During early testing, if there is no other user's bottle yet, it returns a fallback bottle so the receive flow can still be tested.

`reportBottle` marks a delivered bottle as reported. Reported bottles are excluded from future delivery and the author is not notified.

## Setup

1. Enable Firestore in the Firebase console.
2. Upgrade the Firebase project to Blaze.
3. From this `firebase` directory, run `firebase use --add` and select `shortdiary-66f95`.
4. Run `npm install` inside `functions` if dependencies are not installed.
5. Deploy with `firebase deploy --only functions,firestore`.

The iOS app calls these deployed HTTP Functions:

- `https://exchangebottle-2c27cj2ouq-an.a.run.app`
- `https://reportbottle-2c27cj2ouq-an.a.run.app`
- `https://asia-northeast1-shortdiary-66f95.cloudfunctions.net/deleteAccountData`

Firestore reads/writes are denied to clients. Only Cloud Functions should access the `bottles` and `reports` collections.
