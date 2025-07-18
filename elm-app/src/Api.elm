module Api exposing (..)

import File exposing (File)
import Http
import Json.Decode as Decode
import Models exposing (..)


type alias Config =
    { apiUrl : String
    }



getDocuments : Config -> (Result Http.Error (List Document) -> msg) -> Cmd msg
getDocuments config msg =
    Http.get
        { url = config.apiUrl ++ "/documents"
        , expect = Http.expectJson msg (Decode.list documentDecoder)
        }


searchDocuments : Config -> String -> Int -> (Result Http.Error (List SearchResult) -> msg) -> Cmd msg
searchDocuments config query limit msg =
    Http.post
        { url = config.apiUrl ++ "/search"
        , body = Http.jsonBody (encodeSearch query limit)
        , expect = Http.expectJson msg (Decode.list searchResultDecoder)
        }


getDocument : Config -> Int -> (Result Http.Error Document -> msg) -> Cmd msg
getDocument config index msg =
    Http.get
        { url = config.apiUrl ++ "/documents/by-index/" ++ String.fromInt index
        , expect = Http.expectJson msg documentDecoder
        }


addDocument : Config -> String -> String -> Maybe String -> String -> Maybe String -> Maybe String -> (Result Http.Error Document -> msg) -> Cmd msg
addDocument config title content docType tags source authors msg =
    Http.post
        { url = config.apiUrl ++ "/documents"
        , body = Http.jsonBody (encodeDocument title content docType tags source authors)
        , expect = Http.expectJson msg documentDecoder
        }


deleteDocument : Config -> String -> (Result Http.Error () -> msg) -> Cmd msg
deleteDocument config docId msg =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = config.apiUrl ++ "/documents/" ++ docId
        , body = Http.emptyBody
        , expect = Http.expectWhatever msg
        , timeout = Nothing
        , tracker = Nothing
        }


renameDocument : Config -> String -> String -> (Result Http.Error () -> msg) -> Cmd msg
renameDocument config docId newTitle msg =
    Http.request
        { method = "PUT"
        , headers = []
        , url = config.apiUrl ++ "/documents/" ++ docId ++ "/rename"
        , body = Http.jsonBody (encodeRename newTitle)
        , expect = Http.expectWhatever msg
        , timeout = Nothing
        , tracker = Nothing
        }


getStats : Config -> (Result Http.Error Stats -> msg) -> Cmd msg
getStats config msg =
    Http.get
        { url = config.apiUrl ++ "/stats"
        , expect = Http.expectJson msg statsDecoder
        }


clearAllDocuments : Config -> (Result Http.Error () -> msg) -> Cmd msg
clearAllDocuments config msg =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = config.apiUrl ++ "/documents/clear-all"
        , body = Http.emptyBody
        , expect = Http.expectWhatever msg
        , timeout = Nothing
        , tracker = Nothing
        }


updateDocument : Config -> String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> (Result Http.Error Document -> msg) -> Cmd msg
updateDocument config docId title content docType tags source authors msg =
    Http.request
        { method = "PUT"
        , headers = []
        , url = config.apiUrl ++ "/documents/" ++ docId
        , body = Http.jsonBody (encodeUpdate title content docType tags Nothing Nothing source authors)
        , expect = Http.expectJson msg documentDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


askClaude : Config -> String -> (Result Http.Error Document -> msg) -> Cmd msg
askClaude config prompt msg =
    Http.post
        { url = config.apiUrl ++ "/claude"
        , body = Http.jsonBody (encodeClaude prompt)
        , expect = Http.expectJson msg documentDecoder
        }


getClusters : Config -> Maybe Int -> (Result Http.Error ClusterResponse -> msg) -> Cmd msg
getClusters config numClusters msg =
    Http.post
        { url = config.apiUrl ++ "/clusters"
        , body = Http.jsonBody (encodeClusterRequest numClusters)
        , expect = Http.expectJson msg clusterResponseDecoder
        }


getClusterVisualization : Config -> (Result Http.Error ClusterVisualization -> msg) -> Cmd msg
getClusterVisualization config msg =
    Http.get
        { url = config.apiUrl ++ "/cluster-visualization"
        , expect = Http.expectJson msg clusterVisualizationDecoder
        }


uploadPDF : Config -> File -> (Result Http.Error Document -> msg) -> Cmd msg
uploadPDF config file msg =
    Http.post
        { url = config.apiUrl ++ "/upload-pdf"
        , body = Http.multipartBody
            [ Http.filePart "file" file
            ]
        , expect = Http.expectJson msg documentDecoder
        }


openPDFNative : Config -> String -> msg -> Cmd msg
openPDFNative config filename msg =
    Http.post
        { url = config.apiUrl ++ "/open-pdf-native"
        , body = Http.jsonBody (encodeOpenPDF filename)
        , expect = Http.expectWhatever (always msg)
        }


importPDFFromURL : Config -> String -> Maybe String -> (Result Http.Error Document -> msg) -> Cmd msg
importPDFFromURL config url title msg =
    Http.post
        { url = config.apiUrl ++ "/import-pdf-url"
        , body = Http.jsonBody (encodeImportPDF url title)
        , expect = Http.expectJson msg documentDecoder
        }


moveDocument : Config -> String -> String -> (Result Http.Error Document -> msg) -> Cmd msg
moveDocument config docId targetDatabaseId msg =
    Http.post
        { url = config.apiUrl ++ "/documents/" ++ docId ++ "/move"
        , body = Http.jsonBody (encodeMoveDocument targetDatabaseId)
        , expect = Http.expectJson msg documentDecoder
        }


-- Database management


getCurrentDatabase : Config -> (Result Http.Error DatabaseInfo -> msg) -> Cmd msg
getCurrentDatabase config msg =
    Http.get
        { url = config.apiUrl ++ "/current-database"
        , expect = Http.expectJson msg databaseInfoDecoder
        }


getDatabases : Config -> (Result Http.Error (List DatabaseInfo) -> msg) -> Cmd msg
getDatabases config msg =
    Http.get
        { url = config.apiUrl ++ "/databases"
        , expect = Http.expectJson msg (Decode.list databaseInfoDecoder)
        }


createDatabase : Config -> String -> Maybe String -> (Result Http.Error DatabaseInfo -> msg) -> Cmd msg
createDatabase config name description msg =
    Http.post
        { url = config.apiUrl ++ "/databases"
        , body = Http.jsonBody (encodeCreateDatabase name description)
        , expect = Http.expectJson msg databaseInfoDecoder
        }


switchDatabase : Config -> String -> (Result Http.Error DatabaseInfo -> msg) -> Cmd msg
switchDatabase config databaseId msg =
    Http.post
        { url = config.apiUrl ++ "/databases/" ++ databaseId ++ "/activate"
        , body = Http.emptyBody
        , expect = Http.expectJson msg databaseInfoDecoder
        }


updateDatabase : Config -> String -> Maybe String -> Maybe String -> (Result Http.Error DatabaseInfo -> msg) -> Cmd msg
updateDatabase config databaseId name description msg =
    Http.request
        { method = "PUT"
        , headers = []
        , url = config.apiUrl ++ "/databases/" ++ databaseId
        , body = Http.jsonBody (encodeUpdateDatabase name description)
        , expect = Http.expectJson msg databaseInfoDecoder
        , timeout = Nothing
        , tracker = Nothing
        }