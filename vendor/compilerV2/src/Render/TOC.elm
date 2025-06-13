module Render.TOC exposing (view, viewWithTitle)

-- import Render.Block

import Dict exposing (Dict)
import Either exposing (Either(..))
import Element exposing (Element)
import Element.Events as Events
import Element.Font as Font
import Generic.ASTTools
import Generic.Acc exposing (Accumulator)
import Generic.Forest exposing (Forest)
import Generic.Language exposing (ExprMeta, Expression, ExpressionBlock)
import Library.Tree
import List.Extra
import Render.Expression
import Render.Settings
import Render.TOCTree
import Render.Utility
import ScriptaV2.Config as Config
import ScriptaV2.Msg exposing (MarkupMsg(..))


viewWithTitle : Int -> Accumulator -> List (Element.Attribute MarkupMsg) -> Forest ExpressionBlock -> List (Element ScriptaV2.Msg.MarkupMsg)
viewWithTitle counter acc attr ast =
    let
        maximumLevel =
            case Dict.get "contentsdepth" acc.keyValueDict of
                Just level ->
                    String.toInt level |> Maybe.withDefault 3

                Nothing ->
                    3
    in
    prepareTOCWithTitle maximumLevel counter acc Render.Settings.defaultSettings attr ast


view : Render.TOCTree.ViewParameters -> Accumulator -> Forest ExpressionBlock -> List (Element ScriptaV2.Msg.MarkupMsg)
view viewParameters acc ast =
    let
        maximumLevel =
            case Dict.get "contentsdepth" acc.keyValueDict of
                Just level ->
                    String.toInt level |> Maybe.withDefault 3

                Nothing ->
                    3

        defaultSettings =
            Render.Settings.defaultSettings
    in
    --prepareTOC maximumLevel counter acc { defaultSettings | selectedId = selectedId } attr ast
    Render.TOCTree.view viewParameters acc ast



-- NEW TOC CODE
-- Need function
-- List ExpressionBlock ->  RoseTree.Tree ExpressionBlock
-- where the depth in the tree is determined by the level


viewTocItem : String -> Int -> Accumulator -> Render.Settings.RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
viewTocItem selectedId count acc settings attr ({ args, body, properties } as block) =
    let
        maximumNumberedTocLevel =
            3
    in
    case body of
        Left _ ->
            Element.none

        Right exprs ->
            let
                id =
                    Config.expressionIdPrefix ++ String.fromInt block.meta.lineNumber ++ ".0"

                sectionNumber =
                    case List.Extra.getAt 1 args of
                        Just "-" ->
                            Element.none

                        _ ->
                            case tocLevel block of
                                Just level ->
                                    if level <= maximumNumberedTocLevel then
                                        Element.el [] (Element.text (blockLabel properties ++ ". "))

                                    else
                                        Element.none

                                Nothing ->
                                    Element.none

                label : Element MarkupMsg
                label =
                    Element.paragraph [ tocIndent args ] (sectionNumber :: List.map (Render.Expression.render count acc settings attr) exprs)

                color =
                    if id == selectedId then
                        Element.rgb 0.8 0 0.0

                    else
                        Element.rgb 0 0 0.8
            in
            Element.el [ Events.onClick (SelectId id) ]
                (Element.link [ Font.color color ] { url = Render.Utility.internalLink id, label = label })


blockLabel : Dict String String -> String
blockLabel properties =
    Dict.get "label" properties |> Maybe.withDefault "??"


tocLevelAtMost : Int -> ExpressionBlock -> Bool
tocLevelAtMost k { args } =
    case List.Extra.getAt 0 args of
        Nothing ->
            True

        Just level ->
            (String.toInt level |> Maybe.withDefault 4) <= k


tocLevel : ExpressionBlock -> Maybe Int
tocLevel { args } =
    List.Extra.getAt 0 args |> Maybe.andThen String.toInt


prepareTOCWithTitle : Int -> Int -> Accumulator -> Render.Settings.RenderSettings -> List (Element.Attribute MarkupMsg) -> Forest ExpressionBlock -> List (Element MarkupMsg)
prepareTOCWithTitle maximumLevel count acc settings attr ast =
    let
        rawToc : List ExpressionBlock
        rawToc =
            Generic.ASTTools.tableOfContents maximumLevel ast
                |> List.filter (tocLevelAtMost maximumLevel)

        headings =
            getHeadings ast

        title : List (Element MarkupMsg)
        title =
            headings.title
                |> List.map (Render.Expression.render count acc settings attr)

        topItem =
            let
                id =
                    "title"
            in
            Element.el [ Events.onClick (SelectId id), Font.size 18 ]
                (Element.link [ Font.color (Element.rgb 0 0 0.8) ]
                    { url = Render.Utility.internalLink id, label = Element.paragraph [] title }
                )

        toc =
            topItem
                :: (rawToc |> List.map (viewTocItem settings.selectedId count acc settings attr))
    in
    toc


prepareTOC : Int -> Int -> Accumulator -> Render.Settings.RenderSettings -> List (Element.Attribute MarkupMsg) -> Forest ExpressionBlock -> List (Element MarkupMsg)
prepareTOC maximumLevel count acc settings attr ast =
    let
        fixIdInExpressionBlock : ExpressionBlock -> ExpressionBlock
        fixIdInExpressionBlock block =
            let
                meta =
                    block.meta

                newMeta =
                    { meta | id = "xy" ++ meta.id }
            in
            { block | meta = newMeta }

        rawToc : List ExpressionBlock
        rawToc =
            Generic.ASTTools.tableOfContents maximumLevel ast
                |> List.filter (tocLevelAtMost maximumLevel)
                -- The "xy" line below is needed because we also have the possibility of
                -- the TOC in the sidebar. We do not want click on a TOC item in the sidebar
                -- targeting the TOC item in the main text.
                |> List.map (Generic.Language.updateMetaInBlock (\m -> { m | id = "xy" ++ m.id }))

        toc =
            rawToc |> List.map (viewTocItem settings.selectedId count acc settings attr)
    in
    toc


tocIndent args =
    Element.paddingEach { left = tocIndentAux args, right = 0, top = 0, bottom = 0 }


tocIndentAux args =
    case List.head args of
        Nothing ->
            0

        Just str ->
            String.toInt str |> Maybe.withDefault 0 |> (\x -> 12 * (x - 1))


getHeadings : Forest ExpressionBlock -> { title : List Expression, subtitle : List Expression }
getHeadings ast =
    let
        flattened =
            List.map Library.Tree.flatten ast |> List.concat

        title : List Expression
        title =
            flattened
                |> Generic.ASTTools.filterBlocksOnName "title"
                |> List.map getContent
                |> List.concat

        --data
        --    |> List.filter (\item -> item.blockType == OrdinaryBlock [ "title" ])
        --    |> List.head
        --    |> Maybe.map .content
        subtitle : List Expression
        subtitle =
            flattened
                |> Generic.ASTTools.filterBlocksOnName "subtitle"
                |> List.map getContent
                |> List.concat
    in
    { title = title, subtitle = subtitle }


getContent : ExpressionBlock -> List Expression
getContent { body } =
    case body of
        Either.Left _ ->
            []

        Either.Right exprs ->
            exprs
