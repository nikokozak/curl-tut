# Deployment Guide for Racket API

## Prerequisites

- DigitalOcean droplet with Ubuntu/Debian
- Caddy installed and running
- Racket installed on the VPS
- Domain/subdomain DNS configured to point to your droplet

## Step 1: Install Racket on VPS

```bash
# On your VPS
sudo apt update
sudo apt install racket
```

## Step 2: Deploy Application Files

```bash
# On your local machine - upload files to VPS
scp -r micro_api root@your-droplet-ip:/var/www/

# On VPS - set proper ownership
sudo chown -R www-data:www-data /var/www/micro_api
sudo chmod 755 /var/www/micro_api
```

## Step 3: Set Up systemd Service

```bash
# On VPS - copy service file
sudo cp /var/www/micro_api/racket-api.service /etc/systemd/system/

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable racket-api.service
sudo systemctl start racket-api.service

# Check status
sudo systemctl status racket-api.service

# View logs
sudo journalctl -u racket-api.service -f
```

## Step 4: Configure Caddy Reverse Proxy

Add this to your Caddyfile (usually `/etc/caddy/Caddyfile`):

```
api.yourdomain.com {
    reverse_proxy localhost:4321

    # Optional: Enable logging
    log {
        output file /var/log/caddy/api.log
    }
}
```

Or if using a subdirectory instead of subdomain:

```
yourdomain.com {
    handle /api/* {
        reverse_proxy localhost:4321
    }
}
```

After editing Caddyfile:

```bash
# Reload Caddy
sudo systemctl reload caddy

# Or restart if reload doesn't work
sudo systemctl restart caddy
```

## Step 5: Verify Deployment

```bash
# Test health endpoint
curl https://api.yourdomain.com/health

# Should return: {"status":"healthy","timestamp":1234567890}
```

## Managing the Service

```bash
# Start service
sudo systemctl start racket-api.service

# Stop service
sudo systemctl stop racket-api.service

# Restart service
sudo systemctl restart racket-api.service

# View logs
sudo journalctl -u racket-api.service -n 50

# Follow logs in real-time
sudo journalctl -u racket-api.service -f
```

## Updating the Application

```bash
# Upload new version
scp server.rkt root@your-droplet-ip:/var/www/micro_api/

# Restart service
sudo systemctl restart racket-api.service
```

## Health Monitoring

The `/health` endpoint returns a 200 OK with the current timestamp when the service is running properly. You can use this with monitoring tools like:

- UptimeRobot
- Pingdom
- Custom monitoring scripts

Example monitoring script:

```bash
#!/bin/bash
if curl -f -s https://api.yourdomain.com/health > /dev/null; then
    echo "API is healthy"
else
    echo "API is down - restarting"
    sudo systemctl restart racket-api.service
fi
```

## Troubleshooting

**Service won't start:**

```bash
# Check logs for errors
sudo journalctl -u racket-api.service -n 100

# Verify Racket is installed
which racket

# Test server manually
cd /var/www/micro_api
racket server.rkt
```

**Port 4321 already in use:**

```bash
# Find what's using the port
sudo lsof -i :4321

# Kill the process if needed
sudo kill <PID>
```

**Permission issues:**

```bash
# Ensure proper ownership
sudo chown -R www-data:www-data /var/www/micro_api
```

**Caddy not forwarding requests:**

```bash
# Check Caddy status
sudo systemctl status caddy

# View Caddy logs
sudo journalctl -u caddy -f

# Test if app is listening
curl localhost:4321
```
