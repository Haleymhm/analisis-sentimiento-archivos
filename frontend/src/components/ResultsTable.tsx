import React, { useEffect, useState } from 'react';
import { SentimentResult } from '../types';

const ResultsTable: React.FC = () => {
    const [results, setResults] = useState<SentimentResult[]>([]);
    const [loading, setLoading] = useState<boolean>(true);

    const fetchResults = async () => {
        try {
            const response = await fetch(import.meta.env.VITE_RESULTS_URL);
            const data: SentimentResult[] = await response.json();
            setResults(data);
        } catch (error) {
            console.error("Error fetching results:", error);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchResults();
        const interval = setInterval(fetchResults, 5000); // Polling cada 5 segundos
        return () => clearInterval(interval);
    }, []);

    if (loading) return <div className="mt-10">Cargando resultados...</div>;

    return (
        <div className="mt-10 w-full max-w-4xl overflow-hidden rounded-lg border border-gray-200 shadow-md">
            <table className="w-full border-collapse bg-white text-left text-sm text-gray-500">
                <thead className="bg-gray-50">
                    <tr>
                        <th className="px-6 py-4 font-medium text-gray-900">ID del Archivo</th>
                        <th className="px-6 py-4 font-medium text-gray-900">Sentimiento</th>
                        <th className="px-6 py-4 font-medium text-gray-900">Timestamp</th>
                    </tr>
                </thead>
                <tbody className="divide-y divide-gray-100 border-t border-gray-100">
                    {results.map((res) => (
                        <tr key={res.FileId} className="hover:bg-gray-50">
                            <td className="px-6 py-4 font-mono text-xs">{res.FileId}</td>
                            <td className="px-6 py-4">
                                <span className={`inline-flex items-center gap-1 rounded-full px-2 py-1 text-xs font-semibold 
                  ${res.Sentiment === 'POSITIVE' ? 'bg-green-50 text-green-600' :
                                        res.Sentiment === 'NEGATIVE' ? 'bg-red-50 text-red-600' : 'bg-blue-50 text-blue-600'}`}>
                                    {res.Sentiment}
                                </span>
                            </td>
                            <td className="px-6 py-4 text-xs">{res.Timestamp}</td>
                        </tr>
                    ))}
                </tbody>
            </table>
        </div>
    );
};

export default ResultsTable;