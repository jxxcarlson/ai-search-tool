module Render.List exposing (desc, item, numbered)

import Dict exposing (Dict)
import Element exposing (Element)
import Element.Font as Font
import Generic.Acc exposing (Accumulator)
import Generic.Language exposing (ExpressionBlock)
import List.Extra
import Render.Helper
import Render.Settings exposing (RenderSettings)
import Render.Sync
import Render.Utility
import ScriptaV2.Msg exposing (MarkupMsg(..))



-- LISTS


indentationScale =
    15


item : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
item count acc settings attr block =
    let
        id =
            String.fromInt block.meta.lineNumber

        level_ =
            block.indent // 2

        label_ =
            case modBy 3 level_ of
                0 ->
                    String.fromChar '•'

                1 ->
                    String.fromChar '○'

                _ ->
                    "◊"
    in
    Element.row
        [ Element.moveRight (indentationScale * level_ |> toFloat)
        , Element.alignTop
        , Render.Utility.idAttributeFromInt block.meta.lineNumber
        , Render.Utility.vspace 0 settings.topMarginForChildren
        , Element.width (Element.px <| settings.width - 50)
        ]
        [ Element.el
            [ Font.size 14
            , Element.alignTop
            , Element.moveRight 6
            , Element.width (Element.px 24)
            , Render.Utility.leftPadding settings.leftIndentation
            ]
            (Element.text label_)
        , Element.paragraph [ Render.Utility.leftPadding settings.leftIndentation, Render.Sync.rightToLeftSyncHelper block.meta.lineNumber block.meta.numberOfLines ]
            (Render.Helper.renderWithDefault "| item" count acc settings attr (Generic.Language.getExpressionContent block))
        ]


numbered : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
numbered count acc settings attr block =
    let
        id =
            block.meta.id

        alphabet =
            [ "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z" ]

        romanNumerals =
            [ "i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x", "xi", "xii", "xiii", "xiv", "xv", "xvi", "xvii", "xviii", "xix", "xx", "xi", "xxii", "xxiii", "xxiv", "xxv", "vi" ]

        alpha k =
            List.Extra.getAt (modBy 26 (k - 1)) alphabet |> Maybe.withDefault "a"

        roman k =
            List.Extra.getAt (modBy 26 (k - 1)) romanNumerals |> Maybe.withDefault "i"

        val =
            Dict.get id acc.numberedItemDict

        index_ =
            val |> Maybe.map .index |> Maybe.withDefault 1

        level =
            val |> Maybe.map .level |> Maybe.withDefault 0

        label_ =
            case modBy 3 level of
                1 ->
                    alpha index_

                2 ->
                    roman index_

                _ ->
                    String.fromInt index_
    in
    Element.row
        [ Element.moveRight (indentationScale * level |> toFloat)
        , Element.alignTop
        , Render.Utility.idAttributeFromInt block.meta.lineNumber
        , Render.Utility.vspace 0 settings.topMarginForChildren
        , Element.width (Element.px <| settings.width - 50)
        ]
        [ Element.el
            [ Font.size 14
            , Element.alignTop
            , Element.width (Element.px 24)
            , Render.Utility.leftPadding settings.leftRightIndentation
            ]
            (Element.text (label_ ++ ". "))
        , Element.paragraph [ Render.Utility.leftPadding settings.leftIndentation, Render.Sync.rightToLeftSyncHelper block.meta.lineNumber block.meta.numberOfLines ]
            (Render.Helper.renderWithDefault "| numbered" count acc settings attr (Generic.Language.getExpressionContent block))
        ]


desc : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
desc count acc settings attr block =
    let
        label =
            -- Render.Utility.argString block.args
            String.join " " block.args
    in
    Element.row ([ Element.alignTop, Render.Utility.idAttributeFromInt block.meta.lineNumber, Render.Utility.vspace 0 settings.topMarginForChildren ] ++ Render.Sync.highlightIfIdIsSelected block.meta.lineNumber block.meta.numberOfLines settings)
        [ Element.el [ Font.bold, Element.alignTop, Element.width (Element.px 100) ] (Element.text label)
        , Element.paragraph [ Render.Utility.leftPadding settings.leftIndentation, Render.Sync.rightToLeftSyncHelper block.meta.lineNumber block.meta.numberOfLines ]
            (Render.Helper.renderWithDefault "| desc" count acc settings attr (Generic.Language.getExpressionContent block))
        ]
