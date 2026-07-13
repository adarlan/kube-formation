Running a pod with `--image=nginx` is easy.

Let's try with a private image.

```shell

# Create a Buildx builder
# Create a builder that uses the docker-container driver:
docker buildx create --name multiarch --driver docker-container --use
docker buildx inspect --bootstrap

docker login

# Build Awesome App

VERSION=4

IMAGE=docker.io/$DOCKER_USER/awesome-app:v$VERSION

cat <<EOF > awesome-app.Dockerfile
FROM nginx:1.31-alpine
ARG VERSION
RUN cat > /usr/share/nginx/html/index.html <<EOT
<!DOCTYPE html>
<html>
    <head>
        <title>Awesome App</title>
    </head>
    <body>
        <h1>Awesome App</h1>
        <p>Hello! You're using <strong>Awesome App v${VERSION}</strong>.</p>
    </body>
</html>
EOT
EOF

# Build and push a multi-architecture image
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -t $IMAGE \
    -f awesome-app.Dockerfile \
    --build-arg VERSION=$VERSION \
    --push .

# Make repository private
```

Create a Docker Hub access token

On Docker Hub:

Account Settings → Personal access tokens
Create a token with Read access.
Suggested description: kube-formation
Access permissions: Read-only

Use your Docker Hub username and the token (not your password).

<!-- Export yout token to `DOCKER_TOKEN` -->

```shell
kubectl create secret docker-registry dockerhub \
    --docker-server=https://index.docker.io/v1/ \
    --docker-username=$DOCKER_USER \
    --docker-password=$DOCKER_TOKEN

kubectl describe secret dockerhub

cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:
  name: awesome-app
spec:
  imagePullSecrets:
  - name: dockerhub
  containers:
  - name: awesome-app
    image: docker.io/$DOCKER_USER/awesome-app:v$VERSION
    ports:
    - containerPort: 80
EOF

kubectl port-forward pod/awesome-app 8080:80
```

Open the app in your browser: http://localhost:8080

Or: `curl http://localhost:8080`
