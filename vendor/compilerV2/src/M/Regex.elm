module M.Regex exposing (findSectionPrefix)

import Regex


titleSectionRegex : Regex.Regex
titleSectionRegex =
    Maybe.withDefault Regex.never <|
        Regex.fromString "^#+\\s*"


findSectionPrefix : String -> Maybe String
findSectionPrefix string =
    Regex.find titleSectionRegex string
        |> List.map .match
        |> List.head
        |> Maybe.map String.trim
