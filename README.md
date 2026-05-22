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

## Terraform Deploy

Create an AWS EC2 key pair named `dynamic-site-key`, then run:

```bash
cd terraform
terraform init
terraform apply -var="your_ip=YOUR_PUBLIC_IP/32"
```

Terraform outputs:

- `website_url`
- `grafana_url`
- `prometheus_url`

## Jenkins Credentials

Create these Jenkins credentials:

| Credential ID | Type | Value |
| --- | --- | --- |
| `DOCKERHUB_CREDENTIALS` | Username with password | Docker Hub username and access token |
| `EC2_HOST` | Secret text | EC2 Elastic IP |
| `EC2_USER` | Secret text | `ubuntu` |
| `EC2_SSH_KEY` | SSH username with private key | Private key from `dynamic-site-key.pem` |
| `AWS_ACCESS_KEY_ID` | Secret text | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Secret text | AWS secret key |

## Jenkins Pipeline

Set the pipeline parameters:

- `DOCKER_IMAGE`: your Docker Hub image, for example `yourname/dynamic-site`
- `YOUR_IP_CIDR`: your public IP, for example `49.36.55.12/32`
- `APPLY_TERRAFORM`: enable for the first run or when you want to force infrastructure deployment

The pipeline builds the Docker image, pushes it to Docker Hub, applies Terraform when needed, then deploys the website container to EC2.

## Grafana

Open `http://YOUR_EC2_IP:3000`.

Default login:

- Username: `admin`
- Password: `admin`

Import dashboards:

- Node Exporter Full: `1860`
- Nginx dashboard: `12708`

Use Prometheus as the data source: `http://prometheus:9090`.
