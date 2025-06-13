module Render.Export.Check exposing (nonExportableBlocks, nonExportableExpressions)

{-| This module contains functions for checking whether a given forest of

@docs nonExportableBlocks, nonExportableExpressions

-}

import Generic.ASTTools
import Generic.Language
import Render.Expression
import Render.Helper
import RoseTree.Tree as Tree exposing (Tree)


{-| -}
nonExportableBlocks : List (Tree.Tree Generic.Language.ExpressionBlock) -> List String
nonExportableBlocks forest =
    forest |> Generic.ASTTools.blockNames |> List.filter (\block -> List.member block nonExportableBlockNameList)


{-| -}
nonExportableExpressions : List (Tree.Tree Generic.Language.ExpressionBlock) -> List String
nonExportableExpressions forest =
    forest |> Generic.ASTTools.expressionNames |> List.filter (\expr -> List.member expr Render.Expression.nonstandardElements)


nonExportableBlockNameList =
    Render.Helper.nonExportableVerbatimBlocks ++ Render.Helper.nonExportableOrdinaryBlocks
