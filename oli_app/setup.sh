#!/bin/bash
cd "$(dirname "$0")"
echo "Cleaning Flutter project..."
flutter clean
echo "Getting dependencies..."
flutter pub get
echo "Done!"
