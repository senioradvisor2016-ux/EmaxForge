#!/bin/bash
echo "🔍 Starting EmaxForge with console logging..."
echo ""

cd ~/clawd/EmaxForge
open -a Console

# Wait a bit for Console to open
sleep 2

# Start app
./.build/EmaxForge.app/Contents/MacOS/EmaxForge 2>&1 | tee ~/clawd/EmaxForge/app-console.log &

echo "App started! Check Console.app for real-time logs."
echo "App console output will be saved to: ~/clawd/EmaxForge/app-console.log"
