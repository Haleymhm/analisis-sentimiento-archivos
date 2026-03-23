import boto3
import json
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('SentimientosResultados')

def lambda_handler(event, context):
    try:
        # Escaneamos la tabla para obtener los resultados
        # Nota: En apps grandes se usa 'query', pero para este MVP 'scan' funciona
        response = table.scan(Limit=10)
        items = response.get('Items', [])

        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Content-Type": "application/json"
            },
            "body": json.dumps(items)
        }
    except Exception as e:
        return {
            "statusCode": 500, 
            "body": json.dumps({"error": str(e)})
        }