module Render.OrdinaryBlock exposing
    ( getAttributes
    , getAttributesForBlock
    , render
    , initRegistry
    )

{-| This module provides a new implementation of OrdinaryBlock using the registry pattern

@docs getAttributes, getAttributesForBlock, render, initRegistry

-}

import Dict exposing (Dict)
import Either exposing (Either(..))
import Element exposing (Element)
import Element.Background as Background
import Element.Font as Font
import Generic.BlockUtilities
import Generic.Acc exposing (Accumulator)
import Generic.Language exposing (Expr(..), Expression, ExpressionBlock, Heading(..))
import Render.Attributes
import Render.BlockRegistry exposing (BlockRegistry)
import Render.BlockType exposing (BlockType(..), ContainerBlockType(..), ListBlockType(..))
import Render.Blocks.Container as ContainerBlocks
import Render.Blocks.Document as DocumentBlocks
import Render.Blocks.Interactive as InteractiveBlocks
import Render.Blocks.Text as TextBlocks
import Render.Color
import Render.Helper
import Render.Indentation
import Render.List
import Render.Footnote
import Render.Table
import Render.Settings exposing (RenderSettings)
import ScriptaV2.Msg exposing (MarkupMsg(..))


{-| Get attributes for a specific block type by name
-}
getAttributes : String -> List (Element.Attribute MarkupMsg)
getAttributes name =
    let
        blockType =
            Render.BlockType.fromString name
    in
    case blockType of
        ContainerBlock Box ->
            [ Background.color Render.Color.boxBackground ]
        
        _ ->
            if List.member name Render.Attributes.italicBlockNames then
                [ Font.italic ]
            else
                []


{-| Get attributes for a block
-}
getAttributesForBlock : ExpressionBlock -> List (Element.Attribute MarkupMsg)
getAttributesForBlock block =
    case Generic.BlockUtilities.getExpressionBlockName block of
        Nothing ->
            []

        Just name ->
            getAttributes name


{-| Initialize the registry with all renderers
-}
initRegistry : BlockRegistry
initRegistry =
    Render.BlockRegistry.empty
        |> TextBlocks.registerRenderers
        |> ContainerBlocks.registerRenderers
        |> DocumentBlocks.registerRenderers
        |> InteractiveBlocks.registerRenderers
        |> Render.BlockRegistry.registerBatch
            [ ( "table", Render.Table.render )
            , ( "item", Render.List.item )
            , ( "desc", Render.List.desc )
            , ( "numbered", Render.List.numbered )
            , ( "index", Render.Footnote.index )
            , ( "endnotes", Render.Footnote.endnotes )
            ]


{-| Render an ordinary block using the registry
-}
render : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
render count acc settings attr block =
    let
        registry =
            initRegistry
    in
    case block.body of
        Left _ ->
            Element.none

        Right _ ->
            case block.heading of
                Ordinary functionName ->
                    let
                        renderedBlock =
                            case Render.BlockRegistry.lookup functionName registry of
                                Nothing ->
                                    -- Fall back to the environment renderer
                                    let
                                        -- Find the env renderer as our fallback
                                        envRenderer =
                                            Render.BlockRegistry.lookup "env" registry
                                                |> Maybe.withDefault (\_ _ _ _ _ -> Element.none)
                                    in
                                    envRenderer count acc settings attr block

                                Just renderer ->
                                    let
                                        blockType =
                                            Render.BlockType.fromString functionName
                                            
                                        newSettings =
                                            case blockType of
                                                ListBlock Item ->
                                                    { settings | width = settings.width - 6 * block.indent }
                                                    
                                                ListBlock Numbered ->
                                                    { settings | width = settings.width - 6 * block.indent }
                                                    
                                                _ ->
                                                    settings
                                    in
                                    renderer count acc newSettings attr block
                    in
                    -- Apply indentation to the rendered block
                    indentOrdinaryBlock block.indent (String.fromInt block.meta.lineNumber) settings renderedBlock

                _ ->
                    Element.none


{-| Apply indentation to an ordinary block
-}
indentOrdinaryBlock : Int -> String -> RenderSettings -> Element msg -> Element msg
indentOrdinaryBlock indent id settings x =
    Render.Indentation.indentOrdinaryBlock indent id settings x