export interface SentimentResult {
  FileId: string;
  Sentiment: 'POSITIVE' | 'NEGATIVE' | 'NEUTRAL' | 'MIXED';
  Confidence: string; // AWS lo devuelve como JSON stringified en nuestro caso
  Timestamp: string;
}

export interface PresignedUrlResponse {
  uploadURL: string;
}