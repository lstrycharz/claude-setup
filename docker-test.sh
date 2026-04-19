#!/bin/bash
# docker-test.sh — Run the test suite in a clean Ubuntu container
# Use this to verify install.sh works on a fresh machine with no customizations.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if ! command -v docker &> /dev/null; then
  echo "❌ Docker is not installed or not in PATH."
  echo "   Install: https://docs.docker.com/get-docker/"
  exit 1
fi

echo "Building test container (Ubuntu 22.04 + node + git)..."
docker build -t claude-setup-test . > /tmp/claude-setup-docker-build.log 2>&1 || {
  echo "❌ Docker build failed. Log: /tmp/claude-setup-docker-build.log"
  tail -20 /tmp/claude-setup-docker-build.log
  exit 1
}

echo ""
echo "Running tests in container..."
echo ""

docker run --rm claude-setup-test
EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ All tests passed in Docker sandbox"
else
  echo "❌ Tests failed in Docker sandbox (exit $EXIT_CODE)"
fi
exit $EXIT_CODE
