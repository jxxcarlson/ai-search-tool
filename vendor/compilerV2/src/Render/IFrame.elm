module Render.IFrame exposing (render)

import Bool.Extra
import Dict exposing (Dict)
import Element exposing (Element)
import Generic.Acc exposing (Accumulator)
import Generic.Language exposing (ExpressionBlock)
import Html
import Html.Attributes
import Render.PUtility
import Render.Settings exposing (RenderSettings)
import Render.Sync
import Render.Utility
import ScriptaV2.Msg exposing (MarkupMsg(..))


render : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
render count acc settings attrs block =
    case parseIFrame (Render.Utility.getVerbatimContent block) of
        Nothing ->
            Element.el [] (Element.text "Error parsing iframe or unregistered src")

        Just iframeProperties ->
            let
                w =
                    String.toInt iframeProperties.width |> Maybe.withDefault 400

                caption_ =
                    Dict.get "caption" block.properties

                label_ =
                    Dict.get "figure" block.properties

                figureLabel =
                    case ( label_, caption_ ) of
                        ( Just label, Just caption ) ->
                            "Figure " ++ label ++ ". " ++ caption

                        ( Just label, Nothing ) ->
                            "Figure " ++ label

                        ( Nothing, Just caption ) ->
                            caption

                        ( Nothing, Nothing ) ->
                            ""
            in
            Element.column
                ([ Element.width (Element.px w)
                 ]
                    ++ attrs
                )
                [ Html.iframe
                    [ Html.Attributes.src <| iframeProperties.src
                    , Html.Attributes.style "border" "none"
                    , Html.Attributes.style "width" (iframeProperties.width ++ "px")
                    , Html.Attributes.style "height" (iframeProperties.height ++ "px")
                    ]
                    []
                    |> Element.html
                , Element.row [ Element.centerX, Element.paddingXY 0 12 ] [ Element.text figureLabel ]
                ]


parseIFrame : String -> Maybe { width : String, height : String, src : String }
parseIFrame str =
    let
        src_ =
            Render.PUtility.parseItem "src" str

        width_ =
            Render.PUtility.parseItem "width" str

        height_ =
            Render.PUtility.parseItem "height" str
    in
    case ( src_, width_, height_ ) of
        ( Just src, Just width, Just height ) ->
            if validSrc src then
                Just { width = width, height = height, src = src }

            else
                Nothing

        _ ->
            Nothing


allowedIFrameSrcList =
    [ "https://www.desmos.com/calculator/"
    , "https://openprocessing.org/"
    , "https://codepen.io/"
    , "https://q.uiver.app/"
    , "https://www.youtube.com/embed/"
    , "https://www.geogebra.org/"
    ]


validSrc : String -> Bool
validSrc src =
    List.map (\src_ -> String.contains src_ src) allowedIFrameSrcList |> Bool.Extra.any
