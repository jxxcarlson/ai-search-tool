module Render.Html.Math exposing
    ( DisplayMode(..)
    , aligned
    , array
    , bar
    , displayedMath
    , equation
    , foo
    , mathText
    , textarray
    )

import Dict exposing (Dict)
import Either exposing (Either(..))
import Element exposing (Element)
import Element.Background as Background
import Element.Font as Font
import Generic.Acc exposing (Accumulator)
import Generic.Language exposing (ExpressionBlock)
import Generic.MathMacro
import Generic.PTextMacro
import Generic.TextMacro
import Html exposing (Html)
import Html.Attributes as HA
import Html.Keyed
import Json.Encode
import Render.Settings exposing (RenderSettings)
import Render.Sync
import Render.Utility
import ScriptaV2.Msg exposing (MarkupMsg(..))
import String.Extra


type DisplayMode
    = InlineMathMode
    | DisplayMathMode


displayedMath1 : Accumulator -> RenderSettings -> String -> String -> String
displayedMath1 acc settings content id =
    "(???)"


displayedMath : Accumulator -> RenderSettings -> String -> String -> String
displayedMath acc settings id content =
    let
        w =
            String.fromInt settings.width ++ "px"

        escapedContent =
            String.replace "\n" " " (Generic.MathMacro.evalStr acc.mathMacroDict content)
                |> String.replace "\"" "\\\""
    in
    String.concat
        [ "<span id="
        , String.Extra.quote id
        , ">...</span>"
        , "<script>"
        , "katex.render(\""
        , content
        , "\", document.getElementById(\""
        , id
        , "\"));"
        , "</scr" ++ "ipt>" -- Split to prevent early script termination
        ]


bar id content =
    "BAR " ++ id ++ ": " ++ content


foo id content =
    String.concat
        [ "<span id="
        , String.Extra.quote id
        , ">...</span>"
        , "<script>"
        , "katex.render(\""
        , content
        , "\", document.getElementById(\""
        , id
        , "\"));"
        , "</script>"
        ]



-- Uncaught SyntaxError: '' literal not terminated before end of script


getContent : ExpressionBlock -> String
getContent { body } =
    case body of
        Left str ->
            str

        Right _ ->
            ""


equation : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
equation count acc settings attrs block =
    let
        w =
            String.fromInt settings.width ++ "px"

        evalMacro line =
            if String.right 2 line == "\\\\" then
                line
                    |> String.dropRight 2
                    |> Generic.MathMacro.evalStr acc.mathMacroDict
                    |> (\str -> str ++ "\\\\")

            else
                line |> Generic.MathMacro.evalStr acc.mathMacroDict

        filteredLines =
            -- lines of math text to be rendered: filter stuff out
            String.lines (getContent block)
                |> List.map String.trimRight
                |> List.filter (\line -> not (String.left 2 line == "$$") && not (String.left 6 line == "[label") && not (line == "end"))
                -- |> List.map (Generic.MathMacro.evalStr acc.mathMacroDict)
                |> List.map evalMacro

        content =
            String.join "\n" filteredLines

        label : Element msg
        label =
            Element.el [ Element.alignTop ] (equationLabel settings block.properties content)
    in
    Element.column ([ Element.width (Element.px settings.width) ] ++ attrs)
        [ Element.row
            (highlightMath settings block)
            [ mathText count w block.meta.id DisplayMathMode content, label ]
        ]


highlightMath : RenderSettings -> ExpressionBlock -> List (Element.Attr () msg)
highlightMath settings block =
    Render.Sync.highlightIfIdSelected block.meta.id
        settings
        (Render.Sync.highlighter block.args
            []
        )


equationLabel settings properties content =
    let
        labelText =
            "(" ++ (Dict.get "equation-number" properties |> Maybe.withDefault "-") ++ ")"

        label_ =
            Element.el [ Font.size 12, Element.alignRight, Element.moveDown 35 ] (Element.text labelText)
    in
    showIf settings content label_


showIf : Render.Settings.RenderSettings -> String -> Element msg -> Element msg
showIf settings content element =
    if Render.Utility.textWidth settings.display content > (toFloat settings.width - 40) then
        Element.none

    else
        element


getCounter : String -> Dict String Int -> String
getCounter counterName dict =
    Dict.get counterName dict |> Maybe.withDefault 0 |> String.fromInt


getLabel : String -> Dict String String -> String
getLabel label dict =
    Dict.get label dict |> Maybe.withDefault "" |> String.trim


aligned : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
aligned count acc settings attrs block =
    let
        str =
            case block.body of
                Left str_ ->
                    str_

                Right _ ->
                    ""

        filteredLines =
            -- filter stuff out of lines of math text to be rendered:
            String.lines str
                |> List.filter (\line -> not (String.left 6 line == "[label") && not (line == ""))

        deleteTrailingSlashes inputString =
            let
                str_ =
                    String.trim inputString
            in
            if String.right 2 str_ == "\\\\" then
                String.dropRight 2 str_

            else
                str_

        adjustedLines_ =
            -- delete trailing slashes before evaluating macros
            List.map (deleteTrailingSlashes >> Generic.MathMacro.evalStr acc.mathMacroDict) filteredLines
                -- remove bank lines
                |> List.filter (\line -> line /= "")

        innerContent =
            -- restore trailing slashes
            adjustedLines_
                |> String.join "\\\\\n"

        content =
            "\\begin{aligned}\n" ++ innerContent ++ "\n\\end{aligned}"

        label =
            equationLabel settings block.properties content
    in
    Element.column ([ Element.width (Element.px settings.width) ] ++ attrs)
        [ Element.row
            (Element.width (Element.px settings.width) :: rightToLeftSyncHelper block label)
            [ Element.el
                (Element.centerX :: highlightMath settings block)
                (mathText count str block.meta.id DisplayMathMode content)
            ]
        ]


array : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
array count acc settings attrs block =
    let
        args : String
        args =
            block.args
                |> List.head
                |> Maybe.withDefault ""
                -- TODO: remove bad hack in next two lines
                |> String.replace "{" ""
                |> String.replace "}" ""

        -- |> String.replace " " ""
        str =
            case block.body of
                Left str_ ->
                    str_

                Right _ ->
                    ""

        filteredLines =
            -- filter stuff out of lines of math text to be rendered:
            String.lines str
                |> List.filter (\line -> not (String.left 6 line == "[label") && not (line == ""))

        deleteTrailingSlashes inputString =
            let
                str_ =
                    String.trim inputString
            in
            if String.right 2 str_ == "\\\\" then
                String.dropRight 2 str_

            else
                str_

        adjustedLines_ =
            -- delete trailing slashes before evaluating macros
            List.map (deleteTrailingSlashes >> Generic.MathMacro.evalStr acc.mathMacroDict) filteredLines
                -- remove bank lines
                |> List.filter (\line -> line /= "")

        innerContent =
            -- restore trailing slashes
            adjustedLines_
                |> String.join "\\\\\n"

        content =
            "\\begin{array}{" ++ args ++ "}\n" ++ innerContent ++ "\n\\end{array}"

        label =
            equationLabel settings block.properties content
    in
    Element.column ([ Element.width (Element.px settings.width) ] ++ attrs)
        [ Element.row
            (Element.width (Element.px settings.width) :: rightToLeftSyncHelper block label)
            [ Element.el
                (Element.centerX :: highlightMath settings block)
                (mathText count str block.meta.id DisplayMathMode content)
            ]
        ]


textarray : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
textarray count acc settings attrs block =
    let
        args : String
        args =
            block.args
                |> List.head
                |> Maybe.withDefault ""
                |> String.replace "{" ""
                |> String.replace "}" ""

        -- |> String.replace " " ""
        str =
            case block.body of
                Left str_ ->
                    str_

                Right _ ->
                    ""

        filteredLines =
            -- filter stuff out of lines of math text to be rendered:
            String.lines str
                |> List.filter (\line -> not (String.left 6 line == "[label") && not (line == ""))
                |> List.map fixrow

        fixrow : String -> String
        fixrow str_ =
            str_
                |> String.split "&"
                |> List.map String.trim
                |> List.map (\s -> "\\text{" ++ s ++ "}")
                |> String.join " & "

        deleteTrailingSlashes inputString =
            let
                str_ =
                    String.trim inputString
            in
            if String.right 2 str_ == "\\\\" then
                String.dropRight 2 str_

            else
                str_

        adjustedLines_ =
            -- delete trailing slashes before evaluating macros
            List.map (deleteTrailingSlashes >> Generic.MathMacro.evalStr acc.mathMacroDict) filteredLines
                -- remove bank lines
                |> List.filter (\line -> line /= "")

        innerContent =
            -- restore trailing slashes
            adjustedLines_
                |> String.join "\\\\\n"

        content =
            "\\begin{array}{"
                ++ args
                ++ "}\n"
                ++ innerContent
                ++ "\n\\end{array}"

        label =
            equationLabel settings block.properties content
    in
    Element.column ([ Element.width (Element.px settings.width) ] ++ attrs)
        [ Element.row
            (Element.width (Element.px settings.width) :: rightToLeftSyncHelper block label)
            [ Element.el
                (Element.centerX :: highlightMath settings block)
                (mathText count str block.meta.id DisplayMathMode content)
            ]
        ]


rightToLeftSyncHelper : { a | meta : { b | lineNumber : Int, numberOfLines : Int, id : String } } -> Element MarkupMsg -> List (Element.Attribute MarkupMsg)
rightToLeftSyncHelper block label =
    [ Element.centerX, Element.spacing 12, Element.inFront label ]
        ++ (Render.Sync.rightToLeftSyncHelper block.meta.lineNumber block.meta.numberOfLines
                :: [ Render.Utility.elementAttribute "id" block.meta.id ]
           )


mathText : Int -> String -> String -> DisplayMode -> String -> Element msg
mathText generation width id displayMode content =
    -- TODO Track this down at the source.
    Html.Keyed.node "span"
        [ HA.style "padding-top" "0px"
        , HA.style "padding-bottom" "0px"
        , HA.id id
        , HA.style "width" width
        ]
        [ ( String.fromInt generation, mathText_ displayMode (eraseLabeMacro content) )
        ]
        |> Element.html


eraseLabeMacro content =
    content |> String.lines |> List.map (Generic.PTextMacro.eraseLeadingMacro "label") |> String.join "\n"


mathText_ : DisplayMode -> String -> Html msg
mathText_ displayMode content =
    Html.node "math-text"
        -- active meta selectedId  ++
        [ HA.property "display" (Json.Encode.bool (isDisplayMathMode displayMode))
        , HA.property "content" (Json.Encode.string content)

        -- , clicker meta
        -- , HA.id (makeId meta)
        ]
        []


isDisplayMathMode : DisplayMode -> Bool
isDisplayMathMode displayMode =
    case displayMode of
        InlineMathMode ->
            False

        DisplayMathMode ->
            True
