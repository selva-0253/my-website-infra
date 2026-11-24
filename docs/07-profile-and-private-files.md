# Profile details, photo and CV

The website code contains **no personal details**. They live in AWS and are
pulled in by the website's deploy workflow:

| What | Where | Visibility |
|---|---|---|
| Name, email, LinkedIn, GitHub, certifications | SSM Parameter Store `/my-website/prod/profile/*` | Shown on the site |
| Photo | `s3://<private bucket>/public/photo.<jpg\|png\|webp>` | Copied into the site at deploy; shown on the About page |
| CV | `s3://<private bucket>/private/cv.pdf` | **Never published.** Visitors pass a Turnstile bot check, then the API returns a link valid for 5 minutes |

The private bucket is `my-website-prod-private-<account id>`. Its name is also in
SSM at `/my-website/prod/private_assets_bucket`.

> Anything displayed on the site is public once deployed. Parameter Store and the
> private bucket keep these details out of git and give you one place to change
> them. The CV additionally has no permanent public URL.

## Who can read what

| Principal | Profile parameters | `public/*` (photo) | `private/cv.pdf` |
|---|---|---|---|
| Website deploy role (GitHub Actions) | read | read | existence check only (list) |
| Engagement Lambda | — | — | read (to sign download links) |
| Anyone else | — | — | — |

The bucket blocks all public access, is encrypted, versioned (old versions kept
90 days) and refuses non-HTTPS requests.

## 1. Set your details

Any parameter you leave out is simply hidden on the site. Use `String`; values
are published on the site anyway (`SecureString` also works).

```bash
P=/my-website/prod/profile
R=ap-south-1

aws ssm put-parameter --region $R --type String --overwrite --name $P/name     --value "Firstname Lastname"
aws ssm put-parameter --region $R --type String --overwrite --name $P/email    --value "you@example.com"
aws ssm put-parameter --region $R --type String --overwrite --name $P/linkedin --value "https://www.linkedin.com/in/your-handle"
aws ssm put-parameter --region $R --type String --overwrite --name $P/github   --value "https://github.com/your-handle"

# Certifications: a JSON list (keep under 4 KB)
aws ssm put-parameter --region $R --type String --overwrite --name $P/certifications --value '[
  {"name": "AWS Certified Solutions Architect – Associate", "issuer": "Amazon Web Services", "year": "2025", "url": "https://www.credly.com/badges/..."}
]'
```

PowerShell: put the JSON in a file and use `--value file://certs.json`.

To remove one: `aws ssm delete-parameter --region $R --name $P/github`.

## 2. Upload your photo and CV

```bash
B=$(aws ssm get-parameter --region ap-south-1 --name /my-website/prod/private_assets_bucket --query Parameter.Value --output text)

# Photo: square, ~600x600, under 200 KB. jpg, png or webp.
aws s3 cp ./photo.jpg "s3://$B/public/photo.jpg" --content-type image/jpeg

# CV: always this exact key
aws s3 cp ./my-cv.pdf "s3://$B/private/cv.pdf" --content-type application/pdf
```

Remove the phone number and home address from the PDF before uploading.

To remove the CV from the site: `aws s3 rm "s3://$B/private/cv.pdf"`, then redeploy.

## 3. Publish

Profile changes are read at deploy time. Re-run the website's **Deploy site**
workflow (Actions > Deploy site > Run workflow), or push to `main`.

- New photo or details: visible after the deploy.
- Replaced CV (same key): visible immediately, no deploy needed.
- First CV upload or CV removed: needs a deploy (the button is shown or hidden at deploy time).

## Settings

In `envs/<env>` (module `engagement`), optional:

| Variable | Default | Meaning |
|---|---|---|
| `cv_download_name` | `CV.pdf` | File name the visitor's browser saves |
| `cv_link_ttl_seconds` | `300` | How long a download link works |

Each download writes `cv link issued` to the Lambda's CloudWatch log.
