# 1. Configuración del Provider
provider "aws" {
  region = "us-east-1" # Puedes cambiarla a tu región preferida
}

# 2. Bucket de S3 para subir los archivos (.txt, .json, etc.)
resource "aws_s3_bucket" "analisis_bucket" {
  bucket = "mi-proyecto-sentiment-data-2026" # Nombre único global
}

# Bloqueo de acceso público (Buena práctica de seguridad)
resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket = aws_s3_bucket.analisis_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 3. Tabla DynamoDB para resultados
resource "aws_dynamodb_table" "resultados_tabla" {
  name           = "SentimientosResultados"
  billing_mode   = "PAY_PER_REQUEST" # Escala a cero costo si no hay uso
  hash_key       = "FileId"

  attribute {
    name = "FileId"
    type = "S" # String (Nombre del archivo o UUID)
  }

  tags = {
    Environment = "Dev"
    Project     = "SentimentAnalysis"
  }
}

# 4. Output para usar en nuestro código Python después
output "s3_bucket_name" {
  value = aws_s3_bucket.analisis_bucket.id
}

# --- IAM Role para la Lambda ---
resource "aws_iam_role" "lambda_role" {
  name = "sentiment_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# --- Permisos (S3, DynamoDB, Comprehend y Logs) ---
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Nota: En producción, usa políticas más restrictivas (Least Privilege)
resource "aws_iam_policy" "lambda_extra_perms" {
  name = "sentiment_analysis_perms"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Action = ["s3:GetObject"], Effect = "Allow", Resource = "${aws_s3_bucket.analisis_bucket.arn}/*" },
      { Action = ["dynamodb:PutItem"], Effect = "Allow", Resource = aws_dynamodb_table.resultados_tabla.arn },
      { Action = ["comprehend:DetectSentiment"], Effect = "Allow", Resource = "*" }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_extra" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_extra_perms.arn
}

# --- La Función Lambda ---
resource "aws_lambda_function" "sentiment_processor" {
  filename      = "lambda_function_payload.zip" # Terraform necesita el código comprimido
  function_name = "SentimentProcessor"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_handler.lambda_handler"
  runtime       = "python3.12"

  # Esto permite que Terraform suba tu código automáticamente
  source_code_hash = filebase64sha256("lambda_function_payload.zip")
}

# --- Trigger: Activar Lambda cuando se sube algo a S3 ---
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.analisis_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.sentiment_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".txt" # Solo archivos de texto
  }
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sentiment_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.analisis_bucket.arn
}