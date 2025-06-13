module Render.Compatibility.OrdinaryBlock exposing
    ( render
    , getAttributes 
    , getAttributesForBlock
    )

{-| This module provides compatibility for ordinary block rendering.

@docs render, getAttributes, getAttributesForBlock

-}

import Element exposing (Element)
import Generic.Acc exposing (Accumulator)
import Generic.Language exposing (ExpressionBlock)
import Render.OrdinaryBlock as NewOrdinaryBlock
import Render.Settings exposing (RenderSettings)
import ScriptaV2.Msg exposing (MarkupMsg)


{-| Compatibility wrapper for OrdinaryBlock.render
-}
render : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
render =
    NewOrdinaryBlock.render


{-| Compatibility wrapper for OrdinaryBlock.getAttributes
-}
getAttributes : String -> List (Element.Attribute MarkupMsg)
getAttributes =
    NewOrdinaryBlock.getAttributes


{-| Compatibility wrapper for OrdinaryBlock.getAttributesForBlock
-}
getAttributesForBlock : ExpressionBlock -> List (Element.Attribute MarkupMsg)
getAttributesForBlock =
    NewOrdinaryBlock.getAttributesForBlock