#!/bin/bash

# Launch script for ParqView
set -e

# Check if app bundle exists, build if not
if [ ! -d ".build/ParqView.app" ]; then
    echo "App bundle not found. Building..."
    ./build_app.sh
fi

# Launch the app bundle
echo "Launching ParqView.app..."
open .build/ParqView.app --args "$@"