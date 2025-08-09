import json
import os
import uuid
from datetime import datetime, timezone

import boto3


def handler(event, context):
    bucket_name = os.environ.get("BUCKET_NAME")
    table_name = os.environ.get("TABLE_NAME")

    dynamodb = boto3.resource("dynamodb")
    table = dynamodb.Table(table_name)
    s3 = boto3.client("s3")

    item_id = str(uuid.uuid4())

    payload = {
        "id": item_id,
        "message": "Hello from Lambda!",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "request_event": event,
    }

    table.put_item(Item={"id": item_id, "createdAt": payload["timestamp"], "message": payload["message"]})

    s3.put_object(
        Bucket=bucket_name,
        Key=f"hello-{item_id}.json",
        Body=json.dumps(payload).encode("utf-8"),
        ContentType="application/json",
    )

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"ok": True, "id": item_id, "bucket": bucket_name, "table": table_name}),
    }