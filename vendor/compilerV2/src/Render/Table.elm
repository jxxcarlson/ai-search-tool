module Render.Table exposing (render)

import Dict exposing (Dict)
import Either exposing (Either(..))
import Element exposing (Element)
import Generic.Acc exposing (Accumulator)
import Generic.Language exposing (ExpressionBlock)
import Render.Expression
import Render.Settings exposing (RenderSettings)
import Render.Sync2
import ScriptaV2.Msg exposing (MarkupMsg(..))


render : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> Generic.Language.ExpressionBlock -> Element MarkupMsg
render count acc settings columnFormats block =
    case block.body of
        Right [ Generic.Language.Fun "table" rows _ ] ->
            let
                formatList_ =
                    Dict.get "format" block.properties
                        |> Maybe.withDefault ""
                        |> String.trim
                        |> String.split " "
                        |> List.map String.trim
                        |> List.map (\c -> Dict.get (String.trim c) formatDict |> Maybe.withDefault Element.centerX)

                columnWidths_ =
                    Dict.get "columnWidths" block.properties
                        |> Maybe.withDefault ""
                        |> String.dropLeft 1
                        |> String.dropRight 1
                        |> String.split ","
                        |> List.map String.trim
                        |> List.map (\c -> String.toInt c |> Maybe.withDefault 100)

                formats =
                    List.map2 (\x y -> ( x, y )) columnWidths_ formatList_
            in
            Element.column ([ Element.paddingEach { left = 24, right = 0, top = 24, bottom = 24 }, Element.spacing 0 ] |> Render.Sync2.sync block settings)
                (List.map (renderRow count acc settings formats) rows)

        Right _ ->
            Element.none

        Left data ->
            Element.text data


renderRow : Int -> Accumulator -> RenderSettings -> List ( Int, Element.Attribute MarkupMsg ) -> Generic.Language.Expr Generic.Language.ExprMeta -> Element MarkupMsg
renderRow count acc settings columnFormats row =
    case row of
        Generic.Language.Fun "row" cells _ ->
            let
                list =
                    List.map2 (renderCell count acc settings) columnFormats cells
            in
            Element.row [ Element.height (Element.px 20), Element.spacing 12 ] list

        _ ->
            Element.none


renderCell : Int -> Accumulator -> RenderSettings -> ( Int, Element.Attribute MarkupMsg ) -> Generic.Language.Expr Generic.Language.ExprMeta -> Element MarkupMsg
renderCell count acc settings ( colWidth, fmt ) cell =
    --Element.el [ Element.width (Element.px (colWidth + 18)) ]
    --    (Element.row [ Element.paddingXY 12 8, fmt ] list)
    case cell of
        Generic.Language.Fun "cell" exprs _ ->
            Element.el [ Element.width (Element.px <| colWidth + 10) ]
                (Element.row [ fmt ] (List.map (Render.Expression.render count acc settings []) exprs))

        _ ->
            Element.none


formatDict : Dict String (Element.Attribute msg)
formatDict =
    Dict.fromList
        [ ( "l", Element.alignLeft )
        , ( "r", Element.alignRight )
        , ( "c", Element.centerX )
        ]
