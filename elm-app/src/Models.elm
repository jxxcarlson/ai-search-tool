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



documentDecoder : Decoder Document
documentDecoder =
    Decode.succeed Document
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "title" Decode.string)
        |> andMap (Decode.field "content" Decode.string)
        |> andMap (Decode.maybe (Decode.field "created_at" Decode.string))
        |> andMap (Decode.maybe (Decode.field "doc_type" Decode.string))
        |> andMap (Decode.maybe (Decode.field "tags" Decode.string))
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



encodeDocument : String -> String -> Maybe String -> String -> Encode.Value
encodeDocument title content docType tags =
    Encode.object
        [ ( "title", Encode.string title )
        , ( "content", Encode.string content )
        , ( "doc_type", encodeMaybe Encode.string docType )
        , ( "tags", if String.isEmpty tags then Encode.null else Encode.string tags )
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


encodeUpdate : Maybe String -> Maybe String -> Maybe String -> Maybe String -> Encode.Value
encodeUpdate title content docType tags =
    let
        fields =
            List.filterMap identity
                [ Maybe.map (\t -> ( "title", Encode.string t )) title
                , Maybe.map (\c -> ( "content", Encode.string c )) content
                , Maybe.map (\d -> ( "doc_type", Encode.string d )) docType
                , Maybe.map (\t -> ( "tags", Encode.string t )) tags
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