# Voidcrew Wiki

A static wiki for the Voidcrew server, built from markdown into plain HTML.
No server-side anything: host it on S3, GitHub Pages, or any file host.

## Layout

```
wiki/
  content/        one .md file per page (frontmatter: title/category/order/blurb)
  assets/         style.css, wiki.js, images/
  tools/vendor/   vendored python-markdown (no pip install needed)
  build.py        content/ + assets/  ->  dist/
  dist/           the finished site (committed, ready to upload)
```

## Build

```
python wiki/build.py
```

Rebuilds `dist/` from scratch in a couple of seconds. Run it after any edit
under `content/` or `assets/`.

## Deploy to S3

One-time bucket setup:

1. Create a bucket, e.g. `wiki.voidcrew-lrp.com`.
2. Properties → **Static website hosting** → enable. Index document
   `index.html`, error document `404.html`.
3. Permissions → turn off **Block all public access**, then add a public-read
   bucket policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "PublicRead",
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::wiki.voidcrew-lrp.com/*"
  }]
}
```

Then every deploy is one command from the repo root:

```
.\wiki\deploy.ps1
```

It rebuilds `dist/` and syncs it to the bucket (uploads changed files, deletes
removed ones). The default bucket name is set at the top of `deploy.ps1`;
override with `-Bucket <name>`. Equivalent manual commands:

```
python wiki/build.py
aws s3 sync wiki/dist s3://wiki.voidcrew-lrp.com --delete
```

One-time machine setup for the sync (see below for details):

1. Install the AWS CLI: `winget install Amazon.AWSCLI`
2. In the AWS console, create an IAM user (e.g. `wiki-deployer`) with the
   minimal policy shown below, create an access key for it, and run
   `aws configure` to store the key locally.

Minimal IAM policy for the deploy user (replace the bucket name):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::wiki.voidcrew-lrp.com"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::wiki.voidcrew-lrp.com/*"
    }
  ]
}
```

The site URL is the bucket's website endpoint
(`http://wiki.voidcrew-lrp.com.s3-website-<region>.amazonaws.com`). For HTTPS and a
custom domain, put CloudFront in front of the bucket later, nothing about
the site needs to change; all links are relative and work under any prefix.

## Adding a page

1. Copy `content/_TEMPLATE.md` (it contains the style guide) to
   `content/my-page.md`.
2. Fill in the frontmatter: `category` decides which sidebar section it
   lands in, `order` sorts within the section.
3. `python wiki/build.py`, open `wiki/dist/my-page.html` in a browser to check.
4. Commit `content/`, `assets/`, and `dist/` together; sync to S3.
