module Main exposing (main)

import Api
import Browser
import Browser.Dom
import Browser.Events
import Element
import File exposing (File)
import File.Select
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onClick, onInput, stopPropagationOn)
import Http
import Svg exposing (svg, circle, line, g, text_, path)
import Svg.Attributes as SvgAttr
import Svg.Events as SvgEvents
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
    , selectedPDF : Maybe File
    , expandedClusters : List Int
    , currentDatabase : Maybe DatabaseInfo
    , databases : List DatabaseInfo
    , showDatabaseMenu : Bool
    , showCreateDatabaseModal : Bool
    , newDatabaseName : String
    , newDatabaseDescription : String
    , showMoveDocumentModal : Bool
    , moveDocumentId : Maybe String
    , moveTargetDatabaseId : Maybe String
    , showPDFImportModal : Bool
    , pdfImportURL : String
    , pdfImportTitle : String
    , showAddDocumentMenu : Bool
    , clusterVisualization : Maybe ClusterVisualization
    , showEditDatabaseModal : Bool
    , editDatabaseId : Maybe String
    , editDatabaseName : String
    , editDatabaseDescription : String
    , showGraphWindow : Bool
    , graphWindowPosition : { x : Int, y : Int }
    , graphWindowSize : { width : Int, height : Int }
    , graphWindowDragging : Maybe { startX : Int, startY : Int, offsetX : Int, offsetY : Int }
    , graphWindowResizing : Maybe { edge : ResizeEdge }
    }


type ResizeEdge
    = TopEdge
    | RightEdge
    | BottomEdge
    | LeftEdge
    | TopRightCorner
    | BottomRightCorner
    | BottomLeftCorner
    | TopLeftCorner


type alias NewDocument =
    { title : String
    , content : String
    , docType : DocType
    , tags : String
    , source : String
    , authors : String
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

        DTPDF ->
            "pdf"


type alias EditingDocument =
    { id : String
    , title : String
    , content : String
    , docType : Maybe String
    , tags : String
    , source : String
    , authors : String
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
    | UpdateNewDocTags String
    | UpdateNewDocSource String
    | UpdateNewDocAuthors String
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
    | UpdateEditingTags String
    | UpdateEditingSource String
    | UpdateEditingAuthors String
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
    | ShowMoveDocumentModal String
    | CancelMoveDocument
    | SelectTargetDatabase String
    | ConfirmMoveDocument
    | DocumentMoved (Result Http.Error Document)
    | GotViewport Browser.Dom.Viewport
    | SelectPDFFile
    | PDFSelected File
    | PDFUploaded (Result Http.Error Document)
    | UploadPDF
    | OpenPDFNative String
    | ShowPDFImportModal
    | HidePDFImportModal
    | UpdatePDFImportURL String
    | UpdatePDFImportTitle String
    | ImportPDFFromURL
    | PDFImported (Result Http.Error Document)
    | KeyPressed String
    | ToggleClusterExpansion Int
    | ToggleAddDocumentMenu
    | NavigateToCluster Int
    | GotClusterVisualization (Result Http.Error ClusterVisualization)
    | GotCurrentDatabase (Result Http.Error DatabaseInfo)
    | GotDatabases (Result Http.Error (List DatabaseInfo))
    | ShowDatabaseMenu
    | HideDatabaseMenu
    | ShowCreateDatabaseModal
    | HideCreateDatabaseModal
    | UpdateNewDatabaseName String
    | UpdateNewDatabaseDescription String
    | CreateDatabase
    | DatabaseCreated (Result Http.Error DatabaseInfo)
    | SwitchDatabase String
    | DatabaseSwitched (Result Http.Error DatabaseInfo)
    | ShowEditDatabaseModal String
    | HideEditDatabaseModal
    | UpdateEditDatabaseName String
    | UpdateEditDatabaseDescription String
    | SaveDatabaseChanges
    | DatabaseUpdated (Result Http.Error DatabaseInfo)
    | ToggleGraphWindow
    | CloseGraphWindow
    | StartDraggingGraphWindow Int Int
    | DragGraphWindow Int Int
    | StopDraggingGraphWindow
    | StartResizingGraphWindow ResizeEdge Int Int
    | ResizeGraphWindow Int Int
    | StopResizingGraphWindow


type DocType
    = DTMarkDown
    | DTScripta
    | DTLaTeX
    | DTClaudeResponse
    | DTPDF


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

        "pdf" ->
            DTPDF

        _ ->
            DTMarkDown


inferDocType : String -> DocType
inferDocType content =
    let
        -- Take first 500 characters to check for patterns
        topContent =
            String.left 500 content

        -- Check for LaTeX patterns
        hasLatexTitle =
            String.contains "\\title{" topContent

        hasLatexCommands =
            -- Look for \command{...} pattern
            String.contains "\\" content
                && (String.contains "{" content || String.contains "}" content)

        -- Check for Scripta patterns
        hasScriptaTitle =
            String.contains "| title " topContent

        hasScriptaBrackets =
            -- Look for [command ...] pattern
            String.contains "[" content
                && String.contains "]" content
                && -- Make sure it's not just a markdown link
                   not (String.contains "](http" content || String.contains "](/" content)
    in
    if hasLatexTitle || hasLatexCommands then
        DTLaTeX

    else if hasScriptaTitle || hasScriptaBrackets then
        DTScripta

    else
        DTMarkDown


inferTitle : String -> DocType -> Maybe String
inferTitle content docType =
    case docType of
        DTLaTeX ->
            -- Look for \title{...}
            case String.indexes "\\title{" content of
                [] ->
                    Nothing

                index :: _ ->
                    let
                        afterTitle =
                            String.dropLeft (index + 7) content

                        -- Find the closing brace
                        closingIndex =
                            String.indexes "}" afterTitle
                                |> List.head
                                |> Maybe.withDefault 0

                        title =
                            String.left closingIndex afterTitle
                                |> String.trim
                    in
                    if String.isEmpty title then
                        Nothing

                    else
                        Just title

        DTScripta ->
            -- Look for | title\nSTRING pattern
            case String.indexes "| title" content of
                [] ->
                    Nothing

                index :: _ ->
                    let
                        afterTitle =
                            String.dropLeft (index + 7) content
                                |> String.lines
                                |> List.drop 1
                                -- Skip the "| title" line
                                |> List.head
                                |> Maybe.withDefault ""
                                |> String.trim
                    in
                    if String.isEmpty afterTitle then
                        Nothing

                    else
                        Just afterTitle

        DTMarkDown ->
            -- Look for first # STRING
            content
                |> String.lines
                |> List.filter (String.startsWith "# ")
                |> List.head
                |> Maybe.map (String.dropLeft 2 >> String.trim)
                |> Maybe.andThen
                    (\title ->
                        if String.isEmpty title then
                            Nothing

                        else
                            Just title
                    )

        DTClaudeResponse ->
            -- Claude responses might have markdown titles
            inferTitle content DTMarkDown

        DTPDF ->
            -- PDF titles should be provided during upload
            Nothing


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
      , newDocument = NewDocument "" "" DTMarkDown "" "" ""
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
      , selectedPDF = Nothing
      , expandedClusters = []
      , currentDatabase = Nothing
      , databases = []
      , showDatabaseMenu = False
      , showCreateDatabaseModal = False
      , newDatabaseName = ""
      , newDatabaseDescription = ""
      , showMoveDocumentModal = False
      , moveDocumentId = Nothing
      , moveTargetDatabaseId = Nothing
      , showPDFImportModal = False
      , pdfImportURL = ""
      , pdfImportTitle = ""
      , showAddDocumentMenu = False
      , clusterVisualization = Nothing
      , showEditDatabaseModal = False
      , editDatabaseId = Nothing
      , editDatabaseName = ""
      , editDatabaseDescription = ""
      , showGraphWindow = False
      , graphWindowPosition = { x = 100, y = 100 }
      , graphWindowSize = { width = 800, height = 600 }
      , graphWindowDragging = Nothing
      , graphWindowResizing = Nothing
      }
    , Cmd.batch
        [ Api.getDocuments (Api.Config flags.apiUrl) GotDocuments
        , Task.perform GotViewport Browser.Dom.getViewport
        , Api.getCurrentDatabase (Api.Config flags.apiUrl) GotCurrentDatabase
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
            let
                cmd = 
                    Cmd.none
            in
            ( { model | view = newView, justSavedClaude = False, showAddDocumentMenu = False }, cmd )

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

                -- Auto-detect document type from content
                detectedType =
                    inferDocType value

                -- Auto-infer title if current title is empty
                newTitle =
                    if String.isEmpty newDoc.title then
                        inferTitle value detectedType
                            |> Maybe.withDefault newDoc.title

                    else
                        newDoc.title
            in
            ( { model | newDocument = { newDoc | content = value, docType = detectedType, title = newTitle } }, Cmd.none )

        UpdateNewDocType value ->
            let
                newDocument_ =
                    model.newDocument

                docType =
                    docTypeFromString value
            in
            ( { model | newDocument = { newDocument_ | docType = docType } }, Cmd.none )

        UpdateNewDocTags value ->
            let
                newDocument_ =
                    model.newDocument
            in
            ( { model | newDocument = { newDocument_ | tags = value } }, Cmd.none )

        UpdateNewDocSource value ->
            let
                newDocument_ =
                    model.newDocument
            in
            ( { model | newDocument = { newDocument_ | source = value } }, Cmd.none )

        UpdateNewDocAuthors value ->
            let
                newDocument_ =
                    model.newDocument
            in
            ( { model | newDocument = { newDocument_ | authors = value } }, Cmd.none )

        AddDocument ->
            let
                docType =
                    Just (docTypeToString model.newDocument.docType)
            in
            ( { model | loading = True }
            , Api.addDocument model.config
                model.newDocument.title
                model.newDocument.content
                docType
                model.newDocument.tags
                (if String.isEmpty model.newDocument.source then Nothing else Just model.newDocument.source)
                (if String.isEmpty model.newDocument.authors then Nothing else Just model.newDocument.authors)
                DocumentAdded
            )

        DocumentAdded result ->
            case result of
                Ok _ ->
                    ( { model
                        | loading = False
                        , error = Nothing
                        , view = ListView
                        , newDocument = NewDocument "" "" DTMarkDown "" "" ""
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
            ( { model | editingDocument = Just (EditingDocument doc.id doc.title doc.content doc.docType (Maybe.withDefault "" doc.tags) (Maybe.withDefault "" doc.source) (Maybe.withDefault "" doc.authors)) }
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
                    let
                        -- Auto-detect document type from content
                        detectedDocType =
                            inferDocType content

                        detectedTypeString =
                            docTypeToString detectedDocType

                        -- Auto-infer title if current title is empty
                        newTitle =
                            if String.isEmpty editing.title then
                                inferTitle content detectedDocType
                                    |> Maybe.withDefault editing.title

                            else
                                editing.title
                    in
                    ( { model | editingDocument = Just { editing | content = content, docType = Just detectedTypeString, title = newTitle } }, Cmd.none )

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

        UpdateEditingTags tags ->
            case model.editingDocument of
                Just editing ->
                    ( { model | editingDocument = Just { editing | tags = tags } }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        UpdateEditingSource source ->
            case model.editingDocument of
                Just editing ->
                    ( { model | editingDocument = Just { editing | source = source } }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        UpdateEditingAuthors authors ->
            case model.editingDocument of
                Just editing ->
                    ( { model | editingDocument = Just { editing | authors = authors } }, Cmd.none )

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
                        (Just editing.tags)
                        (if String.isEmpty editing.source then Nothing else Just editing.source)
                        (if String.isEmpty editing.authors then Nothing else Just editing.authors)
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

        ShowMoveDocumentModal docId ->
            ( { model
                | showMoveDocumentModal = True
                , moveDocumentId = Just docId
                , moveTargetDatabaseId = Nothing
              }
            , Api.getDatabases model.config GotDatabases
            )

        CancelMoveDocument ->
            ( { model
                | showMoveDocumentModal = False
                , moveDocumentId = Nothing
                , moveTargetDatabaseId = Nothing
              }
            , Cmd.none
            )

        SelectTargetDatabase dbId ->
            ( { model | moveTargetDatabaseId = Just dbId }, Cmd.none )

        ConfirmMoveDocument ->
            case ( model.moveDocumentId, model.moveTargetDatabaseId ) of
                ( Just docId, Just targetDbId ) ->
                    ( { model | loading = True }
                    , Api.moveDocument model.config docId targetDbId DocumentMoved
                    )

                _ ->
                    ( model, Cmd.none )

        DocumentMoved result ->
            case result of
                Ok movedDoc ->
                    ( { model
                        | loading = False
                        , showMoveDocumentModal = False
                        , moveDocumentId = Nothing
                        , moveTargetDatabaseId = Nothing
                        , documents = List.filter (\d -> d.id /= (model.moveDocumentId |> Maybe.withDefault "")) model.documents
                        , selectedDocument = Nothing
                        , view = ListView
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model
                        | loading = False
                        , error = Just (httpErrorToString error)
                      }
                    , Cmd.none
                    )

        SelectPDFFile ->
            ( { model | showAddDocumentMenu = False }
            , File.Select.file [ "application/pdf" ] PDFSelected
            )

        PDFSelected file ->
            ( { model | selectedPDF = Just file }, Cmd.none )

        UploadPDF ->
            case model.selectedPDF of
                Just file ->
                    ( { model | loading = True }
                    , Api.uploadPDF model.config file PDFUploaded
                    )

                Nothing ->
                    ( model, Cmd.none )

        PDFUploaded result ->
            case result of
                Ok document ->
                    ( { model
                        | loading = False
                        , error = Nothing
                        , selectedPDF = Nothing
                        , view = DocumentView
                        , selectedDocument = Just document
                      }
                    , Api.getDocuments model.config GotDocuments
                    )

                Err error ->
                    ( { model | loading = False, error = Just (httpErrorToString error) }
                    , Cmd.none
                    )

        OpenPDFNative filename ->
            ( model
            , Api.openPDFNative model.config filename NoOp
            )

        ShowPDFImportModal ->
            ( { model | showPDFImportModal = True, pdfImportURL = "", pdfImportTitle = "", showAddDocumentMenu = False }
            , Task.attempt (\_ -> NoOp) (Browser.Dom.focus "pdf-import-url-input")
            )

        HidePDFImportModal ->
            ( { model | showPDFImportModal = False }
            , Cmd.none
            )

        UpdatePDFImportURL url ->
            ( { model | pdfImportURL = url }
            , Cmd.none
            )

        UpdatePDFImportTitle title ->
            ( { model | pdfImportTitle = title }
            , Cmd.none
            )

        ImportPDFFromURL ->
            if String.isEmpty model.pdfImportURL || model.loading then
                ( model, Cmd.none )
            else
                ( { model | loading = True }
                , Api.importPDFFromURL model.config model.pdfImportURL 
                    (if String.isEmpty model.pdfImportTitle then Nothing else Just model.pdfImportTitle) 
                    PDFImported
                )

        PDFImported result ->
            case result of
                Ok document ->
                    ( { model
                        | loading = False
                        , error = Nothing
                        , showPDFImportModal = False
                        , pdfImportURL = ""
                        , pdfImportTitle = ""
                        , view = DocumentView
                        , selectedDocument = Just document
                      }
                    , Api.getDocuments model.config GotDocuments
                    )

                Err error ->
                    ( { model | loading = False, error = Just (httpErrorToString error) }
                    , Cmd.none
                    )

        KeyPressed key ->
            case key of
                "n" ->
                    -- Ctrl+N: New Document
                    ( { model | view = AddDocumentView, newDocument = { title = "", content = "", docType = DTMarkDown, tags = "", source = "", authors = "" }, showAddDocumentMenu = False }
                    , Cmd.none
                    )

                "u" ->
                    -- Ctrl+U: Upload PDF
                    ( { model | showAddDocumentMenu = False }
                    , Task.perform (\_ -> SelectPDFFile) (Task.succeed ())
                    )

                "d" ->
                    -- Ctrl+D: Download PDF from URL
                    ( { model | showPDFImportModal = True, showAddDocumentMenu = False }
                    , Task.attempt (\_ -> NoOp) (Browser.Dom.focus "pdf-import-url-input")
                    )

                "c" ->
                    -- Ctrl+C: Ask Claude
                    ( { model | view = ClaudeView }
                    , Cmd.none
                    )

                "l" ->
                    -- Ctrl+L: Documents
                    ( { model | view = ListView, loading = True }
                    , Api.getDocuments model.config GotDocuments
                    )

                "k" ->
                    -- Ctrl+K: Clusters
                    ( { model | view = ClustersView, clusterLoading = True }
                    , Api.getClusters model.config Nothing GotClusters
                    )

                "r" ->
                    -- Ctrl+R: Random
                    ( { model | view = RandomView }
                    , Task.perform GotCurrentTime Time.now
                    )

                "g" ->
                    -- Ctrl+G: Graph Window
                    ( { model | showGraphWindow = True, clusterLoading = True }
                    , Api.getClusterVisualization model.config GotClusterVisualization
                    )

                _ ->
                    ( model, Cmd.none )

        ToggleAddDocumentMenu ->
            ( { model | showAddDocumentMenu = not model.showAddDocumentMenu }
            , Cmd.none
            )

        ToggleClusterExpansion clusterId ->
            let
                isExpanded =
                    List.member clusterId model.expandedClusters

                newExpandedClusters =
                    if isExpanded then
                        List.filter (\id -> id /= clusterId) model.expandedClusters

                    else
                        clusterId :: model.expandedClusters
            in
            ( { model | expandedClusters = newExpandedClusters }, Cmd.none )

        NavigateToCluster clusterId ->
            ( { model
                | view = ClustersView
                , clusterLoading = True
                , expandedClusters = [ clusterId ] -- Expand only the selected cluster
              }
            , Api.getClusters model.config Nothing GotClusters
            )

        GotClusterVisualization result ->
            case result of
                Ok visualization ->
                    ( { model 
                        | clusterVisualization = Just visualization
                        , clusterLoading = False 
                      }
                    , Cmd.none
                    )
                    
                Err _ ->
                    ( { model 
                        | clusterLoading = False
                        , error = Just "Failed to load cluster visualization"
                      }
                    , Cmd.none
                    )

        GotCurrentDatabase result ->
            case result of
                Ok database ->
                    ( { model | currentDatabase = Just database }
                    , Cmd.none
                    )

                Err _ ->
                    ( model, Cmd.none )

        GotDatabases result ->
            case result of
                Ok databases ->
                    ( { model | databases = databases }
                    , Cmd.none
                    )

                Err _ ->
                    ( { model | error = Just "Failed to load databases" }
                    , Cmd.none
                    )

        ShowDatabaseMenu ->
            ( { model | showDatabaseMenu = True }
            , Api.getDatabases model.config GotDatabases
            )

        HideDatabaseMenu ->
            ( { model | showDatabaseMenu = False }
            , Cmd.none
            )

        ShowCreateDatabaseModal ->
            ( { model
                | showCreateDatabaseModal = True
                , showDatabaseMenu = False
                , newDatabaseName = ""
                , newDatabaseDescription = ""
              }
            , Cmd.none
            )

        HideCreateDatabaseModal ->
            ( { model | showCreateDatabaseModal = False }
            , Cmd.none
            )

        UpdateNewDatabaseName name ->
            ( { model | newDatabaseName = name }
            , Cmd.none
            )

        UpdateNewDatabaseDescription description ->
            ( { model | newDatabaseDescription = description }
            , Cmd.none
            )

        CreateDatabase ->
            let
                description =
                    if String.isEmpty model.newDatabaseDescription then
                        Nothing

                    else
                        Just model.newDatabaseDescription
            in
            ( { model | loading = True }
            , Api.createDatabase model.config model.newDatabaseName description DatabaseCreated
            )

        DatabaseCreated result ->
            case result of
                Ok database ->
                    ( { model
                        | loading = False
                        , showCreateDatabaseModal = False
                        , currentDatabase = Just database
                        , databases = database :: model.databases
                      }
                    , Cmd.batch
                        [ Api.getDocuments model.config GotDocuments
                        , Api.switchDatabase model.config database.id DatabaseSwitched
                        ]
                    )

                Err _ ->
                    ( { model
                        | loading = False
                        , error = Just "Failed to create database"
                      }
                    , Cmd.none
                    )

        SwitchDatabase databaseId ->
            ( { model | loading = True }
            , Api.switchDatabase model.config databaseId DatabaseSwitched
            )

        DatabaseSwitched result ->
            case result of
                Ok database ->
                    ( { model
                        | loading = False
                        , currentDatabase = Just database
                        , showDatabaseMenu = False
                        , documents = []
                        , searchResults = []
                        , selectedDocument = Nothing
                        , view = ListView
                      }
                    , Api.getDocuments model.config GotDocuments
                    )

                Err _ ->
                    ( { model
                        | loading = False
                        , error = Just "Failed to switch database"
                      }
                    , Cmd.none
                    )

        ShowEditDatabaseModal databaseId ->
            case List.filter (\db -> db.id == databaseId) model.databases |> List.head of
                Just database ->
                    ( { model
                        | showEditDatabaseModal = True
                        , editDatabaseId = Just databaseId
                        , editDatabaseName = database.name
                        , editDatabaseDescription = Maybe.withDefault "" database.description
                        , showDatabaseMenu = False
                      }
                    , Cmd.none
                    )
                    
                Nothing ->
                    ( model, Cmd.none )

        HideEditDatabaseModal ->
            ( { model
                | showEditDatabaseModal = False
                , editDatabaseId = Nothing
                , editDatabaseName = ""
                , editDatabaseDescription = ""
              }
            , Cmd.none
            )

        UpdateEditDatabaseName name ->
            ( { model | editDatabaseName = name }
            , Cmd.none
            )

        UpdateEditDatabaseDescription description ->
            ( { model | editDatabaseDescription = description }
            , Cmd.none
            )

        SaveDatabaseChanges ->
            case model.editDatabaseId of
                Just databaseId ->
                    ( { model | loading = True }
                    , Api.updateDatabase model.config 
                        databaseId 
                        (Just model.editDatabaseName)
                        (if String.isEmpty model.editDatabaseDescription then Nothing else Just model.editDatabaseDescription)
                        DatabaseUpdated
                    )
                    
                Nothing ->
                    ( model, Cmd.none )

        DatabaseUpdated result ->
            case result of
                Ok database ->
                    let
                        updatedDatabases =
                            List.map
                                (\db ->
                                    if db.id == database.id then
                                        database
                                    else
                                        db
                                )
                                model.databases
                                
                        updatedCurrentDatabase =
                            if Maybe.map .id model.currentDatabase == Just database.id then
                                Just database
                            else
                                model.currentDatabase
                    in
                    ( { model
                        | loading = False
                        , showEditDatabaseModal = False
                        , editDatabaseId = Nothing
                        , editDatabaseName = ""
                        , editDatabaseDescription = ""
                        , databases = updatedDatabases
                        , currentDatabase = updatedCurrentDatabase
                      }
                    , Cmd.none
                    )

                Err _ ->
                    ( { model
                        | loading = False
                        , error = Just "Failed to update database"
                      }
                    , Cmd.none
                    )

        ToggleGraphWindow ->
            ( { model | showGraphWindow = not model.showGraphWindow }
            , if not model.showGraphWindow then
                Api.getClusterVisualization model.config GotClusterVisualization
              else
                Cmd.none
            )

        CloseGraphWindow ->
            ( { model | showGraphWindow = False }
            , Cmd.none
            )

        StartDraggingGraphWindow x y ->
            ( { model 
                | graphWindowDragging = Just 
                    { startX = x
                    , startY = y
                    , offsetX = x - model.graphWindowPosition.x
                    , offsetY = y - model.graphWindowPosition.y
                    }
              }
            , Cmd.none
            )

        DragGraphWindow x y ->
            case model.graphWindowDragging of
                Just drag ->
                    ( { model 
                        | graphWindowPosition = 
                            { x = x - drag.offsetX
                            , y = y - drag.offsetY
                            }
                      }
                    , Cmd.none
                    )
                Nothing ->
                    ( model, Cmd.none )

        StopDraggingGraphWindow ->
            ( { model | graphWindowDragging = Nothing }
            , Cmd.none
            )

        StartResizingGraphWindow edge x y ->
            ( { model | graphWindowResizing = Just { edge = edge } }
            , Cmd.none
            )

        ResizeGraphWindow x y ->
            case model.graphWindowResizing of
                Just { edge } ->
                    let
                        newSize = 
                            case edge of
                                RightEdge ->
                                    { width = Basics.max 400 (x - model.graphWindowPosition.x)
                                    , height = model.graphWindowSize.height
                                    }
                                BottomEdge ->
                                    { width = model.graphWindowSize.width
                                    , height = Basics.max 300 (y - model.graphWindowPosition.y)
                                    }
                                BottomRightCorner ->
                                    { width = Basics.max 400 (x - model.graphWindowPosition.x)
                                    , height = Basics.max 300 (y - model.graphWindowPosition.y)
                                    }
                                _ ->
                                    model.graphWindowSize
                    in
                    ( { model | graphWindowSize = newSize }
                    , Cmd.none
                    )
                Nothing ->
                    ( model, Cmd.none )

        StopResizingGraphWindow ->
            ( { model | graphWindowResizing = Nothing }
            , Cmd.none
            )


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
        , if model.showCreateDatabaseModal then
            viewCreateDatabaseModal model

          else
            text ""
        , if model.showEditDatabaseModal then
            viewEditDatabaseModal model

          else
            text ""
        , if model.showMoveDocumentModal then
            viewMoveDocumentModal model

          else
            text ""
        , if model.showPDFImportModal then
            viewPDFImportModal model

          else
            text ""
        , if model.showGraphWindow then
            viewGraphWindow model
          else
            text ""
        ]


viewDatabaseMenu : Model -> Html Msg
viewDatabaseMenu model =
    div [ class "database-dropdown-menu" ]
        [ ul [ class "database-list" ]
            (List.map (viewDatabaseMenuItem model) model.databases
                ++ [ li
                        [ class "database-menu-item create-new"
                        , onClick ShowCreateDatabaseModal
                        ]
                        [ text "Create New Database..." ]
                   ]
            )
        ]


viewDatabaseMenuItem : Model -> DatabaseInfo -> Html Msg
viewDatabaseMenuItem model database =
    let
        isActive =
            model.currentDatabase
                |> Maybe.map (\db -> db.id == database.id)
                |> Maybe.withDefault False
    in
    li
        [ class
            (if isActive then
                "database-menu-item active"

             else
                "database-menu-item"
            )
        , onClick (SwitchDatabase database.id)
        ]
        [ span [ class "database-item-name" ] [ text database.name ]
        , span [ class "database-item-count" ] [ text ("(" ++ String.fromInt database.documentCount ++ " docs)") ]
        , button
            [ class "database-item-edit"
            , type_ "button"
            , stopPropagationOn "click" (Decode.succeed (ShowEditDatabaseModal database.id, True))
            , title "Edit database name"
            ]
            [ text "✏️" ]
        ]


viewCreateDatabaseModal : Model -> Html Msg
viewCreateDatabaseModal model =
    div [ class "modal-overlay", onClick HideCreateDatabaseModal ]
        [ div [ class "modal-content", stopPropagationOn "click" (Decode.succeed ( NoOp, True )) ]
            [ h2 [] [ text "Create New Database" ]
            , div [ class "form-group" ]
                [ label [] [ text "Database Name" ]
                , input
                    [ type_ "text"
                    , placeholder "My New Database"
                    , value model.newDatabaseName
                    , onInput UpdateNewDatabaseName
                    , class "form-input"
                    ]
                    []
                ]
            , div [ class "form-group" ]
                [ label [] [ text "Description (optional)" ]
                , textarea
                    [ placeholder "Description of this database..."
                    , value model.newDatabaseDescription
                    , onInput UpdateNewDatabaseDescription
                    , class "form-textarea"
                    , Html.Attributes.rows 3
                    ]
                    []
                ]
            , div [ class "modal-actions" ]
                [ button
                    [ onClick CreateDatabase
                    , class "submit-button"
                    , disabled (String.isEmpty model.newDatabaseName || model.loading)
                    ]
                    [ text
                        (if model.loading then
                            "Creating..."

                         else
                            "Create"
                        )
                    ]
                , button
                    [ onClick HideCreateDatabaseModal
                    , class "cancel-button"
                    ]
                    [ text "Cancel" ]
                ]
            ]
        ]


viewEditDatabaseModal : Model -> Html Msg
viewEditDatabaseModal model =
    div [ class "modal-overlay", onClick HideEditDatabaseModal ]
        [ div [ class "modal-content", stopPropagationOn "click" (Decode.succeed ( NoOp, True )) ]
            [ h2 [] [ text "Edit Database" ]
            , div [ class "form-group" ]
                [ label [] [ text "Database Name" ]
                , input
                    [ type_ "text"
                    , placeholder "Database Name"
                    , value model.editDatabaseName
                    , onInput UpdateEditDatabaseName
                    , class "form-input"
                    ]
                    []
                ]
            , div [ class "form-group" ]
                [ label [] [ text "Description (optional)" ]
                , textarea
                    [ placeholder "Description of this database..."
                    , value model.editDatabaseDescription
                    , onInput UpdateEditDatabaseDescription
                    , class "form-textarea"
                    , Html.Attributes.rows 3
                    ]
                    []
                ]
            , div [ class "modal-actions" ]
                [ button
                    [ onClick SaveDatabaseChanges
                    , class "submit-button"
                    , disabled (String.isEmpty model.editDatabaseName || model.loading)
                    ]
                    [ text
                        (if model.loading then
                            "Saving..."

                         else
                            "Save"
                        )
                    ]
                , button
                    [ onClick HideEditDatabaseModal
                    , class "cancel-button"
                    ]
                    [ text "Cancel" ]
                ]
            ]
        ]


viewMoveDocumentModal : Model -> Html Msg
viewMoveDocumentModal model =
    let
        currentDbId =
            model.currentDatabase
                |> Maybe.map .id
                |> Maybe.withDefault ""

        otherDatabases =
            model.databases
                |> List.filter (\db -> db.id /= currentDbId)
    in
    div [ class "modal-overlay", onClick CancelMoveDocument ]
        [ div [ class "modal-content", stopPropagationOn "click" (Decode.succeed ( NoOp, True )) ]
            [ h2 [] [ text "Move Document to Another Database" ]
            , if List.isEmpty otherDatabases then
                div [ class "info-message" ]
                    [ text "No other databases available. Create a new database first." ]

              else
                div []
                    [ div [ class "form-group" ]
                        [ label [] [ text "Select Target Database:" ]
                        , div [ class "database-list" ]
                            (otherDatabases
                                |> List.map
                                    (\db ->
                                        div
                                            [ class
                                                (if Just db.id == model.moveTargetDatabaseId then
                                                    "database-menu-item active"

                                                 else
                                                    "database-menu-item"
                                                )
                                            , onClick (SelectTargetDatabase db.id)
                                            , Html.Attributes.style "cursor" "pointer"
                                            , Html.Attributes.style "padding" "0.5rem"
                                            , Html.Attributes.style "border" "1px solid #ddd"
                                            , Html.Attributes.style "margin" "0.25rem 0"
                                            , Html.Attributes.style "border-radius" "4px"
                                            ]
                                            [ div [ class "database-item-name" ] [ text db.name ]
                                            , div [ class "database-item-count" ]
                                                [ text (String.fromInt db.documentCount ++ " documents") ]
                                            ]
                                    )
                            )
                        ]
                    ]
            , div [ class "modal-actions" ]
                [ if not (List.isEmpty otherDatabases) then
                    button
                        [ onClick ConfirmMoveDocument
                        , class "submit-button"
                        , disabled (model.moveTargetDatabaseId == Nothing || model.loading)
                        ]
                        [ text
                            (if model.loading then
                                "Moving..."

                             else
                                "Move Document"
                            )
                        ]

                  else
                    text ""
                , button
                    [ onClick CancelMoveDocument
                    , class "cancel-button"
                    ]
                    [ text "Cancel" ]
                ]
            ]
        ]


viewPDFImportModal : Model -> Html Msg
viewPDFImportModal model =
    div [ class "modal-overlay", onClick HidePDFImportModal ]
        [ div [ class "modal-content", stopPropagationOn "click" (Decode.succeed ( NoOp, True )) ]
            [ h2 [] [ text "Import PDF from URL" ]
            , div [ class "form-group" ]
                [ label [] [ text "PDF URL:" ]
                , input
                    [ type_ "url"
                    , id "pdf-import-url-input"
                    , value model.pdfImportURL
                    , onInput UpdatePDFImportURL
                    , placeholder "https://example.com/document.pdf"
                    , class "form-input"
                    , onEnter ImportPDFFromURL
                    ]
                    []
                ]
            , div [ class "form-group" ]
                [ label [] [ text "Title (optional):" ]
                , input
                    [ type_ "text"
                    , value model.pdfImportTitle
                    , onInput UpdatePDFImportTitle
                    , placeholder "Leave empty to use filename or PDF title"
                    , class "form-input"
                    , onEnter ImportPDFFromURL
                    ]
                    []
                ]
            , div [ class "modal-actions" ]
                [ button
                    [ onClick ImportPDFFromURL
                    , class "submit-button"
                    , disabled (String.isEmpty model.pdfImportURL || model.loading)
                    ]
                    [ text
                        (if model.loading then
                            "Importing..."
                         else
                            "Import PDF"
                        )
                    ]
                , button
                    [ onClick HidePDFImportModal
                    , class "cancel-button"
                    ]
                    [ text "Cancel" ]
                ]
            ]
        ]


viewHeader : Model -> Html Msg
viewHeader model =
    header [ class "app-header" ]
        [ h1 [] [ text "SemanticSearch" ]
        , div [ class "database-info" ]
            [ span [ class "database-label" ] [ text "Database: " ]
            , span [ class "database-name" ]
                [ text
                    (model.currentDatabase
                        |> Maybe.map .name
                        |> Maybe.withDefault "Loading..."
                    )
                ]
            , button
                [ onClick
                    (if model.showDatabaseMenu then
                        HideDatabaseMenu

                     else
                        ShowDatabaseMenu
                    )
                , class "database-menu-button"
                ]
                [ text "▼" ]
            , if model.showDatabaseMenu then
                viewDatabaseMenu model

              else
                text ""
            ]
        , nav []
            [ button [ onClick (ChangeView ListView), class "nav-button", title "Ctrl+L" ]
                [ text "Documents"
                , span [ class "shortcut-hint" ] [ text " (Ctrl+L)" ]
                ]
            , div [ class "add-document-menu" ]
                [ button 
                    [ onClick ToggleAddDocumentMenu
                    , class "nav-button"
                    , title "Add Document"
                    ]
                    [ text "Add Document ▼" ]
                , if model.showAddDocumentMenu then
                    div [ class "add-document-dropdown" ]
                        [ button 
                            [ onClick (ChangeView AddDocumentView)
                            , class "add-document-dropdown-item"
                            ]
                            [ span [] [ text "New" ]
                            , span [ class "shortcut" ] [ text "Ctrl+N" ]
                            ]
                        , button 
                            [ onClick SelectPDFFile
                            , class "add-document-dropdown-item"
                            ]
                            [ span [] [ text "Upload" ]
                            , span [ class "shortcut" ] [ text "Ctrl+U" ]
                            ]
                        , button 
                            [ onClick ShowPDFImportModal
                            , class "add-document-dropdown-item"
                            ]
                            [ span [] [ text "Download" ]
                            , span [ class "shortcut" ] [ text "Ctrl+D" ]
                            ]
                        ]
                  else
                    text ""
                ]
            , button [ onClick (ChangeView ClaudeView), class "nav-button", title "Ctrl+C" ]
                [ text "Ask Claude"
                , span [ class "shortcut-hint" ] [ text " (Ctrl+C)" ]
                ]
            , button [ onClick LoadRandomDocuments, class "nav-button", title "Ctrl+R" ]
                [ text "Random"
                , span [ class "shortcut-hint" ] [ text " (Ctrl+R)" ]
                ]
            , button [ onClick LoadClusters, class "nav-button", title "Ctrl+K" ]
                [ text "Clusters"
                , span [ class "shortcut-hint" ] [ text " (Ctrl+K)" ]
                ]
            , button 
                [ class "nav-button"
                , title "Ctrl+G"
                , onClick ToggleGraphWindow
                ]
                [ text "Graph"
                , span [ class "shortcut-hint" ] [ text " (Ctrl+G)" ]
                ]
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
        , case doc.clusterName of
            Just clusterName ->
                case doc.clusterId of
                    Just clusterId ->
                        div [ class "cluster-info" ]
                            [ span [ class "cluster-label" ] [ text "Cluster: " ]
                            , a
                                [ href "#"
                                , onClick (NavigateToCluster clusterId)
                                , class "cluster-link"
                                , stopPropagationOn "click" (Decode.succeed ( NavigateToCluster clusterId, True ))
                                ]
                                [ text (String.fromInt (clusterId + 1) ++ ". " ++ clusterName) ]
                            ]

                    Nothing ->
                        text ""

            Nothing ->
                text ""
        , case doc.tags of
            Just tags ->
                if String.isEmpty tags then
                    text ""

                else
                    div [ class "tags" ]
                        (tags
                            |> String.split ","
                            |> List.map String.trim
                            |> List.filter (not << String.isEmpty)
                            |> List.map (\tag -> span [ class "tag" ] [ text tag ])
                        )

            Nothing ->
                text ""
        , case doc.abstract of
            Just abstract ->
                div [ class "abstract-preview" ] [ text (truncate 150 abstract) ]
            
            Nothing ->
                div [ class "content-preview" ] [ text (truncate 150 doc.content) ]
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
    div [ class "search-result", onClick (SelectDocument { id = result.id, title = result.title, content = result.content, createdAt = result.createdAt, docType = result.docType, tags = result.tags, abstract = result.abstract, abstractSource = result.abstractSource, source = result.source, authors = result.authors, index = result.index, clusterId = result.clusterId, clusterName = result.clusterName }) ]
        [ h3 [] [ text result.title ]
        , div [ class "document-meta" ]
            [ span [ class "created-at" ] [ text (formatDate result.createdAt) ]
            , case result.docType of
                Just dt ->
                    span [ class "category" ] [ text dt ]

                Nothing ->
                    text ""
            ]
        , case result.clusterName of
            Just clusterName ->
                case result.clusterId of
                    Just clusterId ->
                        div [ class "cluster-info" ]
                            [ span [ class "cluster-label" ] [ text "Cluster: " ]
                            , a
                                [ href "#"
                                , onClick (NavigateToCluster clusterId)
                                , class "cluster-link"
                                , stopPropagationOn "click" (Decode.succeed ( NavigateToCluster clusterId, True ))
                                ]
                                [ text (String.fromInt (clusterId + 1) ++ ". " ++ clusterName) ]
                            ]

                    Nothing ->
                        text ""

            Nothing ->
                text ""
        , case result.similarityScore of
            Just score ->
                div [ class "similarity" ] [ text (formatPercent score ++ " match") ]

            Nothing ->
                text ""
        , case result.abstract of
            Just abstract ->
                div [ class "abstract-preview" ] [ text (truncate 200 abstract) ]
            
            Nothing ->
                div [ class "snippet" ] [ text (truncate 150 result.content) ]
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


type alias PDFMetadata =
    { filename : String
    , pages : Int
    , thumbnails : List String
    }


extractPDFFilename : String -> String
extractPDFFilename content =
    case String.indexes "[PDF_FILE:" content of
        [] ->
            ""

        index :: _ ->
            let
                afterMarker =
                    String.dropLeft (index + 10) content

                endIndex =
                    String.indexes "]" afterMarker
                        |> List.head
                        |> Maybe.withDefault 0

                filename =
                    String.left endIndex afterMarker
            in
            filename


extractPDFMetadata : String -> Maybe PDFMetadata
extractPDFMetadata content =
    case String.indexes "[PDF_META:" content of
        [] ->
            Nothing

        index :: _ ->
            let
                afterMarker =
                    String.dropLeft (index + 10) content

                endIndex =
                    String.indexes "]" afterMarker
                        |> List.head
                        |> Maybe.withDefault 0

                metaJson =
                    String.left endIndex afterMarker

                extractPages json =
                    case String.indexes "\"pages\":" json of
                        [] ->
                            0

                        idx :: _ ->
                            let
                                afterField =
                                    String.dropLeft (idx + 8) json
                            in
                            afterField
                                |> String.split ","
                                |> List.head
                                |> Maybe.andThen String.toInt
                                |> Maybe.withDefault 0

                extractThumbnails json =
                    case String.indexes "\"thumbnails\":" json of
                        [] ->
                            []

                        idx :: _ ->
                            let
                                afterField =
                                    String.dropLeft (idx + 13) json
                            in
                            case String.indexes "[" afterField of
                                [] ->
                                    []

                                arrIdx :: _ ->
                                    let
                                        afterBracket =
                                            String.dropLeft (arrIdx + 1) afterField

                                        endIdx =
                                            String.indexes "]" afterBracket |> List.head |> Maybe.withDefault 0

                                        arrayContent =
                                            String.left endIdx afterBracket
                                    in
                                    if String.isEmpty arrayContent then
                                        []

                                    else
                                        arrayContent
                                            |> String.split ","
                                            |> List.map (String.trim >> String.replace "\"" "")

                pages =
                    extractPages metaJson

                thumbnails =
                    extractThumbnails metaJson

                filename =
                    extractPDFFilename content
            in
            if String.isEmpty filename then
                Nothing

            else
                Just { filename = filename, pages = pages, thumbnails = thumbnails }


viewThumbnail : String -> String -> Html Msg
viewThumbnail apiUrl thumbFilename =
    div [ class "pdf-thumbnail" ]
        [ img
            [ src (apiUrl ++ "/pdf/thumbnail/" ++ thumbFilename)
            , alt ("Page " ++ (thumbFilename |> String.split "_" |> List.reverse |> List.head |> Maybe.withDefault ""))
            , class "thumbnail-image"
            ]
            []
        , p [ class "thumbnail-label" ]
            [ text
                ("Page "
                    ++ (thumbFilename
                            |> String.split "_"
                            |> List.reverse
                            |> List.head
                            |> Maybe.andThen (String.split "." >> List.head)
                            |> Maybe.withDefault ""
                       )
                )
            ]
        ]


viewReadOnlyDocument : Model -> Document -> Html Msg
viewReadOnlyDocument model doc =
    let
        -- Calculate document width based on window width with some padding
        -- Accounting for margins, padding, and other UI elements
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
        , case doc.abstract of
            Just abstract ->
                div [ class "document-abstract" ]
                    [ h3 [ class "abstract-title" ] [ text "Abstract" ]
                    , p [ class "abstract-text" ] [ text abstract ]
                    , case doc.abstractSource of
                        Just source ->
                            span [ class "abstract-source" ] [ text ("Source: " ++ abstractSourceLabel source) ]
                        Nothing ->
                            text ""
                    ]
            Nothing ->
                text ""
        , case doc.clusterName of
            Just clusterName ->
                case doc.clusterId of
                    Just clusterId ->
                        div [ class "cluster-info" ]
                            [ span [ class "cluster-label" ] [ text "Cluster: " ]
                            , a
                                [ href "#"
                                , onClick (NavigateToCluster clusterId)
                                , class "cluster-link"
                                ]
                                [ text (String.fromInt (clusterId + 1) ++ ". " ++ clusterName) ]
                            ]

                    Nothing ->
                        text ""

            Nothing ->
                text ""
        , case doc.tags of
            Just tags ->
                if String.isEmpty tags then
                    text ""

                else
                    div [ class "tags" ]
                        (tags
                            |> String.split ","
                            |> List.map String.trim
                            |> List.filter (not << String.isEmpty)
                            |> List.map (\tag -> span [ class "tag" ] [ text tag ])
                        )

            Nothing ->
                text ""
        , case doc.source of
            Just source ->
                if String.isEmpty source then
                    text ""
                else
                    div [ class "document-source" ]
                        [ span [ class "source-label" ] [ text "Source: " ]
                        , if String.startsWith "http://" source || String.startsWith "https://" source then
                            a [ href source, target "_blank", class "source-link" ] [ text source ]
                          else
                            span [ class "source-text" ] [ text source ]
                        ]

            Nothing ->
                text ""
        , case doc.authors of
            Just authors ->
                if String.isEmpty authors then
                    text ""
                else
                    div [ class "document-authors" ]
                        [ span [ class "authors-label" ] [ text "Authors: " ]
                        , span [ class "authors-text" ] [ text authors ]
                        ]

            Nothing ->
                text ""
        , div [ class "document-actions" ]
            (case doc.docType of
                Just "pdf" ->
                    [ button [ onClick (OpenPDFNative (extractPDFFilename doc.content)), class "open-button" ] [ text "Open PDF" ]
                    , button [ onClick (StartEditingDocument doc), class "edit-button" ] [ text "Edit" ]
                    , button [ onClick (ShowMoveDocumentModal doc.id), class "edit-button" ] [ text "Move" ]
                    , button [ onClick (DeleteDocument doc.id), class "delete-button" ] [ text "Delete" ]
                    ]

                _ ->
                    if String.startsWith "[PDF_FILE:" doc.content then
                        [ button [ onClick (OpenPDFNative (extractPDFFilename doc.content)), class "open-button" ] [ text "Open PDF" ]
                        , button [ onClick (StartEditingDocument doc), class "edit-button" ] [ text "Edit" ]
                        , button [ onClick (ShowMoveDocumentModal doc.id), class "edit-button" ] [ text "Move" ]
                        , button [ onClick (DeleteDocument doc.id), class "delete-button" ] [ text "Delete" ]
                        ]

                    else
                        [ button [ onClick (StartEditingDocument doc), class "edit-button" ] [ text "Edit" ]
                        , button [ onClick (ShowMoveDocumentModal doc.id), class "edit-button" ] [ text "Move" ]
                        , button [ onClick (DeleteDocument doc.id), class "delete-button" ] [ text "Delete" ]
                        ]
            )
        , case doc.docType of
            Just "scr" ->
                div
                    [ class "document-content"
                    , class "scr"
                    , Html.Attributes.style "width" (String.fromInt (docWidth - 80) ++ "px")
                    , Html.Attributes.style "font-size" (String.fromInt 12 ++ "px")
                    ]
                    (ScriptaV2.APISimple.compile params doc.content
                        |> List.map (Element.map ScriptaDocument >> Element.layout [ Render.Helper.htmlId "rendered-text" ])
                    )

            Just "ltx" ->
                div
                    [ class "document-content"
                    , class "ltx"
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

            Just "pdf" ->
                let
                    filename =
                        extractPDFFilename doc.content
                in
                if String.isEmpty filename then
                    div [ class "document-content" ]
                        [ text "PDF file not found" ]

                else
                    div [ class "document-content pdf-content" ]
                        [ -- Try to extract thumbnail info
                          case extractPDFMetadata doc.content of
                            Just meta ->
                                if List.isEmpty meta.thumbnails then
                                    -- No thumbnails, show fallback message
                                    div [ class "pdf-iframe-fallback" ]
                                        [ p [] [ text "PDF viewer blocked by browser security settings." ]
                                        , p [] [ text "Use the 'Open PDF' button above to view this document." ]
                                        ]

                                else
                                    -- Show thumbnails
                                    div [ class "pdf-thumbnails" ]
                                        [ h4 [] [ text ("Pages: " ++ String.fromInt meta.pages) ]
                                        , div [ class "thumbnail-grid" ]
                                            (List.map (viewThumbnail model.config.apiUrl) meta.thumbnails)
                                        ]

                            Nothing ->
                                -- No metadata, show fallback message
                                div [ class "pdf-iframe-fallback" ]
                                    [ p [] [ text "PDF viewer blocked by browser security settings." ]
                                    , p [] [ text "Use the 'Open PDF' button above to view this document." ]
                                    ]
                        ]

            _ ->
                -- Check if this is a PDF by looking at content
                if String.startsWith "[PDF_FILE:" doc.content then
                    let
                        -- Extract PDF filename from content
                        pdfFilename =
                            case String.indexes "[PDF_FILE:" doc.content of
                                [] ->
                                    Nothing

                                index :: _ ->
                                    let
                                        afterMarker =
                                            String.dropLeft (index + 10) doc.content

                                        endIndex =
                                            String.indexes "]" afterMarker
                                                |> List.head
                                                |> Maybe.withDefault 0

                                        filename =
                                            String.left endIndex afterMarker
                                    in
                                    if String.isEmpty filename then
                                        Nothing

                                    else
                                        Just filename
                    in
                    case pdfFilename of
                        Just filename ->
                            div [ class "document-content pdf-content" ]
                                [ div [ class "pdf-iframe-container" ]
                                    [ iframe
                                        [ src (model.config.apiUrl ++ "/pdf/" ++ filename)
                                        , Html.Attributes.style "width" "100%"
                                        , Html.Attributes.style "height" "800px"
                                        , Html.Attributes.style "border" "1px solid #ccc"
                                        , Html.Attributes.attribute "sandbox" "allow-same-origin"
                                        , Html.Attributes.type_ "application/pdf"
                                        ]
                                        []
                                    ]
                                ]

                        Nothing ->
                            div [ class "document-content" ]
                                [ text "PDF file not found" ]

                else
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
        , div [ class "editing-header" ]
            [ div [ class "editing-mode-section" ]
                [ span [ class "editing-label" ] [ text "Editing mode" ]
                , div [ class "inline-tags-editor" ]
                    [ label [] [ text "Tags:" ]
                    , input
                        [ type_ "text"
                        , value editing.tags
                        , onInput UpdateEditingTags
                        , placeholder "e.g., quantum physics, research, 2023"
                        , class "inline-tags-input"
                        ]
                        []
                    ]
                , div [ class "inline-tags-editor" ]
                    [ label [] [ text "Source:" ]
                    , input
                        [ type_ "text"
                        , value editing.source
                        , onInput UpdateEditingSource
                        , placeholder "e.g., https://example.com or Book Title"
                        , class "inline-tags-input"
                        ]
                        []
                    ]
                , div [ class "inline-tags-editor" ]
                    [ label [] [ text "Authors:" ]
                    , input
                        [ type_ "text"
                        , value editing.authors
                        , onInput UpdateEditingAuthors
                        , placeholder "e.g., F.M. Claro, Ph.D; Mary Jo Feinhof, M.D."
                        , class "inline-tags-input"
                        ]
                        []
                    ]
                ]
            , div [ class "document-actions" ]
                [ button
                    [ onClick SaveEditingDocument
                    , class "save-button"
                    , disabled (String.isEmpty editing.title)
                    ]
                    [ text "Save" ]
                , button
                    [ onClick CancelEditingDocument
                    , class "cancel-button"
                    ]
                    [ text "Cancel" ]
                ]
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
                , if editing.docType == Just "pdf" || String.startsWith "[PDF_FILE:" editing.content then
                    div []
                        [ textarea
                            [ value editing.content
                            , class "form-textarea"
                            , rows 15
                            , disabled True
                            , Html.Attributes.style "background-color" "#f5f5f5"
                            , Html.Attributes.style "cursor" "not-allowed"
                            ]
                            []
                        , p [ Html.Attributes.style "color" "#666", Html.Attributes.style "font-size" "0.875rem", Html.Attributes.style "margin-top" "0.5rem" ]
                            [ text "PDF content cannot be edited. You can only change the title and tags." ]
                        ]

                  else
                    textarea
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
                [ label [] [ text "Tags (comma-separated)" ]
                , input
                    [ type_ "text"
                    , value model.newDocument.tags
                    , onInput UpdateNewDocTags
                    , placeholder "e.g., quantum physics, research, 2023"
                    , class "form-input"
                    ]
                    []
                ]
            , div [ class "form-group" ]
                [ label [] [ text "Source (URL or reference)" ]
                , input
                    [ type_ "text"
                    , value model.newDocument.source
                    , onInput UpdateNewDocSource
                    , placeholder "e.g., https://example.com/article or Book Title, Page 123"
                    , class "form-input"
                    ]
                    []
                ]
            , div [ class "form-group" ]
                [ label [] [ text "Authors (semicolon-separated)" ]
                , input
                    [ type_ "text"
                    , value model.newDocument.authors
                    , onInput UpdateNewDocAuthors
                    , placeholder "e.g., F.M. Claro, Ph.D; Mary Jo Feinhof, M.D."
                    , class "form-input"
                    ]
                    []
                ]
            , button
                [ onClick AddDocument
                , class "submit-button"
                , disabled (String.isEmpty model.newDocument.title || String.isEmpty model.newDocument.content)
                ]
                [ text "Add Document" ]
            ]
        ]


viewGraph : Model -> Html Msg
viewGraph model =
    div [ class "graph-view" ]
        [ h2 [] [ text "Cluster Graph" ]
        , case model.clusterVisualization of
            Nothing ->
                if model.clusterLoading then
                    div [ class "loading" ] [ text "Loading visualization..." ]
                else
                    div [ class "empty-state" ] [ text "No visualization data available" ]
                    
            Just visualization ->
                let
                    -- Find bounds for scaling
                    allX = List.map .x visualization.documents ++ List.map .x visualization.clusters
                    allY = List.map .y visualization.documents ++ List.map .y visualization.clusters
                    
                    minX = Maybe.withDefault 0 (List.minimum allX)
                    maxX = Maybe.withDefault 1 (List.maximum allX)
                    minY = Maybe.withDefault 0 (List.minimum allY)
                    maxY = Maybe.withDefault 1 (List.maximum allY)
                    
                    -- Add padding
                    rangeX = maxX - minX
                    rangeY = maxY - minY
                    paddingFactor = 0.1
                    
                    viewMinX = minX - (rangeX * paddingFactor)
                    viewMaxX = maxX + (rangeX * paddingFactor)
                    viewMinY = minY - (rangeY * paddingFactor)
                    viewMaxY = maxY + (rangeY * paddingFactor)
                    
                    -- Scale to SVG coordinates
                    svgWidth = 800
                    svgHeight = 600
                    
                    scaleX x = ((x - viewMinX) / (viewMaxX - viewMinX)) * svgWidth
                    scaleY y = svgHeight - ((y - viewMinY) / (viewMaxY - viewMinY)) * svgHeight  -- Flip Y axis
                    
                    -- Group documents by cluster
                    documentsByCluster =
                        List.foldl
                            (\doc acc ->
                                let
                                    key = String.fromInt doc.clusterId
                                    current = Maybe.withDefault [] (Dict.get key acc)
                                in
                                Dict.insert key (doc :: current) acc
                            )
                            Dict.empty
                            visualization.documents
                in
                div [ class "graph-container" ]
                    [ svg
                        [ SvgAttr.viewBox ("0 0 " ++ String.fromFloat svgWidth ++ " " ++ String.fromFloat svgHeight)
                        , SvgAttr.width "100%"
                        , SvgAttr.height "600"
                        , SvgAttr.style "background-color: #f9f9f9; border: 1px solid #e0e0e0;"
                        ]
                        (viewProjectedVisualization scaleX scaleY visualization documentsByCluster svgWidth svgHeight)
                    , div [ class "graph-legend" ]
                        [ p [] [ text "• Small dots: Individual documents" ]
                        , p [] [ text "• Large dots: Cluster centroids (click to view cluster)" ]
                        , p [] [ text ("• Explained variance: " ++ 
                            (String.join ", " (List.map (\v -> String.fromFloat (toFloat (round (v * 10000)) / 100) ++ "%") (List.take 2 visualization.explainedVarianceRatio))) ++ 
                            " (first two principal components)") ]
                        ]
                    ]
        ]


viewProjectedVisualization : (Float -> Float) -> (Float -> Float) -> ClusterVisualization -> Dict String (List VisualizationDocument) -> Float -> Float -> List (Svg.Svg Msg)
viewProjectedVisualization scaleX scaleY visualization documentsByCluster svgWidth svgHeight =
    let
        -- Draw Voronoi cells from server data
        voronoiCells =
            List.map (drawVoronoiCell scaleX scaleY) visualization.voronoiCells
        
        -- Draw lines from documents to their cluster centers
        lines =
            List.concatMap
                (\doc ->
                    case List.filter (\c -> c.clusterId == doc.clusterId) visualization.clusters |> List.head of
                        Just cluster ->
                            [ line
                                [ SvgAttr.x1 (String.fromFloat (scaleX doc.x))
                                , SvgAttr.y1 (String.fromFloat (scaleY doc.y))
                                , SvgAttr.x2 (String.fromFloat (scaleX cluster.x))
                                , SvgAttr.y2 (String.fromFloat (scaleY cluster.y))
                                , SvgAttr.stroke "#d0d0d0"
                                , SvgAttr.strokeWidth "0.5"
                                , SvgAttr.opacity "0.3"
                                ]
                                []
                            ]
                        Nothing ->
                            []
                )
                visualization.documents
        
        -- Draw document dots
        documentDots =
            List.map
                (\doc ->
                    circle
                        [ SvgAttr.cx (String.fromFloat (scaleX doc.x))
                        , SvgAttr.cy (String.fromFloat (scaleY doc.y))
                        , SvgAttr.r "3"
                        , SvgAttr.fill "#6b7280"
                        , SvgAttr.title doc.title
                        , SvgAttr.opacity "0.7"
                        ]
                        []
                )
                visualization.documents
        
        -- Draw cluster centroids
        clusterElements =
            List.map
                (\cluster ->
                    g []
                        [ -- Clickable cluster dot
                          circle
                            [ SvgAttr.cx (String.fromFloat (scaleX cluster.x))
                            , SvgAttr.cy (String.fromFloat (scaleY cluster.y))
                            , SvgAttr.r "6"
                            , SvgAttr.fill "rgba(37, 99, 235, 0.2)"
                            , SvgAttr.stroke "#2563eb"
                            , SvgAttr.strokeWidth "2"
                            , SvgAttr.cursor "pointer"
                            , SvgEvents.onClick (NavigateToCluster (cluster.clusterId - 1))
                            , SvgAttr.title ("Cluster " ++ String.fromInt cluster.clusterId ++ ": " ++ cluster.name ++ " (" ++ String.fromInt cluster.size ++ " docs)")
                            ]
                            []
                        , -- Cluster label
                          Svg.text_
                            [ SvgAttr.x (String.fromFloat (scaleX cluster.x))
                            , SvgAttr.y (String.fromFloat (scaleY cluster.y + 15))  -- Below the centroid
                            , SvgAttr.textAnchor "middle"
                            , SvgAttr.fontSize "10"
                            , SvgAttr.fill "#1f2937"
                            ]
                            [ Svg.text (String.fromInt cluster.clusterId ++ ". " ++ abbreviateClusterName cluster.name) ]
                        ]
                )
                visualization.clusters
    in
    voronoiCells ++ lines ++ documentDots ++ clusterElements


drawVoronoiCell : (Float -> Float) -> (Float -> Float) -> VoronoiCell -> Svg.Svg Msg
drawVoronoiCell scaleX scaleY cell =
    let
        -- Scale the vertices
        scaledVertices =
            List.map (\(x, y) -> (scaleX x, scaleY y)) cell.vertices
        
        -- Create path string for polygon
        pathString =
            case scaledVertices of
                [] ->
                    ""
                    
                first :: rest ->
                    let
                        moveTo = "M " ++ String.fromFloat (Tuple.first first) ++ " " ++ String.fromFloat (Tuple.second first)
                        lineTo = List.map (\(x, y) -> "L " ++ String.fromFloat x ++ " " ++ String.fromFloat y) rest
                        closePath = " Z"
                    in
                    moveTo ++ " " ++ String.join " " lineTo ++ closePath
    in
    Svg.path
        [ SvgAttr.d pathString
        , SvgAttr.fill "none"
        , SvgAttr.stroke "red"
        , SvgAttr.strokeWidth "0.5"
        , SvgAttr.opacity "0.7"
        ]
        []


abbreviateClusterName : String -> String
abbreviateClusterName name =
    let
        words = String.words name
        abbreviated =
            if List.length words > 3 then
                String.join " " (List.take 2 words) ++ "..."
            else if String.length name > 20 then
                String.left 17 name ++ "..."
            else
                name
    in
    abbreviated


viewGraphWindow : Model -> Html Msg
viewGraphWindow model =
    div
        [ class "graph-window"
        , style "position" "fixed"
        , style "left" (String.fromInt model.graphWindowPosition.x ++ "px")
        , style "top" (String.fromInt model.graphWindowPosition.y ++ "px")
        , style "width" (String.fromInt model.graphWindowSize.width ++ "px")
        , style "height" (String.fromInt model.graphWindowSize.height ++ "px")
        , style "background-color" "white"
        , style "border" "1px solid #ccc"
        , style "box-shadow" "0 4px 8px rgba(0,0,0,0.2)"
        , style "z-index" "1000"
        , style "display" "flex"
        , style "flex-direction" "column"
        ]
        [ -- Title bar
          div
            [ class "graph-window-titlebar"
            , style "background-color" "#f0f0f0"
            , style "padding" "8px"
            , style "display" "flex"
            , style "justify-content" "space-between"
            , style "align-items" "center"
            , style "cursor" "move"
            , onMouseDown StartDraggingGraphWindow
            ]
            [ h3 [ style "margin" "0" ] [ text "Cluster Visualization" ]
            , button
                [ onClick CloseGraphWindow
                , style "background" "none"
                , style "border" "none"
                , style "font-size" "18px"
                , style "cursor" "pointer"
                ]
                [ text "×" ]
            ]
        , -- Content
          div
            [ style "flex" "1"
            , style "overflow" "auto"
            , style "padding" "10px"
            ]
            [ if model.clusterLoading then
                div [ class "loading" ] [ text "Loading visualization..." ]
              else
                case model.clusterVisualization of
                    Nothing ->
                        div [ class "empty-state" ] [ text "No visualization data available" ]
                        
                    Just visualization ->
                        viewGraphContent model visualization
            ]
        , -- Resize handle
          div
            [ class "resize-handle"
            , style "position" "absolute"
            , style "bottom" "0"
            , style "right" "0"
            , style "width" "15px"
            , style "height" "15px"
            , style "cursor" "nwse-resize"
            , style "background" "linear-gradient(135deg, transparent 50%, #999 50%)"
            , onMouseDown (StartResizingGraphWindow BottomRightCorner)
            ]
            []
        ]


viewGraphContent : Model -> ClusterVisualization -> Html Msg
viewGraphContent model visualization =
    let
        -- Find bounds for scaling
        allX = List.map .x visualization.documents ++ List.map .x visualization.clusters
        allY = List.map .y visualization.documents ++ List.map .y visualization.clusters
        
        minX = Maybe.withDefault 0 (List.minimum allX)
        maxX = Maybe.withDefault 1 (List.maximum allX)
        minY = Maybe.withDefault 0 (List.minimum allY)
        maxY = Maybe.withDefault 1 (List.maximum allY)
        
        -- Add padding
        rangeX = maxX - minX
        rangeY = maxY - minY
        paddingFactor = 0.1
        
        viewMinX = minX - (rangeX * paddingFactor)
        viewMaxX = maxX + (rangeX * paddingFactor)
        viewMinY = minY - (rangeY * paddingFactor)
        viewMaxY = maxY + (rangeY * paddingFactor)
        
        -- Scale to SVG coordinates
        svgWidth = toFloat (model.graphWindowSize.width - 40)  -- Account for padding
        svgHeight = toFloat (model.graphWindowSize.height - 120)  -- Account for title bar and padding
        
        scaleX x = ((x - viewMinX) / (viewMaxX - viewMinX)) * svgWidth
        scaleY y = svgHeight - ((y - viewMinY) / (viewMaxY - viewMinY)) * svgHeight  -- Flip Y axis
        
        -- Group documents by cluster
        documentsByCluster =
            List.foldl
                (\doc acc ->
                    let
                        key = String.fromInt doc.clusterId
                        current = Maybe.withDefault [] (Dict.get key acc)
                    in
                    Dict.insert key (doc :: current) acc
                )
                Dict.empty
                visualization.documents
    in
    div []
        [ svg
            [ SvgAttr.viewBox ("0 0 " ++ String.fromFloat svgWidth ++ " " ++ String.fromFloat svgHeight)
            , SvgAttr.width "100%"
            , SvgAttr.height (String.fromInt (model.graphWindowSize.height - 120) ++ "px")
            , SvgAttr.style "background-color: #f9f9f9; border: 1px solid #e0e0e0;"
            ]
            (viewProjectedVisualization scaleX scaleY visualization documentsByCluster svgWidth svgHeight)
        , div [ class "graph-legend", style "margin-top" "10px" ]
            [ p [ style "margin" "5px 0", style "font-size" "12px" ] [ text "• Small dots: Individual documents" ]
            , p [ style "margin" "5px 0", style "font-size" "12px" ] [ text "• Large dots: Cluster centroids (click to view cluster)" ]
            , p [ style "margin" "5px 0", style "font-size" "12px" ] [ text ("• Explained variance: " ++ 
                (String.join ", " (List.map (\v -> String.fromFloat (toFloat (round (v * 10000)) / 100) ++ "%") (List.take 2 visualization.explainedVarianceRatio))) ++ 
                " (first two principal components)") ]
            ]
        ]


onMouseDown : (Int -> Int -> msg) -> Attribute msg
onMouseDown toMsg =
    on "mousedown" (Decode.map2 toMsg pageX pageY)


pageX : Decode.Decoder Int
pageX =
    Decode.field "pageX" Decode.int


pageY : Decode.Decoder Int
pageY =
    Decode.field "pageY" Decode.int


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
                        [ h3 [] [ text "Documents" ]
                        , p [ class "stat-value", style "display" "flex", style "align-items" "center", style "justify-content" "center" ]
                            [ text (String.fromInt stats.totalDocuments)
                            , span [ style "font-size" "0.5em", style "margin-left" "1rem", style "font-weight" "normal" ]
                                [ text ("DB: " ++ formatDatabaseSize stats.databaseSizeKb) ]
                            ]
                        ]
                    , div [ class "stat-card" ]
                        [ h3 [] [ text "Vectors" ]
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


abstractSourceLabel : String -> String
abstractSourceLabel source =
    case source of
        "extracted" ->
            "Extracted from document"
        
        "ai_generated" ->
            "AI generated"
        
        "manual" ->
            "Manually entered"
        
        "first_paragraph" ->
            "First paragraph"
        
        _ ->
            source


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


formatDatabaseSize : Float -> String
formatDatabaseSize sizeKb =
    if sizeKb >= 1024 then
        let
            sizeMb =
                sizeKb / 1024

            -- Round to 2 decimal places
            rounded =
                toFloat (round (sizeMb * 100)) / 100
        in
        String.fromFloat rounded ++ " MB"

    else
        String.fromFloat sizeKb ++ " KB"


viewClusters : Model -> Html Msg
viewClusters model =
    div [ class "clusters-view" ]
        [ h2 [] [ text "Clusters" ]
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
                        , div [ class "clusters-list" ]
                            (List.indexedMap (viewClusterCollapsible model) clusterResponse.clusters)
                        ]

                Nothing ->
                    div [ class "empty-state" ] [ text "No clusters loaded. Click 'Clusters' to analyze." ]
        ]


viewClusterCollapsible : Model -> Int -> Cluster -> Html Msg
viewClusterCollapsible model index cluster =
    let
        isExpanded =
            List.member cluster.clusterId model.expandedClusters

        totalDocs =
            case model.clusters of
                Just clusterResponse ->
                    clusterResponse.totalDocuments

                Nothing ->
                    0
    in
    div [ class "cluster-list-item" ]
        [ div
            [ onClick (ToggleClusterExpansion cluster.clusterId)
            , style "cursor" "pointer"
            , class "cluster-name-line"
            ]
            [ text (String.fromInt (index + 1) ++ ". " ++ cluster.clusterName ++ " (" ++ String.fromInt cluster.size ++ "/" ++ String.fromInt totalDocs ++ ")") ]
        , if isExpanded then
            div [ class "cluster-expanded-content" ]
                [ ul [ class "cluster-doc-list" ]
                    (List.map viewClusterDocument cluster.documents)
                ]

          else
            text ""
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
    li [ class "cluster-document-item" ]
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
subscriptions model =
    Sub.batch
        [ Browser.Events.onResize WindowResized
        , Browser.Events.onKeyDown keyDecoder
        , if model.graphWindowDragging /= Nothing then
            Sub.batch
                [ Browser.Events.onMouseMove (Decode.map2 DragGraphWindow pageX pageY)
                , Browser.Events.onMouseUp (Decode.succeed StopDraggingGraphWindow)
                ]
          else if model.graphWindowResizing /= Nothing then
            Sub.batch
                [ Browser.Events.onMouseMove (Decode.map2 ResizeGraphWindow pageX pageY)
                , Browser.Events.onMouseUp (Decode.succeed StopResizingGraphWindow)
                ]
          else
            Sub.none
        ]


keyDecoder : Decode.Decoder Msg
keyDecoder =
    Decode.map2 toKeyMsg
        (Decode.field "key" Decode.string)
        (Decode.field "ctrlKey" Decode.bool)


toKeyMsg : String -> Bool -> Msg
toKeyMsg key ctrlPressed =
    if ctrlPressed then
        case String.toLower key of
            "n" ->
                KeyPressed "n"

            "u" ->
                KeyPressed "u"

            "d" ->
                KeyPressed "d"

            "c" ->
                KeyPressed "c"

            "l" ->
                KeyPressed "l"

            "k" ->
                KeyPressed "k"

            "r" ->
                KeyPressed "r"

            "g" ->
                KeyPressed "g"

            _ ->
                NoOp

    else
        NoOp


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
