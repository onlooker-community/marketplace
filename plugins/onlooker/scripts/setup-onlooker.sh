#!/bin/bash
# Setup Onlooker for the first time

set -e

echo "🔍 Onlooker Setup"
echo "================="

# Create log directory
mkdir -p ~/.claude/logs
echo "✓ Created log directory"

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo "✗ Python 3 not found. Hooks require Python."
    exit 1
fi
echo "✓ Python 3 found"
