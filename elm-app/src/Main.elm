module Main exposing (main)

import Api
import Browser
import Browser.Dom
import Browser.Events
import Element
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Decode
import Markdown.Html
import Markdown.Parser
import Markdown.Renderer
import Models exposing (..)
import Random
import Random.List
import Render.Helper
import ScriptaV2.APISimple
import ScriptaV2.Compiler
import ScriptaV2.Language
import ScriptaV2.Msg exposing (MarkupMsg)
import Task
import Time


type alias Model =
    { config : Api.Config
    , documents : List Document
    , searchResults : List SearchResult
    , selectedDocument : Maybe Document
    , searchQuery : String
    , loading : Bool
    , error : Maybe String
    , view : View
    , newDocument : NewDocument
    , stats : Maybe Stats
    , editingDocument : Maybe EditingDocument
    , randomDocuments : List Document
    , claudePrompt : String
    , claudeLoading : Bool
    , claudeResponse : Maybe Document
    , justSavedClaude : Bool
    , clusters : Maybe ClusterResponse
    , clusterLoading : Bool
    , windowWidth : Int
    }


type alias NewDocument =
    { title : String
    , content : String
    , docType : DocType
    }


docTypeToString : DocType -> String
docTypeToString docType =
    case docType of
        DTMarkDown ->
            "md"

        DTScripta ->
            "scr"

        DTLaTeX ->
            "ltx"

        DTClaudeResponse ->
            "claude-response"


type alias EditingDocument =
    { id : String
    , title : String
    , content : String
    , docType : Maybe String
    }


type View
    = ListView
    | SearchView
    | DocumentView
    | AddDocumentView
    | StatsView
    | RandomView
    | ClaudeView
    | ClustersView


type Msg
    = NoOp
    | LoadDocuments
    | GotDocuments (Result Http.Error (List Document))
    | SearchDocuments
    | GotSearchResults (Result Http.Error (List SearchResult))
    | UpdateSearchQuery String
    | SelectDocument Document
    | ChangeView View
    | DeleteDocument String
    | DocumentDeleted (Result Http.Error ())
    | UpdateNewDocTitle String
    | UpdateNewDocContent String
    | UpdateNewDocType String
    | AddDocument
    | DocumentAdded (Result Http.Error Document)
    | LoadStats
    | GotStats (Result Http.Error Stats)
    | ClearError
    | LoadRandomDocuments
    | GotCurrentTime Time.Posix
    | GotRandomDocuments (List Document)
    | StartEditingDocument Document
    | CancelEditingDocument
    | UpdateEditingTitle String
    | UpdateEditingContent String
    | UpdateEditingDocType String
    | SaveEditingDocument
    | DocumentRenamed (Result Http.Error ())
    | DocumentUpdated (Result Http.Error Document)
    | UpdateClaudePrompt String
    | SendClaudePrompt
    | ClaudeResponseReceived (Result Http.Error Document)
    | SaveClaudeResponse
    | NewClaudeQuestion
    | LoadClusters
    | GotClusters (Result Http.Error ClusterResponse)
    | SelectDocumentFromCluster String
    | ScriptaDocument ScriptaV2.Msg.MarkupMsg
    | WindowResized Int Int
    | GotViewport Browser.Dom.Viewport


type DocType
    = DTMarkDown
    | DTScripta
    | DTLaTeX
    | DTClaudeResponse


docTypeFromString : String -> DocType
docTypeFromString str =
    case String.toLower str of
        "md" ->
            DTMarkDown

        "scr" ->
            DTScripta

        "ltx" ->
            DTLaTeX

        "claude-response" ->
            DTClaudeResponse

        _ ->
            DTMarkDown


type alias Flags =
    { apiUrl : String
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { config = Api.Config flags.apiUrl
      , documents = []
      , searchResults = []
      , selectedDocument = Nothing
      , searchQuery = ""
      , loading = False
      , error = Nothing
      , view = ListView
      , newDocument = NewDocument "" "" DTMarkDown
      , stats = Nothing
      , editingDocument = Nothing
      , randomDocuments = []
      , claudePrompt = ""
      , claudeLoading = False
      , claudeResponse = Nothing
      , justSavedClaude = False
      , clusters = Nothing
      , clusterLoading = False
      , windowWidth = 800 -- Default width
      }
    , Cmd.batch
        [ Api.getDocuments (Api.Config flags.apiUrl) GotDocuments
        , Task.perform GotViewport Browser.Dom.getViewport
        ]
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        LoadDocuments ->
            ( { model | loading = True }
            , Api.getDocuments model.config GotDocuments
            )

        GotDocuments result ->
            case result of
                Ok documents ->
                    ( { model | documents = documents, loading = False, error = Nothing }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | loading = False, error = Just (httpErrorToString error) }
                    , Cmd.none
                    )

        SearchDocuments ->
            if String.isEmpty model.searchQuery then
                ( model, Cmd.none )

            else
                ( { model | loading = True, view = SearchView }
                , Api.searchDocuments model.config model.searchQuery 10 GotSearchResults
                )

        GotSearchResults result ->
            case result of
                Ok results ->
                    ( { model | searchResults = results, loading = False, error = Nothing }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | loading = False, error = Just (httpErrorToString error) }
                    , Cmd.none
                    )

        UpdateSearchQuery query ->
            ( { model | searchQuery = query }, Cmd.none )

        SelectDocument document ->
            ( { model | selectedDocument = Just document, view = DocumentView }
            , Cmd.none
            )

        ChangeView newView ->
            ( { model | view = newView, justSavedClaude = False }, Cmd.none )

        DeleteDocument docId ->
            ( { model | loading = True }
            , Api.deleteDocument model.config docId DocumentDeleted
            )

        DocumentDeleted result ->
            case result of
                Ok _ ->
                    ( { model
                        | loading = False
                        , error = Nothing
                        , selectedDocument = Nothing
                        , view = ListView
                        , justSavedClaude = False
                      }
                    , Api.getDocuments model.config GotDocuments
                    )

                Err error ->
                    ( { model | loading = False, error = Just (httpErrorToString error) }
                    , Cmd.none
                    )

        UpdateNewDocTitle value ->
            let
                newDoc =
                    model.newDocument
            in
            ( { model | newDocument = { newDoc | title = value } }, Cmd.none )

        UpdateNewDocContent value ->
            let
                newDoc =
                    model.newDocument
            in
            ( { model | newDocument = { newDoc | content = value } }, Cmd.none )

        UpdateNewDocType value ->
            let
                newDocument_ =
                    model.newDocument

                docType =
                    docTypeFromString value
            in
            ( { model | newDocument = { newDocument_ | docType = docType } }, Cmd.none )

        AddDocument ->
            let
                docType =
                    docTypeFromString "md" |> Just

                --if String.isEmpty model.newDocument.docType then
                --    Nothing
                --
                --else
                --    Just model.newDocument.docType
            in
            ( { model | loading = True }
            , Api.addDocument model.config
                model.newDocument.title
                model.newDocument.content
                (Just "scr")
                DocumentAdded
            )

        DocumentAdded result ->
            case result of
                Ok _ ->
                    ( { model
                        | loading = False
                        , error = Nothing
                        , view = ListView
                        , newDocument = NewDocument "" "" DTMarkDown
                      }
                    , Api.getDocuments model.config GotDocuments
                    )

                Err error ->
                    ( { model | loading = False, error = Just (httpErrorToString error) }
                    , Cmd.none
                    )

        LoadStats ->
            ( { model | loading = True, view = StatsView }
            , Api.getStats model.config GotStats
            )

        GotStats result ->
            case result of
                Ok stats ->
                    ( { model | stats = Just stats, loading = False, error = Nothing }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | loading = False, error = Just (httpErrorToString error) }
                    , Cmd.none
                    )

        ClearError ->
            ( { model | error = Nothing }, Cmd.none )

        LoadRandomDocuments ->
            ( { model | view = RandomView }
            , Task.perform GotCurrentTime Time.now
            )

        GotCurrentTime time ->
            let
                seed =
                    Random.initialSeed (Time.posixToMillis time)

                ( randomDocs, _ ) =
                    Random.step (shuffleAndTake 10 model.documents) seed
            in
            ( { model | randomDocuments = randomDocs }, Cmd.none )

        GotRandomDocuments docs ->
            ( { model | randomDocuments = docs }, Cmd.none )

        StartEditingDocument doc ->
            ( { model | editingDocument = Just (EditingDocument doc.id doc.title doc.content doc.docType) }
            , Cmd.none
            )

        CancelEditingDocument ->
            ( { model | editingDocument = Nothing }, Cmd.none )

        UpdateEditingTitle title ->
            case model.editingDocument of
                Just editing ->
                    ( { model | editingDocument = Just { editing | title = title } }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        UpdateEditingContent content ->
            case model.editingDocument of
                Just editing ->
                    ( { model | editingDocument = Just { editing | content = content } }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        UpdateEditingDocType docType ->
            case model.editingDocument of
                Just editing ->
                    ( { model
                        | editingDocument =
                            Just
                                { editing
                                    | docType =
                                        if String.isEmpty docType then
                                            Nothing

                                        else
                                            Just docType
                                }
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        SaveEditingDocument ->
            case model.editingDocument of
                Just editing ->
                    ( { model | loading = True }
                    , Api.updateDocument model.config
                        editing.id
                        (Just editing.title)
                        (Just editing.content)
                        editing.docType
                        DocumentUpdated
                    )

                Nothing ->
                    ( model, Cmd.none )

        DocumentRenamed result ->
            case result of
                Ok _ ->
                    let
                        updatedSelectedDoc =
                            case ( model.selectedDocument, model.editingDocument ) of
                                ( Just doc, Just editing ) ->
                                    if doc.id == editing.id then
                                        Just { doc | title = editing.title }

                                    else
                                        model.selectedDocument

                                _ ->
                                    model.selectedDocument
                    in
                    ( { model
                        | loading = False
                        , error = Nothing
                        , editingDocument = Nothing
                        , selectedDocument = updatedSelectedDoc
                      }
                    , Api.getDocuments model.config GotDocuments
                    )

                Err error ->
                    ( { model | loading = False, error = Just (httpErrorToString error) }
                    , Cmd.none
                    )

        DocumentUpdated result ->
            case result of
                Ok updatedDoc ->
                    ( { model
                        | loading = False
                        , error = Nothing
                        , editingDocument = Nothing
                        , selectedDocument = Just updatedDoc
                      }
                    , Api.getDocuments model.config GotDocuments
                    )

                Err error ->
                    ( { model | loading = False, error = Just (httpErrorToString error) }
                    , Cmd.none
                    )

        UpdateClaudePrompt prompt ->
            ( { model | claudePrompt = prompt }, Cmd.none )

        SendClaudePrompt ->
            if String.isEmpty model.claudePrompt then
                ( model, Cmd.none )

            else
                ( { model | claudeLoading = True, error = Nothing }
                , Api.askClaude model.config model.claudePrompt ClaudeResponseReceived
                )

        ClaudeResponseReceived result ->
            case result of
                Ok document ->
                    ( { model
                        | claudeLoading = False
                        , claudeResponse = Just document
                        , error = Nothing
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | claudeLoading = False, error = Just (httpErrorToString error) }
                    , Cmd.none
                    )

        SaveClaudeResponse ->
            case model.claudeResponse of
                Just document ->
                    ( { model
                        | claudePrompt = ""
                        , claudeResponse = Nothing
                        , selectedDocument = Just document
                        , view = DocumentView
                        , justSavedClaude = True
                      }
                    , Api.getDocuments model.config GotDocuments
                    )

                Nothing ->
                    ( model, Cmd.none )

        NewClaudeQuestion ->
            ( { model
                | claudePrompt = ""
                , claudeResponse = Nothing
              }
            , Cmd.none
            )

        LoadClusters ->
            ( { model | clusterLoading = True, view = ClustersView }
            , Api.getClusters model.config Nothing GotClusters
            )

        GotClusters result ->
            case result of
                Ok clusterResponse ->
                    ( { model
                        | clusterLoading = False
                        , clusters = Just clusterResponse
                        , error = Nothing
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | clusterLoading = False, error = Just (httpErrorToString error) }
                    , Cmd.none
                    )

        SelectDocumentFromCluster docId ->
            case List.filter (\doc -> doc.id == docId) model.documents of
                doc :: _ ->
                    ( { model | selectedDocument = Just doc, view = DocumentView }
                    , Cmd.none
                    )

                [] ->
                    ( model, Cmd.none )

        ScriptaDocument _ ->
            ( model, Cmd.none )

        WindowResized width _ ->
            ( { model | windowWidth = width }, Cmd.none )

        GotViewport viewport ->
            ( { model | windowWidth = round viewport.viewport.width }, Cmd.none )


httpErrorToString : Http.Error -> String
httpErrorToString error =
    case error of
        Http.BadUrl url ->
            "Invalid URL: " ++ url

        Http.Timeout ->
            "Request timed out"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus statusCode ->
            "Bad status: " ++ String.fromInt statusCode

        Http.BadBody body ->
            "Bad response body: " ++ body


view : Model -> Html Msg
view model =
    div [ class "app-container" ]
        [ viewHeader model
        , viewError model.error
        , case model.view of
            ListView ->
                viewDocumentList model

            SearchView ->
                viewSearchResults model

            DocumentView ->
                viewDocument model

            AddDocumentView ->
                viewAddDocument model

            StatsView ->
                viewStats model

            RandomView ->
                viewRandomDocuments model

            ClaudeView ->
                viewClaude model

            ClustersView ->
                viewClusters model
        ]


viewHeader : Model -> Html Msg
viewHeader model =
    header [ class "app-header" ]
        [ h1 [] [ text "AI Search Tool" ]
        , nav []
            [ button [ onClick (ChangeView ListView), class "nav-button" ] [ text "Documents" ]
            , button [ onClick (ChangeView AddDocumentView), class "nav-button" ] [ text "Add Document" ]
            , button [ onClick (ChangeView ClaudeView), class "nav-button" ] [ text "Ask Claude" ]
            , button [ onClick LoadRandomDocuments, class "nav-button" ] [ text "Random" ]
            , button [ onClick LoadClusters, class "nav-button" ] [ text "Clusters" ]
            , button [ onClick LoadStats, class "nav-button" ] [ text "Stats" ]
            ]
        , div [ class "search-bar" ]
            [ input
                [ type_ "text"
                , placeholder "Search documents..."
                , value model.searchQuery
                , onInput UpdateSearchQuery
                , onEnter SearchDocuments
                , class "search-input"
                ]
                []
            , button [ onClick SearchDocuments, class "search-button" ] [ text "Search" ]
            ]
        ]


viewError : Maybe String -> Html Msg
viewError maybeError =
    case maybeError of
        Just error ->
            div [ class "error-message" ]
                [ text error
                , button [ onClick ClearError, class "close-button" ] [ text "×" ]
                ]

        Nothing ->
            text ""


viewDocumentList : Model -> Html Msg
viewDocumentList model =
    div [ class "document-list" ]
        [ h2 [] [ text "Documents" ]
        , if model.loading then
            div [ class "loading" ] [ text "Loading..." ]

          else if List.isEmpty model.documents then
            div [ class "empty-state" ] [ text "No documents found" ]

          else
            div [ class "documents-grid" ]
                (List.map viewDocumentCard (sortDocumentsByDate model.documents))
        ]


viewDocumentCard : Document -> Html Msg
viewDocumentCard doc =
    div [ class "document-card", onClick (SelectDocument doc) ]
        [ h3 [] [ text doc.title ]
        , div [ class "document-meta" ]
            [ span [ class "created-at" ] [ text (formatDate doc.createdAt) ]
            , case doc.docType of
                Just dt ->
                    span [ class "category" ] [ text dt ]

                Nothing ->
                    text ""
            ]

        -- Tags removed from API
        , div [ class "content-preview" ] [ text (truncate 150 doc.content) ]
        ]


viewSearchResults : Model -> Html Msg
viewSearchResults model =
    div [ class "search-results" ]
        [ h2 [] [ text ("Search Results for: " ++ model.searchQuery) ]
        , if model.loading then
            div [ class "loading" ] [ text "Searching..." ]

          else if List.isEmpty model.searchResults then
            div [ class "empty-state" ] [ text "No results found" ]

          else
            div [ class "results-list" ]
                (List.map viewSearchResult model.searchResults)
        ]


viewSearchResult : SearchResult -> Html Msg
viewSearchResult result =
    div [ class "search-result", onClick (SelectDocument { id = result.id, title = result.title, content = result.content, createdAt = result.createdAt, docType = result.docType, index = result.index }) ]
        [ h3 [] [ text result.title ]
        , div [ class "document-meta" ]
            [ span [ class "created-at" ] [ text (formatDate result.createdAt) ]
            , case result.docType of
                Just dt ->
                    span [ class "category" ] [ text dt ]

                Nothing ->
                    text ""
            ]
        , case result.similarityScore of
            Just score ->
                div [ class "similarity" ] [ text (formatPercent score ++ " match") ]

            Nothing ->
                text ""
        , div [ class "snippet" ] [ text (truncate 150 result.content) ]
        ]


viewDocument : Model -> Html Msg
viewDocument model =
    case model.selectedDocument of
        Just doc ->
            case model.editingDocument of
                Just editing ->
                    if editing.id == doc.id then
                        viewEditingDocument editing

                    else
                        viewReadOnlyDocument model doc

                Nothing ->
                    viewReadOnlyDocument model doc

        Nothing ->
            div [] [ text "No document selected" ]


type alias ScriptaDocInfo =
    { lang : ScriptaV2.Language.Language
    , createdAt : Maybe String
    , docType : DocType
    , title : String
    , sourceText : String
    }


viewReadOnlyDocument : Model -> Document -> Html Msg
viewReadOnlyDocument model doc =
    let
        -- Calculate document width based on window width with some padding
        -- Accounting for margins, padding, and other UI elements
        _ =
            Debug.log "viewReadOnlyDocument" ( doc.title, doc.docType )

        _ =
            case doc.docType of
                Just dt ->
                    Debug.log "docType is Just" dt

                Nothing ->
                    Debug.log "docType is Nothing" "nothing"

        docWidth =
            Basics.max 300 (model.windowWidth - 200)

        -- Minimum 300px, leave 200px for margins/padding
        params =
            { lang = ScriptaV2.Language.EnclosureLang
            , docWidth = docWidth
            , editCount = 1
            , selectedId = "selectedId"
            , idsOfOpenNodes = []
            , filter = ScriptaV2.Compiler.NoFilter
            }
    in
    div [ class "document-view" ]
        [ button [ onClick (ChangeView ListView), class "back-button" ] [ text "← Back" ]
        , h2 [] [ text doc.title ]
        , div [ class "document-meta" ]
            [ span [ class "created-at" ] [ text ("Created: " ++ formatDate doc.createdAt) ]
            , case doc.docType of
                Just dt ->
                    span [ class "category" ] [ text ("Type: " ++ dt) ]

                Nothing ->
                    text ""
            ]
        , div [ class "document-actions" ]
            [ button [ onClick (StartEditingDocument doc), class "edit-button" ] [ text "Edit" ]
            , button [ onClick (DeleteDocument doc.id), class "delete-button" ] [ text "Delete" ]
            ]
        , case doc.docType of
            Just "scr" ->
                div
                    [ class "document-content"
                    , Html.Attributes.style "width" (String.fromInt (docWidth - 80) ++ "px")
                    , Html.Attributes.style "font-size" (String.fromInt 12 ++ "px")
                    ]
                    (ScriptaV2.APISimple.compile params doc.content
                        |> List.map (Element.map ScriptaDocument >> Element.layout [ Render.Helper.htmlId "rendered-text" ])
                    )

            Just "ltx" ->
                div
                    [ class "document-content"
                    , Html.Attributes.style "width" (String.fromInt docWidth ++ "px")
                    , Html.Attributes.style "font-size" (String.fromInt 12 ++ "px")
                    ]
                    (ScriptaV2.APISimple.compile { params | lang = ScriptaV2.Language.MicroLaTeXLang } doc.content
                        |> List.map (Element.map ScriptaDocument >> Element.layout [ Render.Helper.htmlId "rendered-text" ])
                    )

            Just "md" ->
                div [ class "document-content" ]
                    [ renderMarkdown doc.content ]

            Just "claude-response" ->
                div [ class "document-content" ]
                    [ renderMarkdown doc.content ]

            _ ->
                div [ class "document-content" ]
                    [ Html.text "Unsupported document type" ]
        , if model.justSavedClaude then
            div [ class "document-actions", style "margin-top" "2rem" ]
                [ button
                    [ onClick (ChangeView ClaudeView)
                    , class "submit-button"
                    ]
                    [ text "Ask another question" ]
                ]

          else
            text ""
        ]


viewEditingDocument : EditingDocument -> Html Msg
viewEditingDocument editing =
    div [ class "document-view editing" ]
        [ button [ onClick (ChangeView ListView), class "back-button" ] [ text "← Back" ]
        , h2 [] [ text editing.title ]
        , div [ class "document-meta" ]
            [ span [ class "editing-label" ] [ text "Editing mode" ]
            ]
        , div [ class "document-actions" ]
            [ button
                [ onClick SaveEditingDocument
                , class "save-button"
                , disabled (String.isEmpty editing.title || String.isEmpty editing.content)
                ]
                [ text "Save" ]
            , button
                [ onClick CancelEditingDocument
                , class "cancel-button"
                ]
                [ text "Cancel" ]
            ]
        , div [ class "form" ]
            [ div [ class "form-group" ]
                [ label [] [ text "Title" ]
                , input
                    [ type_ "text"
                    , value editing.title
                    , onInput UpdateEditingTitle
                    , class "form-input"
                    ]
                    []
                ]
            , div [ class "form-group" ]
                [ label [] [ text "Content" ]
                , textarea
                    [ value editing.content
                    , onInput UpdateEditingContent
                    , class "form-textarea"
                    , rows 15
                    ]
                    []
                ]
            , div [ class "form-group" ]
                [ label [] [ text "Document Type (optional)" ]
                , input
                    [ type_ "text"
                    , value (Maybe.withDefault "" editing.docType)
                    , onInput UpdateEditingDocType
                    , class "form-input"
                    ]
                    []
                ]
            ]
        ]


viewAddDocument : Model -> Html Msg
viewAddDocument model =
    div [ class "add-document" ]
        [ h2 [] [ text "Add New Document" ]
        , div [ class "form" ]
            [ div [ class "form-group" ]
                [ label [] [ text "Title" ]
                , input
                    [ type_ "text"
                    , value model.newDocument.title
                    , onInput UpdateNewDocTitle
                    , class "form-input"
                    ]
                    []
                ]
            , div [ class "form-group" ]
                [ label [] [ text "Content" ]
                , textarea
                    [ value model.newDocument.content
                    , onInput UpdateNewDocContent
                    , class "form-textarea"
                    , rows 10
                    ]
                    []
                ]
            , div [ class "form-group" ]
                [ label [] [ text "Document Type (optional)" ]
                , input
                    [ type_ "text"
                    , value (docTypeToString model.newDocument.docType)
                    , onInput UpdateNewDocType
                    , class "form-input"
                    ]
                    []
                ]

            -- Tags input removed
            , button
                [ onClick AddDocument
                , class "submit-button"
                , disabled (String.isEmpty model.newDocument.title || String.isEmpty model.newDocument.content)
                ]
                [ text "Add Document" ]
            ]
        ]


viewRandomDocuments : Model -> Html Msg
viewRandomDocuments model =
    div [ class "document-list" ]
        [ h2 [] [ text "Random Documents" ]
        , div [ style "margin-bottom" "1rem" ]
            [ button [ onClick LoadRandomDocuments, class "nav-button" ] [ text "Shuffle" ]
            ]
        , if List.isEmpty model.randomDocuments then
            div [ class "empty-state" ] [ text "No documents available" ]

          else
            div [ class "documents-grid" ]
                (List.map viewDocumentCard model.randomDocuments)
        ]


viewClaude : Model -> Html Msg
viewClaude model =
    div [ class "claude-view" ]
        [ h2 [] [ text "Ask Claude" ]
        , case model.claudeResponse of
            Just response ->
                div []
                    [ div [ class "claude-response" ]
                        [ h3 [] [ text response.title ]
                        , div [ class "document-content" ] [ renderMarkdown response.content ]
                        , div [ class "form-actions" ]
                            [ button
                                [ onClick SaveClaudeResponse
                                , class "save-button"
                                ]
                                [ text "Save" ]
                            , button
                                [ onClick NewClaudeQuestion
                                , class "cancel-button"
                                ]
                                [ text "New Question" ]
                            ]
                        ]
                    ]

            Nothing ->
                div [ class "claude-form" ]
                    [ div [ class "form-group" ]
                        [ label [] [ text "Your prompt:" ]
                        , textarea
                            [ value model.claudePrompt
                            , onInput UpdateClaudePrompt
                            , placeholder "Ask Claude anything..."
                            , class "form-textarea"
                            , rows 10
                            , disabled model.claudeLoading
                            ]
                            []
                        ]
                    , button
                        [ onClick SendClaudePrompt
                        , class "submit-button"
                        , disabled (String.isEmpty model.claudePrompt || model.claudeLoading)
                        ]
                        [ if model.claudeLoading then
                            text "Asking Claude..."

                          else
                            text "Send to Claude"
                        ]
                    , div [ class "claude-info" ]
                        [ p [] [ text "Claude will respond to your prompt. You can then choose to save it as a document." ]
                        , p [] [ text "Saved documents can be searched, edited, or referenced like any other document." ]
                        ]
                    ]
        ]


viewStats : Model -> Html Msg
viewStats model =
    case model.stats of
        Just stats ->
            div [ class "stats-view" ]
                [ h2 [] [ text "Statistics" ]
                , div [ class "stats-grid" ]
                    [ div [ class "stat-card" ]
                        [ h3 [] [ text "Total Documents" ]
                        , p [ class "stat-value" ] [ text (String.fromInt stats.totalDocuments) ]
                        ]
                    , div [ class "stat-card" ]
                        [ h3 [] [ text "Vector Collections" ]
                        , p [ class "stat-value" ] [ text (String.fromInt stats.chromaCollectionCount) ]
                        ]
                    , div [ class "stat-card" ]
                        [ h3 [] [ text "Embedding Dimension" ]
                        , p [ class "stat-value" ] [ text (String.fromInt stats.embeddingDimension) ]
                        ]
                    ]
                , div [ class "model-info" ]
                    [ p [] [ strong [] [ text "Model: " ], text stats.model ]
                    , p [] [ strong [] [ text "Storage: " ], text stats.storageLocation ]
                    ]
                ]

        Nothing ->
            if model.loading then
                div [ class "loading" ] [ text "Loading stats..." ]

            else
                div [] [ text "No stats available" ]


formatDate : Maybe String -> String
formatDate maybeDate =
    case maybeDate of
        Just dateStr ->
            formatDateTime dateStr

        Nothing ->
            "Unknown"


formatDateTime : String -> String
formatDateTime isoString =
    -- For now, we'll do a simple formatting
    -- ISO format example: "2025-06-12T15:30:45.123456"
    let
        parts =
            String.split "T" isoString

        datePart =
            List.head parts |> Maybe.withDefault ""

        timePart =
            List.head (List.drop 1 parts) |> Maybe.withDefault ""

        -- Parse date
        dateParts =
            String.split "-" datePart

        year =
            List.head dateParts |> Maybe.withDefault ""

        month =
            List.head (List.drop 1 dateParts) |> Maybe.withDefault ""

        day =
            List.head (List.drop 2 dateParts) |> Maybe.withDefault ""

        -- Parse time
        timeWithoutMs =
            String.split "." timePart |> List.head |> Maybe.withDefault ""

        timeParts =
            String.split ":" timeWithoutMs

        hour =
            List.head timeParts |> Maybe.andThen String.toInt |> Maybe.withDefault 0

        minute =
            List.head (List.drop 1 timeParts) |> Maybe.withDefault "00"

        -- Convert to 12-hour format
        ( hour12, ampm ) =
            if hour == 0 then
                ( 12, "am" )

            else if hour < 12 then
                ( hour, "am" )

            else if hour == 12 then
                ( 12, "pm" )

            else
                ( hour - 12, "pm" )

        monthName =
            case month of
                "01" ->
                    "January"

                "02" ->
                    "February"

                "03" ->
                    "March"

                "04" ->
                    "April"

                "05" ->
                    "May"

                "06" ->
                    "June"

                "07" ->
                    "July"

                "08" ->
                    "August"

                "09" ->
                    "September"

                "10" ->
                    "October"

                "11" ->
                    "November"

                "12" ->
                    "December"

                _ ->
                    month

        -- Remove leading zero from day
        dayNum =
            String.toInt day |> Maybe.map String.fromInt |> Maybe.withDefault day
    in
    if String.isEmpty datePart then
        isoString

    else
        monthName ++ " " ++ dayNum ++ ", " ++ year ++ " " ++ String.fromInt hour12 ++ ":" ++ minute ++ " " ++ ampm


truncate : Int -> String -> String
truncate maxLength str =
    if String.length str > maxLength then
        String.left maxLength str ++ "..."

    else
        str


sortDocumentsByDate : List Document -> List Document
sortDocumentsByDate documents =
    List.sortBy
        (\doc ->
            case doc.createdAt of
                Just date ->
                    -- Negate the timestamp to sort in descending order
                    -- (most recent first)
                    -(dateToComparable date)

                Nothing ->
                    0
        )
        documents


dateToComparable : String -> Float
dateToComparable dateStr =
    -- Convert ISO date string to a comparable number
    -- For simplicity, we'll remove non-numeric characters and convert to float
    dateStr
        |> String.replace "-" ""
        |> String.replace "T" ""
        |> String.replace ":" ""
        |> String.replace "." ""
        |> String.left 14
        -- Take only up to seconds
        |> String.toFloat
        |> Maybe.withDefault 0


formatPercent : Float -> String
formatPercent score =
    let
        percent =
            score * 100

        rounded =
            toFloat (round (percent * 100)) / 100
    in
    String.fromFloat rounded ++ "%"


viewClusters : Model -> Html Msg
viewClusters model =
    div [ class "clusters-view" ]
        [ h2 [] [ text "Document Clusters" ]
        , if model.clusterLoading then
            div [ class "loading" ] [ text "Analyzing document clusters..." ]

          else
            case model.clusters of
                Just clusterResponse ->
                    div []
                        [ div [ class "cluster-info" ]
                            [ p [] [ text ("Found " ++ String.fromInt clusterResponse.numClusters ++ " clusters") ]
                            , p [] [ text ("Silhouette score: " ++ String.fromFloat (toFloat (round (clusterResponse.silhouetteScore * 100)) / 100)) ]
                            ]
                        , div [ class "clusters-grid" ]
                            (List.map (viewCluster model) clusterResponse.clusters)
                        ]

                Nothing ->
                    div [ class "empty-state" ] [ text "No clusters loaded. Click 'Clusters' to analyze." ]
        ]


viewCluster : Model -> Cluster -> Html Msg
viewCluster model cluster =
    let
        representativeDoc =
            List.filter (\doc -> doc.id == cluster.representativeDocumentId) model.documents
                |> List.head

        representativeTitle =
            case representativeDoc of
                Just doc ->
                    doc.title

                Nothing ->
                    "Unknown"

        totalDocs =
            case model.clusters of
                Just clusterResponse ->
                    clusterResponse.totalDocuments

                Nothing ->
                    0
    in
    div [ class "cluster-card" ]
        [ h3 [] [ text (String.fromInt (cluster.clusterId + 1) ++ ". " ++ cluster.clusterName ++ " (" ++ String.fromInt cluster.size ++ "/" ++ String.fromInt totalDocs ++ ")") ]
        , p [ class "cluster-representative" ]
            [ text ("Representative: " ++ representativeTitle)
            ]
        , div [ class "cluster-documents" ]
            [ h4 [] [ text "Documents:" ]
            , ul []
                (List.map viewClusterDocument cluster.documents)
            ]
        ]


viewClusterDocument : ClusterDocument -> Html Msg
viewClusterDocument doc =
    li []
        [ a
            [ href "#"
            , onClick (SelectDocumentFromCluster doc.id)
            , style "cursor" "pointer"
            , style "color" "#2563eb"
            ]
            [ text doc.title ]
        , case doc.docType of
            Just docType ->
                span [ class "doc-type-badge" ] [ text (" (" ++ docType ++ ")") ]

            Nothing ->
                text ""
        ]


renderMarkdown : String -> Html msg
renderMarkdown markdown =
    case Markdown.Parser.parse markdown of
        Ok blocks ->
            case Markdown.Renderer.render Markdown.Renderer.defaultHtmlRenderer blocks of
                Ok html ->
                    div [] html

                Err _ ->
                    text markdown

        Err _ ->
            text markdown


onEnter : msg -> Attribute msg
onEnter msg =
    let
        isEnter code =
            if code == 13 then
                Decode.succeed msg

            else
                Decode.fail "not ENTER"
    in
    on "keydown" (Decode.andThen isEnter keyCode)


keyCode : Decode.Decoder Int
keyCode =
    Decode.field "keyCode" Decode.int


shuffleAndTake : Int -> List a -> Random.Generator (List a)
shuffleAndTake n list =
    Random.List.shuffle list
        |> Random.map (List.take n)


subscriptions : Model -> Sub Msg
subscriptions _ =
    Browser.Events.onResize WindowResized


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
