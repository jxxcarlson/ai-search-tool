# K-means Clustering Anomalies

## Issue: Getting Only 2 Clusters Instead of Expected 10

Based on code analysis, several possible causes for getting only 2 clusters instead of 10:

### 1. Automatic cluster selection using Davies-Bouldin score
The system uses Davies-Bouldin score (lower is better) to automatically determine the optimal number of clusters when `num_clusters` is not specified. The algorithm searches between `min_clusters` (default 2) and `max_clusters` (default 10) in `server/server.py:1461-1470`.

### 2. Strong bi-modal distribution
If the documents you added are very different from the existing ones, they might create two distinct groups that the Davies-Bouldin score identifies as the optimal clustering.

### 3. Embedding quality or distribution
The embeddings might have become polarized after adding the new documents, making 2 clusters appear more natural to the algorithm.

## Solutions

- **Force a specific number of clusters**: Pass `num_clusters=10` in your cluster request to override the automatic selection
- **Adjust the scoring method**: Consider using silhouette score instead of Davies-Bouldin 
- **Check your embeddings**: Verify that the new documents have proper embeddings and aren't creating outliers
- **Normalize the data**: The code already normalizes embeddings (`server/server.py:1451-1453`), but you might want to verify this is working correctly