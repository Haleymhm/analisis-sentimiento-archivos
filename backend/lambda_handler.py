import boto3
import json
import os

# Inicializamos los clientes de AWS
s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
comprehend = boto3.client('comprehend')

def lambda_handler(event, context):
    # 1. Obtener información del archivo subido desde el evento de S3
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    file_key = event['Records'][0]['s3']['object']['key']
    
    try:
        # 2. Leer el contenido del archivo de S3
        response = s3.get_object(Bucket=bucket_name, Key=file_key)
        text_content = response['Body'].read().decode('utf-8')

        # 3. Analizar sentimiento con AWS Comprehend
        # Limitamos a 5000 bytes que es el límite estándar de Comprehend
        sentiment_data = comprehend.detect_sentiment(
            Text=text_content[:4500], 
            LanguageCode='es'
        )
        
        sentiment = sentiment_data['Sentiment'] # POSITIVE, NEGATIVE, etc.
        score = sentiment_data['SentimentScore']

        # 4. Guardar el resultado en DynamoDB
        table = dynamodb.Table('SentimientosResultados')
        table.put_item(
            Item={
                'FileId': file_key,
                'Sentiment': sentiment,
                'Confidence': json.dumps(score),
                'Timestamp': context.aws_request_id
            }
        )

        return {"status": "success", "file": file_key}

    except Exception as e:
        print(f"Error procesando {file_key}: {str(e)}")
        raise e