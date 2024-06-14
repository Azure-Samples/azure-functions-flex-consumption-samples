import * as pdfjs from 'pdfjs-dist/legacy/build/pdf.mjs';
import { app, output } from '@azure/functions';
import _ from 'lodash';

const blobOutput = output.storageBlob({
    connection: 'PDFProcessorSTORAGE',
    path: 'processed-text/{name}.txt',
});

app.storageBlob('PDFProcessor', {
    path: 'unprocessed-pdf/{name}.pdf',
    source: 'EventGrid',
    connection: 'PDFProcessorSTORAGE',
    return: blobOutput,
    handler: async (blob, context) => {
        context.log(`Storage blob (using Event Grid) function processed blob "${context.triggerMetadata.name}" with size ${blob.length} bytes`);
        
        // Load the PDF document pages
        const file = new Uint8Array(blob);
        const doc = await pdfjs.getDocument(file).promise;
        const totalPages = doc.numPages;
        context.log(`Extracting text from ${totalPages} PDF pages.`);
        
        // Load all pages in the PDF in parallel
        const pages = await Promise.all(_.range(1, totalPages + 1).map(async (pageNumber) => {
            return await doc.getPage(pageNumber);
        }));

        // Extract text from each page then join them together
        const texts = await Promise.all(pages.map(async (page) => {
            const textContent = await page.getTextContent();
            return textContent.items.map((item) => item.str).join('');
        }));

        return texts;
    }
});
