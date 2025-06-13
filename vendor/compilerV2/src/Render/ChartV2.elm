module Render.ChartV2 exposing (plot2D, render)

import Chart
import Chart.Attributes as CA
import Chart.Svg exposing (Axis)
import Dict
import Either exposing (Either(..))
import Element exposing (Element)
import Element.Background
import Element.Font as Font
import Element.Lazy
import Generic.Acc exposing (Accumulator)
import Generic.Language exposing (ExpressionBlock)
import List.Extra
import Maybe.Extra
import Render.Settings exposing (RenderSettings)
import ScriptaV2.Msg exposing (MarkupMsg(..))
import Stat
import Tools.KV


dWidth =
    -- TODO: this is a bad hack
    80


render : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
render count acc settings attr block =
    case block.body of
        Right _ ->
            Element.text "Oops, Error!"

        Left str ->
            case String.split "====" str of
                [ argString, data_ ] ->
                    let
                        properties_ =
                            Tools.KV.makeDict argString

                        kind =
                            List.head block.args |> Maybe.withDefault "line" |> String.trim

                        properties : Dict.Dict String String
                        properties =
                            properties_
                                |> Dict.insert "width" (String.fromInt (settings.width + dWidth))

                        backgroundColor =
                            case Dict.get "dark" properties of
                                Just "yes" ->
                                    Element.rgb 0.1 0.1 0.1

                                Just "no" ->
                                    Element.rgb 1 1 1

                                _ ->
                                    Element.rgb 1 1 1

                        data =
                            if data_ == "" then
                                case Dict.get "source" properties of
                                    Just tag ->
                                        case Dict.get tag settings.data of
                                            Just data__ ->
                                                data__

                                            Nothing ->
                                                ""

                                    _ ->
                                        ""

                            else
                                data_
                    in
                    Element.column [ Element.Background.color backgroundColor, Element.width (Element.px (settings.width + dWidth)) ]
                        [ chart kind properties data ]

                _ ->
                    Element.text "Oops, Error! (2)"


red =
    Element.rgb255 255 0 0


deltaWidth =
    100


type alias Options =
    { direction : Maybe String
    , header : Maybe Int
    , reverse : Bool
    , filter : Maybe String
    , columns : Maybe (List Int)
    , rows : Maybe ( Int, Int )
    , separator : Maybe String
    , lowest : Maybe Float
    , caption : Maybe String
    , label : Maybe String
    , regression : Maybe String
    , kind : Maybe String -- e.g, kind:line or --kind:scatter
    , domain : Maybe Range
    , range : Maybe Range
    , width : Int
    , dark : Bool
    }


type alias Range =
    { lowest : Maybe Float, highest : Maybe Float }


fontWidth =
    10


plot2D : String -> Dict.Dict String String -> List ( Float, Float ) -> Element msg
plot2D kind properties_ xyData =
    let
        properties =
            Dict.insert "kind" kind properties_

        options : Options
        options =
            { direction = Dict.get "direction" properties
            , columns = Dict.get "columns" properties |> Maybe.map (String.split "," >> List.map String.trim >> List.map String.toInt >> Maybe.Extra.values >> List.map (\x -> x - 1))
            , rows = Dict.get "rows" properties |> Maybe.map (String.split "," >> List.map String.trim >> twoListToIntPair)
            , separator = Dict.get "separator" properties
            , reverse = Dict.get "reverse" properties |> toBool |> Maybe.withDefault False
            , header = Dict.get "header" properties |> Maybe.andThen String.toInt
            , filter = Dict.get "filter" properties
            , lowest = Dict.get "lowest" properties |> Maybe.andThen String.toFloat
            , caption = Dict.get "caption" properties
            , label = Dict.get "figure" properties
            , regression = Dict.get "regression" properties
            , kind = Dict.get "kind" properties
            , domain = Dict.get "domain" properties |> Maybe.andThen getRange
            , range = Dict.get "range" properties |> Maybe.andThen getRange
            , width = Dict.get "width" properties |> Maybe.andThen String.toInt |> Maybe.withDefault 300
            , dark = Dict.get "dark" properties |> toBool |> Maybe.withDefault False
            }

        data : ChartData
        data =
            List.map (\( x, y ) -> { x = x, y = y }) xyData |> ChartData2D
    in
    Element.column [ Element.width (Element.px (options.width - deltaWidth)), Element.paddingEach { left = 48, right = 0, top = 36, bottom = 72 }, Element.spacing 24 ]
        [ Element.el [ Element.width (Element.px (options.width - deltaWidth)) ]
            (rawLineChart options (Just data))
        , case ( options.label, options.caption ) of
            ( Nothing, Nothing ) ->
                Element.none

            ( Just labelText, Nothing ) ->
                Element.el [ Element.centerX, Font.size 14, Font.color (Element.rgb 0.5 0.5 0.7), Element.paddingEach { left = 0, right = 0, top = 24, bottom = 0 } ] (Element.text <| "Figure " ++ labelText)

            ( Nothing, Just captionText ) ->
                Element.el [ Element.centerX, Font.size 14, Font.color (Element.rgb 0.5 0.5 0.7), Element.paddingEach { left = 0, right = 0, top = 24, bottom = 0 } ] (Element.text <| captionText)

            ( Just labelText, Just captionText ) ->
                Element.el [ Element.centerX, Font.size 14, Font.color (Element.rgb 0.5 0.5 0.7), Element.paddingEach { left = 0, right = 0, top = 24, bottom = 0 } ] (Element.text <| "Figure " ++ labelText ++ ". " ++ captionText)
        ]


chart : String -> Dict.Dict String String -> String -> Element msg
chart kind properties_ data_ =
    Element.Lazy.lazy3 chart_ kind properties_ data_


chart_ : String -> Dict.Dict String String -> String -> Element msg
chart_ kind properties_ data_ =
    let
        properties =
            Dict.insert "kind" kind properties_

        options : Options
        options =
            { direction = Dict.get "direction" properties
            , columns = Dict.get "columns" properties |> Maybe.map (String.split "," >> List.map String.trim >> List.map String.toInt >> Maybe.Extra.values >> List.map (\x -> x - 1))
            , rows = Dict.get "rows" properties |> Maybe.map (String.split "," >> List.map String.trim >> twoListToIntPair)
            , separator = Dict.get "separator" properties
            , reverse = Dict.get "reverse" properties |> toBool |> Maybe.withDefault False
            , header = Dict.get "header" properties |> Maybe.andThen String.toInt
            , filter = Dict.get "filter" properties
            , lowest = Dict.get "lowest" properties |> Maybe.andThen String.toFloat
            , caption = Dict.get "caption" properties
            , label = Dict.get "figure" properties
            , regression = Dict.get "regression" properties
            , kind = Dict.get "kind" properties
            , domain = Dict.get "domain" properties |> Maybe.andThen getRange
            , range = Dict.get "range" properties |> Maybe.andThen getRange
            , width = Dict.get "width" properties |> Maybe.andThen String.toInt |> Maybe.withDefault 300
            , dark = Dict.get "dark" properties |> toBool |> Maybe.withDefault False
            }

        data : Maybe ChartData
        data =
            csvToChartData options (data_ |> String.trim |> String.split "\n")
    in
    Element.column [ Element.width (Element.px (options.width - deltaWidth)), Element.paddingEach { left = 48, right = 0, top = 36, bottom = 36 }, Element.spacing 24 ]
        [ Element.el [ Element.width (Element.px (options.width - deltaWidth)) ]
            (rawLineChart options data)
        , case ( options.label, options.caption ) of
            ( Nothing, Nothing ) ->
                Element.none

            ( Just labelText, Nothing ) ->
                Element.el [ Element.centerX, Font.size 14, Font.color (Element.rgb 0.5 0.5 0.7), Element.paddingEach { left = 0, right = 0, top = 24, bottom = 0 } ] (Element.text <| "Figure " ++ labelText)

            ( Nothing, Just captionText ) ->
                Element.el [ Element.centerX, Font.size 14, Font.color (Element.rgb 0.5 0.5 0.7), Element.paddingEach { left = 0, right = 0, top = 24, bottom = 0 } ] (Element.text <| captionText)

            ( Just labelText, Just captionText ) ->
                Element.el [ Element.centerX, Font.size 14, Font.color (Element.rgb 0.5 0.5 0.7), Element.paddingEach { left = 0, right = 0, top = 24, bottom = 0 } ] (Element.text <| "Figure " ++ labelText ++ ". " ++ captionText)
        ]


toBool : Maybe String -> Maybe Bool
toBool maybeString =
    case maybeString of
        Just "yes" ->
            Just True

        Just "no" ->
            Just False

        _ ->
            Nothing


getArg : String -> List String -> Maybe String
getArg name args =
    List.filter (\item -> String.contains name item) args |> List.head


type ChartData
    = ChartData2D (List { x : Float, y : Float })
    | ChartData3D (List { x : Float, y : Float, z : Float })
    | ChartData4D (List { x : Float, y : Float, z : Float, w : Float })


getRange : String -> Maybe Range
getRange str =
    case str |> String.split "," |> List.map String.trim |> List.take 2 of
        low :: high :: [] ->
            Just { lowest = String.toFloat low, highest = String.toFloat high }

        _ ->
            Nothing


select : Maybe (List Int) -> List a -> Maybe (List a)
select columns_ data =
    case columns_ of
        Nothing ->
            Just data

        Just columns ->
            let
                selectors : List (List a -> Maybe a)
                selectors =
                    List.map List.Extra.getAt columns
            in
            applyFunctions selectors data |> Maybe.Extra.combine


selectColumns : Maybe (List Int) -> List (List a) -> Maybe (List (List a))
selectColumns columns data =
    if columns == Just [] then
        Just data

    else
        List.map (select columns) data |> Maybe.Extra.combine


dim : List (List a) -> ( Int, Int )
dim data =
    case data of
        [] ->
            ( 0, 0 )

        first :: _ ->
            ( List.length data, List.length first )


makeTimeseries : List (List String) -> List (List String)
makeTimeseries data =
    List.indexedMap (\i oneList -> String.fromInt i :: oneList) data


csvToChartData : Options -> List String -> Maybe ChartData
csvToChartData options inputLines_ =
    let
        filteredInputLines : List String
        filteredInputLines =
            inputLines_
                |> List.filter (\line -> String.trim line /= "" && String.left 1 line /= "#")
                |> stripHeader options.header
                |> filterLines options.filter
                |> (\data -> takeRows (flipIf data options.reverse options.rows) data)

        flipIf : List String -> Bool -> Maybe ( Int, Int ) -> Maybe ( Int, Int )
        flipIf data reverse_ rows =
            if reverse_ then
                case rows of
                    Nothing ->
                        Just ( 0, List.length data )

                    Just ( start, end ) ->
                        Just ( List.length data - end, List.length data - start )

            else
                rows

        reverse : Options -> List String -> List String
        reverse options_ lines =
            if options_.reverse then
                List.reverse lines

            else
                lines

        takeRows : Maybe ( Int, Int ) -> List String -> List String
        takeRows maybeRowPair lines =
            case maybeRowPair of
                Nothing ->
                    lines

                Just ( start, end ) ->
                    case ( start, end ) of
                        ( 0, 0 ) ->
                            lines

                        ( 0, _ ) ->
                            List.take end lines

                        ( _, 0 ) ->
                            List.drop start lines

                        ( _, _ ) ->
                            List.drop start lines |> List.take end

        stripHeader dropLines lines =
            case dropLines of
                Nothing ->
                    lines

                Just n ->
                    List.drop n lines

        filterLines filter_ lines =
            case filter_ of
                Nothing ->
                    lines

                Just filter ->
                    List.filter (\line -> String.contains filter line) lines

        separator =
            case options.separator of
                Just sep ->
                    if sep == "tab" then
                        "\t"

                    else if sep == "blank" then
                        " "

                    else if sep == "comma" then
                        ","

                    else if sep == "semicolon" then
                        ";"

                    else if sep == "colon" then
                        ":"

                    else
                        sep

                Nothing ->
                    ","

        data_ : Maybe (List (List String))
        data_ =
            case options.kind of
                Just "timeseries" ->
                    List.map (String.split "," >> List.map String.trim) filteredInputLines
                        |> selectColumns options.columns
                        |> Maybe.map (applyIf options.reverse List.reverse)
                        |> Maybe.map makeTimeseries

                _ ->
                    List.map (String.split separator >> List.map String.trim) filteredInputLines
                        |> selectColumns options.columns

        dimension : Maybe Int
        dimension =
            data_ |> Maybe.andThen List.head |> Maybe.map List.length
    in
    case ( dimension, data_ ) of
        ( Nothing, _ ) ->
            Nothing

        ( _, Nothing ) ->
            Nothing

        ( Just 2, Just data ) ->
            Just (ChartData2D (csvTo2DData data))

        ( Just 3, Just data ) ->
            Just (ChartData3D (csvTo3DData data))

        _ ->
            Nothing


csvTo2DData : List (List String) -> List { x : Float, y : Float }
csvTo2DData data =
    data
        |> List.map listTo2DPoint
        |> Maybe.Extra.values


csvTo3DData : List (List String) -> List { x : Float, y : Float, z : Float }
csvTo3DData data =
    data
        |> List.map listTo3DPoint
        |> Maybe.Extra.values


listTo2DPoint : List String -> Maybe { x : Float, y : Float }
listTo2DPoint list =
    case list of
        x :: y :: rest ->
            ( String.toFloat (String.trim x), String.toFloat (String.trim y) ) |> valueOfPair |> Maybe.map (\( u, v ) -> { x = u, y = v })

        _ ->
            Nothing


listTo3DPoint : List String -> Maybe { x : Float, y : Float, z : Float }
listTo3DPoint list =
    case list of
        x :: y :: z :: rest ->
            ( String.toFloat (String.trim x), String.toFloat (String.trim y), String.toFloat (String.trim z) ) |> valueOfTriple |> Maybe.map (\( u, v, w ) -> { x = u, y = v, z = w })

        _ ->
            Nothing


listTo4DPoint : List String -> Maybe { x : Float, y : Float }
listTo4DPoint list =
    case list of
        x :: y :: rest ->
            ( String.toFloat (String.trim x), String.toFloat (String.trim y) ) |> valueOfPair |> Maybe.map (\( u, v ) -> { x = u, y = v })

        _ ->
            Nothing


valueOfPair : ( Maybe a, Maybe b ) -> Maybe ( a, b )
valueOfPair ( ma, mb ) =
    case ( ma, mb ) of
        ( Just a, Just b ) ->
            Just ( a, b )

        _ ->
            Nothing


valueOfTriple : ( Maybe a, Maybe b, Maybe c ) -> Maybe ( a, b, c )
valueOfTriple ( ma, mb, mc ) =
    case ( ma, mb, mc ) of
        ( Just a, Just b, Just c ) ->
            Just ( a, b, c )

        _ ->
            Nothing


rawLineChart : Options -> Maybe ChartData -> Element msg
rawLineChart options mChartData =
    case mChartData of
        Nothing ->
            Element.el [ Font.size 14, Font.color red ] (Element.text "Line chart: Error parsing data")

        Just (ChartData2D data) ->
            rawLineChart2D options data

        Just (ChartData3D data) ->
            rawLineChart3D data

        _ ->
            Element.el [ Font.size 14, Font.color red ] (Element.text "Line chart: Error, can only handle 2D data")



--
--expandRange : { a | lowest : Maybe Float, highest : Maybe Float } -> List (Axis -> Axis)
--expandRange { lowest, highest } =
--    let
--        low =
--            case lowest of
--                Nothing ->
--                    CA.lowest 0 CA.orLower
--
--                Just u ->
--                    CA.lowest u CA.exactly
--
--        high =
--            case highest of
--                Nothing ->
--                    CA.highest 100 CA.orHigher
--
--                Just u ->
--                    CA.highest u CA.exactly
--    in
--    [ low, high ]


regressionLine : List { x : Float, y : Float } -> Maybe (Float -> Float)
regressionLine points =
    let
        data =
            List.map (\{ x, y } -> ( x, y ))
                points
    in
    case Stat.linearRegression data of
        Nothing ->
            Nothing

        Just ( alpha, beta ) ->
            Just (\x -> alpha + beta * x)


rawLineChart2D : Options -> List { x : Float, y : Float } -> Element msg
rawLineChart2D options data =
    --let
    --    domain =
    --        case options.domain of
    --            Nothing ->
    --                CA.domain []
    --
    --            Just range_ ->
    --                CA.domain (expandRange range_)
    --
    --    range =
    --        case options.range of
    --            Nothing ->
    --                CA.range []
    --
    --            Just range_ ->
    --                CA.range (expandRange range_)
    --in
    Chart.chart
        [ CA.height 200
        , CA.width (toFloat options.width)
        , case options.lowest of
            Nothing ->
                CA.domain []

            Just lowest ->
                CA.domain [ CA.lowest lowest CA.orLower ]

        --, CA.range []
        --, CA.domain []
        ]
        [ Chart.xLabels [ CA.fontSize 10 ]
        , Chart.yLabels [ CA.withGrid, CA.fontSize 10 ]
        , case options.regression of
            Nothing ->
                Chart.none

            Just _ ->
                let
                    f_ : Maybe (Float -> Float)
                    f_ =
                        regressionLine data
                in
                case f_ of
                    Nothing ->
                        Chart.none

                    Just f ->
                        let
                            regressionData =
                                List.map (\{ x, y } -> { x = x, y = f x }) data
                        in
                        Chart.series .x [ Chart.interpolated .y [ CA.color CA.blue ] [] ] regressionData
        , case options.kind of
            Just "line" ->
                Chart.series .x [ Chart.interpolated .y [ CA.color CA.red ] [] ] data

            Just "scatter" ->
                Chart.series .x [ Chart.scatter .y [] ] data

            Just "bar" ->
                Chart.bars []
                    [ Chart.bar .y []
                    ]
                    data

            _ ->
                Chart.series .x [ Chart.interpolated .y [ CA.color CA.blue ] [] ] data
        ]
        |> Element.html


rawLineChart3D : List { x : Float, y : Float, z : Float } -> Element msg
rawLineChart3D data =
    Chart.chart
        [ CA.height 200
        , CA.width 400
        ]
        [ Chart.xLabels [ CA.fontSize 10 ]
        , Chart.yLabels [ CA.withGrid, CA.fontSize 10 ]
        , Chart.series .x
            [ Chart.interpolated .y [ CA.color CA.red ] []
            , Chart.interpolated .z [ CA.color CA.darkBlue ] []
            ]
            data
        ]
        |> Element.html



-- UTILTIES


applyFunctions : List (a -> b) -> a -> List b
applyFunctions fs a =
    List.foldl (\f acc -> f a :: acc) [] fs |> List.reverse


liftToMaybe : (a -> b) -> Maybe a -> Maybe b
liftToMaybe f maybe =
    case maybe of
        Just a ->
            Just (f a)

        Nothing ->
            Nothing


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


twoListToIntPair : List String -> ( Int, Int )
twoListToIntPair list =
    case list of
        [ x, y ] ->
            ( String.toInt x |> Maybe.withDefault 0, String.toInt y |> Maybe.withDefault 0 )

        _ ->
            ( 0, 0 )
