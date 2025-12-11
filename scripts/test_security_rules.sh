#!/bin/bash

# Security Rules Testing Script
# This script helps test Firestore and Realtime Database security rules

echo "=========================================="
echo "Firebase Security Rules Testing"
echo "=========================================="
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null
then
    echo "❌ Firebase CLI is not installed."
    echo "Please install it with: npm install -g firebase-tools"
    exit 1
fi

echo "✅ Firebase CLI is installed"
echo ""

# Check if user is logged in
if ! firebase projects:list &> /dev/null
then
    echo "❌ Not logged in to Firebase."
    echo "Please login with: firebase login"
    exit 1
fi

echo "✅ Logged in to Firebase"
echo ""

# Display menu
echo "Select an option:"
echo "1. Start Firebase Emulators"
echo "2. Start Emulators with fresh data"
echo "3. Deploy security rules to Firebase"
echo "4. Run unit tests"
echo "5. Exit"
echo ""
read -p "Enter your choice (1-5): " choice

case $choice in
    1)
        echo ""
        echo "Starting Firebase Emulators..."
        echo "Firestore: http://localhost:8080"
        echo "Realtime Database: http://localhost:9000"
        echo "Emulator UI: http://localhost:4000"
        echo ""
        firebase emulators:start
        ;;
    2)
        echo ""
        echo "Starting Firebase Emulators with fresh data..."
        firebase emulators:start --clear-data
        ;;
    3)
        echo ""
        echo "Deploying security rules to Firebase..."
        read -p "Are you sure you want to deploy to production? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            firebase deploy --only firestore:rules,database
            echo "✅ Security rules deployed successfully"
        else
            echo "Deployment cancelled"
        fi
        ;;
    4)
        echo ""
        echo "Running unit tests..."
        flutter test test/firestore_security_rules_test.dart
        ;;
    5)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid choice. Please run the script again."
        exit 1
        ;;
esac
