module M.Symbol exposing (Symbol(..), balance, toString, toSymbols, value)

import M.Tokenizer exposing (Token, Token_(..))


type Symbol
    = L -- LB, [
    | R -- RB, ]
    | BM -- bracketed math, e.g., \[x^2\]
    | LM -- left math, e.g., \(
    | RM -- right math, e.g., \)
    | ST -- S String (string)
    | M -- $
    | C -- `
    | WS -- W String (whitespace)
    | E -- Token error


value : Symbol -> Int
value symbol =
    case symbol of
        L ->
            1

        R ->
            -1

        LM ->
            1

        RM ->
            -1

        ST ->
            0

        WS ->
            0

        M ->
            0

        BM ->
            0

        C ->
            0

        E ->
            0


balance : List Symbol -> Int
balance symbols =
    symbols |> List.map value |> List.sum


symbolToString : Symbol -> String
symbolToString symbol =
    case symbol of
        L ->
            "L"

        R ->
            "R"

        LM ->
            "LM"

        RM ->
            "RM"

        ST ->
            "S"

        WS ->
            "W"

        M ->
            "M"

        BM ->
            "BM"

        C ->
            "C"

        E ->
            "E"


toString : List Symbol -> String
toString symbols =
    List.map symbolToString symbols |> String.join " "


toSymbols : List Token -> List Symbol
toSymbols tokens =
    List.map toSymbol tokens


toSymbol : Token -> Symbol
toSymbol token =
    case token of
        LB _ ->
            L

        RB _ ->
            R

        LMB _ ->
            LM

        RMB _ ->
            RM

        S _ _ ->
            ST

        W _ _ ->
            WS

        MathToken _ ->
            M

        BracketedMath _ _ ->
            BM

        CodeToken _ ->
            C

        TokenError _ _ ->
            E
