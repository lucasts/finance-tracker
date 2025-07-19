# Production Deployment Guide

## Overview

This guide explains how to deploy the Finance Tracker application to production using Docker.

## Prerequisites

- Docker and Docker Compose installed
- PostgreSQL database (can be provided via Docker Compose)
- SSL certificate (recommended for production)

## Environment Variables

Copy `.env.production.example` to `.env` and configure the following required variables:

### Required Variables

```bash
DATABASE_URL=postgresql://username:password@host:port/database_name
SECRET_KEY_BASE=your_secret_key_base_here
RAILS_MASTER_KEY=your_master_key_here
```

### Optional Variables

```bash
PORT=3000                    # Application port (default: 3000)
WEB_CONCURRENCY=2           # Number of Puma workers (default: 1)
RAILS_MAX_THREADS=5         # Number of threads per worker (default: 3)
FORCE_SSL=true              # Force HTTPS (recommended for production)
HOST=your-domain.com        # Your application domain
```

## Generate Required Keys

### Secret Key Base
```bash
bundle exec rails secret
```

### Master Key (if not already generated)
```bash
bundle exec rails credentials:edit
```

## Deployment Options

### Option 1: Using Docker Compose (Recommended)

1. Configure environment variables in `.env` file
2. Run the deployment script:
```bash
./deploy.sh
```

### Option 2: Manual Deployment

1. Build the Docker image:
```bash
docker build -t finance-tracker:latest .
```

2. Run with external database:
```bash
docker run -d \
  --name finance-tracker \
  -p 3000:3000 \
  -e DATABASE_URL="postgresql://user:pass@host:5432/dbname" \
  -e SECRET_KEY_BASE="your_secret_key" \
  -e RAILS_MASTER_KEY="your_master_key" \
  finance-tracker:latest
```

3. Run database migrations:
```bash
docker exec finance-tracker bundle exec rails db:migrate
```

## Health Check

The application provides a health check endpoint at `/up` which can be used for:
- Load balancer health checks
- Container orchestration health probes
- Monitoring systems

## Security Considerations

1. **Use HTTPS**: Set `FORCE_SSL=true` in production
2. **Secure Secrets**: Use secure secret management (e.g., Docker secrets, Kubernetes secrets)
3. **Database Security**: Use strong database passwords and restrict network access
4. **Regular Updates**: Keep dependencies and base images updated

## Monitoring

- Application logs are sent to STDOUT for easy collection
- Health check endpoint: `GET /up`
- Consider implementing external monitoring (Sentry, New Relic, etc.)

## Backup Strategy

1. **Database Backups**: Regular PostgreSQL dumps
2. **File Storage**: Backup the `/storage` directory for uploaded files
3. **Configuration**: Keep environment variables and secrets backed up securely

## Scaling

The application is configured for horizontal scaling:
- Stateless design (session data in database/cache)
- Multiple Puma workers support
- Database connection pooling
- Static assets served efficiently

## Troubleshooting

### Common Issues

1. **Asset Compilation Errors**: Ensure Node.js is available during build
2. **Database Connection**: Verify DATABASE_URL format and database accessibility
3. **Permission Issues**: Check file permissions in Docker container

### Logs

View application logs:
```bash
docker-compose logs app
```

View database logs:
```bash
docker-compose logs db
```

## Maintenance

### Database Migrations
```bash
docker-compose exec app bundle exec rails db:migrate
```

### Console Access
```bash
docker-compose exec app bundle exec rails console
```

### Restart Application
```bash
docker-compose restart app
```
