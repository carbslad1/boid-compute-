#!/bin/bash

echo "LÖVE 12.0 Nightly Setup Script"
echo "==============================="
echo ""
echo "Step 1: Download the nightly build"
echo "-----------------------------------"
echo "1. Open: https://github.com/love2d/love/actions/workflows/main.yml"
echo "2. Sign in to GitHub"
echo "3. Click on the latest green checkmark build"
echo "4. Scroll down to 'Artifacts' section"
echo "5. Download 'love-macos-portable'"
echo ""
echo "Press Enter once you've downloaded the file to your Downloads folder..."
read

# Check if file exists
if [ -f ~/Downloads/love-macos-portable.zip ]; then
    echo "Found love-macos-portable.zip!"
    
    # Create directory for LÖVE 12
    mkdir -p ~/love12
    
    echo "Extracting LÖVE 12.0..."
    unzip -q ~/Downloads/love-macos-portable.zip -d ~/love12/
    
    # Make it executable
    chmod +x ~/love12/love.app/Contents/MacOS/love
    
    # Create alias for easy access
    echo "Creating love12 command..."
    echo "alias love12='~/love12/love.app/Contents/MacOS/love'" >> ~/.zshrc
    
    # Test installation
    echo "Testing LÖVE 12.0..."
    ~/love12/love.app/Contents/MacOS/love --version
    
    echo ""
    echo "✅ LÖVE 12.0 installed successfully!"
    echo ""
    echo "To run the compute shader demo:"
    echo "  ~/love12/love.app/Contents/MacOS/love $(pwd)/main_compute.lua"
    echo ""
    echo "Or use the alias (after restarting terminal):"
    echo "  love12 main_compute.lua"
    
else
    echo "❌ File not found: ~/Downloads/love-macos-portable.zip"
    echo "Please download it from GitHub Actions first."
fi
