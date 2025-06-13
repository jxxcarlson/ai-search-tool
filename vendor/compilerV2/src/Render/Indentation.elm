module Render.Indentation exposing
    ( indentParagraph
    , indentOrdinaryBlock
    , indentElement
    , topPaddingForIndentedElements
    )

{-| This module provides unified indentation helpers to eliminate code duplication.

@docs indentParagraph, indentOrdinaryBlock, indentElement, topPaddingForIndentedElements

-}

import Element exposing (Element)
import Render.Helper
import Render.Settings exposing (RenderSettings)


{-| Standard top padding for indented elements
-}
topPaddingForIndentedElements : Int
topPaddingForIndentedElements =
    Render.Helper.topPaddingForIndentedElements


{-| Indent a paragraph based on indent level
-}
indentParagraph : Int -> Element msg -> Element msg
indentParagraph indent x =
    if indent > 0 then
        Element.el [ Element.paddingEach { top = topPaddingForIndentedElements, bottom = 0, left = 0, right = 0 } ] x
    else
        x


{-| Indent an ordinary block based on indent level and id
-}
indentOrdinaryBlock : Int -> String -> RenderSettings -> Element msg -> Element msg
indentOrdinaryBlock indent id settings x =
    if indent > 0 then
        Element.el 
            [ Render.Helper.selectedColor id settings
            , Element.paddingEach { top = topPaddingForIndentedElements, bottom = 0, left = 0, right = 0 } 
            ] 
            x
    else
        x


{-| Generic indent helper for any element with a specified left padding
-}
indentElement : Int -> Int -> Element msg -> Element msg
indentElement indent leftPadding x =
    if indent > 0 then
        Element.el 
            [ Element.paddingEach 
                { top = topPaddingForIndentedElements
                , bottom = 0
                , left = leftPadding
                , right = 0 
                } 
            ] 
            x
    else
        x