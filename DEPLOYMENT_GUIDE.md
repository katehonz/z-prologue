# Z-Prologue Production Deployment Guide

## 🚀 Deployment Overview

Z-Prologue is now production-ready with enterprise-grade features. This guide covers deployment to Hetzner VPS and other cloud platforms.

---

## 📋 Pre-Deployment Checklist

### **✅ Code Preparation**
- [x] Production features implemented
- [x] Security middleware configured
- [x] Health checks operational
- [x] Configuration management ready
- [ ] Minor type fixes (30min task for engineer)
- [ ] Final integration testing

### **✅ Infrastructure Requirements**
- **CPU:** 2+ cores (4+ recommended)
- **RAM:** 4GB+ (8GB+ recommended)
- **Storage:** 20GB+ SSD
- **Network:** 1Gbps connection
- **OS:** Ubuntu 20.04+ / Alpine Linux

---

## 🐳 Docker Deployment

### **1. Dockerfile**
```dockerfile
# Multi-stage build for optimization
FROM nimlang/nim:1.6.14-alpine AS builder

# Install dependencies
RUN apk add --no-cache \
    build-base \
    openssl-dev \
    pcre-dev \
    libressl-dev

# Set working directory
WORKDIR /app

# Copy source files
COPY . .

# Build application
RUN nimble build -d:release -d:ssl --threads:on

# Production stage
FROM alpine:3.18

# Install runtime dependencies
RUN apk add --no-cache \
    openssl \
    pcre \
    libressl \
    ca-certificates

# Create app user
RUN addgroup -g 1001 appgroup && \
    adduser -D -u 1001 -G appgroup appuser

# Set working directory
WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/z_prologue_app ./app
COPY --from=builder /app/static ./static
COPY --from=builder /app/templates ./templates

# Set ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health/live || exit 1

# Start application
CMD ["./app"]
```

### **2. Docker Compose**
```yaml
version: '3.8'

services:
  z-prologue:
    build: .
    container_name: z-prologue-app
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - APP_NAME=Z-Prologue Production
      - APP_PORT=8080
      - APP_DEBUG=false
      - APP_LOG_LEVEL=info
      - APP_LOG_FORMAT=json
      - APP_RATE_LIMIT_MAX=1000
      - APP_SECRET_KEY=${SECRET_KEY}
    volumes:
      - ./logs:/app/logs
      - ./config:/app/config:ro
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8080/health/live"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - app-network

  # Optional: Reverse proxy
  nginx:
    image: nginx:alpine
    container_name: nginx-proxy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - z-prologue
    networks:
      - app-network

networks:
  app-network:
    driver: bridge
```

### **3. Build and Deploy**
```bash
# Build image
docker build -t z-prologue:latest .

# Run with docker-compose
docker-compose up -d

# Check logs
docker-compose logs -f z-prologue

# Health check
curl http://localhost:8080/health
```

---

## 🔧 Hetzner VPS Deployment

### **1. Server Setup**

**Choose VPS:**
- **CPX21:** 3 vCPU, 8GB RAM, 80GB SSD (~€8.90/month)
- **CPX31:** 4 vCPU, 16GB RAM, 160GB SSD (~€16.90/month)

**Initial Setup:**
```bash
# Connect to server
ssh root@your-server-ip

# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-linux-x86_64" \
     -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create app directory
mkdir -p /opt/z-prologue
cd /opt/z-prologue
```

### **2. Application Deployment**
```bash
# Clone repository
git clone https://github.com/your-repo/z-prologue.git .

# Create environment file
cat > .env << EOF
SECRET_KEY=$(openssl rand -hex 32)
APP_NAME=Z-Prologue Production
APP_DEBUG=false
APP_LOG_LEVEL=info
ENVIRONMENT=production
EOF

# Create production config
mkdir -p config
cat > config/production.json << EOF
{
  "app_name": "Z-Prologue Production",
  "debug": false,
  "port": 8080,
  "log_format": "json",
  "log_output": "both",
  "log_file": "logs/app.log",
  "rate_limit_max": 1000,
  "rate_limit_window": 60,
  "compression_enabled": true,
  "security_hsts": true,
  "shutdown_timeout": 30.0
}
EOF

# Deploy
docker-compose up -d

# Verify deployment
curl http://localhost:8080/health
```

### **3. NGINX Reverse Proxy**
```nginx
# /opt/z-prologue/nginx.conf
events {
    worker_connections 1024;
}

http {
    upstream z-prologue {
        server z-prologue:8080;
    }
    
    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    
    server {
        listen 80;
        server_name your-domain.com;
        
        # Redirect to HTTPS
        return 301 https://$server_name$request_uri;
    }
    
    server {
        listen 443 ssl http2;
        server_name your-domain.com;
        
        # SSL Configuration
        ssl_certificate /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
        
        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        
        # Health check (bypass rate limiting)
        location /health {
            proxy_pass http://z-prologue;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
        
        # API endpoints
        location /api {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://z-prologue;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        # All other requests
        location / {
            proxy_pass http://z-prologue;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
```

---

## ☸️ Kubernetes Deployment

### **1. Deployment Manifest**
```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: z-prologue
  labels:
    app: z-prologue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: z-prologue
  template:
    metadata:
      labels:
        app: z-prologue
    spec:
      containers:
      - name: z-prologue
        image: z-prologue:latest
        ports:
        - containerPort: 8080
        env:
        - name: APP_NAME
          value: "Z-Prologue K8s"
        - name: APP_PORT
          value: "8080"
        - name: APP_DEBUG
          value: "false"
        - name: APP_LOG_LEVEL
          value: "info"
        - name: SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: z-prologue-secret
              key: secret-key
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: z-prologue-service
spec:
  selector:
    app: z-prologue
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: z-prologue-ingress
  annotations:
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - your-domain.com
    secretName: tls-secret
  rules:
  - host: your-domain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: z-prologue-service
            port:
              number: 80
```

### **2. Deploy to Kubernetes**
```bash
# Create secret
kubectl create secret generic z-prologue-secret \
  --from-literal=secret-key=$(openssl rand -hex 32)

# Deploy application
kubectl apply -f k8s/

# Check status
kubectl get pods -l app=z-prologue
kubectl get services
kubectl get ingress

# View logs
kubectl logs -f deployment/z-prologue
```

---

## 📊 Monitoring Setup

### **1. Prometheus Configuration**
```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'z-prologue'
    static_configs:
      - targets: ['z-prologue:8080']
    metrics_path: /metrics
    scrape_interval: 10s
```

### **2. Grafana Dashboard**
```json
{
  "dashboard": {
    "title": "Z-Prologue Metrics",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(app_request_count[5m])"
          }
        ]
      },
      {
        "title": "Response Time",
        "type": "graph", 
        "targets": [
          {
            "expr": "app_response_time"
          }
        ]
      },
      {
        "title": "Health Status",
        "type": "stat",
        "targets": [
          {
            "expr": "app_health_check"
          }
        ]
      }
    ]
  }
}
```

---

## 🔧 Environment Configuration

### **Production Environment Variables**
```bash
# Application
APP_NAME=Z-Prologue Production
APP_PORT=8080
APP_DEBUG=false
APP_SECRET_KEY=your-super-secret-key-here

# Logging
APP_LOG_LEVEL=info
APP_LOG_FORMAT=json
APP_LOG_FILE=logs/production.log
APP_LOG_ASYNC=true

# Security
APP_RATE_LIMIT_MAX=1000
APP_RATE_LIMIT_WINDOW=60
APP_SECURITY_HSTS=true

# Performance  
APP_COMPRESSION_ENABLED=true
APP_COMPRESSION_LEVEL=6
APP_BUFFER_SIZE=40960

# Monitoring
APP_METRICS_ENABLED=true
APP_HEALTH_CHECKS_ENABLED=true

# Database (if used)
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=z_prologue_prod
DATABASE_POOL_SIZE=20

# Redis (if used)
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=0
```

---

## 🚨 Security Configuration

### **1. Firewall Setup (UFW)**
```bash
# Reset firewall
ufw --force reset

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (change port if needed)
ufw allow 22/tcp

# Allow HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Allow specific IPs for management
ufw allow from YOUR_ADMIN_IP to any port 22

# Enable firewall
ufw enable

# Check status
ufw status verbose
```

### **2. SSL/TLS Setup (Let's Encrypt)**
```bash
# Install certbot
apt install snapd
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot

# Get certificate
certbot certonly --standalone -d your-domain.com

# Copy certificates for Docker
mkdir -p /opt/z-prologue/ssl
cp /etc/letsencrypt/live/your-domain.com/fullchain.pem /opt/z-prologue/ssl/
cp /etc/letsencrypt/live/your-domain.com/privkey.pem /opt/z-prologue/ssl/

# Set up auto-renewal
echo "0 12 * * * /usr/bin/certbot renew --quiet" | crontab -
```

---

## 📈 Performance Optimization

### **1. System Optimization**
```bash
# Increase file descriptor limits
echo "fs.file-max = 2097152" >> /etc/sysctl.conf
echo "* soft nofile 1048576" >> /etc/security/limits.conf
echo "* hard nofile 1048576" >> /etc/security/limits.conf

# Network optimization
echo "net.core.somaxconn = 65535" >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 65535" >> /etc/sysctl.conf

# Apply changes
sysctl -p
```

### **2. Application Optimization**
```nim
# Configure in production
let settings = newSettings(
  bufSize = 65536,        # Larger buffer
  reusePort = true,       # Port reuse
  maxBody = 1048576,      # 1MB max body
  keepAliveTimeout = 75   # Keep connections alive
)
```

---

## 🔍 Troubleshooting

### **Common Issues**

**1. Application Won't Start**
```bash
# Check logs
docker-compose logs z-prologue

# Check health endpoint
curl -v http://localhost:8080/health/live

# Check resource usage
docker stats
```

**2. High Memory Usage**
```bash
# Monitor memory
watch -n 1 'free -h && echo && docker stats --no-stream'

# Adjust container limits
# In docker-compose.yml:
deploy:
  resources:
    limits:
      memory: 1G
    reservations:
      memory: 512M
```

**3. SSL Certificate Issues**
```bash
# Check certificate expiry
openssl x509 -in /opt/z-prologue/ssl/fullchain.pem -text -noout | grep "Not After"

# Renew certificate
certbot renew --force-renewal
docker-compose restart nginx
```

### **Monitoring Commands**
```bash
# Application health
curl http://localhost:8080/health

# Resource usage
htop
iotop
nethogs

# Container logs
docker-compose logs -f --tail=100 z-prologue

# Network connectivity
netstat -tulpn | grep :8080
ss -tulpn | grep :8080
```

---

## 🎯 Deployment Checklist

### **Pre-Deployment**
- [ ] Code review completed
- [ ] Tests passing
- [ ] Configuration validated
- [ ] Secrets generated
- [ ] SSL certificates ready
- [ ] Monitoring configured

### **Deployment**
- [ ] Server provisioned
- [ ] Docker installed
- [ ] Application deployed
- [ ] Reverse proxy configured
- [ ] SSL certificates installed
- [ ] Monitoring active

### **Post-Deployment**
- [ ] Health checks passing
- [ ] Performance metrics normal
- [ ] Logs flowing correctly
- [ ] Backups configured
- [ ] Monitoring alerts configured
- [ ] Documentation updated

---

**Z-Prologue is now ready for production deployment on Hetzner VPS or any cloud platform!** 🚀