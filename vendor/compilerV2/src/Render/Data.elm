module Render.Data exposing (prepareTable, table)

import Dict
import Either exposing (Either(..))
import Element exposing (Element)
import Element.Font as Font
import Generic.Acc exposing (Accumulator)
import Generic.Language exposing (ExpressionBlock)
import List.Extra
import Maybe.Extra
import Render.Settings exposing (RenderSettings)
import ScriptaV2.Msg exposing (MarkupMsg(..))


red =
    Element.rgb255 255 0 0


type alias Options =
    { timeseries : Maybe String
    , reverse : Maybe String
    , columns : Maybe (List Int)
    , lowest : Maybe Float
    , caption : Maybe String
    , label : Maybe String
    , kind : Maybe String -- e.g, kind:line or --kind:scatter
    , domain : Maybe Range
    , range : Maybe Range
    }


type alias Range =
    { lowest : Maybe Float, highest : Maybe Float }


fontWidth =
    10



-- UTILTIES


applyFunctions : List (a -> b) -> a -> List b
applyFunctions fs a =
    List.foldl (\f acc -> f a :: acc) [] fs |> List.reverse


applyIf : Bool -> (a -> a) -> a -> a
applyIf flag f x =
    if flag then
        f x

    else
        x


maybeApply : Maybe a -> (b -> b) -> b -> b
maybeApply maybe f x =
    case maybe of
        Just _ ->
            f x

        Nothing ->
            x


maybeChoose : Maybe a -> (b -> b) -> (b -> b) -> b -> b
maybeChoose maybe f g x =
    case maybe of
        Just _ ->
            f x

        Nothing ->
            g x



-- ARG


getColumns : List String -> Maybe (List Int)
getColumns args =
    case getArg "columns" args of
        Nothing ->
            Nothing

        Just argList ->
            parseArg argList |> List.map String.toInt |> Maybe.Extra.values |> Just


getFloat : Maybe String -> Maybe Float
getFloat str =
    str
        --|> Maybe.map (String.split ":")
        --|> Maybe.map (List.drop 1)
        --|> Maybe.andThen List.head
        |> getString
        |> Maybe.andThen String.toFloat


getString : Maybe String -> Maybe String
getString str =
    str
        |> Maybe.map (String.split ":")
        |> Maybe.map (List.drop 1)
        |> Maybe.andThen List.head


getArgAfter : String -> List String -> Maybe String
getArgAfter label args =
    case List.Extra.findIndex (\item -> String.contains label item) args of
        Nothing ->
            Nothing

        Just k ->
            let
                a =
                    List.Extra.getAt k args |> Maybe.withDefault "" |> String.replace (label ++ ":") ""

                b =
                    List.drop (k + 1) args |> String.join " "
            in
            Just (a ++ b)


getArg : String -> List String -> Maybe String
getArg name args =
    List.filter (\item -> String.contains name item) args |> List.head


parseArg : String -> List String
parseArg arg =
    let
        parts =
            String.split ":" arg
    in
    case parts of
        [] ->
            []

        name :: [] ->
            []

        name :: argString :: [] ->
            String.split "," argString

        _ ->
            []


getRange : String -> Maybe Range
getRange str =
    case str |> String.split "," |> List.map String.trim |> List.take 2 of
        low :: high :: [] ->
            Just { lowest = String.toFloat low, highest = String.toFloat high }

        _ ->
            Nothing


getVerbatimContent : ExpressionBlock -> String
getVerbatimContent block =
    case block.body of
        Left str ->
            str

        Right _ ->
            ""


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


table : Int -> Accumulator -> RenderSettings -> ExpressionBlock -> Element MarkupMsg
table count acc settings block =
    let
        data =
            prepareTable fontWidth block

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
