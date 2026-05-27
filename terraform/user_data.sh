#!/usr/bin/env bash
set -euxo pipefail

apt-get update
apt-get install -y ca-certificates curl gnupg

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $${VERSION_CODENAME} stable" > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker

docker pull "${docker_image}"
docker stop dynamic-site-container || true
docker rm dynamic-site-container || true
docker run -d --restart unless-stopped \
  --name dynamic-site-container \
  -p 80:80 \
  "${docker_image}"

mkdir -p /opt/monitoring
cat >/opt/monitoring/prometheus.yml <<'PROMETHEUS_CONFIG'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ['prometheus:9090']

  - job_name: node-exporter
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: nginx
    static_configs:
      - targets: ['nginx-exporter:9113']

  - job_name: cadvisor
    static_configs:
      - targets: ['cadvisor:8080']
PROMETHEUS_CONFIG

mkdir -p /opt/monitoring/provisioning/datasources
cat >/opt/monitoring/provisioning/datasources/datasource.yml <<'GRAFANA_DATASOURCE'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
GRAFANA_DATASOURCE

cat >/opt/monitoring/docker-compose.yml <<'COMPOSE'
services:
  prometheus:
    image: prom/prometheus:v2.53.2
    container_name: prometheus
    restart: unless-stopped
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.retention.time=15d
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:11.2.0
    container_name: grafana
    restart: unless-stopped
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: admin
    volumes:
      - grafana-data:/var/lib/grafana
      - ./provisioning:/etc/grafana/provisioning:ro
    ports:
      - "3000:3000"
    depends_on:
      - prometheus

  node-exporter:
    image: prom/node-exporter:v1.8.2
    container_name: node-exporter
    restart: unless-stopped
    command:
      - --path.rootfs=/host
    pid: host
    volumes:
      - /:/host:ro,rslave

  nginx-exporter:
    image: nginx/nginx-prometheus-exporter:1.3.0
    container_name: nginx-exporter
    restart: unless-stopped
    command:
      - -nginx.scrape-uri=http://host.docker.internal/stub_status
    extra_hosts:
      - host.docker.internal:host-gateway
    ports:
      - "9113:9113"

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:v0.49.1
    container_name: cadvisor
    restart: unless-stopped
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    devices:
      - /dev/kmsg
    ports:
      - "8080:8080"

volumes:
  prometheus-data:
  grafana-data:
COMPOSE

docker compose -f /opt/monitoring/docker-compose.yml up -d
