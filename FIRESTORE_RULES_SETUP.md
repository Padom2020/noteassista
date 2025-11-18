# Firestore Security Rules Setup

## The Problem
You're getting a `permission-denied` error because Firestore security rules are blocking access to your database.

## Solution: Deploy Security Rules

### Option 1: Deploy via Firebase Console (Recommended for Quick Fix)

1. **Go to Firebase Console**
   - Visit: https://console.firebase.google.com/
   - Select your project

2. **Navigate to Firestore Database**
   - Click on "Firestore Database" in the left sidebar
   - Click on the "Rules" tab at the top

3. **Copy and Paste the Rules**
   - Open the `firestore.rules` file in this project
   - Copy all the content
   - Paste it into the Firebase Console rules editor
   - Click "Publish" button

4. **Verify**
   - The rules should now be active
   - Restart your app and try again

### Option 2: Deploy via Firebase CLI

1. **Install Firebase CLI** (if not already installed)
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase**
   ```bash
   firebase login
   ```

3. **Initialize Firebase** (if not already done)
   ```bash
   firebase init firestore
   ```
   - Select your Firebase project
   - Accept the default `firestore.rules` file location

4. **Deploy the Rules**
   ```bash
   firebase deploy --only firestore:rules
   ```

## What These Rules Do

The security rules in `firestore.rules` ensure:

✅ **Authentication Required**: Only authenticated users can access Firestore
✅ **User Isolation**: Users can only read/write their own user document
✅ **Note Privacy**: Users can only access notes in their own subcollection
✅ **Default Deny**: All other access is denied by default

## Rule Structure

```
/users/{userId}                    ← User can only access their own document
  └── /notes/{noteId}              ← User can only access their own notes
```

## Testing

After deploying the rules:

1. **Login to your app** with a valid account
2. **Try creating a note** - should work ✓
3. **Try viewing notes** - should work ✓
4. **Try editing/deleting notes** - should work ✓

## Troubleshooting

If you still get permission errors:

1. **Check Authentication**: Make sure you're logged in
   - Check if `FirebaseAuth.instance.currentUser` is not null

2. **Verify User ID**: Ensure the userId in Firestore matches the auth UID
   - The app uses `currentUser?.uid` for all operations

3. **Check Rules Deployment**: Verify rules are published in Firebase Console
   - Go to Firestore Database → Rules tab
   - Check the timestamp to confirm latest deployment

4. **Clear App Data**: Sometimes cached data causes issues
   - Logout and login again
   - Or reinstall the app

## Important Notes

⚠️ **Never use test mode rules in production!**
   - Test mode allows anyone to read/write your database
   - Always use authenticated rules like the ones provided

⚠️ **Rules are not filters!**
   - Your queries must only request data the user has access to
   - The app already does this by filtering by userId
