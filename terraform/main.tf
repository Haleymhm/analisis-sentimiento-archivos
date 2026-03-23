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