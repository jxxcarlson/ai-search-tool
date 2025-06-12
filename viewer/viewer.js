// Document Viewer JavaScript

// Get URL parameters
function getUrlParams() {
    const params = new URLSearchParams(window.location.search);
    return {
        mode: params.get('mode') || 'server',
        port: params.get('port') || '8001',
        index: params.get('index'),
        data: params.get('data')
    };
}

// Format date for display
function formatDate(dateString) {
    if (!dateString) return 'N/A';
    const date = new Date(dateString);
    
    // Format: "Jun 12, 6:00 PM"
    const options = {
        month: 'short',
        day: 'numeric',
        hour: 'numeric',
        minute: '2-digit',
        hour12: true
    };
    
    return date.toLocaleString('en-US', options);
}

// Render content based on document type
function renderContent(content, docType) {
    const contentDiv = document.getElementById('doc-content');
    
    if (docType === 'md' || docType === 'markdown') {
        // Render as markdown
        contentDiv.className = 'markdown-content';
        contentDiv.innerHTML = marked.parse(content);
    } else {
        // Render as plain text
        contentDiv.className = 'text-content';
        contentDiv.textContent = content;
    }
}

// Load document from API or embedded data
async function loadDocument() {
    const params = getUrlParams();
    const errorDiv = document.getElementById('error-message');
    
    try {
        let doc;
        
        // Check for embedded document first (standalone mode)
        if (window.EMBEDDED_DOCUMENT) {
            doc = window.EMBEDDED_DOCUMENT;
        } else if (params.mode === 'standalone' && params.data) {
            // Standalone mode: decode document from URL parameter
            try {
                const decodedData = atob(decodeURIComponent(params.data));
                doc = JSON.parse(decodedData);
            } catch (e) {
                throw new Error('Failed to decode document data');
            }
        } else if (params.index) {
            // Server mode: fetch from API
            // Show loading state
            document.getElementById('doc-title').textContent = 'Loading...';
            document.getElementById('doc-content').innerHTML = '<p>Loading document...</p>';
            
            const response = await fetch(`http://localhost:${params.port}/documents/by-index/${params.index}`);
            
            if (!response.ok) {
                throw new Error(`Failed to load document: ${response.status}`);
            }
            
            doc = await response.json();
        } else {
            throw new Error('No document data provided');
        }
        
        // Update UI with document data
        document.getElementById('doc-title').textContent = doc.title;
        document.getElementById('created-date').textContent = formatDate(doc.created_at);
        document.getElementById('modified-date').textContent = formatDate(doc.updated_at);
        document.getElementById('doc-type').textContent = doc.doc_type || 'unknown';
        
        // Render content
        renderContent(doc.content, doc.doc_type);
        
        // Update page title
        document.title = `${doc.title} - Document Viewer`;
        
    } catch (error) {
        console.error('Error loading document:', error);
        errorDiv.textContent = error.message;
        errorDiv.classList.remove('hidden');
        
        // Hide content area on error
        document.getElementById('content-area').classList.add('hidden');
    }
}

// Handle escape key to close window
document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        window.close();
    }
});

// Load document when page loads
window.addEventListener('DOMContentLoaded', loadDocument);

// Reload on focus (in case document was updated)
let lastLoadTime = Date.now();
window.addEventListener('focus', () => {
    // Only reload if it's been more than 5 seconds
    if (Date.now() - lastLoadTime > 5000) {
        loadDocument();
        lastLoadTime = Date.now();
    }
});