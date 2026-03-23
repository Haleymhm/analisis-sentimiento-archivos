terraform {
  backend "s3" {
    bucket         = "tu-nombre-de-bucket-para-estado" # Crea uno manualmente antes o usa el ya creado
    key            = "terraform/state.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}
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

# Configurar CORS en S3 para permitir subidas desde el navegador
resource "aws_s3_bucket_cors_configuration" "cors" {
  bucket = aws_s3_bucket.analisis_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["*"] # En prod, usa tu dominio real
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Crear la Lambda 'Presigner' y su Function URL
resource "aws_lambda_function_url" "presigner_url" {
  function_name      = aws_lambda_function.presigner.function_name # Asume que ya definiste la lambda
  authorization_type = "NONE" # Para este demo, en prod usa IAM o JWT

  cors {
    allow_origins = ["*"]
    allow_methods = ["POST"]
  }
}

output "api_endpoint" {
  value = aws_lambda_function_url.presigner_url.function_url
}

# --- Lambda para Leer de DynamoDB ---
resource "aws_lambda_function" "get_results" {
  filename      = "lambda_results_payload.zip"
  function_name = "GetSentimentResults"
  role          = aws_iam_role.lambda_role.arn # Reutilizamos el rol anterior
  handler       = "get_results.lambda_handler"
  runtime       = "python3.12"
}

# Permiso específico para leer (Read)
resource "aws_iam_policy" "lambda_read_dynamo" {
  name = "lambda_read_dynamo_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["dynamodb:Scan", "dynamodb:GetItem"]
      Effect   = "Allow"
      Resource = aws_dynamodb_table.resultados_tabla.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_read" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_read_dynamo.arn
}

# URL pública para la API de consulta
resource "aws_lambda_function_url" "get_results_url" {
  function_name      = aws_lambda_function.get_results.function_name
  authorization_type = "NONE"
  cors {
    allow_origins = ["*"]
    allow_methods = ["GET"]
  }
}

output "results_api_url" {
  value = aws_lambda_function_url.get_results_url.function_url
}

# --- Bucket para el Frontend (Sitio Web) ---
resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "mi-proyecto-frontend-sentimientos-2026" # Nombre único global
}

# Configuración de alojamiento web
resource "aws_s3_bucket_website_configuration" "frontend_hosting" {
  bucket = aws_s3_bucket.frontend_bucket.id
  index_document { suffix = "index.html" }
  error_document { key    = "index.html" } # Importante para SPAs con rutas
}

# Permitir acceso público de lectura (necesario para sitios web)
resource "aws_s3_bucket_public_access_block" "frontend_public_block" {
  bucket = aws_s3_bucket.frontend_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "allow_public_access" {
  bucket = aws_s3_bucket.frontend_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.frontend_public_block]
}

# --- OUTPUT Clave para el CI/CD ---
output "frontend_bucket_name" {
  value = aws_s3_bucket.frontend_bucket.id
}

output "website_url" {
  value = aws_s3_bucket_website_configuration.frontend_hosting.website_endpoint
}