module Render.Blocks.Container exposing
    ( registerRenderers
    , box, comment, collection, bibitem, env, env_
    )

{-| This module provides renderers for container blocks.

@docs registerRenderers
@docs box, comment, collection, bibitem, env, env_

-}

import Dict exposing (Dict)
import Either exposing (Either(..))
import Element exposing (Element)
import Element.Font as Font
import Generic.Acc exposing (Accumulator)
import Generic.Language exposing (ExpressionBlock)
import List.Extra
import Render.BlockRegistry exposing (BlockRegistry)
import Render.Color as Color
import Render.Expression
import Render.Helper
import Render.Settings exposing (RenderSettings)
import Render.Sync
import Render.Sync2
import Render.Utility exposing (elementAttribute)
import ScriptaV2.Msg exposing (MarkupMsg(..))
import String.Extra


{-| Register all container block renderers to the registry
-}
registerRenderers : BlockRegistry -> BlockRegistry
registerRenderers registry =
    Render.BlockRegistry.registerBatch
        [ ( "box", box )
        , ( "comment", comment )
        , ( "collection", collection )
        , ( "bibitem", bibitem )
        , ( "env", env_ )
        ]
        registry


{-| Render a box block
-}
box : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
box count acc settings attr block =
    Element.column [ Element.spacing 8 ]
        [ Element.row [ Font.bold ] [ Element.text (blockHeading block), Element.el [] (Element.text (String.join " " block.args)) ]
        , Element.paragraph
            []
            (Render.Helper.renderWithDefault "" count acc settings attr (Generic.Language.getExpressionContent block))
        ]


{-| Render a comment block
-}
comment : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
comment count acc settings attrs block =
    let
        author_ =
            String.join " " block.args

        author =
            if author_ == "" then
                ""

            else
                author_ ++ ":"
    in
    Element.column ([ Element.spacing 6 ] |> Render.Sync2.sync block settings)
        [ Element.el [ Font.bold, Font.color Color.blue ] (Element.text author)
        , Element.paragraph ([ Font.italic, Font.color Color.blue, Render.Sync.rightToLeftSyncHelper block.meta.lineNumber block.meta.numberOfLines, Render.Utility.idAttributeFromInt block.meta.lineNumber ] ++ Render.Sync.highlightIfIdIsSelected block.meta.lineNumber block.meta.numberOfLines settings)
            (Render.Helper.renderWithDefault "| comment" count acc settings attrs (Generic.Language.getExpressionContent block))
        ]


{-| Render a collection block (currently returns Element.none)
-}
collection : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
collection _ _ _ _ _ =
    Element.none


{-| Render a bibitem block
-}
bibitem : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
bibitem count acc settings attrs block =
    let
        label =
            List.Extra.getAt 0 block.args |> Maybe.withDefault "(12)" |> (\s -> "[" ++ s ++ "]")
    in
    Element.row ([ Element.alignTop, Render.Utility.idAttributeFromInt block.meta.lineNumber, Render.Utility.vspace 0 settings.topMarginForChildren ] ++ Render.Sync.highlightIfIdIsSelected block.meta.lineNumber block.meta.numberOfLines settings)
        [ Element.el
            [ Font.size 14
            , Element.alignTop
            , Font.bold
            , Element.width (Element.px 34)
            ]
            (Element.text label)
        , Element.paragraph []
            (Render.Helper.renderWithDefault "bibitem" count acc settings attrs (Generic.Language.getExpressionContent block))
        ]


{-| Entry point for environment blocks
-}
env_ : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
env_ count acc settings attr block =
    case List.head block.args of
        Nothing ->
            --Element.paragraph
            --    [ Render.Utility.idAttributeFromInt block.meta.lineNumber
            --    , Font.color settings.redColor
            --    , Render.Sync.rightToLeftSyncHelper block.meta.lineNumber block.meta.numberOfLines
            --    ]
            --    [ Element.text "| env (missing name!!!)" ]
            env count acc settings attr block

        Just _ ->
            env count acc settings attr block


{-| Render an environment block
-}
env : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
env count acc settings attr block =
    case block.body of
        Left _ ->
            Element.none

        Right exprs ->
            Element.column ([ Element.spacing 8, Render.Utility.idAttributeFromInt block.meta.lineNumber ] ++ Render.Sync.highlightIfIdIsSelected block.meta.lineNumber block.meta.numberOfLines settings)
                [ Element.row
                    ([ Render.Sync.rightToLeftSyncHelper block.meta.lineNumber block.meta.numberOfLines
                     ]
                        |> Render.Sync.highlightIfIdSelected block.meta.id settings
                    )
                    [ Element.el [ Font.bold ] (Element.text (blockHeading block))
                    , Element.el [] (Element.text (String.join " " block.args))
                    ]
                , Element.paragraph
                    ([ Font.italic
                     , Render.Helper.htmlId block.meta.id
                     , Render.Sync.rightToLeftSyncHelper block.meta.lineNumber block.meta.numberOfLines
                     ]
                        |> Render.Sync.highlightIfIdSelected block.meta.id
                            settings
                    )
                    (renderWithDefault2 ("??" ++ (Generic.Language.getNameFromHeading block.heading |> Maybe.withDefault "(name)")) count acc settings attr exprs)
                ]


{-| Helper for rendering default content
-}
renderWithDefault2 _ count acc settings attr exprs =
    List.map (Render.Expression.render count acc settings attr) exprs


{-| Extract block heading for display
-}
blockHeading : ExpressionBlock -> String
blockHeading block =
    case Generic.Language.getNameFromHeading block.heading of
        Nothing ->
            ""

        Just name ->
            if List.member name [ "banner_", "banner" ] then
                ""

            else
                (name |> String.Extra.toTitleCase)
                    ++ " "
                    ++ (Dict.get "label" block.properties |> Maybe.withDefault "")
                    ++ ". "
