# Firestore security rules

The rules source is `firestore.rules`. Committing this file to GitHub does not publish it to Firebase.

## Bootstrap administrators

These Firebase Authentication UIDs have administrator access in the rules:

- `JR4B6wAtRPauXlEAkh2fzBDGZ902`
- `NHP5fwv5EyZC7ooI2TvXhpRCskd2`

## Add a future administrator

A user's `role` field alone does not grant access to administrator operations. To promote a user:

1. Set `users/{uid}.role` to `admin` using a trusted project administrator.
2. Create `admins/{uid}` with this document body:

   ```json
   { "active": true }
   ```

Only an existing administrator can create or edit documents in `admins`. The new user must sign out and back in to refresh the app's role and permissions.

To revoke a future administrator, delete `admins/{uid}` or set `active` to `false`, then change the user's role from `admin` to their appropriate account role. The two bootstrap UIDs remain administrators until they are removed from `firestore.rules` and the updated rules are published.

## Publish the rules

Open Firebase Console, select the Mon-Coloc project, then go to **Firestore Database > Rules**. Publish the contents of `firestore.rules`. Review the Firebase rules simulator and app flows before deploying to a live project.

The app currently reads signed-in user profiles for matching and messaging. The Firestore rules retain authenticated profile reads to preserve those features; verification documents and other private profile data should be moved to a separate private collection before tightening profile reads.
