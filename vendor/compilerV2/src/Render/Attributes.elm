module Render.Attributes exposing
    ( getBlockAttributes
    , getItalicAttributes
    , getBoxAttributes
    , getContainerAttributes
    , getDocumentAttributes
    , getIndentAttributes
    , getQuotationAttributes
    , italicBlockNames
    )

{-| This module consolidates attribute handling for various block types.

Instead of having attribute logic scattered across multiple files, this module
provides a unified approach to determining the attributes for any given block.

@docs getBlockAttributes, getItalicAttributes, getBoxAttributes, getContainerAttributes, getDocumentAttributes, getIndentAttributes, getQuotationAttributes
@docs italicBlockNames

-}

import Element exposing (Element)
import Element.Background as Background
import Element.Font as Font
import Generic.BlockUtilities
import Generic.Language exposing (ExpressionBlock)
import Render.BlockType as BlockType exposing (BlockType(..))
import Render.Color
import Render.Helper
import Render.Indentation
import Render.Settings exposing (RenderSettings)
import Render.Sync
import ScriptaV2.Msg exposing (MarkupMsg)
import Render.Utility


{-| Main function to get attributes for a block based on its type
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


{-| Get attributes specific to a block type
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
                    [ Font.color Render.Color.redText ]

                BlockType.Red2 ->
                    [ Font.color Render.Color.redText ]

                BlockType.Blue ->
                    [ Font.color Render.Color.blue ]

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
    [ Element.spacing standardSpacing
    , Font.italic
    , Element.paddingXY standardLeftPadding standardLeftPadding
    , Background.color Render.Color.boxBackground
    ]


{-| Get attributes for container blocks
-}
getContainerAttributes : List (Element.Attribute msg)
getContainerAttributes =
    [ Element.spacing standardSpacing ]


{-| Get attributes for document blocks
-}
getDocumentAttributes : List (Element.Attribute msg)
getDocumentAttributes =
    []


{-| Standard spacing value for consistent spacing
-}
standardSpacing : Int
standardSpacing = 
    11


{-| Standard left padding for indented content
-}
standardLeftPadding : Int
standardLeftPadding =
    12


{-| Get attributes for indented blocks
-}
getIndentAttributes : List (Element.Attribute msg)
getIndentAttributes =
    [ Element.spacing standardSpacing
    , Element.paddingEach { left = standardLeftPadding, right = 0, top = 0, bottom = 0 }
    ]


{-| Get attributes for quotation blocks
-}
getQuotationAttributes : List (Element.Attribute msg)
getQuotationAttributes =
    [ Font.italic
    , Element.paddingEach { left = standardLeftPadding, right = 0, top = 0, bottom = 0 }
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