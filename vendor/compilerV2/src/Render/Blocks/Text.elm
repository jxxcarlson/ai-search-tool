module Render.Blocks.Text exposing
    ( registerRenderers
    , centered
    , indented
    , compact
    , identity
    , red
    , red2
    , blue
    , quotation
    )

{-| This module provides renderers for text-related blocks.

@docs registerRenderers
@docs centered, indented, compact, identity, red, red2, blue, quotation

-}

import Element exposing (Element)
import Element.Font as Font
import Generic.Acc exposing (Accumulator)
import Generic.Language exposing (ExpressionBlock)
import Render.Attributes exposing (getIndentAttributes)
import Render.BlockRegistry exposing (BlockRegistry)
import Render.Helper
import Render.Settings exposing (RenderSettings)
import Render.Sync
import Render.Sync2
import Render.Utility exposing (elementAttribute)
import ScriptaV2.Msg exposing (MarkupMsg(..))


{-| Register all text block renderers to the registry
-}
registerRenderers : BlockRegistry -> BlockRegistry
registerRenderers registry =
    Render.BlockRegistry.registerBatch
        [ ( "indent", indented )
        , ( "center", centered )
        , ( "compact", compact )
        , ( "identity", identity )
        , ( "red", red )
        , ( "red2", red2 )
        , ( "blue", blue )
        , ( "quotation", quotation )
        ]
        registry


{-| Render a centered block
-}
centered : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
centered count acc settings attr block =
    Element.el
        ((Element.width (Element.px settings.width) :: attr) |> Render.Sync2.sync block settings)
        (Element.paragraph [ Element.centerX, Element.width (Element.px (settings.width - 100)) ]
            (Render.Helper.renderWithDefault "centered" count acc settings attr (Generic.Language.getExpressionContent block))
        )


{-| Render an indented block
-}
indented : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
indented count acc settings attr block =
    Element.el
        ([ Element.width (Element.px settings.width) ] |> Render.Sync2.sync block settings)
        (Element.paragraph [ Element.paddingEach { left = 12, right = 0, top = 0, bottom = 0 } ]
            (Render.Helper.renderWithDefault "indent" count acc settings attr (Generic.Language.getExpressionContent block))
        )


{-| Render a compact block
-}
compact : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
compact count acc settings attr block =
    Element.el
        ((Element.width (Element.px settings.width) :: attr) |> Render.Sync2.sync block settings)
        (Element.column [ Element.spacing 0, Element.width (Element.px (settings.width - 0)) ]
            (Render.Helper.renderWithDefaultNarrow "compact" count acc settings attr (Generic.Language.getExpressionContent block))
        )


{-| Render an identity block (passes content through with minimal formatting)
-}
identity : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
identity count acc settings attr block =
    Element.el
        ((Element.width (Element.px settings.width) :: attr) |> Render.Sync2.sync block settings)
        (Element.column [ Element.spacing 0, Element.width (Element.px (settings.width - 0)) ]
            (Render.Helper.renderWithDefault "identity" count acc settings attr (Generic.Language.getExpressionContent block))
        )


{-| Render a red text block
-}
red : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
red count acc settings attr block =
    Element.el
        ((Element.width (Element.px settings.width) :: attr) |> Render.Sync2.sync block settings)
        (Element.column
            [ Element.width (Element.px (settings.width - 0))
            , Font.color (Element.rgb 0.8 0 0)
            ]
            (Render.Helper.renderWithDefaultNarrow "red" count acc settings attr (Generic.Language.getExpressionContent block))
        )


{-| Render a red2 text block (alternative red styling)
-}
red2 : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
red2 count acc settings attr block =
    Element.el
        ([ Element.width (Element.px settings.width) ] |> Render.Sync2.sync block settings)
        (Element.column
            [ Element.paddingEach { left = 12, right = 0, top = 0, bottom = 0 }
            , Font.color (Element.rgb 0.8 0 0)
            ]
            (Render.Helper.renderWithDefault "red2" count acc settings attr (Generic.Language.getExpressionContent block))
        )


{-| Render a blue text block
-}
blue : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
blue count acc settings attr block =
    Element.el
        ((Element.width (Element.px settings.width) :: attr) |> Render.Sync2.sync block settings)
        (Element.column
            [ Element.width (Element.px (settings.width - 0))
            , Font.color (Element.rgb 0 0 0.8)
            ]
            (Render.Helper.renderWithDefaultNarrow "blue" count acc settings attr (Generic.Language.getExpressionContent block))
        )


{-| Render a quotation block
-}
quotation : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
quotation count acc settings attrs block =
    Element.column ([ Element.spacing 8 ] |> Render.Sync2.sync block settings)
        [ Render.Helper.noteFromPropertyKey "title" [ Font.bold ] block
        , Element.paragraph
            (Render.Helper.blockAttributes settings block [])
            (Render.Helper.renderWithDefault "quotation" count acc settings attrs (Generic.Language.getExpressionContent block))
        , Render.Helper.noteFromPropertyKey "source" [] block
        ]