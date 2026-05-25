#!/bin/bash
set -e

echo "Installing Chrome..."
apt-get update
apt-get install -y google-chrome-stable

echo "Starting app..."
npm start
