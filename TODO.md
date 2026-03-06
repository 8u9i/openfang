# TODO: Fix Dockerfile.railway for Railway Deployment

## Information Gathered:

- `Dockerfile.railway` is a multi-stage Docker build for deploying OpenFang on Railway
- The main `Dockerfile` works correctly and has good patterns to follow
- `docker-entrypoint.sh` provides config bootstrapping and proper signal handling
- Railway deployment uses `railway.json` for configuration

## Plan: Fix Dockerfile.railway

### Step 1: Update Dockerfile.railway ✅ COMPLETED

- Added syntax directive (`# syntax=docker/dockerfile:1`)
- Added ARG for cache busting (`RUST_CACHE_BUST`, `CACHE_BUST`)
- Added missing runtime dependencies (`wget`, `libssl3`, `libgcc-s1`)
- Added `docker-entrypoint.sh` copy and processing (BOM removal, line ending fix)
- Changed to use `ENTRYPOINT` instead of raw `CMD`
- Fixed health check to use `wget` instead of `curl`
- Added proper `HOME` and `PORT` environment variables
- Changed directory creation to `/data/.openfang` with proper permissions
- Added `apt-get clean` for smaller image size

### Step 2: Verify Changes ✅ COMPLETED

- All patterns match the working main Dockerfile
- Railway health check compatibility verified

## Dependent Files Edited:

- `Dockerfile.railway` - Main file fixed

## Followup Steps:

- No installation/testing needed as this is a configuration file fix
- User should test deployment on Railway after the fix
