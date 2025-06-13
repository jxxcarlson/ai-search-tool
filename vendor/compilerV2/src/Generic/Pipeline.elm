module Generic.Pipeline exposing (toExpressionBlock)

import Dict exposing (Dict)
import Either exposing (Either(..))
import Generic.Language exposing (Expr(..), Expression, ExpressionBlock, Heading(..), PrimitiveBlock)
import List.Extra
import M.Expression
import ScriptaV2.Language exposing (Language(..))
import Tools.Utility


toExpressionBlock : Language -> (Int -> String -> List Expression) -> PrimitiveBlock -> ExpressionBlock
toExpressionBlock lang parser block =
    toExpressionBlock_ lang (parser block.meta.lineNumber) block
        |> Generic.Language.boostBlock



---XXX---


toExpressionBlock_ : Language -> (String -> List Expression) -> PrimitiveBlock -> ExpressionBlock
toExpressionBlock_ lang parse block =
    { heading = block.heading
    , indent = block.indent
    , args = block.args
    , properties =
        block.properties |> Dict.insert "id" block.meta.id
    , firstLine = block.firstLine
    , body =
        case block.heading of
            Paragraph ->
                Right (String.join "\n" block.body |> parse)

            Ordinary _ ->
                Right (String.join "\n" block.body |> parse)

            Verbatim _ ->
                Left <| String.join "\n" block.body
    , meta = block.meta
    , style = block.style
    }


fixTableProperties : PrimitiveBlock -> Dict String String
fixTableProperties block =
    let
        cellsAsString : List (List String)
        cellsAsString =
            String.join "\n" block.body
                |> String.split "\\\\\n"
                |> List.map (String.split "&")

        effectiveFontWidth_ =
            9.0

        columnWidths : List Int
        columnWidths =
            List.map (List.map (textWidthWithPixelsPerCharacter effectiveFontWidth_)) cellsAsString
                |> List.Extra.transpose
                |> List.map (\column -> List.maximum column |> Maybe.withDefault 1)
                |> List.map round
    in
    block.properties
        |> Dict.insert "columnWidths" (String.join "," (List.map String.fromInt columnWidths) |> (\x -> "[" ++ x ++ "]"))
        |> Dict.insert "format" (block.args |> String.join " ")
        |> Dict.insert "id" block.meta.id


fixTable : PrimitiveBlock -> Language -> (String -> List Expression) -> Either a (List Expression)
fixTable block lang parse =
    let
        t1 : List Expression
        t1 =
            case lang of
                MicroLaTeXLang ->
                    prepareTableLaTeX parse (String.join "\n" block.body)
                        |> Debug.log "@@:prepareTableLaTeX"

                EnclosureLang ->
                    prepareTableL0 parse (String.join "\n" block.body)

                SMarkdownLang ->
                    prepareTableL0 (M.Expression.parse 0) (String.join "\n" block.body)
    in
    Right t1


fixTable_ : List Expression -> List Expression
fixTable_ exprs =
    let
        _ =
            Debug.log "@@:fixTable_:EXPR (IN)" exprs
    in
    case List.head exprs of
        Just (Fun "table" innerExprs meta) ->
            [ Fun "table" (fixInner innerExprs |> List.map fixRow) meta ] |> Debug.log "@@:fixTable_:EXPR (OUT)"

        _ ->
            exprs


fixInner : List Expression -> List Expression
fixInner exprs =
    List.filter
        (\e ->
            case e of
                Text str _ ->
                    if compress str == "" then
                        False

                    else
                        True

                _ ->
                    True
        )
        exprs


fixRow : Expression -> Expression
fixRow expr =
    case expr of
        Fun "row" innerExprs meta ->
            Fun "row" (fixInner innerExprs) meta

        _ ->
            expr


fixInnerLaTeX : List Expression -> List Expression
fixInnerLaTeX exprs =
    List.filter
        (\e ->
            case e of
                Text str _ ->
                    if compress str == "" then
                        False

                    else
                        True

                _ ->
                    True
        )
        exprs


prepareTableLaTeX : (String -> List Expression) -> String -> List Expression
prepareTableLaTeX parse str =
    let
        inner : String -> String
        inner row =
            String.split "&" row
                |> List.filter (\s -> compress s /= "")
                -- TODO: remove hack of extra spaces after \cell to force correct parsing of arguments
                |> List.map (\cell -> "\\cell{  " ++ String.trim cell ++ "}")
                |> String.join ""

        cells : String
        cells =
            str
                |> String.split "\\\\\n"
                |> List.filter (\s -> compress s /= "")
                |> List.map (\r -> "\\row{" ++ inner r ++ "}")
                |> (\rows -> "\\table{" ++ String.join "" rows ++ "}")
                |> Debug.log "@@:prepareTableLaTeX:CELLS"
    in
    parse cells
        |> Debug.log "@@:prepareTableLaTeX:PARSE"


prepareTableL0 : (String -> List Expression) -> String -> List Expression
prepareTableL0 parse str =
    let
        inner : String -> String
        inner row =
            String.split "&" row
                |> List.filter (\s -> compress s /= "")
                |> List.map (\cell -> "[cell " ++ String.trim cell ++ "]")
                |> String.join " "

        cells : String
        cells =
            str
                |> String.split "\\\\\n"
                |> List.filter (\s -> compress s /= "")
                |> List.map (\r -> "[row " ++ inner r ++ " ]")
                |> (\rows -> "[table " ++ String.join " " rows ++ "]")
    in
    parse cells
        |> fixTable_


prepareTableSMarkdown : (String -> List Expression) -> String -> List Expression
prepareTableSMarkdown parse str =
    let
        inner : String -> String
        inner row =
            String.split "&" row
                |> List.filter (\s -> compress s /= "")
                |> List.map (\cell -> "@[cell " ++ String.trim cell ++ "]")
                |> String.join " "

        cells : String
        cells =
            str
                |> String.split "\\\\\n"
                |> List.filter (\s -> compress s /= "")
                |> List.map (\r -> "@[row " ++ inner r ++ " ]")
                |> (\rows -> "@[table " ++ String.join " " rows ++ "]")
    in
    parse cells
        |> fixTable_


textWidthWithPixelsPerCharacter : Float -> String -> Float
textWidthWithPixelsPerCharacter pixelsPerCharacter str =
    textWidth_ str * pixelsPerCharacter


textWidth_ : String -> Float
textWidth_ str__ =
    let
        str_ =
            compress str__
    in
    if String.contains "\\\\" str_ then
        str_
            |> String.split "\\\\"
            |> List.map basicTextWidth
            |> List.maximum
            -- TODO: is 30.0 the correct value?
            |> Maybe.withDefault 30.0

    else
        basicTextWidth str_


basicTextWidth : String -> Float
basicTextWidth str_ =
    let
        -- \\[a-z]*([^a-z])
        str =
            str_ |> String.words |> List.map compress |> String.join " "

        letters =
            String.split "" str
    in
    letters |> List.map charWidth |> List.sum


charWidth : String -> Float
charWidth c =
    Dict.get c charDict |> Maybe.withDefault 1.0


compress string =
    string
        ++ " "
        |> Tools.Utility.userReplace "\\\\[a-z].*[^a-zA-Z0-9]" (\_ -> "a")
        |> Tools.Utility.userReplace "\\[A-Z].*[^a-zA-Z0-9]" (\_ -> "A")
        |> String.trim


charDict : Dict String Float
charDict =
    Dict.fromList
        [ ( "a", 1.0 )
        , ( "b", 1.0 )
        , ( "c", 1.0 )
        , ( "d", 1.0 )
        , ( "e", 1.0 )
        , ( "f", 1.0 )
        , ( "g", 1.0 )
        , ( "h", 1.0 )
        , ( "i", 1.0 )
        , ( "j", 1.0 )
        , ( "k", 1.0 )
        , ( "l", 1.0 )
        , ( "m", 1.0 )
        , ( "n", 1.0 )
        , ( "o", 1.0 )
        , ( "p", 1.0 )
        , ( "q", 1.0 )
        , ( "r", 1.0 )
        , ( "s", 1.0 )
        , ( "t", 1.0 )
        , ( "u", 1.0 )
        , ( "v", 1.0 )
        , ( "w", 1.0 )
        , ( "x", 1.0 )
        , ( "y", 1.0 )
        , ( "z", 1.0 )
        , ( "A", 2.0 )
        , ( "B", 2.0 )
        , ( "C", 2.0 )
        , ( "D", 2.0 )
        , ( "E", 2.0 )
        , ( "F", 2.0 )
        , ( "G", 2.0 )
        , ( "H", 2.0 )
        , ( "I", 2.0 )
        , ( "J", 2.0 )
        , ( "K", 2.0 )
        , ( "L", 2.0 )
        , ( "M", 2.0 )
        , ( "N", 2.0 )
        , ( "O", 2.0 )
        , ( "P", 2.0 )
        , ( "Q", 2.0 )
        , ( "R", 2.0 )
        , ( "S", 2.0 )
        , ( "T", 2.0 )
        , ( "U", 2.0 )
        , ( "V", 2.0 )
        , ( "W", 2.0 )
        , ( "X", 2.0 )
        , ( "Y", 2.0 )
        , ( "Z", 2.0 )
        , ( "$", 1.0 )
        ]
