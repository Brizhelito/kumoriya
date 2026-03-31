# Cloudflare R2 Credentials Guide (AWS CLI)

This guide explains how to create R2 credentials and configure AWS CLI for automated Kumoriya releases.

## 0. What values you need

Fill these keys in `secrets/r2.credentials.env`:

- `R2_BUCKET_NAME`
- `R2_PUBLIC_BASE_URL`
- `R2_ENDPOINT_URL`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_DEFAULT_REGION` (use `auto`)
- `AWS_PROFILE` (recommended: `kumoriya-r2`)

## 1. Create R2 API Credentials

1. Open Cloudflare Dashboard.
2. Go to R2.
3. Open Manage R2 API Tokens.
4. Click Create API Token.
5. Grant `Object Read` and `Object Write` permissions to your target bucket.
6. Save these values:
   - Access Key ID
   - Secret Access Key
   - Account ID

Where each value comes from:

- Access Key ID / Secret Access Key:
   - Shown once when creating the R2 API token.
- Account ID:
   - Available in Cloudflare dashboard account details.
   - Also used in the endpoint format below.

You will also need:
- Bucket name (for example: `kumoriya-releases`)
- Public base URL (for example: `https://pub-8159019abe1741a097538b976c19722c.r2.dev`)

How to get these:

- Bucket name:
   - Cloudflare Dashboard -> R2 -> Buckets -> your bucket name.
- Public base URL:
   - Cloudflare Dashboard -> R2 -> your bucket -> Public access domain / custom domain.

Construct endpoint value exactly as:

`https://<ACCOUNT_ID>.r2.cloudflarestorage.com`

## 2. Install AWS CLI

On Windows (PowerShell):

```powershell
winget install Amazon.AWSCLI
aws --version
```

## 3. Configure AWS CLI (recommended profile)

Use a dedicated profile for R2:

```powershell
aws configure --profile kumoriya-r2
```

When prompted:
- AWS Access Key ID: use R2 Access Key ID
- AWS Secret Access Key: use R2 Secret Access Key
- Default region name: `auto`
- Default output format: `json`

## 4. Endpoint and environment variables

Set these variables before running the publish script:

```powershell
$env:AWS_PROFILE = "kumoriya-r2"
$env:R2_BUCKET_NAME = "your-bucket-name"
$env:R2_ENDPOINT_URL = "https://<ACCOUNT_ID>.r2.cloudflarestorage.com"
$env:R2_PUBLIC_BASE_URL = "https://pub-8159019abe1741a097538b976c19722c.r2.dev"
```

Or load all values from your local file with:

```powershell
.\scripts\windows\load-r2-credentials.ps1
```

This reads `secrets/r2.credentials.env` and exports values into the current session.

## 5. Validate access

```powershell
aws s3 ls "s3://$env:R2_BUCKET_NAME" --endpoint-url "$env:R2_ENDPOINT_URL" --region auto
```

If this command lists objects (or returns an empty list without auth errors), credentials are working.

Validate public URL + endpoint quickly:

```powershell
Write-Output $env:R2_ENDPOINT_URL
Write-Output $env:R2_PUBLIC_BASE_URL
```

If publish script variables are all present:

```powershell
"R2_BUCKET_NAME=$env:R2_BUCKET_NAME"
"R2_ENDPOINT_URL=$env:R2_ENDPOINT_URL"
"R2_PUBLIC_BASE_URL=$env:R2_PUBLIC_BASE_URL"
"AWS_PROFILE=$env:AWS_PROFILE"
```

## 6. Security notes

- Do not commit Access Key ID or Secret Access Key to git.
- Prefer scoped tokens per environment (dev/staging/prod).
- Rotate credentials periodically.
