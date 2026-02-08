# Alertmanager Configuration Examples

This document provides ready-to-use Alertmanager configurations for various notification channels.

## Quick Start

The default `alertmanager.yml` logs alerts to console. To enable notifications, copy one of the examples below into your `alertmanager.yml`.

## Table of Contents

1. [Slack Integration](#slack-integration)
2. [Email (Gmail) Integration](#email-gmail-integration)
3. [Email (SMTP) Integration](#email-smtp-integration)
4. [Discord Integration](#discord-integration)
5. [Telegram Integration](#telegram-integration)
6. [PagerDuty Integration](#pagerduty-integration)
7. [Multiple Channels](#multiple-channels-advanced)
8. [Testing Configuration](#testing-your-configuration)

---

## Slack Integration

### Step 1: Create Slack Webhook

1. Go to https://api.slack.com/apps
2. Create new app → From scratch
3. Enable "Incoming Webhooks"
4. Add webhook to workspace
5. Copy webhook URL

### Step 2: Configure Alertmanager

```yaml
global:
  resolve_timeout: 5m
  slack_api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'

route:
  receiver: 'slack-notifications'
  group_by: ['alertname', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  
  routes:
    # Critical alerts - immediate notification
    - match:
        severity: critical
      receiver: 'slack-critical'
      group_wait: 10s
      repeat_interval: 1h
    
    # Warning alerts - batched
    - match:
        severity: warning
      receiver: 'slack-warnings'
      group_wait: 5m
      repeat_interval: 4h

receivers:
  - name: 'slack-notifications'
    slack_configs:
      - channel: '#monitoring'
        title: '{{ .Status | toUpper }}: {{ .CommonLabels.alertname }}'
        text: |
          *Severity:* {{ .CommonLabels.severity }}
          *Summary:* {{ range .Alerts }}{{ .Annotations.summary }}{{ end }}
          *Details:* {{ range .Alerts }}{{ .Annotations.description }}{{ end }}
        send_resolved: true

  - name: 'slack-critical'
    slack_configs:
      - channel: '#alerts-critical'
        username: 'Homelab Alert'
        icon_emoji: ':rotating_light:'
        title: ':fire: CRITICAL ALERT: {{ .CommonLabels.alertname }}'
        text: |
          *Instance:* {{ .CommonLabels.instance }}
          *Description:* {{ range .Alerts }}{{ .Annotations.description }}{{ end }}
          *Runbook:* {{ range .Alerts }}{{ .Annotations.runbook }}{{ end }}
        color: 'danger'
        send_resolved: true

  - name: 'slack-warnings'
    slack_configs:
      - channel: '#monitoring'
        username: 'Homelab Alert'
        icon_emoji: ':warning:'
        title: '⚠️ WARNING: {{ .CommonLabels.alertname }}'
        text: |
          {{ range .Alerts }}
          *Instance:* {{ .Labels.instance }}
          *Summary:* {{ .Annotations.summary }}
          {{ end }}
        color: 'warning'
        send_resolved: true

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
```

**Test with:**
```bash
curl -X POST http://localhost:9093/api/v2/alerts -H "Content-Type: application/json" -d '[
  {
    "labels": {
      "alertname": "TestAlert",
      "severity": "warning",
      "instance": "localhost:9100"
    },
    "annotations": {
      "summary": "This is a test alert",
      "description": "Testing Slack integration"
    }
  }
]'
```

---

## Email (Gmail) Integration

### Step 1: Create Gmail App Password

1. Go to https://myaccount.google.com/security
2. Enable 2-Factor Authentication (required)
3. Go to "App passwords"
4. Generate password for "Mail"
5. Copy the 16-character password

### Step 2: Configure Alertmanager

```yaml
global:
  resolve_timeout: 5m
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'your-homelab@gmail.com'
  smtp_auth_username: 'your-homelab@gmail.com'
  smtp_auth_password: 'your-app-password-here'  # 16-char app password
  smtp_require_tls: true

route:
  receiver: 'email-notifications'
  group_by: ['alertname', 'severity', 'instance']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  
  routes:
    - match:
        severity: critical
      receiver: 'email-critical'
      group_wait: 10s
      repeat_interval: 1h

receivers:
  - name: 'email-notifications'
    email_configs:
      - to: 'your-email@gmail.com'
        send_resolved: true
        headers:
          Subject: '[Homelab] {{ .Status | toUpper }}: {{ .CommonLabels.alertname }}'
        html: |
          <!DOCTYPE html>
          <html>
          <body style="font-family: Arial, sans-serif;">
            <h2 style="color: {{ if eq .Status "firing" }}#d93025{{ else }}#188038{{ end }}">
              {{ .Status | toUpper }}: {{ .CommonLabels.alertname }}
            </h2>
            {{ range .Alerts }}
            <div style="background: #f1f3f4; padding: 15px; margin: 10px 0; border-radius: 5px;">
              <p><strong>Severity:</strong> <span style="color: {{ if eq .Labels.severity "critical" }}#d93025{{ else }}#ea8600{{ end }}">{{ .Labels.severity }}</span></p>
              <p><strong>Instance:</strong> {{ .Labels.instance }}</p>
              <p><strong>Summary:</strong> {{ .Annotations.summary }}</p>
              <p><strong>Description:</strong> {{ .Annotations.description }}</p>
              <p><strong>Started:</strong> {{ .StartsAt.Format "2006-01-02 15:04:05 MST" }}</p>
              {{ if .EndsAt }}
              <p><strong>Ended:</strong> {{ .EndsAt.Format "2006-01-02 15:04:05 MST" }}</p>
              {{ end }}
            </div>
            {{ end }}
            <hr>
            <p style="color: #5f6368; font-size: 12px;">
              This alert was sent from your Homelab monitoring system.
            </p>
          </body>
          </html>

  - name: 'email-critical'
    email_configs:
      - to: 'your-email@gmail.com'
        send_resolved: true
        headers:
          Subject: '[CRITICAL] {{ .CommonLabels.alertname }} - Immediate Action Required'
          Priority: 'urgent'
        html: |
          <!DOCTYPE html>
          <html>
          <body>
            <div style="background: #d93025; color: white; padding: 20px; border-radius: 5px;">
              <h1>🚨 CRITICAL ALERT</h1>
              <h2>{{ .CommonLabels.alertname }}</h2>
            </div>
            {{ range .Alerts }}
            <div style="padding: 20px;">
              <p><strong>Instance:</strong> {{ .Labels.instance }}</p>
              <p><strong>Description:</strong> {{ .Annotations.description }}</p>
              <p><strong>Runbook:</strong> <a href="{{ .Annotations.runbook }}">View response procedure</a></p>
            </div>
            {{ end }}
          </body>
          </html>

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
```

---

## Email (SMTP) Integration

For generic SMTP servers (Mailgun, SendGrid, self-hosted):

```yaml
global:
  resolve_timeout: 5m
  smtp_smarthost: 'smtp.yourdomain.com:587'
  smtp_from: 'alerts@yourdomain.com'
  smtp_auth_username: 'alerts@yourdomain.com'
  smtp_auth_password: 'your-password'
  smtp_require_tls: true
  
  # For self-signed certificates
  # smtp_require_tls: false

route:
  receiver: 'email-default'
  group_by: ['alertname', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

receivers:
  - name: 'email-default'
    email_configs:
      - to: 'admin@yourdomain.com'
        send_resolved: true
        headers:
          Subject: '[Homelab Alert] {{ .CommonLabels.alertname }}'
        text: |
          Status: {{ .Status }}
          Alert: {{ .CommonLabels.alertname }}
          Severity: {{ .CommonLabels.severity }}
          
          Details:
          {{ range .Alerts }}
          - Instance: {{ .Labels.instance }}
          - Summary: {{ .Annotations.summary }}
          - Description: {{ .Annotations.description }}
          - Started: {{ .StartsAt.Format "2006-01-02 15:04:05" }}
          {{ end }}
```

---

## Discord Integration

### Step 1: Create Discord Webhook

1. Open Discord server settings
2. Go to Integrations → Webhooks
3. Create webhook
4. Copy webhook URL

### Step 2: Configure Alertmanager

```yaml
global:
  resolve_timeout: 5m

route:
  receiver: 'discord-notifications'
  group_by: ['alertname', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

receivers:
  - name: 'discord-notifications'
    webhook_configs:
      - url: 'https://discord.com/api/webhooks/YOUR_WEBHOOK_URL'
        send_resolved: true
        max_alerts: 10
        # Discord uses webhook format, we send as JSON
        http_config:
          follow_redirects: true

# Note: Discord requires custom webhook format
# Consider using alertmanager-discord bridge:
# https://github.com/benjojo/alertmanager-discord
```

**Better approach - Use alertmanager-discord bridge:**

Add to your `compose.yaml`:
```yaml
  alertmanager-discord:
    image: benjojo/alertmanager-discord
    environment:
      - DISCORD_WEBHOOK=https://discord.com/api/webhooks/YOUR_WEBHOOK_URL
    ports:
      - "9094:9094"
```

Then configure Alertmanager webhook:
```yaml
receivers:
  - name: 'discord-notifications'
    webhook_configs:
      - url: 'http://alertmanager-discord:9094/webhook'
```

---

## Telegram Integration

### Step 1: Create Telegram Bot

1. Message @BotFather on Telegram
2. Create new bot: `/newbot`
3. Copy bot token
4. Get chat ID: Message your bot, then visit:
   ```
   https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates
   ```

### Step 2: Configure Alertmanager

```yaml
global:
  resolve_timeout: 5m

route:
  receiver: 'telegram-notifications'
  group_by: ['alertname', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  
  routes:
    - match:
        severity: critical
      receiver: 'telegram-critical'
      group_wait: 10s

receivers:
  - name: 'telegram-notifications'
    webhook_configs:
      - url: 'https://api.telegram.org/bot<YOUR_BOT_TOKEN>/sendMessage'
        send_resolved: true
        http_config:
          follow_redirects: true

  - name: 'telegram-critical'
    webhook_configs:
      - url: 'https://api.telegram.org/bot<YOUR_BOT_TOKEN>/sendMessage'
        send_resolved: true
```

**Better approach - Use alertmanager-telegram bridge:**
```yaml
  alertmanager-telegram:
    image: metalmatze/alertmanager-bot:latest
    environment:
      - TELEGRAM_TOKEN=your-bot-token
      - TELEGRAM_ADMIN=your-chat-id
      - STORE=bolt
      - BOLT_PATH=/data/bot.db
    volumes:
      - /srv/data/observability/telegram:/data
    ports:
      - "8080:8080"
```

---

## PagerDuty Integration

### Step 1: Get PagerDuty Integration Key

1. Log into PagerDuty
2. Go to Services → Your Service
3. Integrations → Add Integration
4. Select "Prometheus"
5. Copy Integration Key

### Step 2: Configure Alertmanager

```yaml
global:
  resolve_timeout: 5m
  pagerduty_url: 'https://events.pagerduty.com/v2/enqueue'

route:
  receiver: 'pagerduty-critical'
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 5m
  repeat_interval: 4h
  
  routes:
    # Only page for critical alerts
    - match:
        severity: critical
      receiver: 'pagerduty-critical'
    
    # Warnings go to Slack/email instead
    - match:
        severity: warning
      receiver: 'slack-warnings'

receivers:
  - name: 'pagerduty-critical'
    pagerduty_configs:
      - service_key: 'YOUR_INTEGRATION_KEY'
        severity: 'critical'
        details:
          instance: '{{ .CommonLabels.instance }}'
          summary: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
          description: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
        links:
          - href: '{{ range .Alerts }}{{ .Annotations.runbook }}{{ end }}'
            text: 'Runbook'

  - name: 'slack-warnings'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#monitoring'
```

---

## Multiple Channels (Advanced)

Route different alert types to different channels:

```yaml
global:
  resolve_timeout: 5m
  
  # Email config
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'homelab@gmail.com'
  smtp_auth_username: 'homelab@gmail.com'
  smtp_auth_password: 'your-app-password'
  smtp_require_tls: true
  
  # Slack config
  slack_api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'

route:
  receiver: 'default'
  group_by: ['alertname', 'severity', 'instance']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  
  routes:
    # Critical system alerts → PagerDuty + Email
    - match_re:
        alertname: '(NodeDown|ServiceCritical|DiskFull)'
        severity: critical
      receiver: 'pagerduty-and-email'
      group_wait: 10s
      repeat_interval: 1h
    
    # Security alerts → Slack security channel
    - match_re:
        alertname: '(SSHBruteForce|PrivilegeEscalation|UnauthorizedAccess)'
      receiver: 'slack-security'
      group_wait: 30s
    
    # Docker issues → Slack devops channel
    - match_re:
        alertname: 'Docker.*'
      receiver: 'slack-devops'
    
    # Everything else → Email
    - match:
        severity: warning
      receiver: 'email-warnings'

receivers:
  - name: 'default'
    slack_configs:
      - channel: '#monitoring'
        title: '{{ .CommonLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'

  - name: 'pagerduty-and-email'
    pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_KEY'
    email_configs:
      - to: 'admin@example.com'
        headers:
          Subject: '[CRITICAL] {{ .CommonLabels.alertname }}'

  - name: 'slack-security'
    slack_configs:
      - channel: '#security-alerts'
        username: 'Security Bot'
        icon_emoji: ':shield:'
        color: 'danger'
        title: '🔒 Security Alert: {{ .CommonLabels.alertname }}'

  - name: 'slack-devops'
    slack_configs:
      - channel: '#devops'
        username: 'Docker Monitor'
        icon_emoji: ':docker:'

  - name: 'email-warnings'
    email_configs:
      - to: 'team@example.com'

inhibit_rules:
  # Don't page for warnings if critical is already firing
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
  
  # Don't send resolved if still firing
  - source_match:
      alertname: '.*'
    target_match_re:
      alertname: '.*Resolved'
    equal: ['instance']
```

---

## Testing Your Configuration

### 1. Validate Configuration Syntax

```bash
# Using docker
docker run --rm \
  -v $(pwd)/alertmanager.yml:/tmp/alertmanager.yml:ro \
  prom/alertmanager:latest \
  amtool check-config /tmp/alertmanager.yml

# Should output: Checking '/tmp/alertmanager.yml'  SUCCESS
```

### 2. Send Test Alert

```bash
# Send a test warning alert
curl -X POST http://localhost:9093/api/v2/alerts -H "Content-Type: application/json" -d '[
  {
    "labels": {
      "alertname": "TestAlert",
      "severity": "warning",
      "instance": "test-instance:9100",
      "job": "test"
    },
    "annotations": {
      "summary": "This is a test alert to verify notification delivery",
      "description": "If you received this, your alerting configuration is working correctly!",
      "runbook": "https://github.com/your-repo/runbooks/test.md"
    },
    "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "endsAt": "'$(date -u -d '+5 minutes' +%Y-%m-%dT%H:%M:%SZ)'"
  }
]'
```

### 3. Send Test Critical Alert

```bash
curl -X POST http://localhost:9093/api/v2/alerts -H "Content-Type: application/json" -d '[
  {
    "labels": {
      "alertname": "TestCriticalAlert",
      "severity": "critical",
      "instance": "test-instance:9100"
    },
    "annotations": {
      "summary": "CRITICAL test alert",
      "description": "This tests your critical alert routing and notification"
    }
  }
]'
```

### 4. Check Alert Received

```bash
# View alerts in Alertmanager
curl -s http://localhost:9093/api/v2/alerts | jq '.[] | {name: .labels.alertname, status: .status.state}'

# Check Alertmanager logs
docker logs observability-alertmanager-1 --tail 50
```

### 5. Silence Test Alerts

```bash
# Get silence ID
SILENCE_ID=$(curl -s http://localhost:9093/api/v2/silences -H "Content-Type: application/json" -d '{
  "matchers": [
    {
      "name": "alertname",
      "value": "TestAlert",
      "isRegex": false
    }
  ],
  "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "endsAt": "'$(date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%SZ)'",
  "createdBy": "admin",
  "comment": "Silencing test alert"
}' | jq -r '.silenceID')

echo "Created silence: $SILENCE_ID"
```

---

## Troubleshooting

### Alerts not sending

```bash
# Check Alertmanager logs
docker logs observability-alertmanager-1 --tail 100

# Check Alertmanager status
curl http://localhost:9093/api/v2/status | jq

# Verify configuration loaded
curl http://localhost:9093/api/v2/status | jq .config
```

### Email not working (Gmail)

- Verify 2FA is enabled on Gmail account
- Use App Password (not your regular password)
- Check for "blocked sign-in attempt" emails from Google
- Verify `smtp_require_tls: true` is set

### Slack not working

- Verify webhook URL is correct (should start with `https://hooks.slack.com/services/`)
- Check Slack app is installed in workspace
- Test webhook directly:
  ```bash
  curl -X POST -H 'Content-type: application/json' \
    --data '{"text":"Test message"}' \
    YOUR_WEBHOOK_URL
  ```

### Too many notifications

Add silences for noisy alerts:
```bash
# Silence for 4 hours
curl -X POST http://localhost:9093/api/v2/silences -H "Content-Type: application/json" -d '{
  "matchers": [{
    "name": "alertname",
    "value": "NoisyAlert",
    "isRegex": false
  }],
  "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "endsAt": "'$(date -u -d '+4 hours' +%Y-%m-%dT%H:%M:%SZ)'",
  "createdBy": "admin",
  "comment": "Temporarily silencing noisy alert"
}'
```

---

## Best Practices

1. **Start Simple** - Begin with one channel (email or Slack), then add more
2. **Test Thoroughly** - Send test alerts before relying on notifications
3. **Route by Severity** - Critical alerts should page, warnings can wait
4. **Use Inhibition Rules** - Prevent alert storms
5. **Document Runbooks** - Link to response procedures in alerts
6. **Regular Testing** - Test notification delivery weekly
7. **Monitor Alertmanager** - Watch for delivery failures
8. **Secure Credentials** - Use secrets management for API keys/passwords

---

## References

- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/configuration/)
- [Notification Template Examples](https://prometheus.io/docs/alerting/latest/notification_examples/)
- [amtool CLI](https://github.com/prometheus/alertmanager#amtool)
