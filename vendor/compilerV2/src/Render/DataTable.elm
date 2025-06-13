module Render.DataTable exposing (..)

import Dict exposing (Dict)
import Either exposing (Either(..))
import Element exposing (Element)
import Element.Font as Font
import Generic.Acc exposing (Accumulator)
import Generic.Language exposing (ExpressionBlock)
import List.Extra
import Maybe.Extra
import Render.Settings exposing (RenderSettings)
import ScriptaV2.Msg exposing (MarkupMsg(..))


render : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
render count acc settings attrs block =
    let
        data =
            prepareTable 15 block

        title =
            case data.title of
                Nothing ->
                    Element.none

                Just title_ ->
                    Element.el [ Font.bold ] (Element.text title_)

        renderRow : Int -> List Int -> List String -> Element MarkupMsg
        renderRow rowNumber widths_ cells_ =
            let
                totalWidth =
                    List.sum widths_ + 0
            in
            if rowNumber == 0 then
                Element.row [ Element.width (Element.px totalWidth) ] (List.map2 (\cell width -> Element.el [ Element.width (Element.px width), Font.underline ] (Element.text <| String.replace "_" "" cell)) cells_ widths_)

            else
                Element.row [ Element.width (Element.px totalWidth) ] (List.map2 (\cell width -> Element.el [ Element.width (Element.px width) ] (Element.text cell)) cells_ widths_)
    in
    Element.column [ Element.spacing 12, Element.paddingEach { left = 36, right = 0, top = 18, bottom = 18 } ] (title :: List.indexedMap (\k row -> renderRow k data.columnWidths row) data.selectedCells)


type alias TableData =
    { title : Maybe String, columnWidths : List Int, totalWidth : Int, selectedCells : List (List String) }


prepareTable : Int -> ExpressionBlock -> TableData
prepareTable fontWidth_ block =
    let
        title =
            Dict.get "title" block.properties

        columnsToDisplay : List Int
        columnsToDisplay =
            Dict.get "columns" block.properties
                |> Maybe.map (String.split ",")
                |> Maybe.withDefault []
                |> List.map (String.trim >> String.toInt)
                |> Maybe.Extra.values
                |> List.map (\n -> n - 1)

        lines =
            String.split "\n" (getVerbatimContent block)

        rawCells : List (List String)
        rawCells =
            List.map (String.split ",") lines
                |> List.map (List.map String.trim)

        selectedCells : List (List String)
        selectedCells =
            if columnsToDisplay == [] then
                rawCells

            else
                let
                    cols : List ( Int, List String )
                    cols =
                        List.Extra.transpose rawCells |> List.indexedMap (\k col -> ( k, col ))

                    updater : ( Int, List String ) -> List (List String) -> List (List String)
                    updater =
                        \( k, col ) acc_ ->
                            if List.member k columnsToDisplay then
                                col :: acc_

                            else
                                acc_

                    selectedCols =
                        List.foldl updater [] cols
                in
                List.Extra.transpose (List.reverse selectedCols)

        columnWidths : List Int
        columnWidths =
            List.map (List.map String.length) selectedCells
                |> List.Extra.transpose
                |> List.map (\column -> List.maximum column |> Maybe.withDefault 1)
                |> List.map (\w -> fontWidth_ * w)

        totalWidth =
            List.sum columnWidths
    in
    { title = title, columnWidths = columnWidths, totalWidth = totalWidth, selectedCells = selectedCells }


getVerbatimContent : ExpressionBlock -> String
getVerbatimContent block =
    case block.body of
        Left str ->
            str

        Right _ ->
            ""
