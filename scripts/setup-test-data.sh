#!/bin/bash

# This script uses curl to create a bucket and upload files using the correct API endpoints

GCS_EMULATOR_HOST=${STORAGE_EMULATOR_HOST:-"http://localhost:4443"}
PROJECT_ID=${GOOGLE_CLOUD_PROJECT:-"test-project"}
BUCKET_NAME="test-bucket"

echo "Creating bucket: $BUCKET_NAME"
curl -X POST "$GCS_EMULATOR_HOST/storage/v1/b?project=$PROJECT_ID" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$BUCKET_NAME\"}"

echo
echo "Uploading test file: some_file.txt"
curl -X POST "$GCS_EMULATOR_HOST/upload/storage/v1/b/$BUCKET_NAME/o?uploadType=media&name=some_file.txt" \
  -H "Content-Type: text/plain" \
  -d "This is a test file for the proxy."

echo
echo "Uploading test file: test_document.txt"
curl -X POST "$GCS_EMULATOR_HOST/upload/storage/v1/b/$BUCKET_NAME/o?uploadType=media&name=test_document.txt" \
  -H "Content-Type: text/plain" \
  -d "This is another test document for integration tests."

echo
echo "Listing bucket contents:"
curl -s "$GCS_EMULATOR_HOST/storage/v1/b/$BUCKET_NAME/o" | jq -r '.items[].name // empty'

echo
echo "Setup complete!"
