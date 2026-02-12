#!/bin/bash
cd ~/oli-core/oli_app
echo "🔨 Building Flutter web app..."
flutter build web --release

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo ""
    echo "📦 Next step: Deploy to Firebase"
    echo "Run: firebase deploy --only hosting"
else
    echo "❌ Build failed!"
    exit 1
fi
