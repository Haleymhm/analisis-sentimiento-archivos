import React, { useState } from 'react';
import { PresignedUrlResponse } from '../types';

const FileUploader: React.FC = () => {
    const [file, setFile] = useState<File | null>(null);
    const [status, setStatus] = useState<string>('');

    const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        if (e.target.files && e.target.files[0]) {
            setFile(e.target.files[0]);
        }
    };

    const handleUpload = async () => {
        if (!file) {
            setStatus('Por favor, selecciona un archivo primero.');
            return;
        }

        setStatus('Obteniendo permiso de subida...');

        try {
            // 1. Obtener Presigned URL
            const response = await fetch(import.meta.env.VITE_API_URL, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ fileName: file.name }),
            });

            const { uploadURL }: PresignedUrlResponse = await response.json();

            // 2. Subir directamente a S3
            setStatus('Subiendo archivo a AWS S3...');
            const uploadRes = await fetch(uploadURL, {
                method: 'PUT',
                body: file,
                headers: { 'Content-Type': 'text/plain' }
            });

            if (uploadRes.ok) {
                setStatus('¡Éxito! El análisis de IA ha comenzado.');
            } else {
                throw new Error('Error al subir a S3');
            }
        } catch (error) {
            console.error(error);
            setStatus('Error en el proceso de subida.');
        }
    };

    return (
        <div className="p-6 border-2 border-dashed border-blue-200 rounded-lg bg-white shadow-sm">
            <input
                type="file"
                onChange={handleFileChange}
                accept=".txt"
                className="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
            />
            <button
                onClick={handleUpload}
                disabled={!file}
                className="mt-4 w-full bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded disabled:opacity-50 transition-colors"
            >
                Analizar con IA
            </button>
            {status && <p className="mt-3 text-sm text-gray-600 italic text-center">{status}</p>}
        </div>
    );
};

export default FileUploader;