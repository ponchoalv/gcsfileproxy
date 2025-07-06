# GCS File Proxy

A TypeScript-based proxy server for downloading files from Google Cloud Storage (GCS) buckets with built-in safety verification and comprehensive integration testing.

## Overview

This project provides a secure proxy service that:
- Downloads files from GCS buckets through a REST API
- Verifies file safety through an external verification service
- Includes comprehensive integration tests using a fake GCS emulator
- Runs in Kubernetes with support for local development using Kind and Tilt

## Features

- **Secure File Downloads**: Proxy access to GCS files with safety verification
- **TypeScript**: Full TypeScript implementation with proper type safety
- **Integration Testing**: Complete test suite using fake-gcs-server emulator
- **Kubernetes Ready**: Production-ready Kubernetes manifests
- **Local Development**: Easy local development with Kind cluster and Tilt
- **Structured Logging**: Uses Pino for structured JSON logging
- **Health Checks**: Built-in health check endpoints

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│                 │    │                 │    │                 │
│     Client      │───▶│  GCS Proxy      │───▶│ Verification    │
│                 │    │   Server        │    │   Service       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │                 │
                       │ Google Cloud    │
                       │   Storage       │
                       │                 │
                       └─────────────────┘
```

## API Endpoints

### Download File
```
GET /download/{bucket}/{file}
```

Downloads a file from the specified GCS bucket after verifying its safety.

**Parameters:**
- `bucket`: GCS bucket name
- `file`: File path within the bucket (supports nested paths)

**Responses:**
- `200`: File download with `Content-Disposition: attachment`
- `403`: File is not safe to download
- `404`: File not found
- `500`: Internal server error

**Example:**
```bash
curl http://localhost:3000/download/my-bucket/path/to/file.pdf
```

### Health Check
```
GET /healthz
```

Returns server health status.

**Response:**
- `200`: Server is healthy

## Development Setup

### Prerequisites

- Node.js 16+
- Docker
- kubectl
- Kind (for local Kubernetes)
- Tilt (for local development orchestration)

### Local Development

1. **Clone and install dependencies:**
   ```bash
   git clone <repository-url>
   cd gcsfileproxy
   npm install
   ```

2. **Start local development environment:**
   ```bash
   make dev
   ```
   This will:
   - Create a Kind cluster
   - Deploy all services (proxy, verification service, GCS emulator)
   - Start Tilt for live reloading

3. **Run tests:**
   ```bash
   make test
   ```

4. **Clean up:**
   ```bash
   make clean
   ```

### Available Make Commands

- `make setup`: Create Kind cluster and setup environment
- `make dev`: Start development environment with Tilt
- `make test`: Run integration tests
- `make build`: Build Docker images
- `make deploy`: Deploy to Kubernetes
- `make clean`: Clean up resources

## Configuration

### Environment Variables

#### Proxy Server
- `PORT`: Server port (default: 3000)
- `GOOGLE_CLOUD_PROJECT`: GCP project ID
- `GCS_EMULATOR_ENDPOINT`: GCS emulator endpoint (for testing)
- `VERIFICATION_SERVICE_URL`: URL of the verification service

#### Integration Tests
- `GCS_EMULATOR_ENDPOINT`: GCS emulator endpoint
- `PROXY_HOST`: Proxy server URL
- `VERIFICATION_SERVICE_URL`: Verification service URL
- `GOOGLE_CLOUD_PROJECT`: GCP project ID for testing

## Testing

### Integration Tests

The project includes comprehensive integration tests that:
- Use a real fake-gcs-server emulator
- Test actual file upload/download workflows
- Verify error handling (404, 403, 500)
- Test service-to-service communication

### Running Tests Locally

```bash
# Run tests with npm
npm test

# Run tests in Docker (as in CI)
docker build -t gcsfileproxy-tests -f tests/Dockerfile .
docker run --rm gcsfileproxy-tests
```

### Testing in Kubernetes

```bash
# Deploy test job
kubectl apply -f kubernetes/tests-job.yaml

# Check test results
kubectl logs job/integration-tests
```

## Deployment

### Kubernetes Deployment

The project includes complete Kubernetes manifests:

- `kubernetes/proxy-deployment.yaml`: Main proxy service
- `kubernetes/proxy-service.yaml`: Service exposure
- `kubernetes/verification-deployment.yaml`: Mock verification service
- `kubernetes/verification-service.yaml`: Verification service exposure
- `kubernetes/gcs-emulator-deployment.yaml`: GCS emulator (for testing)
- `kubernetes/gcs-emulator-service.yaml`: Emulator service
- `kubernetes/gcs-emulator-pvc.yaml`: Persistent storage for emulator
- `kubernetes/tests-job.yaml`: Integration test job

### Production Deployment

1. **Build and push images:**
   ```bash
   docker build -t your-registry/gcsfileproxy:latest .
   docker push your-registry/gcsfileproxy:latest
   ```

2. **Update image references in manifests**

3. **Deploy to Kubernetes:**
   ```bash
   kubectl apply -f kubernetes/
   ```

### Google Cloud Storage Authentication

For production, ensure proper GCS authentication:

1. **Service Account**: Create a service account with GCS read permissions
2. **Workload Identity** (recommended for GKE):
   ```bash
   # Configure workload identity
   kubectl annotate serviceaccount default \
     iam.gke.io/gcp-service-account=gcs-reader@PROJECT.iam.gserviceaccount.com
   ```
3. **Service Account Key** (alternative):
   - Mount service account key as a secret
   - Set `GOOGLE_APPLICATION_CREDENTIALS` environment variable

## Project Structure

```
.
├── src/
│   ├── index.ts          # Main server entry point
│   ├── routes.ts         # API route handlers
│   └── logger.ts         # Logging configuration
├── tests/
│   ├── integration.test.ts  # Integration tests
│   └── Dockerfile        # Test container
├── kubernetes/           # Kubernetes manifests
├── mocks/               # Mock services
│   └── verification-service/
├── scripts/             # Utility scripts
├── Dockerfile           # Main application container
├── Tiltfile            # Tilt configuration
├── Makefile            # Development automation
└── README.md           # This file
```

## Troubleshooting

### Common Issues

1. **"Only HTTP(S) protocols are supported" error:**
   - Ensure `GCS_EMULATOR_ENDPOINT` is set correctly with `http://` prefix
   - Check that the Storage client `apiEndpoint` configuration is correct

2. **Tests fail with connection errors:**
   - Verify all services are running: `kubectl get pods`
   - Check service logs: `kubectl logs deployment/gcs-emulator`

3. **Kind cluster issues:**
   - Reset cluster: `make clean && make setup`
   - Check cluster status: `kind get clusters`

4. **Tilt build failures:**
   - Check Tilt UI at http://localhost:10350
   - Restart Tilt: `tilt down && tilt up`

### Debugging

1. **View service logs:**
   ```bash
   # Proxy logs
   kubectl logs deployment/gcsfileproxy

   # Emulator logs
   kubectl logs deployment/gcs-emulator

   # Test logs
   kubectl logs job/integration-tests
   ```

2. **Debug in cluster:**
   ```bash
   # Start debug pod
   kubectl run debug --image=busybox -it --rm -- sh

   # Test connectivity
   wget -O- http://gcs-emulator:4443/_internal/config
   ```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass: `make test`
6. Submit a pull request

## License

[Add your license here]

## Support

[Add support information here]
