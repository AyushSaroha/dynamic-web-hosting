# Dynamic Web Hosting DevOps Project

This project deploys a static website with a complete DevOps workflow:

- Docker runs the website on Nginx.
- Terraform creates an AWS EC2 server, security group, and Elastic IP.
- Jenkins builds and pushes the Docker image, applies infrastructure changes, and deploys to EC2.
- Prometheus and Grafana monitor server and Nginx metrics.
- GitHub webhooks trigger the Jenkins pipeline automatically after every push.

## Project Structure

```text
app/                 Static website files
terraform/           AWS EC2 infrastructure
monitoring/          Prometheus scrape configuration
Dockerfile           Production Nginx image
nginx.conf           Nginx site config with stub_status metrics endpoint
Jenkinsfile          CI/CD pipeline
```

## Local Docker Test

```bash
docker build -t dynamic-site .
docker run -d --name dynamic-site -p 8081:80 dynamic-site
```

Open `http://localhost:8081`.

## Upload to a New GitHub Repo

Create an empty GitHub repository, then connect this local folder to it:

```bash
git remote add origin https://github.com/YOUR_USER/YOUR_REPO.git
git branch -M main
git add .
git commit -m "updated devops dynamic website"
git push -u origin main
```

If `origin` already exists, update it instead:

```bash
git remote set-url origin https://github.com/YOUR_USER/YOUR_REPO.git
git push -u origin main
```

## Terraform to EC2 Container Flow

Terraform creates the AWS EC2 key pair from an SSH public key. For local runs, make sure `~/.ssh/id_rsa.pub` exists, or pass `public_key_path` with the path to your public key. Jenkins derives this public key automatically from the `EC2_KEY` private-key credential before running Terraform.

```bash
cd terraform
terraform init
terraform validate
terraform apply -auto-approve \
  -var="your_ip=YOUR_PUBLIC_IP/32" \
  -var="public_key_path=PATH_TO_PUBLIC_KEY.pub" \
  -var="docker_image=YOUR_DOCKERHUB_USER/dynamic-site:latest"
```

Terraform outputs:

- `website_url`
- `grafana_url`
- `prometheus_url`

Terraform creates the key pair, EC2 server, security group, and Elastic IP. The EC2 `user_data.sh` installs Docker, starts the website container on port `80`, and starts the monitoring containers. Jenkins then uses `terraform output -raw ec2_public_ip`, connects with SSH, pulls the latest Docker image, removes the old website container, and starts the new one on port `80`.

## Terraform Structure

```text
terraform/
  main.tf          Provider and Terraform requirements
  variables.tf     Inputs for region, key, IP, instance type, and Docker image
  key.tf           AWS key pair creation
  security.tf      SSH, HTTP, Grafana, and Prometheus security group
  ec2.tf           EC2 instance, Elastic IP, and app bootstrap
  outputs.tf       Website, Grafana, Prometheus, and EC2 IP outputs
  user_data.sh     Docker, app container, Prometheus, and Grafana startup
```

## Jenkins Credentials

Create these Jenkins credentials:

| Credential ID | Type | Value |
| --- | --- | --- |
| `DOCKERHUB_CREDENTIALS` | Username with password | Docker Hub username and access token |
| `EC2_KEY` | Secret file | Private key matching the public key passed to Terraform |
| `AWS_ACCESS_KEY_ID` | Secret text | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Secret text | AWS secret key |

## Jenkins Pipeline

Set the pipeline parameters:

- `DOCKER_IMAGE`: your Docker Hub image, for example `yourname/dynamic-site`
- `YOUR_IP_CIDR`: your public IP, for example `49.36.55.12/32`
- `APPLY_TERRAFORM`: enable for the first run or when you want to force infrastructure deployment

The pipeline builds the Docker image, pushes it to Docker Hub, applies Terraform when needed, then deploys the website container to EC2.

## Auto Trigger from GitHub

1. Install the Jenkins GitHub plugin if it is not already installed.
2. Create a Jenkins Pipeline job pointing to this GitHub repo.
3. In GitHub, open `Settings > Webhooks > Add webhook`.
4. Payload URL: `http://YOUR_JENKINS_URL/github-webhook/`
5. Content type: `application/json`
6. Events: choose `Just the push event`.
7. Save the webhook.

The `Jenkinsfile` includes `githubPush()`, so every push to GitHub can automatically run the build, push the Docker image, apply Terraform when needed, and refresh the EC2 container.

## Manual EC2 Container Refresh

Use this only when you want to deploy without Jenkins:

```bash
cd terraform
EC2_IP=$(terraform output -raw ec2_public_ip)
ssh -i /path/to/dynamic-site-key.pem ubuntu@$EC2_IP
sudo docker pull YOUR_DOCKERHUB_USER/dynamic-site:latest
sudo docker stop dynamic-site-container || true
sudo docker rm dynamic-site-container || true
sudo docker run -d --restart unless-stopped --name dynamic-site-container -p 80:80 YOUR_DOCKERHUB_USER/dynamic-site:latest
```

## Grafana

Open `http://YOUR_EC2_IP:3000`.

Default login:

- Username: `admin`
- Password: `admin`

Import dashboards:

- Node Exporter Full: `1860`
- Nginx dashboard: `12708`

Use Prometheus as the data source: `http://prometheus:9090`.
