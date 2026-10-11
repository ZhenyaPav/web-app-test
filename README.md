# Web app test

A simple HTML page served by Nginx, built with GitHub Actions and deployed to
k3s through Argo CD. Cloudflared exposes the application through a Quick Tunnel.

## Deployment flow

1. Pull requests build and test the container.
2. App/build changes pushed to `main` build, test, and publish an image to
   `ghcr.io/zhenyapav/web-app-test`.
3. The workflow commits the image digest to `deploy/deployment.yaml`.
4. Argo CD watches `main:deploy/` and deploys both Nginx and cloudflared in the
   `web-app-test` namespace. Self-healing is enabled; automatic pruning is disabled.
5. Cloudflared forwards the public hostname to the application's ClusterIP Service.

Deployment and documentation changes do not rebuild the image. Image digests pin
exact content; `/version.txt` identifies the source commit. Older builds are skipped
when a newer source change exists. Actions needs no Kubernetes credentials.

## Local check

Requires Docker, Python 3, Bash, and curl. Commands run from the repository root.

```sh
python3 scripts/check.py
./scripts/build.sh
docker run --rm --read-only --tmpfs /tmp -p 127.0.0.1:8080:8080 web-app-test:local
```

Open http://localhost:8080. Stop the container with Ctrl-C.

## Setup

Requires an existing k3s cluster with Argo CD installed, and kubectl configured for
that cluster. Hosted CI builds Linux/amd64 images. The Quick Tunnel needs no
Cloudflare account, domain, or token.

1. Push the repository to `main` and wait for the first Actions run to publish
   an image and commit its digest. Do not deploy the initial `:bootstrap` placeholder.
2. Make the `web-app-test` GHCR package public in its GitHub package settings.
   The repository being public does not automatically make the package public.
   The workflow uses `GITHUB_TOKEN` with contents/package write permissions; branch
   rules must permit its deployment commit to `main`.
3. Create the namespace and register the Argo project and application:

   ```sh
   kubectl apply -f namespaces.yaml
   kubectl apply -f argocd/
   ```

   The project permits this repository's Deployments and Services only in
   `web-app-test`. In the Argo UI, wait for the application to become Synced and Healthy.
4. Once Argo has synced both Deployments, read the generated HTTPS URL from the logs:

   ```sh
   kubectl -n web-app-test rollout status deployment/cloudflared --timeout=180s
   kubectl -n web-app-test logs deployment/cloudflared
   ```

Open the `https://...trycloudflare.com` URL printed in the logs. Cloudflared routes
directly to the Service. Browser HTTPS terminates at Cloudflare; the connector-to-Service
hop uses HTTP. Argo manages both Deployments through the same Application.
Quick Tunnels are temporary: the hostname changes when the connector is recreated.
Normal app rollouts leave the connector running and preserve its current URL.

Optionally set the GitHub Actions repository variable `APP_URL` to the public HTTPS
URL. CI then waits for its source commit at `/version.txt`; without that variable,
a successful run confirms image publication and Git promotion only. The supplied
check expects an anonymously accessible URL. Update `APP_URL` if the tunnel restarts
and generates a new hostname.

## Scripts

The scripts keep pipeline operations runnable locally and keep the workflow short.
Argo CD itself does not require this directory, but this workflow uses every script.

| Script | Purpose |
| --- | --- |
| `build.sh` | Build and test the running container's HTML, health, version, and 404 response. |
| `promote.sh` | Commit the image digest to Git, reject stale builds, and retry concurrent pushes. CI only. |
| `set-image.py` | Update exactly one image reference and reject malformed digests. |
| `check.py` | Check invalid input, ambiguous manifests, and repeated image updates. |
| `wait-for-version.sh` | Verify the public deployment when `APP_URL` is configured. |

After each promotion, pull the bot's commit before making the next local change:
`git pull --ff-only`. To roll back an image, revert its deployment commit and let
Argo reconcile. Container logs are available with
`kubectl -n web-app-test logs deployment/web-app-test`.
