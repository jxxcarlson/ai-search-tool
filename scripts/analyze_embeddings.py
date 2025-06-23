#!/usr/bin/env python3
"""
Analyze embedding distribution and clustering behavior
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'server'))

import numpy as np
import chromadb
from chromadb.config import Settings
from sklearn.cluster import KMeans
from sklearn.metrics import davies_bouldin_score, silhouette_score
from sklearn.decomposition import PCA
import sqlite3

def analyze_embeddings():
    # Connect to ChromaDB
    chroma_client = chromadb.PersistentClient(
        path="../server/storage/default/chroma_db",
        settings=Settings(anonymized_telemetry=False)
    )
    
    collection = chroma_client.get_collection(name="documents")
    
    # Get all embeddings
    all_data = collection.get(include=['embeddings', 'metadatas'])
    embeddings = np.array(all_data['embeddings'])
    doc_ids = all_data['ids']
    metadatas = all_data['metadatas']
    
    print(f"Total embeddings: {len(embeddings)}")
    print(f"Embedding dimensions: {embeddings.shape[1]}")
    
    # Clean and normalize embeddings
    embeddings = np.nan_to_num(embeddings, nan=0.0, posinf=0.0, neginf=0.0)
    norms = np.linalg.norm(embeddings, axis=1, keepdims=True)
    norms[norms == 0] = 1
    embeddings = embeddings / norms
    
    # Analyze embedding statistics
    print("\nEmbedding Statistics:")
    print(f"Mean norm: {np.mean(np.linalg.norm(embeddings, axis=1)):.4f}")
    print(f"Std norm: {np.std(np.linalg.norm(embeddings, axis=1)):.4f}")
    
    # Calculate pairwise distances
    from sklearn.metrics.pairwise import cosine_distances
    distances = cosine_distances(embeddings)
    
    print(f"\nPairwise Distance Statistics:")
    print(f"Mean distance: {np.mean(distances):.4f}")
    print(f"Std distance: {np.std(distances):.4f}")
    print(f"Min distance (excluding self): {np.min(distances[distances > 0]):.4f}")
    print(f"Max distance: {np.max(distances):.4f}")
    
    # Test different numbers of clusters
    print("\nClustering Analysis:")
    print("k\tDavies-Bouldin\tSilhouette")
    print("-" * 40)
    
    scores = []
    for k in range(2, min(11, len(embeddings))):
        kmeans = KMeans(n_clusters=k, random_state=42, n_init=10)
        labels = kmeans.fit_predict(embeddings)
        
        db_score = davies_bouldin_score(embeddings, labels)
        sil_score = silhouette_score(embeddings, labels)
        
        scores.append((k, db_score, sil_score))
        print(f"{k}\t{db_score:.4f}\t\t{sil_score:.4f}")
    
    # Find best k for each metric
    best_db_k = min(scores, key=lambda x: x[1])[0]
    best_sil_k = max(scores, key=lambda x: x[2])[0]
    
    print(f"\nBest k by Davies-Bouldin (lower is better): {best_db_k}")
    print(f"Best k by Silhouette (higher is better): {best_sil_k}")
    
    # Analyze the 2-cluster solution
    print("\n2-Cluster Analysis:")
    kmeans_2 = KMeans(n_clusters=2, random_state=42, n_init=10)
    labels_2 = kmeans_2.fit_predict(embeddings)
    
    cluster_0_indices = np.where(labels_2 == 0)[0]
    cluster_1_indices = np.where(labels_2 == 1)[0]
    
    print(f"Cluster 0: {len(cluster_0_indices)} documents")
    print(f"Cluster 1: {len(cluster_1_indices)} documents")
    
    # Sample titles from each cluster
    conn = sqlite3.connect("../server/storage/default/documents.db")
    cursor = conn.cursor()
    
    print("\nCluster 0 sample titles:")
    for i in cluster_0_indices[:5]:
        doc_id = doc_ids[i]
        title = metadatas[i].get('title', 'Unknown')
        print(f"  - {title}")
    
    print("\nCluster 1 sample titles:")
    for i in cluster_1_indices[:5]:
        doc_id = doc_ids[i]
        title = metadatas[i].get('title', 'Unknown')
        print(f"  - {title}")
    
    conn.close()
    
    # PCA analysis
    pca = PCA(n_components=2)
    embeddings_2d = pca.fit_transform(embeddings)
    
    print(f"\nPCA explained variance ratio: {pca.explained_variance_ratio_}")
    print(f"Total variance explained by 2 components: {sum(pca.explained_variance_ratio_):.4f}")
    
    # Analyze spread in PCA space
    cluster_0_pca = embeddings_2d[cluster_0_indices]
    cluster_1_pca = embeddings_2d[cluster_1_indices]
    
    print(f"\nCluster spread in PCA space:")
    print(f"Cluster 0 (large): std PC1={np.std(cluster_0_pca[:, 0]):.4f}, std PC2={np.std(cluster_0_pca[:, 1]):.4f}")
    print(f"Cluster 1 (small): std PC1={np.std(cluster_1_pca[:, 0]):.4f}, std PC2={np.std(cluster_1_pca[:, 1]):.4f}")
    
    # Check for outliers or anomalies
    print("\nChecking for potential outliers...")
    mean_dist_per_doc = np.mean(distances, axis=1)
    outlier_threshold = np.mean(mean_dist_per_doc) + 2 * np.std(mean_dist_per_doc)
    outliers = np.where(mean_dist_per_doc > outlier_threshold)[0]
    
    print(f"Found {len(outliers)} potential outliers (>2 std from mean distance)")
    if len(outliers) > 0:
        print("Outlier documents:")
        for idx in outliers[:5]:
            title = metadatas[idx].get('title', 'Unknown')
            print(f"  - {title} (mean distance: {mean_dist_per_doc[idx]:.4f})")

if __name__ == "__main__":
    analyze_embeddings()