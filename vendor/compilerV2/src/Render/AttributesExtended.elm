module Render.AttributesExtended exposing
    ( getBlockAttributes
    , getItalicAttributes
    , getBoxAttributes
    , getContainerAttributes
    , getDocumentAttributes
    , getIndentAttributes
    , getQuotationAttributes
    , italicBlockNames
    , getBlockMarkupAttributes
    )

{-| This module extends Render.Attributes with both generic and specific versions of attribute functions.

@docs getBlockAttributes, getItalicAttributes, getBoxAttributes, getContainerAttributes, getDocumentAttributes, getIndentAttributes, getQuotationAttributes
@docs italicBlockNames, getBlockMarkupAttributes

-}

import Element exposing (Element)
import Element.Background as Background
import Element.Font as Font
import Generic.BlockUtilities
import Generic.Language exposing (ExpressionBlock)
import Render.BlockType as BlockType exposing (BlockType(..))
import Render.Helper
import Render.Settings exposing (RenderSettings)
import Render.Sync
import Render.Utility
import ScriptaV2.Msg exposing (MarkupMsg)


{-| Main function to get generic attributes for a block based on its type
-}
getBlockAttributes : ExpressionBlock -> RenderSettings -> List (Element.Attribute msg)
getBlockAttributes block settings =
    let
        blockName =
            Generic.BlockUtilities.getExpressionBlockName block
                |> Maybe.withDefault ""

        blockType =
            BlockType.fromString blockName

        standardAttrs =
            [ Render.Utility.idAttributeFromInt block.meta.lineNumber
            ]
    in
    standardAttrs ++ getTypeSpecificAttributes blockType


{-| Version that returns MarkupMsg-specific attributes, including sync attributes
-}
getBlockMarkupAttributes : ExpressionBlock -> RenderSettings -> List (Element.Attribute MarkupMsg)
getBlockMarkupAttributes block settings =
    let
        blockName =
            Generic.BlockUtilities.getExpressionBlockName block
                |> Maybe.withDefault ""

        blockType =
            BlockType.fromString blockName

        standardAttrs =
            [ Render.Utility.idAttributeFromInt block.meta.lineNumber
            , Render.Sync.rightToLeftSyncHelper block.meta.lineNumber block.meta.numberOfLines
            ]
                ++ Render.Sync.highlightIfIdIsSelected block.meta.lineNumber block.meta.numberOfLines settings
    in
    standardAttrs ++ getTypeSpecificMarkupAttributes blockType


{-| Get attributes specific to a block type (generic version)
-}
getTypeSpecificAttributes : BlockType -> List (Element.Attribute msg)
getTypeSpecificAttributes blockType =
    case blockType of
        TextBlock textType ->
            case textType of
                BlockType.Indent ->
                    getIndentAttributes

                BlockType.Quotation ->
                    getQuotationAttributes

                BlockType.Red ->
                    [ Font.color (Element.rgb 0.8 0 0) ]

                BlockType.Red2 ->
                    [ Font.color (Element.rgb 0.8 0 0) ]

                BlockType.Blue ->
                    [ Font.color (Element.rgb 0 0 0.8) ]

                _ ->
                    []

        ContainerBlock containerType ->
            case containerType of
                BlockType.Box ->
                    getBoxAttributes

                _ ->
                    []

        _ ->
            if List.member (BlockType.toString blockType) italicBlockNames then
                getItalicAttributes
            else
                []


{-| Get attributes specific to a block type (MarkupMsg-specific version)
-}
getTypeSpecificMarkupAttributes : BlockType -> List (Element.Attribute MarkupMsg)
getTypeSpecificMarkupAttributes blockType =
    case blockType of
        TextBlock textType ->
            case textType of
                BlockType.Indent ->
                    getIndentAttributes

                BlockType.Quotation ->
                    getQuotationAttributes

                BlockType.Red ->
                    [ Font.color (Element.rgb 0.8 0 0) ]

                BlockType.Red2 ->
                    [ Font.color (Element.rgb 0.8 0 0) ]

                BlockType.Blue ->
                    [ Font.color (Element.rgb 0 0 0.8) ]

                _ ->
                    []

        ContainerBlock containerType ->
            case containerType of
                BlockType.Box ->
                    getBoxAttributes

                _ ->
                    []

        _ ->
            if List.member (BlockType.toString blockType) italicBlockNames then
                getItalicAttributes
            else
                []


{-| Get attributes for blocks that should be italicized
-}
getItalicAttributes : List (Element.Attribute msg)
getItalicAttributes =
    [ Font.italic ]


{-| Get attributes for box blocks
-}
getBoxAttributes : List (Element.Attribute msg)
getBoxAttributes =
    [ Element.spacing 11
    , Font.italic
    , Element.paddingXY 12 12
    , Background.color (Element.rgb 0.95 0.93 0.93)
    ]


{-| Get attributes for container blocks
-}
getContainerAttributes : List (Element.Attribute msg)
getContainerAttributes =
    [ Element.spacing 8 ]


{-| Get attributes for document blocks
-}
getDocumentAttributes : List (Element.Attribute msg)
getDocumentAttributes =
    []


{-| Get attributes for indented blocks
-}
getIndentAttributes : List (Element.Attribute msg)
getIndentAttributes =
    [ Element.spacing 11
    , Element.paddingEach { left = 12, right = 0, top = 0, bottom = 0 }
    ]


{-| Get attributes for quotation blocks
-}
getQuotationAttributes : List (Element.Attribute msg)
getQuotationAttributes =
    [ Font.italic
    , Element.paddingEach { left = 12, right = 0, top = 0, bottom = 0 }
    ]


{-| List of block names that should be rendered in italics
-}
italicBlockNames : List String
italicBlockNames =
    [ "quote"
    , "aside"
    , "note"
    , "warning"
    , "exercise"
    , "problem"
    , "theorem"
    , "proof"
    , "definition"
    , "principle"
    , "construction"
    , "axiom"
    , "lemma"
    , "corollary"
    , "proposition"
    , "example"
    , "remark"
    , "question"
    , "answer"
    ]