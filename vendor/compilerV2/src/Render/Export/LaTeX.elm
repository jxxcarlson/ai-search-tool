module Render.Export.LaTeX exposing (export, exportExpr, rawExport)

{-|

@docs export, exportExpr, rawExport

-}

import Dict exposing (Dict)
import Either exposing (Either(..))
import Generic.ASTTools as ASTTools
import Generic.BlockUtilities
import Generic.Forest exposing (Forest)
import Generic.Language exposing (Expr(..), Expression, ExpressionBlock, Heading(..))
import Generic.TextMacro
import List.Extra
import Maybe.Extra
import MicroLaTeX.Util
import Render.Data
import Render.Export.Image
import Render.Export.Preamble
import Render.Export.Util
import Render.Settings exposing (RenderSettings)
import Render.Utility as Utility
import RoseTree.Tree as Tree exposing (Tree)
import Time
import Tools.Loop exposing (Step(..), loop)


counterValue : Forest ExpressionBlock -> Maybe Int
counterValue ast =
    ast
        |> ASTTools.getBlockArgsByName "setcounter"
        |> List.head
        |> Maybe.andThen String.toInt


{-| -}
export : Time.Posix -> RenderSettings -> List (Tree ExpressionBlock) -> String
export currentTime settings_ ast =
    let
        rawBlockNames =
            ASTTools.rawBlockNames ast

        expressionNames =
            ASTTools.expressionNames ast ++ macrosInTextMacroDefinitions

        textMacroDefinitions =
            ASTTools.getVerbatimBlockValue "textmacros" ast

        macrosInTextMacroDefinitions =
            Generic.TextMacro.getTextMacroFunctionNames textMacroDefinitions
    in
    Render.Export.Preamble.make
        rawBlockNames
        expressionNames
        ++ frontMatter currentTime ast
        ++ ("\n\\setcounter{section}{" ++ (counterValue ast |> zeroOrSome |> String.fromInt) ++ "}\n")
        ++ tableofcontents rawBlockNames
        ++ "\n\n"
        ++ rawExport settings_ ast
        ++ "\n\n\\end{document}\n"


frontMatter : Time.Posix -> Forest ExpressionBlock -> String
frontMatter currentTime ast =
    let
        dict =
            ASTTools.frontMatterDict ast

        author1 =
            Dict.get "author1" dict

        author2 =
            Dict.get "author2" dict

        author3 =
            Dict.get "author3" dict

        author4 =
            Dict.get "author4" dict

        authors =
            [ author1, author2, author3, author4 ]
                |> Maybe.Extra.values
                |> String.join "\n\\and\n"
                |> (\s -> "\\author{\n" ++ s ++ "\n}")

        title =
            ASTTools.title ast |> (\title_ -> "\\title{" ++ title_ ++ "}")

        date =
            Dict.get "date" dict |> Maybe.map (\date_ -> "\\date{" ++ date_ ++ "}") |> Maybe.withDefault ""
    in
    ("\\begin{document}"
        :: title
        :: date
        :: authors
        :: "\\maketitle\n\n"
        :: []
        |> String.join "\n\n"
    )
        ++ "\\maketitle\n\n"


today : Time.Posix -> String
today currenTime =
    "currentTime: not implemented"


tableofcontents rawBlockNames_ =
    if List.length (List.filter (\name -> name == "section") rawBlockNames_) > 1 then
        "\n\n\\tableofcontents"

    else
        ""


zeroOrSome : Maybe Int -> Int
zeroOrSome mInt =
    case mInt of
        Nothing ->
            0

        Just k ->
            k


oneOrTwo : Maybe Int -> Int
oneOrTwo mInt =
    case mInt of
        Nothing ->
            1

        Just _ ->
            2


{-| In a standalone MicroLaTeX document, sections correspond to sections in the
exported document.

If a document is part of a collection or "notebook", where we have
set the section number using \\setcounter{N}, sections correspond
to subsections IF the document is exported as a standalone document.

Function shiftSection makes the adjustments needed for export.

-}
shiftSection : Int -> ExpressionBlock -> ExpressionBlock
shiftSection delta block =
    if Generic.BlockUtilities.getExpressionBlockName block == Just "section" then
        case block.args of
            level :: rest ->
                case String.toInt level of
                    Nothing ->
                        block

                    Just kk ->
                        let
                            newLevel =
                                String.fromInt (kk + delta)
                        in
                        { block | args = newLevel :: rest }

            _ ->
                block

    else
        block


exportTree : RenderSettings -> Tree ExpressionBlock -> String
exportTree settings tree =
    case Tree.children tree of
        [] ->
            exportBlock settings (Tree.value tree)

        children ->
            let
                renderedChildren : List String
                renderedChildren =
                    List.map (exportTree settings) children
                        |> List.map String.lines
                        |> List.concat

                root =
                    exportBlock settings (Tree.value tree) |> String.lines
            in
            case List.Extra.unconsLast root of
                Nothing ->
                    ""

                Just ( lastLine, firstLines ) ->
                    let
                        _ =
                            firstLines

                        _ =
                            renderedChildren

                        _ =
                            lastLine
                    in
                    firstLines ++ renderedChildren ++ [ lastLine ] |> String.join "\n"


{-| -}
rawExport : RenderSettings -> List (Tree ExpressionBlock) -> String
rawExport settings ast =
    ast
        |> ASTTools.filterForestOnLabelNames (\name -> not (name == Just "runninghead"))
        |> Generic.Forest.map Generic.BlockUtilities.condenseUrls
        |> encloseLists
        |> Generic.Forest.map (counterValue ast |> oneOrTwo |> shiftSection)
        |> List.map (exportTree settings)
        |> String.join "\n\n"


type Status
    = InsideItemizedList
    | InsideNumberedList
    | InsideDescriptionList
    | OutsideList


encloseLists : Forest ExpressionBlock -> Forest ExpressionBlock
encloseLists blocks =
    loop { status = OutsideList, input = blocks, output = [], itemNumber = 0 } nextStep |> List.reverse


type alias State =
    { status : Status, input : Forest ExpressionBlock, output : Forest ExpressionBlock, itemNumber : Int }


nextStep : State -> Step State (Forest ExpressionBlock)
nextStep state =
    case List.head state.input of
        Nothing ->
            Done state.output

        Just tree ->
            Loop (nextState tree state)


emptyExpressionBlock =
    Generic.Language.expressionBlockEmpty


beginItemizedBlock : ExpressionBlock
beginItemizedBlock =
    { emptyExpressionBlock
        | indent = 1
        , heading = Ordinary "beginBlock"
        , body = Right [ Text "itemize" { begin = 0, end = 7, index = 0, id = "" } ]
    }
        |> Generic.BlockUtilities.updateMeta
            (\m ->
                { m
                    | sourceText = "| beginBlock\nitemize"
                    , numberOfLines = 2
                }
            )


endItemizedBlock : ExpressionBlock
endItemizedBlock =
    { emptyExpressionBlock
        | indent = 1
        , heading = Ordinary "endBlock"
        , body = Right [ Text "itemize" { begin = 0, end = 7, index = 0, id = "end" } ]
    }
        |> Generic.BlockUtilities.updateMeta
            (\m ->
                { m
                    | sourceText = "| endBlock\nitemize"
                    , numberOfLines = 2
                }
            )


beginNumberedBlock : ExpressionBlock
beginNumberedBlock =
    { emptyExpressionBlock
        | indent = 1
        , heading = Ordinary "beginNumberedBlock"
        , body = Right [ Text "enumerate" { begin = 0, end = 7, index = 0, id = "begin" } ]
    }
        |> Generic.BlockUtilities.updateMeta
            (\m ->
                { m
                    | sourceText = "| beginBlock\nitemize"
                    , numberOfLines = 2
                }
            )



--
--ExpressionBlock
--    { args = []
--    , properties = Dict.empty
--    , blockType = OrdinaryBlock [ "beginNumberedBlock" ]
--    , content = Right [ Text "enumerate" { begin = 0, end = 7, index = 0, id = "begin" } ]
--    , messages = []
--    , id = "0"
--    , tag = ""
--    , indent = 1
--    , lineNumber = 0
--    , name = Just "beginNumberedBlock"
--    , numberOfLines = 2
--    , sourceText = "| beginBlock\nitemize"
--    , error = Nothing
--    }


endNumberedBlock : ExpressionBlock
endNumberedBlock =
    { emptyExpressionBlock
        | indent = 1
        , heading = Ordinary "endNumberedBlock"
        , body = Right [ Text "enumerate" { begin = 0, end = 7, index = 0, id = "begin" } ]
    }
        |> Generic.BlockUtilities.updateMeta
            (\m ->
                { m
                    | sourceText = "| endBlock\nitemize"
                    , numberOfLines = 2
                }
            )


beginDescriptionBlock : ExpressionBlock
beginDescriptionBlock =
    { emptyExpressionBlock
        | indent = 1
        , heading = Ordinary "beginDescriptionBlock"
        , body = Right [ Text "description" { begin = 0, end = 7, index = 0, id = "begin" } ]
    }
        |> Generic.BlockUtilities.updateMeta
            (\m ->
                { m
                    | sourceText = "| beginBlock\ndescription"
                    , numberOfLines = 2
                }
            )


endDescriptionBlock : ExpressionBlock
endDescriptionBlock =
    { emptyExpressionBlock
        | indent = 1
        , heading = Ordinary "endDescriptionBlock"
        , body = Right [ Text "description" { begin = 0, end = 7, index = 0, id = "end" } ]
    }
        |> Generic.BlockUtilities.updateMeta
            (\m ->
                { m
                    | sourceText = "| endBlock\ndescription"
                    , numberOfLines = 2
                }
            )


nextState : Tree ExpressionBlock -> State -> State
nextState tree state =
    let
        name_ =
            Tree.value tree |> Generic.BlockUtilities.getExpressionBlockName
    in
    case ( state.status, name_ ) of
        -- ITEMIZED LIST
        ( OutsideList, Just "item" ) ->
            { state | status = InsideItemizedList, itemNumber = 1, output = tree :: Tree.leaf beginItemizedBlock :: state.output, input = List.drop 1 state.input }

        ( InsideItemizedList, Just "item" ) ->
            { state | output = tree :: state.output, itemNumber = state.itemNumber + 1, input = List.drop 1 state.input }

        ( InsideItemizedList, _ ) ->
            { state | status = OutsideList, itemNumber = 0, output = tree :: Tree.leaf endItemizedBlock :: state.output, input = List.drop 1 state.input }

        -- NUMBERED LIST
        ( OutsideList, Just "numbered" ) ->
            { state | status = InsideNumberedList, itemNumber = 1, output = tree :: Tree.leaf beginNumberedBlock :: state.output, input = List.drop 1 state.input }

        ( InsideNumberedList, Just "numbered" ) ->
            { state | output = tree :: state.output, itemNumber = state.itemNumber + 1, input = List.drop 1 state.input }

        ( InsideNumberedList, _ ) ->
            { state | status = OutsideList, itemNumber = 0, output = tree :: Tree.leaf endNumberedBlock :: state.output, input = List.drop 1 state.input }

        -- DESCRIPTION LIST
        ( OutsideList, Just "desc" ) ->
            { state | status = InsideDescriptionList, itemNumber = 1, output = tree :: Tree.leaf beginDescriptionBlock :: state.output, input = List.drop 1 state.input }

        ( InsideDescriptionList, Just "desc" ) ->
            { state | output = tree :: state.output, itemNumber = state.itemNumber + 1, input = List.drop 1 state.input }

        ( InsideDescriptionList, _ ) ->
            { state | status = OutsideList, itemNumber = 0, output = tree :: Tree.leaf endDescriptionBlock :: state.output, input = List.drop 1 state.input }

        --- OUTSIDE
        ( OutsideList, _ ) ->
            { state | output = tree :: state.output, input = List.drop 1 state.input }


exportBlock : RenderSettings -> ExpressionBlock -> String
exportBlock settings block =
    case block.heading of
        Paragraph ->
            case block.body of
                Left str ->
                    mapChars2 str

                Right exprs_ ->
                    exportExprList settings exprs_

        Ordinary "table" ->
            case block.body of
                Left str ->
                    str

                Right exprs_ ->
                    case List.head exprs_ of
                        Just (Fun "table" body _) ->
                            let
                                renderRow : Expression -> List Expression
                                renderRow rowExpr =
                                    case rowExpr of
                                        Fun "row" cells _ ->
                                            cells

                                        _ ->
                                            []

                                cellTable : List (List Expression)
                                cellTable =
                                    List.map renderRow body

                                stringTable : List (List String)
                                stringTable =
                                    cellTable |> List.map (List.map (exportCell settings))

                                exportCell : RenderSettings -> Expression -> String
                                exportCell settings_ expr =
                                    case expr of
                                        Fun "cell" exprs2 _ ->
                                            exportExprList settings_ exprs2

                                        _ ->
                                            "error constructing table cell"

                                makeRow : List String -> String
                                makeRow row =
                                    row |> String.join "& "

                                output =
                                    List.map makeRow stringTable |> String.join " \\\\\n"

                                columns =
                                    List.length (List.Extra.transpose stringTable)

                                defaultFormat =
                                    List.repeat columns "l"
                                        |> String.join " "
                                        |> (\x -> "{" ++ x ++ "}")

                                format =
                                    Dict.get "format" block.properties |> Maybe.withDefault defaultFormat
                            in
                            "\\begin{tabular}" ++ format ++ "\n" ++ output ++ "\n\\end{tabular}"

                        _ ->
                            "error in constructing table"

        Ordinary name ->
            case block.body of
                Left _ ->
                    ""

                Right exprs_ ->
                    case Dict.get name blockDict of
                        Just f ->
                            f settings block.args (exportExprList settings exprs_)

                        Nothing ->
                            environment name (exportExprList settings exprs_)

        Verbatim name ->
            case block.body of
                Left str ->
                    case name of
                        "math" ->
                            let
                                fix_ : String -> String
                                fix_ str_ =
                                    str_
                                        |> String.lines
                                        |> List.filter (\line -> String.left 2 line /= "$$")
                                        |> String.join "\n"
                                        |> MicroLaTeX.Util.transformLabel
                            in
                            -- TODO: This should be fixed upstream
                            [ "$$", fix_ str, "$$" ] |> String.join "\n"

                        "datatable" ->
                            let
                                data =
                                    Render.Data.prepareTable 1 block

                                renderRow : Int -> List Int -> List String -> String
                                renderRow rowNumber widths_ rowOfCells =
                                    if rowNumber == 0 then
                                        List.map2 (\cell width -> String.padRight width ' ' cell) rowOfCells widths_
                                            |> String.join " "
                                            |> String.replace "_" " "

                                    else
                                        List.map2 (\cell width -> String.padRight width ' ' cell) rowOfCells widths_ |> String.join " "

                                renderedRows =
                                    List.indexedMap (\rowNumber -> renderRow rowNumber data.columnWidths) data.selectedCells |> String.join "\n"
                            in
                            case data.title of
                                Nothing ->
                                    [ "\\begin{verbatim}", renderedRows, "\\end{verbatim}" ] |> String.join "\n"

                                Just title ->
                                    let
                                        separator =
                                            String.repeat data.totalWidth "-"
                                    in
                                    [ "\\begin{verbatim}", title, separator, renderedRows, "\\end{verbatim}" ] |> String.join "\n"

                        "equation" ->
                            -- TODO: there should be a trailing "$$"
                            -- TODO: equation numbers and label
                            [ "\\begin{equation}", str |> MicroLaTeX.Util.transformLabel, "\\end{equation}" ] |> String.join "\n"

                        "aligned" ->
                            -- TODO: equation numbers and label
                            [ "\\begin{align}", str |> MicroLaTeX.Util.transformLabel, "\\end{align}" ] |> String.join "\n"

                        "code" ->
                            str |> fixChars |> (\s -> "\\begin{verbatim}\n" ++ s ++ "\n\\end{verbatim}")

                        "tabular" ->
                            str |> fixChars |> (\s -> "\\begin{tabular}{" ++ String.join " " block.args ++ "}\n" ++ s ++ "\n\\end{tabular}")

                        "verbatim" ->
                            str |> fixChars |> (\s -> "\\begin{verbatim}\n" ++ s ++ "\n\\end{verbatim}")

                        "verse" ->
                            str |> fixChars |> (\s -> "\\begin{verbatim}\n" ++ s ++ "\n\\end{verbatim}")

                        "load-files" ->
                            ""

                        "mathmacros" ->
                            str

                        "texComment" ->
                            str |> String.lines |> texComment

                        "textmacros" ->
                            Generic.TextMacro.exportTexMacros str

                        "image" ->
                            Render.Export.Image.exportBlock settings block

                        "quiver" ->
                            let
                                lines =
                                    String.split "---" str
                                        |> List.drop 1
                                        |> String.join "\n"
                                        |> String.lines
                                        |> List.filter (\line -> line /= "")

                                line1 =
                                    List.head lines |> Maybe.withDefault "%%" |> String.trim

                                line1b =
                                    if String.contains "\\hide{" line1 then
                                        -- preserve comment with quiver url
                                        line1 |> String.replace "\\hide{" "" |> String.dropRight 1 |> (\x -> "%% " ++ x)

                                    else
                                        line1

                                data =
                                    lines
                                        |> List.drop 1
                                        -- now normalize the data
                                        |> List.filter (\line -> not <| String.contains "\\[\\begin{tikzcd}" line)
                                        |> List.filter (\line -> not <| String.contains "\\end{tikzcd}\\]" line)
                                        |> (\x -> line1b :: "\\[\\begin{tikzcd}" :: x ++ [ "\\end{tikzcd}\\]" ])
                                        |> String.join "\n"
                            in
                            data

                        "tikz" ->
                            let
                                renderedAsLaTeX =
                                    String.contains "\\hide{" str

                                data =
                                    String.split "---" str
                                        |> List.drop 1
                                        |> String.join ""
                                        |> String.lines
                                        |> List.map (hideToPercentComment >> commentBlankLine)
                                        |> String.join "\n"
                                        |> addTikzPictureClosing renderedAsLaTeX
                            in
                            [ "\\[\n", data, "\n\\]" ]
                                |> String.join ""

                        "docinfo" ->
                            ""

                        _ ->
                            ": export of this block is unimplemented"

                Right _ ->
                    "???(13)"


addTikzPictureClosing flagUp str =
    if flagUp then
        str ++ "\n\\end{tikzpicture}"

    else
        str


commentBlankLine : String -> String
commentBlankLine line =
    if line == "" then
        "%"

    else
        line


hideToPercentComment : String -> String
hideToPercentComment str =
    if String.left 6 str == "\\hide{" then
        str |> String.dropLeft 6 |> String.dropRight 1 |> (\s -> "%% " ++ s)

    else
        str


fixChars str =
    str |> String.replace "{" "\\{" |> String.replace "}" "\\}"


renderDefs settings exprs =
    "%% Macro definitions from Markup text:\n"
        ++ exportExprList settings exprs


mapChars1 : String -> String
mapChars1 str =
    str
        |> String.replace "\\term_" "\\termx"


mapChars2 : String -> String
mapChars2 str =
    str
        |> String.replace "_" "\\_"



-- BEGIN DICTIONARIES


functionDict : Dict String String
functionDict =
    Dict.fromList
        [ ( "italic", "textit" )
        , ( "i", "textit" )
        , ( "bold", "textbf" )
        , ( "b", "textbf" )
        , ( "image", "imagecenter" )
        , ( "contents", "tableofcontents" )
        ]



-- MACRODICT


macroDict : Dict String (RenderSettings -> List Expression -> String)
macroDict =
    Dict.fromList
        [ ( "link", \_ -> link )
        , ( "ilink", \_ -> ilink )
        , ( "par", \_ -> par )
        , ( "index_", \_ _ -> blindIndex )
        , ( "image", Render.Export.Image.export )
        , ( "vspace", \_ -> vspace )
        , ( "bolditalic", \_ -> bolditalic )
        , ( "brackets", \_ -> brackets )
        , ( "lb", \_ -> lb )
        , ( "rb", \_ -> rb )
        , ( "bt", \_ -> bt )
        , ( "underscore", \_ -> underscore )
        , ( "tags", dontRender )
        ]


dontRender : RenderSettings -> List Expression -> String
dontRender _ _ =
    ""



-- BLOCKDICT


blockDict : Dict String (RenderSettings -> List String -> String -> String)
blockDict =
    Dict.fromList
        [ ( "title", \_ _ _ -> "" )
        , ( "subtitle", \_ _ _ -> "" )
        , ( "author", \_ _ _ -> "" )
        , ( "date", \_ _ _ -> "" )
        , ( "contents", \_ _ _ -> "" )
        , ( "hide", \_ _ _ -> "" )
        , ( "texComment", \_ lines _ -> texComment lines )
        , ( "tags", \_ _ _ -> "" )
        , ( "docinfo", \_ _ _ -> "" )
        , ( "banner", \_ _ _ -> "" )
        , ( "set-key", \_ _ _ -> "" )
        , ( "endnotes", \_ _ _ -> "" )
        , ( "index", \_ _ _ -> "Index: not implemented" )

        --
        , ( "section", \settings_ args body -> section settings_ args body )
        , ( "subheading", \settings_ args body -> subheading settings_ args body )
        , ( "smallsubheading", \settings_ args body -> smallsubheading settings_ args body )
        , ( "item", \_ _ body -> macro1 "item" body )
        , ( "descriptionItem", \_ args body -> descriptionItem args body )
        , ( "numbered", \_ _ body -> macro1 "item" body )
        , ( "desc", \_ args body -> descriptionItem args body )
        , ( "beginBlock", \_ _ _ -> "\\begin{itemize}" )
        , ( "endBlock", \_ _ _ -> "\\end{itemize}" )
        , ( "beginNumberedBlock", \_ _ _ -> "\\begin{enumerate}" )
        , ( "endNumberedBlock", \_ _ _ -> "\\end{enumerate}" )
        , ( "beginDescriptionBlock", \_ _ _ -> "\\begin{description}" )
        , ( "endDescriptionBlock", \_ _ _ -> "\\end{description}" )
        , ( "mathmacros", \_ _ body -> body ++ "\nHa ha ha!" )
        , ( "setcounter", \_ _ _ -> "" )
        ]


verbatimExprDict =
    Dict.fromList
        [ ( "code", inlineCode )
        , ( "math", inlineMath )
        ]


texComment lines =
    lines |> List.map putPercent |> String.join "\n"


putPercent str =
    if String.left 1 str == "%" then
        str

    else
        "% " ++ str



-- END DICTIONARIES


inlineMath : String -> String
inlineMath str =
    "$" ++ str ++ "$"


inlineCode : String -> String
inlineCode str =
    "\\verb`" ++ str ++ "`"


link : List Expression -> String
link exprs =
    let
        args =
            Render.Export.Util.getTwoArgs exprs
    in
    [ "\\href{", args.second, "}{", args.first, "}" ] |> String.join ""


vspace : List Expression -> String
vspace exprs =
    let
        arg =
            Render.Export.Util.getOneArg exprs
                |> String.toFloat
                |> Maybe.withDefault 0
                |> (\x -> x / 4.0)
                |> String.fromFloat
                |> (\x -> x ++ "pt")
    in
    [ "\\par\\vspace{", arg, "}" ] |> String.join ""


par : List Expression -> String
par _ =
    [ "\\par\\par" ] |> String.join ""


ilink : List Expression -> String
ilink exprs =
    let
        args =
            Render.Export.Util.getTwoArgs exprs
    in
    [ "\\href{", "https://scripta.io/s/", args.second, "}{", args.first, "}" ] |> String.join ""


bolditalic : List Expression -> String
bolditalic exprs =
    let
        args =
            Render.Export.Util.getArgs exprs |> String.join " "
    in
    "\\textbf{\\emph{" ++ args ++ "}}"


brackets : List Expression -> String
brackets exprs =
    "[" ++ (Render.Export.Util.getArgs exprs |> String.join " ") ++ "]"


lb : List Expression -> String
lb _ =
    "["


rb : List Expression -> String
rb _ =
    "]"


bt : List Expression -> String
bt _ =
    "`"


underscore : List Expression -> String
underscore _ =
    "$\\_$"


blindIndex : String
blindIndex =
    ""


setcounter : List String -> String
setcounter args =
    [ "\\setcounter{section}{", Utility.getArg "0" 0 args, "}" ] |> String.join ""


subheading : RenderSettings -> List String -> String -> String
subheading settings args body =
    "\\vspace{8pt{\\Large{" ++ body ++ "}"


smallsubheading : RenderSettings -> List String -> String -> String
smallsubheading settings args body =
    "\\vspace{4pt{\\large{" ++ body ++ "}"


descriptionItem : List String -> String -> String
descriptionItem args body =
    let
        arg =
            argString args
    in
    case args of
        [] ->
            "\\item{" ++ body ++ "}"

        _ ->
            "\\item[" ++ arg ++ "]{" ++ body ++ "}"


argString : List String -> String
argString args =
    List.filter (\arg -> not <| String.contains "label:" arg) args |> String.join " "


section : RenderSettings -> List String -> String -> String
section settings args body =
    if settings.isStandaloneDocument then
        section1 args body

    else
        section2 args body


section1 : List String -> String -> String
section1 args body =
    let
        tag =
            body
                |> String.words
                |> MicroLaTeX.Util.normalizedWord

        label =
            " \\label{" ++ tag ++ "}"

        suffix =
            case List.Extra.getAt 1 args of
                Nothing ->
                    ""

                Just "-" ->
                    "*"

                Just _ ->
                    ""
    in
    case Utility.getArg "4" 0 args of
        "1" ->
            macro1 ("title" ++ suffix) body ++ label

        "2" ->
            macro1 ("section" ++ suffix) body ++ label

        "3" ->
            macro1 ("subsection" ++ suffix) body ++ label

        "4" ->
            macro1 ("subsubsection" ++ suffix) body ++ label

        _ ->
            macro1 ("subheading" ++ suffix) body ++ label


section2 : List String -> String -> String
section2 args body =
    let
        tag =
            body
                |> String.words
                |> MicroLaTeX.Util.normalizedWord

        label =
            " \\label{" ++ tag ++ "}"

        suffix =
            case List.Extra.getAt 1 args of
                Nothing ->
                    ""

                Just "-" ->
                    "*"

                Just _ ->
                    ""
    in
    case Utility.getArg "4" 0 args of
        "1" ->
            macro1 ("section" ++ suffix) body ++ label

        "2" ->
            macro1 ("subsection" ++ suffix) body ++ label

        "3" ->
            macro1 ("subsubsection" ++ suffix) body ++ label

        _ ->
            macro1 ("subheading" ++ suffix) body ++ label


macro1 : String -> String -> String
macro1 name arg =
    if name == "math" then
        "$" ++ arg ++ "$"

    else if name == "group" then
        arg

    else if name == "tags" then
        ""

    else
        case Dict.get name functionDict of
            Nothing ->
                "\\" ++ unalias name ++ "{" ++ mapChars2 (String.trimLeft arg) ++ "}"

            Just fName ->
                "\\" ++ fName ++ "{" ++ mapChars2 (String.trimLeft arg) ++ "}"


exportExprList : RenderSettings -> List Expression -> String
exportExprList settings exprs =
    List.map (exportExpr settings) exprs |> String.join "" |> mapChars1


{-| -}
exportExpr : RenderSettings -> Expression -> String
exportExpr settings expr =
    case expr of
        Fun name exps_ _ ->
            if name == "lambda" then
                case Generic.TextMacro.extract expr of
                    Just lambda ->
                        Generic.TextMacro.toString (exportExpr settings) lambda

                    Nothing ->
                        "Error extracting lambda"

            else
                case Dict.get name macroDict of
                    Just f ->
                        f settings exps_

                    Nothing ->
                        "\\" ++ unalias name ++ (List.map (encloseWithBraces << exportExpr settings) exps_ |> String.join "")

        Text str _ ->
            mapChars2 str

        VFun name body _ ->
            renderVerbatim name body


{-| Use this to unalias names
-}
unalias : String -> String
unalias str =
    case Dict.get str aliases of
        Nothing ->
            str

        Just realName_ ->
            realName_


aliases : Dict String String
aliases =
    Dict.fromList
        [ ( "i", "italic" )
        , ( "b", "textbf" )
        , ( "bold", "textbf" )
        ]


encloseWithBraces : String -> String
encloseWithBraces str_ =
    "{" ++ String.trim str_ ++ "}"


renderVerbatim : String -> String -> String
renderVerbatim name body =
    case Dict.get name verbatimExprDict of
        Nothing ->
            name ++ "(" ++ body ++ ") — unimplemented "

        Just f ->
            if List.member name [ "equation", "aligned", "math" ] then
                body |> MicroLaTeX.Util.transformLabel |> f

            else
                body |> fixChars |> MicroLaTeX.Util.transformLabel |> f



-- HELPERS


tagged name body =
    "\\" ++ name ++ "{" ++ body ++ "}"


environment name body =
    [ tagged "begin" name, body, tagged "end" name ] |> String.join "\n"
