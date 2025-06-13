module Models exposing (..)

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


type alias Document =
    { id : String
    , title : String
    , content : String
    , createdAt : Maybe String
    , docType : Maybe String
    , index : Maybe Int
    }


type alias SearchResult =
    { id : String
    , title : String
    , content : String
    , createdAt : Maybe String
    , docType : Maybe String
    , index : Maybe Int
    , similarityScore : Maybe Float
    }


type alias Stats =
    { totalDocuments : Int
    , embeddingDimension : Int
    , model : String
    , storageLocation : String
    , chromaCollectionCount : Int
    }


type alias ApiError =
    { message : String
    , detail : Maybe String
    }



documentDecoder : Decoder Document
documentDecoder =
    Decode.map6 Document
        (Decode.field "id" Decode.string)
        (Decode.field "title" Decode.string)
        (Decode.field "content" Decode.string)
        (Decode.maybe (Decode.field "created_at" Decode.string))
        (Decode.maybe (Decode.field "doc_type" Decode.string))
        (Decode.maybe (Decode.field "index" Decode.int))


searchResultDecoder : Decoder SearchResult
searchResultDecoder =
    Decode.map7 SearchResult
        (Decode.field "id" Decode.string)
        (Decode.field "title" Decode.string)
        (Decode.field "content" Decode.string)
        (Decode.maybe (Decode.field "created_at" Decode.string))
        (Decode.maybe (Decode.field "doc_type" Decode.string))
        (Decode.maybe (Decode.field "index" Decode.int))
        (Decode.maybe (Decode.field "similarity_score" Decode.float))


statsDecoder : Decoder Stats
statsDecoder =
    Decode.map5 Stats
        (Decode.field "total_documents" Decode.int)
        (Decode.field "embedding_dimension" Decode.int)
        (Decode.field "model" Decode.string)
        (Decode.field "storage_location" Decode.string)
        (Decode.field "chroma_collection_count" Decode.int)


apiErrorDecoder : Decoder ApiError
apiErrorDecoder =
    Decode.map2 ApiError
        (Decode.field "message" Decode.string)
        (Decode.maybe (Decode.field "detail" Decode.string))



encodeDocument : String -> String -> Maybe String -> Encode.Value
encodeDocument title content docType =
    Encode.object
        [ ( "title", Encode.string title )
        , ( "content", Encode.string content )
        , ( "doc_type", encodeMaybe Encode.string docType )
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


encodeUpdate : Maybe String -> Maybe String -> Maybe String -> Encode.Value
encodeUpdate title content docType =
    let
        fields =
            List.filterMap identity
                [ Maybe.map (\t -> ( "title", Encode.string t )) title
                , Maybe.map (\c -> ( "content", Encode.string c )) content
                , Maybe.map (\d -> ( "doc_type", Encode.string d )) docType
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