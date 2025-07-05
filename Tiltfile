local_resource(
    name='kind-cluster',
    cmd='make cluster-create',
    deps=['Makefile', 'kind-config.yaml']
)

# Docker builds
docker_build('gcsfileproxy', '.', dockerfile='./Dockerfile')
docker_build('verification-service', './mocks/verification-service', dockerfile='./mocks/verification-service/Dockerfile')
docker_build('gcsfileproxy-tests', '.', dockerfile='./tests/Dockerfile')

# Kubernetes resources
k8s_yaml([
    './kubernetes/gcs-emulator-pvc.yaml',
    './kubernetes/test-data-configmap.yaml',
    './kubernetes/proxy-deployment.yaml',
    './kubernetes/proxy-service.yaml',
    './kubernetes/verification-deployment.yaml',
    './kubernetes/verification-service.yaml',
    './kubernetes/gcs-emulator-deployment.yaml',
    './kubernetes/gcs-emulator-service.yaml',
    './kubernetes/tests-job.yaml'
])

# Port forwarding
k8s_resource('gcsfileproxy', port_forwards=['3000:3000'])
k8s_resource('verification-service', port_forwards=['8080:8080'])
k8s_resource('gcs-emulator', port_forwards=['4443:4443'])

# Integration tests
k8s_resource(
    'integration-tests',
    resource_deps=['gcsfileproxy', 'verification-service', 'gcs-emulator']
)
