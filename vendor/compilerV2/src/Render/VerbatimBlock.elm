module Render.VerbatimBlock exposing (render)

import Dict exposing (Dict)
import Either exposing (Either(..))
import Element exposing (Element)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input
import Generic.Acc exposing (Accumulator)
import Generic.Language exposing (Expr(..), Expression, ExpressionBlock, Heading(..))
import Html exposing (Html, text)
import Html.Events as Event
import Render.Chart
import Render.ChartV2
import Render.DataTable
import Render.Graphics
import Render.Helper
import Render.IFrame
import Render.Math
import Render.Settings exposing (RenderSettings)
import Render.Sync
import Render.Table
import Render.Utility exposing (elementAttribute)
import ScriptaV2.Msg exposing (MarkupMsg(..))
import SyntaxHighlight exposing (gitHub, monokai, toBlockHtml, useTheme)


render : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
render count acc settings attrs block =
    case block.body of
        Right _ ->
            Element.none

        Left str ->
            case block.heading of
                Verbatim functionName_ ->
                    let
                        functionName =
                            if functionName_ == "table" then
                                "textarray"

                            else
                                functionName_
                    in
                    case Dict.get functionName verbatimDict of
                        Nothing ->
                            Render.Helper.noSuchVerbatimBlock functionName str

                        Just f ->
                            Element.el
                                [ Render.Helper.selectedColor block.meta.id settings
                                , Render.Helper.htmlId block.meta.id
                                ]
                                (f count acc settings attrs block)

                _ ->
                    Element.none


verbatimDict : Dict String (Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg)
verbatimDict =
    Dict.fromList
        [ ( "math", Render.Math.displayedMath )
        , ( "equation", Render.Math.equation )
        , ( "aligned", Render.Math.aligned )
        , ( "array", Render.Math.array )
        , ( "textarray", Render.Math.textarray )
        , ( "table", Render.Math.textarray )
        , ( "code", renderCode )
        , ( "verse", renderVerse )
        , ( "verbatim", renderVerbatim )

        -- , ( "tabular", Render.Tabular.render )
        , ( "load", renderLoad )
        , ( "load-data", Render.Helper.renderNothing )
        , ( "hide", Render.Helper.renderNothing )
        , ( "texComment", Render.Helper.renderNothing )
        , ( "docinfo", Render.Helper.renderNothing )
        , ( "mathmacros", Render.Helper.renderNothing )
        , ( "textmacros", Render.Helper.renderNothing )
        , ( "datatable", Render.DataTable.render )
        , ( "chart", Render.ChartV2.render )
        , ( "svg", Render.Graphics.svg )
        , ( "quiver", Render.Graphics.quiver )
        , ( "image", Render.Graphics.image2 )
        , ( "tikz", Render.Graphics.tikz )
        , ( "load-files", Render.Helper.renderNothing )
        , ( "include", Render.Helper.renderNothing )
        , ( "setup", Render.Helper.renderNothing )
        , ( "table", Render.Table.render )
        , ( "iframe", Render.IFrame.render )
        ]


renderLoadData : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
renderLoadData _ _ _ _ block =
    Element.none


setup : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
setup _ _ _ _ block =
    Element.none


renderLoad : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
renderLoad _ _ _ _ block =
    case block.body of
        Left url ->
            let
                tag =
                    block.args |> List.head |> Maybe.withDefault "default"
            in
            Element.Input.button []
                { onPress = Just (LoadFile tag url)
                , label =
                    Element.el
                        [ Border.rounded 12
                        , Element.mouseDown [ Background.color (Element.rgb 0.4 0.2 0.9) ]
                        , Background.color (Element.rgb 0 0 0.7)
                        , Font.color (Element.rgb 1 1 1)
                        , Element.padding 12
                        ]
                        (Element.text ("load " ++ url ++ " into " ++ tag))
                }

        Right _ ->
            Element.none


renderCode : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
renderCode count acc settings attr block =
    Element.column
        ([ Background.color (Element.rgb 0.955 0.95 0.95)
         , Element.paddingEach { left = 24, right = 24, top = 8, bottom = 8 }
         , Render.Sync.rightToLeftSyncHelper block.meta.lineNumber block.meta.numberOfLines
         , Render.Utility.idAttributeFromInt block.meta.lineNumber
         , Element.width (Element.px settings.width)
         , Element.scrollbarX
         ]
         -- ++ attr
        )
        (case List.head block.args of
            Just arg ->
                if arg == "numbered" then
                    List.indexedMap (\k str -> renderIndexedVerbatimLine k "plain" str) (String.lines (Render.Utility.getVerbatimContent block))

                else
                    --List.map (renderVerbatimLine arg) (String.lines (Render.Utility.getVerbatimContent block))
                    viewCodeWithHighlight arg (Render.Utility.getVerbatimContent block)

            Nothing ->
                --List.map (renderVerbatimLine "") (String.lines (Render.Utility.getVerbatimContent block))
                viewCodeWithHighlight "noLang" (Render.Utility.getVerbatimContent block)
        )


viewCodeWithHighlight : String -> String -> List (Element msg)
viewCodeWithHighlight language code =
    [ --useTheme gitHub |> Element.html
      ghCSS2
    , viewCodeWithHighlight_ language code |> Element.html
    ]



-- ghTheme =
--".elmsh {color: #24292e;background: #eeeeee;}.elmsh-hl {background: #fffbdd;}.elmsh-add {background: #eaffea;}.elmsh-del {background: #ffecec;}.elmsh-comm {color: #969896;}.elmsh1 {color: #005cc5;}.elmsh2 {color: #df5000;}.elmsh3 {color: #d73a49;}.elmsh4 {color: #0086b3;}.elmsh5 {color: #63a35c;}.elmsh6 {color: #005cc5;}.elmsh7 {color: #795da3;}"


ghTheme =
    ".elmsh {color: #24292e;background: #eeeeee;line-height: 1.5;}.elmsh-hl {background: #fffbdd;}.elmsh-add {background: #eaffea;}.elmsh-del {background: #ffecec;}.elmsh-comm {color: #969896;}.elmsh1 {color: #005cc5;}.elmsh2 {color: #df5000;}.elmsh3 {color: #d73a49;}.elmsh4 {color: #0086b3;}.elmsh5 {color: #63a35c;}.elmsh6 {color: #005cc5;}.elmsh7 {color: #795da3;}"


ghCSS2 : Element msg
ghCSS2 =
    Element.html <|
        Html.node "style"
            []
            [ Html.text ghTheme ]



-- githubTheme = .elmsh {color: #24292e;background: #ffffff;}.elmsh-hl {background: #fffbdd;}.elmsh-add {background: #eaffea;}.elmsh-del {background: #ffecec;}.elmsh-comm {color: #969896;}.elmsh1 {color: #005cc5;}.elmsh2 {color: #df5000;}.elmsh3 {color: #d73a49;}.elmsh4 {color: #0086b3;}.elmsh5 {color: #63a35c;}.elmsh6 {color: #005cc5;}.elmsh7 {color: #795da3;}


viewCodeWithHighlight_ : String -> String -> Html msg
viewCodeWithHighlight_ language code_ =
    let
        lines_ =
            String.lines code_

        code =
            case List.head lines_ of
                Just firstLine ->
                    if String.left 2 firstLine == "  " then
                        List.map (\line -> String.dropLeft 2 line) lines_
                            |> String.join "\n"

                    else
                        code_

                Nothing ->
                    code_
    in
    case language of
        "python" ->
            code
                |> SyntaxHighlight.python
                |> Result.map (toBlockHtml (Just 1))
                |> Result.withDefault (text code)

        "javascript" ->
            code
                |> SyntaxHighlight.javascript
                |> Result.map (toBlockHtml (Just 1))
                |> Result.withDefault (text code)

        "elm" ->
            code
                |> SyntaxHighlight.elm
                |> Result.map (toBlockHtml (Just 1))
                |> Result.withDefault (text code)

        "noLang" ->
            code
                |> SyntaxHighlight.elm
                |> Result.map (toBlockHtml (Just 1))
                |> Result.withDefault (text code)

        _ ->
            code
                |> SyntaxHighlight.noLang
                |> Result.map (toBlockHtml (Just 1))
                |> Result.withDefault (text code)


renderVerbatim : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
renderVerbatim _ _ _ attrs block =
    Element.column
        ([ Font.family
            [ Font.typeface "Inconsolata"
            , Font.monospace
            ]
         , Element.spacing 8
         , Element.paddingEach { left = 24, right = 0, top = 0, bottom = 0 }
         ]
            ++ attrs
        )
        (List.map (renderVerbatimLine "none") (String.lines (String.trim (Render.Utility.getVerbatimContent block))))


renderVerbatimLine : String -> String -> Element msg
renderVerbatimLine lang str =
    let
        spacer s =
            let
                n =
                    String.length s - String.length (String.trimLeft s)
            in
            Element.paddingEach { top = 0, bottom = 0, left = n * 8, right = 0 }
    in
    if String.trim str == "" then
        Element.row [ spacer str, Element.spacing 12 ] [ Element.el [ Element.height (Element.px 11) ] (Element.text "") ]

    else
        Element.row [ spacer str, Element.spacing 12 ] [ Element.el [ Element.height (Element.px 22) ] (Element.text str) ]


renderIndexedVerbatimLine : Int -> String -> String -> Element msg
renderIndexedVerbatimLine k lang str_ =
    let
        str =
            String.replace "\\bt" "`" str_

        index k_ =
            Element.el [ Element.paddingEach { top = 0, bottom = 8, left = 0, right = 0 } ] (Element.text <| String.fromInt (k_ + 1))
    in
    if String.trim str == "" then
        Element.row [ Element.spacing 12 ] [ index k, Element.el [ Element.height (Element.px 11) ] (Element.text "") ]

    else if lang == "plain" then
        Element.row [ Element.spacing 12 ] [ index k, Element.el [ Element.height (Element.px 22) ] (Element.text str) ]

    else
        Element.row [ Element.spacing 12 ] [ index k, Element.paragraph [ Element.height (Element.px 22) ] (renderedColoredLine lang str) ]


renderVerse : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
renderVerse _ _ _ attrs block =
    let
        lines_ =
            String.lines (Render.Utility.getVerbatimContent block)

        lines =
            -- normalize to properly render an indented block of verse
            -- often  used when there are "blank" lines in the verse,
            -- meaning lines with leading spaces (2 spaces)
            case List.head lines_ of
                Just firstLine ->
                    if String.left 2 firstLine == "  " then
                        List.map (\line -> String.dropLeft 2 line) lines_

                    else
                        lines_

                Nothing ->
                    lines_
    in
    Element.column [ Element.spacing 8 ]
        [ Render.Helper.noteFromPropertyKey "title" [ Render.Helper.leftPadding 12, Font.bold ] block
        , Element.column
            (verbatimBlockAttributes block.meta.lineNumber
                block.meta.numberOfLines
                [ Element.paddingEach { left = 12, right = 0, top = 0, bottom = 0 } ]
                ++ attrs
            )
            (List.map (renderVerbatimLine "plain") lines)
        , Render.Helper.noteFromPropertyKey "source" [ Render.Helper.leftPadding 12 ] block
        ]


note block =
    case Dict.get "note" block.properties of
        Nothing ->
            Element.none

        Just note_ ->
            Element.paragraph [] [ Element.text note_ ]


verbatimBlockAttributes lineNumber numberOfLines attrs =
    [ Render.Sync.rightToLeftSyncHelper lineNumber numberOfLines
    , Render.Utility.idAttributeFromInt lineNumber
    ]
        ++ attrs



-- HELPERS


renderedColoredLine lang str =
    str
        |> String.words
        |> List.map (renderedColoredWord lang)


renderedColoredWord lang word =
    case lang of
        "elm" ->
            case Dict.get word elmDict of
                Just color ->
                    Element.el [ color ] (Element.text (word ++ " "))

                Nothing ->
                    Element.el [] (Element.text (word ++ " "))

        _ ->
            Element.el [] (Element.text (word ++ " "))


orange =
    Font.color (Element.rgb255 227 81 18)


green =
    Font.color (Element.rgb255 11 158 26)


cyan =
    Font.color (Element.rgb255 11 143 158)


elmDict =
    Dict.fromList
        [ ( "type", orange )
        , ( "LB", green )
        , ( "RB", green )
        , ( "S", green )
        , ( "String", green )
        , ( "Meta", cyan )
        ]
