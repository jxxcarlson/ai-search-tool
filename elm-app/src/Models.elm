module Models exposing (..)

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


-- Helper for pipeline decoding
andMap : Decoder a -> Decoder (a -> b) -> Decoder b
andMap = Decode.map2 (|>)


type alias Document =
    { id : String
    , title : String
    , content : String
    , createdAt : Maybe String
    , docType : Maybe String
    , tags : Maybe String
    , abstract : Maybe String
    , abstractSource : Maybe String
    , source : Maybe String
    , authors : Maybe String
    , index : Maybe Int
    , clusterId : Maybe Int
    , clusterName : Maybe String
    }


type alias SearchResult =
    { id : String
    , title : String
    , content : String
    , createdAt : Maybe String
    , docType : Maybe String
    , tags : Maybe String
    , abstract : Maybe String
    , abstractSource : Maybe String
    , source : Maybe String
    , authors : Maybe String
    , index : Maybe Int
    , similarityScore : Maybe Float
    , clusterId : Maybe Int
    , clusterName : Maybe String
    }


type alias Stats =
    { totalDocuments : Int
    , embeddingDimension : Int
    , model : String
    , storageLocation : String
    , chromaCollectionCount : Int
    , databaseSizeKb : Float
    }


type alias ApiError =
    { message : String
    , detail : Maybe String
    }


type alias ClusterDocument =
    { id : String
    , title : String
    , docType : Maybe String
    , createdAt : Maybe String
    }


type alias Cluster =
    { clusterId : Int
    , clusterName : String
    , size : Int
    , documents : List ClusterDocument
    , representativeDocumentId : String
    }


type alias ClusterResponse =
    { clusters : List Cluster
    , numClusters : Int
    , silhouetteScore : Float
    , totalDocuments : Int
    }


type alias DatabaseInfo =
    { id : String
    , name : String
    , createdAt : String
    , description : Maybe String
    , documentCount : Int
    , lastAccessed : String
    }


type alias ClusterVisualization =
    { clusters : List VisualizationCluster
    , documents : List VisualizationDocument
    , explainedVarianceRatio : List Float
    , voronoiCells : List VoronoiCell
    }


type alias VoronoiCell =
    { clusterId : Int
    , vertices : List (Float, Float)
    }


type alias VisualizationCluster =
    { clusterId : Int
    , x : Float
    , y : Float
    , size : Int
    , name : String
    }


type alias VisualizationDocument =
    { id : String
    , title : String
    , clusterId : Int
    , x : Float
    , y : Float
    }



documentDecoder : Decoder Document
documentDecoder =
    Decode.succeed Document
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "title" Decode.string)
        |> andMap (Decode.field "content" Decode.string)
        |> andMap (Decode.maybe (Decode.field "created_at" Decode.string))
        |> andMap (Decode.maybe (Decode.field "doc_type" Decode.string))
        |> andMap (Decode.maybe (Decode.field "tags" Decode.string))
        |> andMap (Decode.maybe (Decode.field "abstract" Decode.string))
        |> andMap (Decode.maybe (Decode.field "abstract_source" Decode.string))
        |> andMap (Decode.maybe (Decode.field "source" Decode.string))
        |> andMap (Decode.maybe (Decode.field "authors" Decode.string))
        |> andMap (Decode.maybe (Decode.field "index" Decode.int))
        |> andMap (Decode.maybe (Decode.field "cluster_id" Decode.int))
        |> andMap (Decode.maybe (Decode.field "cluster_name" Decode.string))


searchResultDecoder : Decoder SearchResult
searchResultDecoder =
    Decode.succeed SearchResult
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "title" Decode.string)
        |> andMap (Decode.field "content" Decode.string)
        |> andMap (Decode.maybe (Decode.field "created_at" Decode.string))
        |> andMap (Decode.maybe (Decode.field "doc_type" Decode.string))
        |> andMap (Decode.maybe (Decode.field "tags" Decode.string))
        |> andMap (Decode.maybe (Decode.field "abstract" Decode.string))
        |> andMap (Decode.maybe (Decode.field "abstract_source" Decode.string))
        |> andMap (Decode.maybe (Decode.field "source" Decode.string))
        |> andMap (Decode.maybe (Decode.field "authors" Decode.string))
        |> andMap (Decode.maybe (Decode.field "index" Decode.int))
        |> andMap (Decode.maybe (Decode.field "similarity_score" Decode.float))
        |> andMap (Decode.maybe (Decode.field "cluster_id" Decode.int))
        |> andMap (Decode.maybe (Decode.field "cluster_name" Decode.string))


statsDecoder : Decoder Stats
statsDecoder =
    Decode.map6 Stats
        (Decode.field "total_documents" Decode.int)
        (Decode.field "embedding_dimension" Decode.int)
        (Decode.field "model" Decode.string)
        (Decode.field "storage_location" Decode.string)
        (Decode.field "chroma_collection_count" Decode.int)
        (Decode.field "database_size_kb" Decode.float)


apiErrorDecoder : Decoder ApiError
apiErrorDecoder =
    Decode.map2 ApiError
        (Decode.field "message" Decode.string)
        (Decode.maybe (Decode.field "detail" Decode.string))



encodeDocument : String -> String -> Maybe String -> String -> Maybe String -> Maybe String -> Encode.Value
encodeDocument title content docType tags source authors =
    Encode.object
        [ ( "title", Encode.string title )
        , ( "content", Encode.string content )
        , ( "doc_type", encodeMaybe Encode.string docType )
        , ( "tags", if String.isEmpty tags then Encode.null else Encode.string tags )
        , ( "source", encodeMaybe Encode.string source )
        , ( "authors", encodeMaybe Encode.string authors )
        ]


encodeSearch : String -> Int -> Encode.Value
encodeSearch query limit =
    Encode.object
        [ ( "query", Encode.string query )
        , ( "limit", Encode.int limit )
        ]


encodeRename : String -> Encode.Value
encodeRename newTitle =
    Encode.object
        [ ( "new_title", Encode.string newTitle )
        ]


encodeMaybe : (a -> Encode.Value) -> Maybe a -> Encode.Value
encodeMaybe encoder maybeVal =
    case maybeVal of
        Just val ->
            encoder val

        Nothing ->
            Encode.null


encodeUpdate : Maybe String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Encode.Value
encodeUpdate title content docType tags abstract abstractSource source authors =
    let
        fields =
            List.filterMap identity
                [ Maybe.map (\t -> ( "title", Encode.string t )) title
                , Maybe.map (\c -> ( "content", Encode.string c )) content
                , Maybe.map (\d -> ( "doc_type", Encode.string d )) docType
                , Maybe.map (\t -> ( "tags", Encode.string t )) tags
                , Maybe.map (\a -> ( "abstract", Encode.string a )) abstract
                , Maybe.map (\s -> ( "abstract_source", Encode.string s )) abstractSource
                , Maybe.map (\src -> ( "source", Encode.string src )) source
                , Maybe.map (\auth -> ( "authors", Encode.string auth )) authors
                ]
    in
    Encode.object fields


encodeClaude : String -> Encode.Value
encodeClaude prompt =
    Encode.object
        [ ( "prompt", Encode.string prompt )
        , ( "max_tokens", Encode.int 1000 )
        , ( "temperature", Encode.float 0.7 )
        ]


clusterDocumentDecoder : Decoder ClusterDocument
clusterDocumentDecoder =
    Decode.map4 ClusterDocument
        (Decode.field "id" Decode.string)
        (Decode.field "title" Decode.string)
        (Decode.maybe (Decode.field "doc_type" Decode.string))
        (Decode.maybe (Decode.field "created_at" Decode.string))


clusterDecoder : Decoder Cluster
clusterDecoder =
    Decode.map5 Cluster
        (Decode.field "cluster_id" Decode.int)
        (Decode.field "cluster_name" Decode.string)
        (Decode.field "size" Decode.int)
        (Decode.field "documents" (Decode.list clusterDocumentDecoder))
        (Decode.field "representative_document_id" Decode.string)


clusterResponseDecoder : Decoder ClusterResponse
clusterResponseDecoder =
    Decode.map4 ClusterResponse
        (Decode.field "clusters" (Decode.list clusterDecoder))
        (Decode.field "num_clusters" Decode.int)
        (Decode.field "silhouette_score" Decode.float)
        (Decode.field "total_documents" Decode.int)


encodeClusterRequest : Maybe Int -> Encode.Value
encodeClusterRequest numClusters =
    case numClusters of
        Just n ->
            Encode.object [ ( "num_clusters", Encode.int n ) ]
        Nothing ->
            Encode.object []


encodeOpenPDF : String -> Encode.Value
encodeOpenPDF filename =
    Encode.object [ ( "filename", Encode.string filename ) ]


encodeMoveDocument : String -> Encode.Value
encodeMoveDocument targetDatabaseId =
    Encode.object [ ( "target_database_id", Encode.string targetDatabaseId ) ]


encodeImportPDF : String -> Maybe String -> Encode.Value
encodeImportPDF url title =
    Encode.object
        [ ( "url", Encode.string url )
        , ( "title", encodeMaybe Encode.string title )
        ]


databaseInfoDecoder : Decoder DatabaseInfo
databaseInfoDecoder =
    Decode.map6 DatabaseInfo
        (Decode.field "id" Decode.string)
        (Decode.field "name" Decode.string)
        (Decode.field "created_at" Decode.string)
        (Decode.maybe (Decode.field "description" Decode.string))
        (Decode.field "document_count" Decode.int)
        (Decode.field "last_accessed" Decode.string)


encodeCreateDatabase : String -> Maybe String -> Encode.Value
encodeCreateDatabase name description =
    Encode.object
        [ ( "name", Encode.string name )
        , ( "description", encodeMaybe Encode.string description )
        ]


encodeUpdateDatabase : Maybe String -> Maybe String -> Encode.Value
encodeUpdateDatabase name description =
    let
        fields =
            List.filterMap identity
                [ Maybe.map (\n -> ( "name", Encode.string n )) name
                , Maybe.map (\d -> ( "description", Encode.string d )) description
                ]
    in
    Encode.object fields

clusterVisualizationDecoder : Decoder ClusterVisualization
clusterVisualizationDecoder =
    Decode.succeed ClusterVisualization
        |> andMap (Decode.field "clusters" (Decode.list visualizationClusterDecoder))
        |> andMap (Decode.field "documents" (Decode.list visualizationDocumentDecoder))
        |> andMap (Decode.field "explained_variance_ratio" (Decode.list Decode.float))
        |> andMap (Decode.field "voronoi_cells" (Decode.list voronoiCellDecoder))


voronoiCellDecoder : Decoder VoronoiCell
voronoiCellDecoder =
    Decode.map2 VoronoiCell
        (Decode.field "cluster_id" Decode.int)
        (Decode.field "vertices" (Decode.list coordinateDecoder))


coordinateDecoder : Decoder (Float, Float)
coordinateDecoder =
    Decode.map2 Tuple.pair
        (Decode.index 0 Decode.float)
        (Decode.index 1 Decode.float)


visualizationClusterDecoder : Decoder VisualizationCluster
visualizationClusterDecoder =
    Decode.succeed VisualizationCluster
        |> andMap (Decode.field "cluster_id" Decode.int)
        |> andMap (Decode.field "x" Decode.float)
        |> andMap (Decode.field "y" Decode.float)
        |> andMap (Decode.field "size" Decode.int)
        |> andMap (Decode.field "name" Decode.string)


visualizationDocumentDecoder : Decoder VisualizationDocument
visualizationDocumentDecoder =
    Decode.succeed VisualizationDocument
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "title" Decode.string)
        |> andMap (Decode.field "cluster_id" Decode.int)
        |> andMap (Decode.field "x" Decode.float)
        |> andMap (Decode.field "y" Decode.float)
