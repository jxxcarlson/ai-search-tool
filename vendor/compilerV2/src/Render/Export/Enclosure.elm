module Render.Export.Enclosure exposing
    ( exportExpr, rawExport
    , ExportError(..), WrapOption(..), rawExportSafe, rawExportValidate, rawExportValidateSimple, rawExport_
    )

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
import MicroLaTeX.Util
import Render.Export.Image
import Render.Export.Util
import Render.Settings exposing (RenderSettings)
import Render.Utility as Utility
import RoseTree.Tree as Tree exposing (Tree)
import ScriptaV2.Compiler
import ScriptaV2.Language
import String.Extra
import Tools.Loop exposing (Step(..), loop)
import Tools.String


{-| -}
rawExport : WrapOption -> List (Tree ExpressionBlock) -> String
rawExport wrapOption ast =
    ast
        |> Generic.Forest.map Generic.BlockUtilities.condenseUrls
        |> encloseLists
        |> Generic.Forest.map (counterValue ast |> oneOrTwo |> shiftSection)
        |> List.map (exportTree wrapOption)
        |> String.join "\n\n"


rawExport_ : WrapOption -> String -> Result String String
rawExport_ wrapOption source =
    let
        ast =
            ScriptaV2.Compiler.parse ScriptaV2.Language.EnclosureLang "idPrefix" 0 (String.lines source)
    in
    ast
        |> Generic.Forest.map Generic.BlockUtilities.condenseUrls
        |> encloseLists
        |> Generic.Forest.map (counterValue ast |> oneOrTwo |> shiftSection)
        |> List.map (exportTree wrapOption)
        |> String.join "\n\n"
        |> Ok


type ExportError
    = ExportFailure
    | ExportMismatch String String


rawExportSafe : WrapOption -> String -> Result ExportError String
rawExportSafe wrapOption source =
    case rawExport_ wrapOption source of
        Err _ ->
            Err ExportFailure

        Ok textToExport ->
            if rawExportValidateS wrapOption source then
                Ok textToExport

            else
                Err (ExportMismatch source textToExport)


rawExportValidateSimple : WrapOption -> String -> Bool
rawExportValidateSimple wrapOption source =
    let
        --prettyText =
        --    rawExport wrapOption ast
        source2 =
            rawExport wrapOption (ScriptaV2.Compiler.parse ScriptaV2.Language.EnclosureLang "idPrefix" 0 (String.lines source))

        compress str =
            String.replace " " "" str |> String.replace "\n" "" |> String.replace "\t" ""
    in
    compress source == compress source2


rawExportValidateS : WrapOption -> String -> Bool
rawExportValidateS wrapOption source =
    let
        astResult1 =
            ScriptaV2.Compiler.parse ScriptaV2.Language.EnclosureLang "idPrefix" 0 (String.lines source)

        prettyText =
            rawExport wrapOption astResult1

        astResult2 =
            (\ast -> ScriptaV2.Compiler.parse ScriptaV2.Language.EnclosureLang "idPrefix" 0 (String.lines ast)) prettyText
    in
    astResult1 == astResult2


rawExportValidate : WrapOption -> List (Tree ExpressionBlock) -> Bool
rawExportValidate wrapOption ast =
    let
        prettyText =
            rawExport wrapOption ast

        ast2 : List (Tree ExpressionBlock)
        ast2 =
            ScriptaV2.Compiler.parse ScriptaV2.Language.EnclosureLang "idPrefix" 0 (String.lines prettyText)
    in
    Generic.Language.simplifyForest ast == Generic.Language.simplifyForest ast2


counterValue : Forest ExpressionBlock -> Maybe Int
counterValue ast =
    ast
        |> ASTTools.getBlockArgsByName "setcounter"
        |> List.head
        |> Maybe.andThen String.toInt


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


exportTree : WrapOption -> Tree ExpressionBlock -> String
exportTree wrapOption tree =
    case Tree.children tree of
        [] ->
            exportBlock wrapOption (Tree.value tree)

        children ->
            let
                renderedChildren : List String
                renderedChildren =
                    List.map (exportTree wrapOption) children
                        |> List.map String.lines
                        |> List.concat

                root =
                    exportBlock wrapOption (Tree.value tree) |> String.lines
            in
            case List.Extra.unconsLast root of
                Nothing ->
                    ""

                Just ( lastLine, firstLines ) ->
                    firstLines ++ renderedChildren ++ [ lastLine ] |> String.join "\n"


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


exportBlock : WrapOption -> ExpressionBlock -> String
exportBlock wrapOption block =
    case block.heading of
        Paragraph ->
            case block.body of
                Left str ->
                    mapChars2 str |> wrap wrapOption

                Right exprs_ ->
                    exportExprList NoWrap exprs_ |> wrap wrapOption

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
                                    cellTable |> List.map (List.map exportCell)

                                exportCell : Expression -> String
                                exportCell expr =
                                    case expr of
                                        Fun "cell" exprs2 _ ->
                                            exportExprList wrapOption exprs2

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
                    --case name of
                    --    "section" ->
                    --        "# " ++ name ++ "\n" ++ exportBlock wrapOption block
                    --
                    --    _ ->
                    environment name (exportExprList wrapOption exprs_)

        -- environment name (exportExprList wrapOption exprs_)
        Verbatim name ->
            case block.body of
                Left str ->
                    "|| " ++ name ++ "\n" ++ str

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



--renderDefs settings exprs =
--    "%% Macro definitions from Markup text:\n"
--        ++ exportExprList exprs


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


blockDict : WrapOption -> Dict String (RenderSettings -> List String -> String -> String)
blockDict wrapOption =
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
        , ( "section", \settings_ args body -> section settings_ args (wrap wrapOption body) )
        , ( "subheading", \settings_ args body -> subheading settings_ args (wrap wrapOption body) )
        , ( "item", \_ _ body -> macro1 "item" (wrap wrapOption (wrap wrapOption body)) )
        , ( "descriptionItem", \_ args body -> descriptionItem args (wrap wrapOption body) )
        , ( "numbered", \_ _ body -> macro1 "item" (wrap wrapOption body) )
        , ( "desc", \_ args body -> descriptionItem args (wrap wrapOption body) )
        , ( "beginBlock", \_ _ _ -> "\\begin{itemize}" )
        , ( "endBlock", \_ _ _ -> "\\end{itemize}" )
        , ( "beginNumberedBlock", \_ _ _ -> "\\begin{enumerate}" )
        , ( "endNumberedBlock", \_ _ _ -> "\\end{enumerate}" )
        , ( "beginDescriptionBlock", \_ _ _ -> "\\begin{description}" )
        , ( "endDescriptionBlock", \_ _ _ -> "\\end{description}" )
        , ( "mathmacros", \_ _ body -> body ++ "\nHa ha ha!" )
        , ( "setcounter", \_ _ _ -> "" )
        ]


wrap : WrapOption -> String -> String
wrap option str =
    case option of
        NoWrap ->
            str

        Wrap n ->
            String.Extra.softWrapWith n " \n" str


type WrapOption
    = NoWrap
    | Wrap Int


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


exportExprList : WrapOption -> List Expression -> String
exportExprList wrapOption exprs =
    List.map (exportExpr wrapOption) exprs
        |> String.join ""
        --|> wrap wrapOption
        |> Tools.String.compressSpaces
        |> mapChars1


exportExprList22 : WrapOption -> List Expression -> String
exportExprList22 wrapOption exprs =
    List.map (exportExpr wrapOption) exprs
        |> String.join ""


{-| -}
exportExpr : WrapOption -> Expression -> String
exportExpr wrapOption expr =
    case expr of
        Fun name exps_ _ ->
            if name == "lambda" then
                case Generic.TextMacro.extract expr of
                    Just lambda ->
                        Generic.TextMacro.toString (exportExpr NoWrap) lambda

                    Nothing ->
                        "Error extracting lambda"

            else
                "[" ++ unalias name ++ " " ++ (List.map (exportExpr NoWrap) exps_ |> String.join " ") ++ "]"

        Text str _ ->
            mapChars2 str |> String.replace "\n" " " |> wrap wrapOption

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
    "| " ++ name ++ "\n" ++ body
