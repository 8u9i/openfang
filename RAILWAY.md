# OpenFang on Railway - Deployment Guide

This guide explains how to deploy OpenFang Agent OS on Railway.

## Quick Deploy

Click the button below to deploy to Railway:

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/new?template=https://github.com/RightNow-AI/openfang)

## Manual Deployment

### 1. Fork this repository

Fork [RightNow-AI/openfang](https://github.com/RightNow-AI/openfang) to your GitHub account.

### 2. Create a Railway project

1. Go to [Railway.app](https://railway.app) and create a new project
2. Select "Deploy from GitHub repo"
3. Choose your forked repository
4. Railway will automatically detect the `railway.json` configuration

### 3. Deploy

The app will build and deploy automatically. No environment variables are required for initial deployment.

## Configuration

### API Keys (Optional at Start)

The app will start without API keys. Configure them through the dashboard after deployment:

1. Open your Railway deployment URL
2. Go to Settings/Configuration in the dashboard
3. Add your API keys:
   - `ANTHROPIC_API_KEY` - Anthropic (Claude)
   - `OPENAI_API_KEY` - OpenAI (GPT-4)
   - `GROQ_API_KEY` - Groq
   - `TELEGRAM_BOT_TOKEN` - Telegram
   - `DISCORD_BOT_TOKEN` - Discord
   - `SLACK_BOT_TOKEN` - Slack

### Port

The app runs on port `4200` (configured in `railway.json`).

## Accessing the Dashboard

After deployment, access the dashboard at:

```
https://<your-railway-project>.railway.app/
```

## Data Persistence

Data is stored in the `/data` volume, which is persisted by Railway's filesystem.

## Troubleshooting

### Health Check Failures

If health checks fail initially, wait a minute for the build to complete. The first deployment may take 5-10 minutes.

### API Key Errors

If you see errors about missing API keys, that's normal until you configure them in the dashboard or environment variables.

### Build Failures

If the build fails, ensure you have sufficient Railway plan resources. The build requires ~4GB RAM.
