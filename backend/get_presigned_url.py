import boto3
import json
import os

s3_client = boto3.client('s3')
BUCKET_NAME = os.environ['BUCKET_NAME']

def lambda_handler(event, context):
    # Obtenemos el nombre del archivo desde el body del request
    body = json.loads(event.get('body', '{}'))
    file_name = body.get('fileName')

    if not file_name:
        return {"statusCode": 400, "body": json.dumps({"error": "fileName is required"})}

    try:
        # Generar URL firmada para una operación 'put_object'
        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={'Bucket': BUCKET_NAME, 'Key': file_name},
            ExpiresIn=300 # 5 minutos
        )
        
        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*", # Importante para CORS
                "Access-Control-Allow-Headers": "Content-Type",
                "Access-Control-Allow-Methods": "OPTIONS,POST"
            },
            "body": json.dumps({"uploadURL": presigned_url})
        }
    except Exception as e:
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}