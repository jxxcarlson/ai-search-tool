# Cluster Selection Methods Explained

## Current Method: Silhouette Score

**What it measures**: How similar a point is to its own cluster compared to other clusters.

**Range**: -1 to 1 (higher is better)
- Near +1: Point is well-matched to its cluster
- Near 0: Point is on the border between clusters  
- Negative: Point might be in the wrong cluster

**How it works**:
```python
# For each point, calculate:
a = average distance to other points in same cluster
b = average distance to points in nearest other cluster
silhouette = (b - a) / max(a, b)
```

**Pros**: 
- Intuitive interpretation
- Works well for convex clusters
- Single score per clustering

**Cons**:
- Computationally expensive for large datasets
- Biased toward convex (spherical) clusters

## Alternative 1: Elbow Method (Inertia)

**What it measures**: Sum of squared distances from points to their cluster centers (also called "within-cluster sum of squares" or WCSS).

**How it works**:
1. Plot inertia vs number of clusters
2. Look for an "elbow" where the rate of decrease sharply levels off
3. The elbow point suggests the optimal k

```python
inertias = []
for k in range(2, 11):
    kmeans = KMeans(n_clusters=k)
    kmeans.fit(data)
    inertias.append(kmeans.inertia_)
    
# Plot and look for elbow
# The "elbow" is where adding more clusters doesn't help much
```

**Visual example**:
```
Inertia
|
|\\
| \\
|  \\
|   \\_____ <- Elbow at k=4
|         \\____
+----------------
2  3  4  5  6  7  k
```

**Pros**:
- Simple and fast
- Always computable
- Built into KMeans

**Cons**:
- Elbow is sometimes ambiguous
- Always decreases with more clusters
- Manual interpretation needed

## Alternative 2: Gap Statistic

**What it measures**: Compares the within-cluster dispersion to that expected under a null reference distribution (random uniform data).

**How it works**:
1. Calculate log(WCSS) for your data
2. Generate B reference datasets with random uniform distribution
3. Calculate log(WCSS) for each reference dataset
4. Gap(k) = Expected log(WCSS) for random data - log(WCSS) for your data
5. Choose k where Gap(k) - Gap(k+1) + standard_error is maximized

```python
def gap_statistic(data, k_max=10, B=10):
    gaps = []
    for k in range(1, k_max+1):
        # Cluster actual data
        kmeans = KMeans(n_clusters=k)
        labels = kmeans.fit_predict(data)
        wcss = calculate_wcss(data, labels)
        
        # Generate B random datasets and cluster them
        ref_wcss = []
        for _ in range(B):
            random_data = generate_random_data(data.shape)
            random_labels = KMeans(n_clusters=k).fit_predict(random_data)
            ref_wcss.append(calculate_wcss(random_data, random_labels))
        
        # Calculate gap
        gap = np.mean(np.log(ref_wcss)) - np.log(wcss)
        gaps.append(gap)
    
    return gaps
```

**Pros**:
- Statistically principled
- Can suggest k=1 (no clustering needed)
- Works for different cluster shapes

**Cons**:
- Computationally expensive (needs reference datasets)
- Complex to implement
- Can be unstable for non-globular clusters

## Alternative 3: Davies-Bouldin Index

**What it measures**: Average similarity between each cluster and its most similar cluster.

**Range**: 0 to infinity (lower is better)

**How it works**:
```python
# For each cluster i:
# 1. Calculate within-cluster scatter (Si)
# 2. For each other cluster j:
#    - Calculate between-cluster separation (Dij)
#    - Calculate similarity: Rij = (Si + Sj) / Dij
# 3. Find max similarity: Ri = max(Rij)
# Davies-Bouldin = average of all Ri

def davies_bouldin_score(data, labels):
    n_clusters = len(set(labels))
    cluster_centers = calculate_centers(data, labels)
    
    db_index = 0
    for i in range(n_clusters):
        # Find points in cluster i
        cluster_i_points = data[labels == i]
        # Within-cluster scatter
        Si = np.mean(np.linalg.norm(cluster_i_points - cluster_centers[i], axis=1))
        
        # Find most similar cluster
        max_ratio = 0
        for j in range(n_clusters):
            if i != j:
                cluster_j_points = data[labels == j]
                Sj = np.mean(np.linalg.norm(cluster_j_points - cluster_centers[j], axis=1))
                # Between-cluster separation
                Dij = np.linalg.norm(cluster_centers[i] - cluster_centers[j])
                ratio = (Si + Sj) / Dij
                max_ratio = max(max_ratio, ratio)
        
        db_index += max_ratio
    
    return db_index / n_clusters
```

**Pros**:
- Fast computation
- No need for reference distributions
- Intuitive: measures cluster separation and cohesion

**Cons**:
- Biased toward convex clusters
- Can't handle single-point clusters well
- Not normalized (hard to interpret absolute values)

## Comparison Table

| Method | Best For | Speed | Interpretation | Range |
|--------|----------|-------|----------------|-------|
| Silhouette | Well-separated convex clusters | Slow | Easy | [-1, 1] higher is better |
| Elbow | Quick exploration | Fast | Manual/Visual | [0, ∞) look for elbow |
| Gap Statistic | Statistical rigor | Very Slow | Complex | [0, ∞) higher is better |
| Davies-Bouldin | Fast automated selection | Fast | Moderate | [0, ∞) lower is better |

## Recommendation for Your Use Case

For document clustering with embeddings:

1. **Start with Davies-Bouldin**: Fast and automated, good for initial exploration
2. **Validate with Elbow method**: Visual check to ensure sensible results
3. **Use Silhouette for final tuning**: When you've narrowed down the range
4. **Gap statistic**: Only if you need statistical justification

## Implementation Example

Here's how to implement multiple methods:

```python
def find_optimal_clusters(embeddings, min_k=2, max_k=10):
    scores = {
        'silhouette': [],
        'davies_bouldin': [],
        'inertia': []
    }
    
    for k in range(min_k, max_k + 1):
        kmeans = KMeans(n_clusters=k, random_state=42)
        labels = kmeans.fit_predict(embeddings)
        
        # Silhouette Score (higher is better)
        if k > 1:  # Silhouette needs at least 2 clusters
            scores['silhouette'].append(silhouette_score(embeddings, labels))
        
        # Davies-Bouldin Index (lower is better)
        scores['davies_bouldin'].append(davies_bouldin_score(embeddings, labels))
        
        # Inertia for elbow method (lower is better)
        scores['inertia'].append(kmeans.inertia_)
    
    # Find optimal k for each method
    optimal_k = {
        'silhouette': min_k + np.argmax(scores['silhouette']),
        'davies_bouldin': min_k + np.argmin(scores['davies_bouldin']),
        'elbow': find_elbow_point(scores['inertia'])  # Custom function needed
    }
    
    return optimal_k, scores
```