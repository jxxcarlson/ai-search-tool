module Render.BlockRegistry exposing
    ( BlockRegistry
    , BlockRenderer
    , empty
    , register
    , registerBatch
    , lookup
    , render
    )

{-| This module provides a registry for block renderers.

Instead of having a single monolithic dictionary of renderers, this module
allows renderers to be registered from various modules and looked up by name.

@docs BlockRegistry, BlockRenderer
@docs empty, register, registerBatch, lookup, render

-}

import Dict exposing (Dict)
import Element exposing (Element)
import Generic.Acc exposing (Accumulator)
import Generic.Language exposing (ExpressionBlock, Heading(..))
import Render.BlockType as BlockType
import Render.Settings exposing (RenderSettings)
import ScriptaV2.Msg exposing (MarkupMsg)


{-| Type alias for a block renderer function
-}
type alias BlockRenderer =
    Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg


{-| Type alias for the block registry
-}
type alias BlockRegistry =
    Dict String BlockRenderer


{-| Create an empty registry
-}
empty : BlockRegistry
empty =
    Dict.empty


{-| Register a renderer for a block type
-}
register : String -> BlockRenderer -> BlockRegistry -> BlockRegistry
register name renderer registry =
    Dict.insert name renderer registry


{-| Register multiple renderers at once
-}
registerBatch : List ( String, BlockRenderer ) -> BlockRegistry -> BlockRegistry
registerBatch renderers registry =
    List.foldl (\( name, renderer ) acc -> register name renderer acc) registry renderers


{-| Look up a renderer by name
-}
lookup : String -> BlockRegistry -> Maybe BlockRenderer
lookup =
    Dict.get


{-| Render a block using the registry
Returns Nothing if no renderer is found for the block type
-}
render : BlockRegistry -> Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Maybe (Element MarkupMsg)
render registry count acc settings attrs block =
    case block.heading of
        Ordinary name ->
            lookup name registry
                |> Maybe.map (\renderer -> renderer count acc settings attrs block)

        _ ->
            Nothing