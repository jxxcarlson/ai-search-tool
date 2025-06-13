module Tools.String exposing (..)

import Regex


compressWhitespace : String -> String
compressWhitespace string =
    userReplace "\\s\\s+" (\_ -> " ") string |> String.trim


alphanumOnly : String -> String
alphanumOnly string =
    userReplace "[^a-z0-9 ]+" (\_ -> " ") string


compressSpaces : String -> String
compressSpaces string =
    userReplace " +" (\_ -> " ") string


makeSlug : String -> String
makeSlug str =
    str |> String.toLower |> alphanumOnly |> compressWhitespace |> String.replace " " "-"


userReplace : String -> (Regex.Match -> String) -> String -> String
userReplace userRegex replacer string =
    case Regex.fromString userRegex of
        Nothing ->
            string

        Just regex ->
            Regex.replace regex replacer string
