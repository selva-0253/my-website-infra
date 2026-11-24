"""Likes and comments API for the blog.

Routes (API Gateway HTTP API, payload v2):
  GET  /v1/posts/{slug}           -> {"slug", "likes", "comments": [...]}
  POST /v1/posts/{slug}/likes     body {"turnstileToken"}
  POST /v1/posts/{slug}/comments  body {"name", "text", "turnstileToken"}
  POST /v1/cv                     body {"turnstileToken"} -> {"url", "expiresIn"}

The CV route returns a short-lived presigned S3 link to the owner's CV, which
lives in a private bucket and has no public URL.

Every request must carry the x-origin-verify header that Cloudflare adds;
anything else did not come through Cloudflare and is rejected.
"""

import hashlib
import hmac
import json
import os
import re
import secrets
import time
import unicodedata
import urllib.parse
import urllib.request

import boto3
from boto3.dynamodb.conditions import Attr, Key
from botocore.config import Config
from botocore.exceptions import ClientError

TABLE_NAME = os.environ["TABLE_NAME"]
ORIGIN_SECRET = os.environ["ORIGIN_SECRET"]
TURNSTILE_SECRET = os.environ["TURNSTILE_SECRET"]
ALLOWED_HOSTNAMES = {h for h in os.environ.get("ALLOWED_HOSTNAMES", "").split(",") if h}
REQUIRE_APPROVAL = os.environ.get("COMMENTS_REQUIRE_APPROVAL", "false") == "true"
CV_BUCKET = os.environ.get("CV_BUCKET", "").strip("-")
CV_KEY = os.environ.get("CV_KEY", "private/cv.pdf")
CV_DOWNLOAD_NAME = re.sub(r"[^A-Za-z0-9._-]", "_", os.environ.get("CV_DOWNLOAD_NAME", "CV.pdf"))
CV_LINK_TTL = int(os.environ.get("CV_LINK_TTL", "300"))

SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,63}$")
MAX_BODY = 4096
MAX_NAME = 40
MAX_TEXT = 1000
MAX_COMMENTS = 100
TURNSTILE_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"

_ddb = boto3.resource("dynamodb")
_table = _ddb.Table(TABLE_NAME)
_client = _ddb.meta.client
_s3 = boto3.client("s3", config=Config(signature_version="s3v4")) if CV_BUCKET else None


def _resp(status, body, cache=False):
    return {
        "statusCode": status,
        "headers": {
            "content-type": "application/json",
            "cache-control": "public, max-age=15" if cache else "no-store",
        },
        "body": json.dumps(body),
    }


def _error(status, message):
    return _resp(status, {"error": message})


def _client_ip(event):
    headers = event.get("headers") or {}
    # Only trusted because the origin header proved the request came via Cloudflare.
    return headers.get("cf-connecting-ip") or event["requestContext"]["http"].get("sourceIp", "")


def _visitor_key(ip, slug):
    return hmac.new(ORIGIN_SECRET.encode(), f"{slug}|{ip}".encode(), hashlib.sha256).hexdigest()[:32]


def _clean(text, limit):
    # Drop control characters (keep newlines in comments), trim, cap length.
    text = "".join(
        ch for ch in text if ch == "\n" or unicodedata.category(ch)[0] != "C"
    )
    text = re.sub(r"\n{3,}", "\n\n", text).strip()
    return text[:limit]


def _verify_turnstile(token, ip):
    if not isinstance(token, str) or not token or len(token) > 2048:
        return False
    data = urllib.parse.urlencode(
        {"secret": TURNSTILE_SECRET, "response": token, "remoteip": ip}
    ).encode()
    try:
        with urllib.request.urlopen(TURNSTILE_URL, data=data, timeout=5) as r:
            result = json.load(r)
    except Exception as exc:  # network or JSON error: fail closed
        print(f"turnstile verify failed: {exc}")
        return False
    if not result.get("success"):
        print(f"turnstile rejected: {result.get('error-codes')}")
        return False
    if ALLOWED_HOSTNAMES and result.get("hostname") not in ALLOWED_HOSTNAMES:
        print(f"turnstile hostname not allowed: {result.get('hostname')}")
        return False
    return True


def _likes(slug):
    item = _table.get_item(Key={"pk": f"POST#{slug}", "sk": "STATS"}).get("Item")
    return int(item.get("likes", 0)) if item else 0


def get_post(slug):
    comments = []
    resp = _table.query(
        KeyConditionExpression=Key("pk").eq(f"POST#{slug}") & Key("sk").begins_with("COMMENT#"),
        FilterExpression=Attr("status").eq("approved"),
        ScanIndexForward=False,
        Limit=MAX_COMMENTS,
    )
    for item in resp.get("Items", []):
        comments.append(
            {
                "id": item["sk"].rsplit("#", 1)[-1],
                "name": item.get("name", "Anonymous"),
                "text": item.get("text", ""),
                "createdAt": item.get("createdAt"),
            }
        )
    return _resp(200, {"slug": slug, "likes": _likes(slug), "comments": comments}, cache=True)


def add_like(slug, ip):
    pk = f"POST#{slug}"
    try:
        _client.transact_write_items(
            TransactItems=[
                {
                    "Put": {
                        "TableName": TABLE_NAME,
                        "Item": {"pk": pk, "sk": f"LIKE#{_visitor_key(ip, slug)}", "createdAt": int(time.time())},
                        "ConditionExpression": "attribute_not_exists(pk)",
                    }
                },
                {
                    "Update": {
                        "TableName": TABLE_NAME,
                        "Key": {"pk": pk, "sk": "STATS"},
                        "UpdateExpression": "ADD likes :one",
                        "ExpressionAttributeValues": {":one": 1},
                    }
                },
            ]
        )
        already = False
    except ClientError as exc:
        if exc.response["Error"]["Code"] != "TransactionCanceledException":
            raise
        already = True  # this visitor already liked the post
    return _resp(200, {"likes": _likes(slug), "alreadyLiked": already})


def add_comment(slug, body):
    name = _clean(str(body.get("name") or ""), MAX_NAME).replace("\n", " ") or "Anonymous"
    text = _clean(str(body.get("text") or ""), MAX_TEXT)
    if len(text) < 2:
        return _error(400, "Comment is too short.")

    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    comment_id = secrets.token_hex(6)
    status = "pending" if REQUIRE_APPROVAL else "approved"
    _table.put_item(
        Item={
            "pk": f"POST#{slug}",
            "sk": f"COMMENT#{now}#{comment_id}",
            "name": name,
            "text": text,
            "createdAt": now,
            "status": status,
        }
    )
    comment = {"id": comment_id, "name": name, "text": text, "createdAt": now}
    return _resp(201, {"comment": comment, "pending": status == "pending"})


def cv_link():
    if not _s3:
        return _error(404, "CV is not available.")
    try:
        _s3.head_object(Bucket=CV_BUCKET, Key=CV_KEY)
    except ClientError as exc:
        # Without s3:ListBucket a missing object reports 403, not 404.
        if exc.response["Error"]["Code"] in ("403", "404", "NoSuchKey", "Forbidden", "NotFound"):
            return _error(404, "CV is not available.")
        raise
    url = _s3.generate_presigned_url(
        "get_object",
        Params={
            "Bucket": CV_BUCKET,
            "Key": CV_KEY,
            "ResponseContentType": "application/pdf",
            "ResponseContentDisposition": f'attachment; filename="{CV_DOWNLOAD_NAME}"',
            "ResponseCacheControl": "no-store",
        },
        ExpiresIn=CV_LINK_TTL,
    )
    return _resp(200, {"url": url, "expiresIn": CV_LINK_TTL})


def _parse_body(event):
    """Returns (body dict, None) or (None, error response)."""
    raw = event.get("body") or ""
    if event.get("isBase64Encoded"):
        return None, _error(400, "Unsupported body.")
    if len(raw) > MAX_BODY:
        return None, _error(413, "Request too large.")
    try:
        body = json.loads(raw or "{}")
        if not isinstance(body, dict):
            raise ValueError
    except ValueError:
        return None, _error(400, "Invalid JSON.")
    return body, None


def handler(event, context):
    headers = event.get("headers") or {}
    if not hmac.compare_digest(headers.get("x-origin-verify", ""), ORIGIN_SECRET):
        return _error(403, "Forbidden")

    route = event.get("routeKey", "")

    if route == "POST /v1/cv":
        body, err = _parse_body(event)
        if err:
            return err
        if not _verify_turnstile(body.get("turnstileToken"), _client_ip(event)):
            return _error(403, "Bot check failed. Please try again.")
        print("cv link issued")  # audit trail in CloudWatch, no personal data
        return cv_link()

    slug = (event.get("pathParameters") or {}).get("slug", "")
    if not SLUG_RE.match(slug):
        return _error(404, "Unknown post.")

    if route == "GET /v1/posts/{slug}":
        return get_post(slug)

    body, err = _parse_body(event)
    if err:
        return err

    ip = _client_ip(event)
    if not _verify_turnstile(body.get("turnstileToken"), ip):
        return _error(403, "Bot check failed. Please try again.")

    if route == "POST /v1/posts/{slug}/likes":
        return add_like(slug, ip)
    if route == "POST /v1/posts/{slug}/comments":
        return add_comment(slug, body)
    return _error(404, "Not found.")
