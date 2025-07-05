import request from 'supertest';
import { Storage } from '@google-cloud/storage';
import axios from 'axios';

// For axios calls to configure the emulator
const API_ENDPOINT = process.env.GCS_EMULATOR_ENDPOINT || 'http://localhost:4443';

// For the Google Cloud Storage client with fake-gcs-server
// We need to explicitly set the apiEndpoint to the full URL including /storage/v1
const storage = new Storage({
  projectId: process.env.GOOGLE_CLOUD_PROJECT || 'test-project',
  keyFilename: undefined, // Disable authentication for emulator
  apiEndpoint: `${API_ENDPOINT}`,
  // Disable SSL verification for local testing
  retryOptions: {
    autoRetry: false,
  },
});

const PROXY_HOST = process.env.PROXY_HOST || 'http://localhost:3000';

describe('GET /download/:bucket/:file(*)', () => {
  const bucketName = 'test-bucket';
  const existingFileName = 'some_file.txt';
  const existingFileContent = 'This is a test file for the proxy.';

  beforeAll(async () => {
    // Test connection to services
    console.log(`Testing connections...`);
    console.log(`GCS emulator host: ${API_ENDPOINT}`);
    console.log(`Proxy host: ${PROXY_HOST}`);
    console.log(`Verification service URL: ${process.env.VERIFICATION_SERVICE_URL}`);
    
    // Configure the fake-gcs-server external URL for proper client compatibility
    console.log(`Configuring GCS emulator external URL...`);
    try {
      await axios.put(`${API_ENDPOINT}/_internal/config`, {
        externalUrl: API_ENDPOINT,
      });
      console.log(`GCS emulator external URL configured successfully`);
    } catch (error) {
      console.error(`Failed to configure GCS emulator:`, error instanceof Error ? error.message : String(error));
      // Don't fail here - the configuration might already be set
    }
    
    // Test connection to GCS emulator and create bucket with test data
    console.log(`Testing connection to GCS emulator at: ${API_ENDPOINT}`);
    try {
      // Try to create the test bucket, ignore if it already exists
      console.log(`Creating bucket: ${bucketName}`);
      try {
        await storage.createBucket(bucketName);
        console.log(`Bucket ${bucketName} created successfully`);
      } catch (error) {
        if (error instanceof Error && error.message.includes('already exists')) {
          console.log(`Bucket ${bucketName} already exists, continuing...`);
        } else {
          throw error;
        }
      }
      
      // Upload the test file
      console.log(`Uploading test file: ${existingFileName}`);
      const bucket = storage.bucket(bucketName);
      const file = bucket.file(existingFileName);
      await file.save(existingFileContent);
      console.log(`Test file uploaded successfully`);
      
      // Verify the setup
      const buckets = await storage.getBuckets();
      console.log(`Successfully connected to GCS emulator. Found ${buckets[0].length} buckets.`);
      buckets[0].forEach(bucket => console.log(`  - Bucket: ${bucket.name}`));
      
      const [files] = await bucket.getFiles();
      console.log(`Files in bucket ${bucketName}:`);
      files.forEach(file => console.log(`  - ${file.name}`));
      
    } catch (error) {
      console.error(`Failed to set up GCS emulator:`, error instanceof Error ? error.message : String(error));
      throw error;
    }
    
    // Test connection to proxy service
    console.log(`Testing connection to proxy service at: ${PROXY_HOST}`);
    try {
      const response = await request(PROXY_HOST).get('/healthz');
      console.log(`Successfully connected to proxy service. Status: ${response.status}`);
    } catch (error) {
      console.error(`Failed to connect to proxy service:`, error instanceof Error ? error.message : String(error));
      throw error;
    }
  }, 30000);

  test('should return a file when it exists', async () => {
    console.log(`Testing download of existing file: ${bucketName}/${existingFileName}`);
    const response = await request(PROXY_HOST).get(`/download/${bucketName}/${existingFileName}`);

    expect(response.status).toBe(200);
    expect(response.headers['content-disposition']).toBe(`attachment; filename=${existingFileName}`);
    expect(response.text).toBe(existingFileContent);
  }, 30000);

  test('should return 404 when the file does not exist', async () => {
    console.log(`Testing download of non-existent file`);
    const response = await request(PROXY_HOST).get(`/download/${bucketName}/non_existent_file`);

    expect(response.status).toBe(404);
    expect(response.text).toBe('File not found');
  }, 30000);
});
