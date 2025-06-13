module Generic.BlockUtilities exposing
    ( argsAndProperties
    , condenseUrls
    , dropLast
    , getExpressionBlockName
    , getLineNumber
    , getMessages
    , getPrimitiveBlockName
    , setLineNumber
    , updateMeta
    )

import Dict exposing (Dict)
import Either
import Generic.Language exposing (BlockMeta, Expr(..), Expression, ExpressionBlock, Heading(..), PrimitiveBlock)
import Tools.KV as KV


condenseUrls : ExpressionBlock -> ExpressionBlock
condenseUrls block =
    case block.body of
        Either.Left _ ->
            block

        Either.Right exprList ->
            { block | body = Either.Right (List.map condenseUrl exprList) }


{-| Use to transform image urls for export and PDF generation
-}
condenseUrl : Expression -> Expression
condenseUrl expr =
    case expr of
        Fun "image" ((Text url meta1) :: rest) meta2 ->
            Fun "image" (Text (smashUrl url) meta1 :: rest) meta2

        _ ->
            expr


smashUrl url =
    url |> String.replace "https://" "" |> String.replace "http://" ""


getMessages : ExpressionBlock -> List String
getMessages b =
    b.meta.messages


getLineNumber : { a | meta : BlockMeta } -> Int
getLineNumber b =
    b.meta.lineNumber


setLineNumber : Int -> { a | meta : BlockMeta } -> { a | meta : BlockMeta }
setLineNumber k b =
    updateMeta (\m -> { m | lineNumber = k }) b


updateMeta : (BlockMeta -> BlockMeta) -> { a | meta : BlockMeta } -> { a | meta : BlockMeta }
updateMeta transformMeta block =
    let
        oldMeta =
            block.meta

        newMeta =
            transformMeta oldMeta
    in
    { block | meta = newMeta }


argsAndProperties : List String -> ( List String, Dict String String )
argsAndProperties words =
    let
        args =
            KV.cleanArgs words

        namedArgs =
            List.drop (List.length args) words

        properties =
            namedArgs |> KV.prepareList |> KV.prepareKVData
    in
    ( words, properties )


getPrimitiveBlockName : PrimitiveBlock -> Maybe String
getPrimitiveBlockName block =
    case block.heading of
        Paragraph ->
            Nothing

        Ordinary name ->
            Just name

        Verbatim name ->
            Just name


getExpressionBlockName : ExpressionBlock -> Maybe String
getExpressionBlockName block =
    case block.heading of
        Paragraph ->
            Nothing

        Ordinary name ->
            Just name

        Verbatim name ->
            Just name


dropLast : List a -> List a
dropLast list =
    let
        n =
            List.length list
    in
    List.take (n - 1) list
