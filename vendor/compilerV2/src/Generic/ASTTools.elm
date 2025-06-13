module Generic.ASTTools exposing
    ( banner
    , blockNameInList
    , blockNames
    , changeName
    , existsBlockWithName
    , exprListToStringList
    , expressionNames
    , extractTextFromSyntaxTreeByKey
    , filterBlocks
    , filterBlocksByArgs
    , filterBlocksOnName
    , filterExpressionsOnName
    , filterExpressionsOnName_
    , filterExprs
    , filterForestOnLabelNames
    , filterNotBlocksOnName
    , filterOutExpressionsOnName
    , frontMatterDict
    , getBlockArgsByName
    , getText
    , getValue
    , getVerbatimBlockValue
    , isBlank
    , matchingIdsInAST
    , normalize
    , rawBlockNames
    , stringValueOfList
    , tableOfContents
    , title
    , titleTOC
    , toExprRecord
    )

import Bool.Extra
import Dict exposing (Dict)
import Either exposing (Either(..))
import Generic.Forest exposing (Forest)
import Generic.Language exposing (Expr(..), Expression, ExpressionBlock, Heading(..))
import Library.Tree
import List.Extra
import Maybe.Extra
import RoseTree.Tree as Tree exposing (Tree)


normalize : Either String (List Expression) -> Either String (List Expression)
normalize exprs =
    case exprs of
        Right ((Text _ _) :: rest) ->
            Right rest

        _ ->
            exprs


blockNames : List (Tree.Tree ExpressionBlock) -> List String
blockNames forest =
    forest
        |> rawBlockNames
        |> List.Extra.unique
        |> List.sort


rawBlockNames : List (Tree.Tree ExpressionBlock) -> List String
rawBlockNames forest =
    List.map Library.Tree.flatten forest
        |> List.concat
        |> List.map Generic.Language.getName
        |> Maybe.Extra.values


expressionNames : List (Tree.Tree ExpressionBlock) -> List String
expressionNames forest =
    List.map Library.Tree.flatten forest
        |> List.concat
        |> List.map Generic.Language.getExpressionContent
        |> List.concat
        |> List.map Generic.Language.getFunctionName
        |> Maybe.Extra.values
        |> List.Extra.unique
        |> List.sort


filterExpressionsOnName : String -> List Expression -> List Expression
filterExpressionsOnName name exprs =
    List.filter (matchExprOnName name) exprs


filterOutExpressionsOnName : String -> List Expression -> List Expression
filterOutExpressionsOnName name exprs =
    List.filter (\expr -> not (matchExprOnName name expr)) exprs


filterExpressionsOnName_ : String -> List Expression -> List Expression
filterExpressionsOnName_ name exprs =
    List.filter (matchExprOnName_ name) exprs


filterExprs : (Expression -> Bool) -> List Expression -> List Expression
filterExprs predicate list =
    List.filter (\item -> predicate item) list


isBlank : Expression -> Bool
isBlank expr =
    case expr of
        Text content _ ->
            if String.trim content == "" then
                True

            else
                False

        _ ->
            False


filterBlocksOnName : String -> List ExpressionBlock -> List ExpressionBlock
filterBlocksOnName name blocks =
    List.filter (matchBlockName name) blocks


filterNotBlocksOnName : String -> List ExpressionBlock -> List ExpressionBlock
filterNotBlocksOnName name blocks =
    List.filter (matchBlockName name >> not) blocks



--filterForestOnBlockNames : String -> Forest ExpressionBlock -> Forest ExpressionBlock
--filterForestOnBlockNames name forest =
--    List.filter (\tree -> predicate (labelName tree)) forest


blockNameInList : ExpressionBlock -> List String -> Bool
blockNameInList block names =
    Bool.Extra.any (List.map (\name -> matchBlockName name block) names)


filterBlocks : (ExpressionBlock -> Bool) -> List ExpressionBlock -> List ExpressionBlock
filterBlocks predicate blocks =
    List.filter predicate blocks


filterForestOnLabelNames : (Maybe String -> Bool) -> Forest ExpressionBlock -> Forest ExpressionBlock
filterForestOnLabelNames predicate forest =
    List.filter (\tree -> predicate (labelName tree)) forest


labelName : Tree ExpressionBlock -> Maybe String
labelName tree =
    Tree.value tree |> Generic.Language.getName


matchBlockName : String -> ExpressionBlock -> Bool
matchBlockName key block =
    Just key == Generic.Language.getName block


matchExprOnName : String -> Expression -> Bool
matchExprOnName name expr =
    Just name == Generic.Language.getFunctionName expr


matchExprOnName_ : String -> Expression -> Bool
matchExprOnName_ name expr =
    case Generic.Language.getFunctionName expr of
        Nothing ->
            False

        Just name2 ->
            name == name2


matchingIdsInAST : String -> Forest ExpressionBlock -> List String
matchingIdsInAST key ast =
    ast |> List.map Library.Tree.flatten |> List.concat |> List.filterMap (idOfMatchingBlockContent key)


idOfMatchingBlockContent : String -> ExpressionBlock -> Maybe String
idOfMatchingBlockContent key block =
    if String.contains key block.meta.sourceText then
        Just block.meta.id

    else
        Nothing


titleTOC : Forest ExpressionBlock -> List ExpressionBlock
titleTOC ast =
    filterBlocksByArgs "title" ast


existsBlockWithName : List (Tree.Tree ExpressionBlock) -> String -> Bool
existsBlockWithName ast name =
    let
        mBlock =
            ast
                |> List.map Library.Tree.flatten
                |> List.concat
                |> filterBlocksOnName name
                |> List.head
    in
    case mBlock of
        Nothing ->
            False

        Just _ ->
            True


getBlockByName : String -> List (Tree.Tree ExpressionBlock) -> Maybe ExpressionBlock
getBlockByName name ast =
    ast
        |> List.map Library.Tree.flatten
        |> List.concat
        |> filterBlocksOnName name
        |> List.head


banner : List (Tree ExpressionBlock) -> Maybe ExpressionBlock
banner ast =
    ast |> getBlockByName "banner" |> Maybe.map (changeName "banner" "visibleBanner")


changeName : String -> String -> ExpressionBlock -> ExpressionBlock
changeName oldName newName block =
    if block.heading == Ordinary oldName then
        { block | heading = Ordinary newName }

    else
        block


frontMatterDict : List (Tree ExpressionBlock) -> Dict String String
frontMatterDict ast =
    keyValueDict (getVerbatimBlockValue "docinfo" ast |> String.split "\n" |> fixFrontMatterList)


keyValueDict : List String -> Dict String String
keyValueDict strings_ =
    List.map (String.split ":") strings_
        |> List.map (List.map String.trim)
        |> List.map pairFromList
        |> Maybe.Extra.values
        |> Dict.fromList


pairFromList : List String -> Maybe ( String, String )
pairFromList strings =
    case strings of
        [ x, y ] ->
            Just ( x, y )

        _ ->
            Nothing


fixFrontMatterList : List String -> List String
fixFrontMatterList strings =
    loop { count = 1, input = strings, output = [] } nextStepFix
        |> List.reverse
        |> handleEmptyDocInfo


handleEmptyDocInfo : List String -> List String
handleEmptyDocInfo strings =
    if strings == [ "(docinfo)" ] then
        [ "date:" ]

    else
        strings


type alias FixState =
    { count : Int, input : List String, output : List String }


nextStepFix : FixState -> Step FixState (List String)
nextStepFix state =
    case List.head state.input of
        Nothing ->
            Done state.output

        Just line ->
            if line == "" then
                Loop { state | input = List.drop 1 state.input }

            else if String.left 7 line == "author:" then
                Loop
                    { state
                        | input = List.drop 1 state.input
                        , output = String.replace "author:" ("author" ++ String.fromInt state.count ++ ":") line :: state.output
                        , count = state.count + 1
                    }

            else
                Loop { state | input = List.drop 1 state.input, output = line :: state.output }


type Step state a
    = Loop state
    | Done a


loop : state -> (state -> Step state a) -> a
loop s nextState_ =
    case nextState_ s of
        Loop s_ ->
            loop s_ nextState_

        Done b ->
            b


getVerbatimBlockValue : String -> List (Tree.Tree ExpressionBlock) -> String
getVerbatimBlockValue key ast =
    case getBlockByName key ast of
        Nothing ->
            "(" ++ key ++ ")"

        Just block ->
            case Generic.Language.getVerbatimContent block of
                Just str ->
                    str

                Nothing ->
                    "(" ++ key ++ ")"


getBlockArgsByName : String -> List (Tree.Tree ExpressionBlock) -> List String
getBlockArgsByName key ast =
    case getBlockByName key ast of
        Nothing ->
            []

        Just block ->
            block.args


getValue : String -> List (Tree.Tree ExpressionBlock) -> String
getValue key ast =
    case getBlockByName key ast of
        Nothing ->
            "(" ++ key ++ ")"

        Just block ->
            Generic.Language.getExpressionContent block
                |> List.map getText
                |> Maybe.Extra.values
                |> String.join ""


title : List (Tree ExpressionBlock) -> String
title ast =
    getValue "title" ast


extractTextFromSyntaxTreeByKey : String -> Forest ExpressionBlock -> String
extractTextFromSyntaxTreeByKey key syntaxTree =
    syntaxTree |> filterBlocksByArgs key |> expressionBlockToText


tableOfContents : Int -> List (Tree ExpressionBlock) -> List ExpressionBlock
tableOfContents maximumLevel ast =
    filterBlocksOnName "section" (List.map Library.Tree.flatten ast |> List.concat)


filterBlocksByArgs : String -> Forest ExpressionBlock -> List ExpressionBlock
filterBlocksByArgs key ast =
    ast
        |> List.map Library.Tree.flatten
        |> List.concat
        |> List.filter (matchBlock key)


matchBlock : String -> ExpressionBlock -> Bool
matchBlock key block =
    case block.heading of
        Paragraph ->
            False

        _ ->
            List.any (String.contains key) block.args


exprListToStringList : List Expression -> List String
exprListToStringList exprList =
    List.map getText exprList
        |> Maybe.Extra.values
        |> List.map String.trim
        |> List.filter (\s -> s /= "")


getText : Expression -> Maybe String
getText expression =
    case expression of
        Text str _ ->
            Just str

        VFun _ str _ ->
            Just (String.replace "`" "" str)

        Fun _ expressions _ ->
            List.map getText expressions |> Maybe.Extra.values |> String.join " " |> Just


stringValueOfList : List Expression -> String
stringValueOfList textList =
    String.join " " (List.map stringValue textList)


stringValue : Expression -> String
stringValue expr =
    case expr of
        Text str _ ->
            str

        Fun _ textList _ ->
            String.join " " (List.map stringValue textList)

        VFun _ str _ ->
            str


expressionBlockToText : List ExpressionBlock -> String
expressionBlockToText =
    toExprRecord >> List.map .content >> List.concat >> List.filterMap getText >> String.join " "


toExprRecord : List ExpressionBlock -> List { content : List Expression, heading : Heading }
toExprRecord blocks =
    List.map toExprList_ blocks


toExprList_ : ExpressionBlock -> { content : List Expression, heading : Heading }
toExprList_ block =
    { content = block.body |> Either.toList |> List.concat, heading = block.heading }
