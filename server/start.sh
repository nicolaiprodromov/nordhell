#!/bin/bash

# VPN Orchestrator Server Startup Script

# Change to server directory
cd "$(dirname "$0")"

# Check if we can create virtual environment
if [ ! -d "venv" ]; then
    echo "Attempting to create virtual environment..."
    if python3 -m venv venv 2>/dev/null; then
        echo "Virtual environment created successfully."
        USE_VENV=true
    else
        echo "Warning: Could not create virtual environment."
        echo "This might be because python3-venv is not installed."
        echo "Running without virtual environment (using user packages)."
        USE_VENV=false
    fi
else
    USE_VENV=true
fi

# Activate virtual environment if it exists
if [ "$USE_VENV" = true ] && [ -f "venv/bin/activate" ]; then
    echo "Activating virtual environment..."
    source venv/bin/activate
    PIP_CMD="pip"
else
    echo "Using system Python installation..."
    PIP_CMD="pip3"
fi

# Install/update dependencies
echo "Installing dependencies..."
$PIP_CMD install -r requirements.txt

# Start the server
echo "Starting VPN Orchestrator API server..."
python3 main.py
