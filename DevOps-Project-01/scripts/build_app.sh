#!/bin/bash
set -o errexit  # make your script exit when a command fails
set -o pipefail # to exit when the status of the last command that threw a non-zero exit code is returned
set -o nounset  # to exit when your script tries to use undeclared variables
set -o xtrace   # to trace what gets executed. Useful for debugging

# This script is used to build the Java application

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/../Java-Login-App"

# Build the Java application
cd "$APP_DIR"

# Build artifact first, then run test suite separately for clear failure points.
mvn clean package -DskipTests
mvn test

echo "Deploying artifact with Maven"
mvn deploy
