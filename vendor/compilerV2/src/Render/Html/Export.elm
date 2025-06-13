module Render.Html.Export exposing (export)

import Dict exposing (Dict)
import Either exposing (Either(..))
import File.Download
import Generic.ASTTools as ASTTools
import Generic.Acc
import Generic.BlockUtilities
import Generic.Forest exposing (Forest)
import Generic.Language exposing (Expr(..), Expression, ExpressionBlock, Heading(..))
import Generic.TextMacro
import Html
import Html.String as HS exposing (Html, div, node, span, text)
import Html.String.Attributes exposing (property, style)
import Json.Encode as JE
import List.Extra
import Maybe.Extra
import MicroLaTeX.Util
import Render.Data
import Render.Export.Image
import Render.Export.Util
import Render.Html.Image
import Render.Html.Math
import Render.Settings exposing (RenderSettings)
import Render.Utility as Utility
import RoseTree.Tree exposing (Tree)
import Time


counterValue : Forest ExpressionBlock -> Maybe Int
counterValue ast =
    ast
        |> ASTTools.getBlockArgsByName "setcounter"
        |> List.head
        |> Maybe.andThen String.toInt


{-| -}
export : Time.Posix -> RenderSettings -> Generic.Acc.Accumulator -> List (Tree ExpressionBlock) -> String
export currentTime settings acc ast =
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
    template currentTime settings acc ast



-- template : String -> String -> String


template : Time.Posix -> RenderSettings -> Generic.Acc.Accumulator -> Forest ExpressionBlock -> String
template currentTime settings acc ast =
    """<!DOCTYPE html>
       <html lang="en">
       <head>
           <meta charset="UTF-8">
           <meta name="viewport" content="width=device-width, initial-scale=1.0">
           <title>Scripta.io</title>
           <link href="https://cdn.jsdelivr.net/npm/katex@0.16.3/dist/katex.min.css" rel="stylesheet">
           <style>
              body {
                  max-width: 800px;
                  margin: 0 auto;
                  padding: 1rem;
              }
          </style>
    """
        ++ katexScript
        ++ """
       </head>
       <body>
          """
        ++ katexCSS
        ++ documentBody currentTime settings acc ast
        ++ """
       </body>
       </html>
    """



-- <script src="https://cdn.jsdelivr.net/npm/katex@0.16.3/dist/katex.min.js"></script>


katexScript =
    String.concat
        [ """<script src="https://cdn.jsdelivr.net/npm/katex@0.16.3/dist/katex.min.js">"""
        , "</scri" ++ "pt>"
        ]


katexCSS : String
katexCSS =
    HS.node "link"
        [ Html.String.Attributes.attribute "rel" "stylesheet"
        , Html.String.Attributes.attribute "href" "https://cdn.jsdelivr.net/npm/katex@0.16.3/dist/katex.min.css"
        ]
        []
        |> HS.toString 4



--frontMatter : Time.Posix -> Generic.Acc.Accumulator -> Forest ExpressionBlock -> String
--frontMatter currentTime acc ast =
--    let
--        dict =
--            ASTTools.frontMatterDict ast
--
--        author1 =
--            Dict.get "author1" dict
--
--        author2 =
--            Dict.get "author2" dict
--
--        author3 =
--            Dict.get "author3" dict
--
--        author4 =
--            Dict.get "author4" dict
--
--        authors : String
--        authors =
--            [ author1, author2, author3, author4 ]
--                |> Maybe.Extra.values
--                |> String.join "\n\\and\n"
--                |> (\s -> "\\author{\n" ++ s ++ "\n}")
--
--        title : String
--        title =
--            ASTTools.title ast
--
--        date : String
--        date =
--            Dict.get "date" dict |> Maybe.map (\date_ -> "\\date{" ++ date_ ++ "}") |> Maybe.withDefault ""
--    in
--    topmatter title date authors


documentBody : Time.Posix -> RenderSettings -> Generic.Acc.Accumulator -> Forest ExpressionBlock -> String
documentBody currentTime settings acc ast =
    let
        dict =
            ASTTools.frontMatterDict ast

        date : String
        date =
            Dict.get "date" dict |> Maybe.map (\date_ -> "\\date{" ++ date_ ++ "}") |> Maybe.withDefault ""
    in
    List.map (exportTree settings acc) ast |> String.join "\n\n" |> Debug.log "@@:documentBody"


exportTree : RenderSettings -> Generic.Acc.Accumulator -> Tree ExpressionBlock -> String
exportTree settings acc tree =
    case RoseTree.Tree.children tree of
        [] ->
            exportBlock settings acc (RoseTree.Tree.value tree)

        children ->
            let
                renderedChildren : List String
                renderedChildren =
                    List.map (exportTree settings acc) children
                        |> List.map String.lines
                        |> List.concat

                root =
                    exportBlock settings acc (RoseTree.Tree.value tree) |> String.lines
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


exportBlock : RenderSettings -> Generic.Acc.Accumulator -> ExpressionBlock -> String
exportBlock settings acc block =
    case block.heading of
        Paragraph ->
            case block.body of
                Left str ->
                    "LEFT " ++ str |> divBlock

                Right exprs_ ->
                    exportExprList settings exprs_ |> divBlock

        Ordinary name ->
            case block.body of
                Left _ ->
                    ""

                Right exprs_ ->
                    let
                        _ =
                            Debug.log "@@:ORDINARY" name
                    in
                    case Dict.get name blockDict of
                        Just f ->
                            f settings block.args (exportExprList settings exprs_) |> divBlock

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
                            [ fix_ str ]
                                |> String.join "\n"
                                |> Render.Html.Math.displayedMath acc settings block.meta.id
                                |> divBlock

                        _ ->
                            exportBlock1 settings block

                Right x ->
                    "(VERBATIM RIGHT " ++ "????" ++ ")"


rawHtml : String -> String
rawHtml str =
    str


divBlock : String -> String
divBlock str =
    String.concat
        [ "<div style=\"padding-top: 18px\">\n"
        , "    "
        , str
        , "\n</div>"
        ]


exportBlock1 : RenderSettings -> ExpressionBlock -> String
exportBlock1 settings block =
    case block.heading of
        Paragraph ->
            case block.body of
                Left str ->
                    str

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


title_ : RenderSettings -> List String -> String -> String
title_ settings attrs str =
    div
        []
        [ div [ style "font-size" "36px" ] [ text str ] ]
        |> HS.toString 4


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
        [ ( "i", \_ -> italic )
        , ( "italic", \_ -> italic )
        , ( "b", \_ -> bold )
        , ( "bold", \_ -> bold )
        , ( "link", \_ -> link )
        , ( "ilink", \_ -> ilink )
        , ( "index_", \_ _ -> blindIndex )
        , ( "image", Render.Html.Image.export )
        , ( "vspace", \_ -> vspace )
        , ( "bolditalic", \_ -> bolditalic )
        , ( "brackets", \_ -> brackets )
        , ( "lb", \_ -> lb )
        , ( "rb", \_ -> rb )
        , ( "bt", \_ -> bt )
        , ( "underscore", \_ -> underscore )
        , ( "tags", dontRender )
        ]


italic : List Expression -> String
italic exprs =
    let
        args =
            Render.Export.Util.getArgs exprs |> String.join " "
    in
    span [ style "font-style" "italic" ] [ text args ] |> HS.toString 4


bold : List Expression -> String
bold exprs =
    let
        args =
            Render.Export.Util.getArgs exprs |> String.join " "
    in
    span [ style "font-weight" "bold" ] [ text args ] |> HS.toString 4


dontRender : RenderSettings -> List Expression -> String
dontRender _ _ =
    ""



-- BLOCKDICT


blockDict : Dict String (RenderSettings -> List String -> String -> String)
blockDict =
    Dict.fromList
        [ ( "title", \settings attrs str -> title_ settings attrs str )
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
                |> (\x -> x ++ "mm")
    in
    [ "\\vspace{", arg, "}" ] |> String.join ""


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
    "\\subheading{" ++ body ++ "}"


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
    let
        tag =
            body
                |> String.words
                |> MicroLaTeX.Util.normalizedWord
                |> Debug.log "@@:SECTION 1"

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

        attrs =
            case Utility.getArg "4" 0 args of
                "1" ->
                    [ style "font-size" "28px" ]

                "2" ->
                    [ style "font-size" "20px" ]

                "3" ->
                    [ style "font-size" "14px" ]

                _ ->
                    [ style "font-size" "12px" ]
    in
    div attrs [ text body ] |> HS.toString 4


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
    let
        output =
            List.map (exportExpr settings) exprs |> String.join ""
    in
    if output == "" then
        "Empty Expression LIst"

    else
        (List.map (exportExpr settings) exprs |> String.join "") |> mapChars1


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
            str

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
