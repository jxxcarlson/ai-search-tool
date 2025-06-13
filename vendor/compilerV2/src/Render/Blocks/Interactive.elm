module Render.Blocks.Interactive exposing
    ( registerRenderers
    , question
    , answer
    , reveal
    )

{-| This module provides renderers for interactive blocks (questions, answers, etc.)

@docs registerRenderers
@docs question, answer, reveal

-}

import Dict exposing (Dict)
import Element exposing (Element)
import Element.Background as Background
import Element.Events as Events
import Element.Font as Font
import Generic.Acc exposing (Accumulator)
import Generic.Language exposing (ExpressionBlock)
import Render.BlockRegistry exposing (BlockRegistry)
import Render.Color as Color
import Render.Helper
import Render.Settings exposing (RenderSettings)
import Render.Sync
import Render.Sync2
import Render.Utility exposing (elementAttribute)
import ScriptaV2.Msg exposing (MarkupMsg(..))


{-| Register all interactive block renderers to the registry
-}
registerRenderers : BlockRegistry -> BlockRegistry
registerRenderers registry =
    Render.BlockRegistry.registerBatch
        [ ( "q", question )
        , ( "a", answer )
        , ( "reveal", reveal )
        ]
        registry


{-| Render a question block
-}
question : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
question count acc settings attrs block =
    let
        title_ =
            String.join " " block.args

        label =
            " " ++ Render.Helper.getLabel block.properties

        qId =
            Dict.get block.meta.id acc.qAndADict |> Maybe.withDefault block.meta.id
    in
    Element.column ([ Element.spacing 12 ] |> Render.Sync2.sync block settings)
        -- TODO: clean up?
        [ Element.el [ Font.bold, Font.color Color.blue, Events.onClick (HighlightId qId) ] (Element.text (title_ ++ " " ++ label))
        , Element.paragraph ([ Font.italic, Events.onClick (HighlightId qId), Render.Utility.idAttributeFromInt block.meta.lineNumber ] ++ Render.Sync.highlightIfIdIsSelected block.meta.lineNumber block.meta.numberOfLines settings)
            (Render.Helper.renderWithDefault "..." count acc settings attrs (Generic.Language.getExpressionContent block))
        ]


{-| Render an answer block
-}
answer : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
answer count acc settings attrs block =
    let
        title_ =
            String.join " " (List.drop 1 block.args)

        clicker =
            if settings.selectedId == block.meta.id then
                Events.onClick (ProposeSolution ScriptaV2.Msg.Unsolved)

            else
                Events.onClick (ProposeSolution (ScriptaV2.Msg.Solved block.meta.id))
    in
    Element.column ([ Element.spacing 12, Element.paddingEach { top = 0, bottom = 24, left = 0, right = 0 } ] |> Render.Sync2.sync block settings)
        [ Element.el [ Font.bold, Font.color Color.blue, clicker ] (Element.text title_)
        , if settings.selectedId == block.meta.id then
            -- TODO: clean up?
            Element.el [ Events.onClick (ProposeSolution ScriptaV2.Msg.Unsolved) ]
                (Element.paragraph ([ Font.italic, Render.Utility.idAttributeFromInt block.meta.lineNumber, Element.paddingXY 8 8 ] ++ Render.Sync.highlightIfIdIsSelected block.meta.lineNumber block.meta.numberOfLines settings)
                    (Render.Helper.renderWithDefault "..." count acc settings attrs (Generic.Language.getExpressionContent block))
                )

          else
            Element.none
        ]


{-| Render a reveal block
-}
reveal : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
reveal count acc settings attrs block =
    let
        preTitle =
            String.join " " block.args

        title_ =
            if preTitle == "more" then
                if settings.selectedId /= block.meta.id then
                    "(More ...)"

                else
                    "(Less ...)"

            else
                preTitle ++ " ..."

        label =
            " " ++ Render.Helper.getLabel block.properties

        clicker =
            if settings.selectedId == block.meta.id then
                Events.onClick (ProposeSolution ScriptaV2.Msg.Unsolved)

            else
                Events.onClick (ProposeSolution (ScriptaV2.Msg.Solved block.meta.id))
    in
    Element.column [ Element.spacing 6 ]
        [ Element.el
            [ Font.italic
            , Font.color Color.blue
            , clicker
            ]
            (Element.text (title_ ++ " " ++ label))
        , if settings.selectedId == block.meta.id then
            Element.el []
                (Element.paragraph
                    ([ Background.color (Element.rgb 0.95 0.95 1.0)
                     , Element.paddingXY 18 8
                     ]
                        |> Render.Sync2.sync block settings
                    )
                    (Render.Helper.renderWithDefault "..." count acc settings attrs (Generic.Language.getExpressionContent block))
                )

          else
            Element.none
        ]