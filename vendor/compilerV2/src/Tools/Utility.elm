module Tools.Utility exposing
    ( compressWhitespace
    , compressWhitespaces
    , findOrdinaryTagAtEnd
    , keyValueDict
    , removeNonAlphaNum
    , removeNonAlphaNumExceptHyphen
    , replaceLeadingDashSpace
    , replaceLeadingDotSpace
    , replaceLeadingGreaterThanSign
    , replaceLeadingVertBarItem
    , substituteForITEM
    , truncateString
    , userReplace
    )

import Dict exposing (Dict)
import Maybe.Extra
import Regex


ordinaryTagAtEndRegex : Regex.Regex
ordinaryTagAtEndRegex =
    Maybe.withDefault Regex.never <|
        Regex.fromString ".*\n| .*$"


findOrdinaryTagAtEnd : String -> Maybe String
findOrdinaryTagAtEnd string =
    Regex.find ordinaryTagAtEndRegex string
        |> List.map .match
        |> List.reverse
        |> List.head
        |> Maybe.map String.trim


replaceLeadingDotSpace : String -> String
replaceLeadingDotSpace str =
    let
        regex =
            Regex.fromString "^\\. " |> Maybe.withDefault Regex.never
    in
    Regex.replace regex (\_ -> "") str


replaceLeadingDashSpace : String -> String
replaceLeadingDashSpace str =
    let
        regex =
            Regex.fromString "^- " |> Maybe.withDefault Regex.never
    in
    Regex.replace regex (\_ -> "") str


replaceLeadingGreaterThanSign : String -> String
replaceLeadingGreaterThanSign str =
    let
        regex =
            Regex.fromString "^> " |> Maybe.withDefault Regex.never
    in
    Regex.replace regex (\_ -> "") str


replaceLeadingVertBarItem : String -> String
replaceLeadingVertBarItem str =
    let
        regex =
            Regex.fromString "^| item" |> Maybe.withDefault Regex.never
    in
    Regex.replace regex (\_ -> "") str


truncateString : Int -> String -> String
truncateString k str =
    let
        str2 =
            truncateString_ k str
    in
    if str == str2 then
        str

    else
        str2 ++ " ..."


truncateString_ : Int -> String -> String
truncateString_ k str =
    if String.length str < k then
        str

    else
        let
            words =
                String.words str

            n =
                List.length words
        in
        words
            |> List.take (n - 1)
            |> String.join " "
            |> truncateString_ k


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


compressWhitespace : String -> String
compressWhitespace string =
    userReplace "\\s\\s+" (\_ -> " ") string


compressWhitespaces : String -> String
compressWhitespaces string =
    userReplace "\\s+" (\_ -> " ") string


removeNonAlphaNum : String -> String
removeNonAlphaNum string =
    userReplace "[^A-Za-z0-9\\-]" (\_ -> "") string


removeNonAlphaNumExceptHyphen : String -> String
removeNonAlphaNumExceptHyphen string =
    userReplace "[^A-Za-z0-9]" (\_ -> "") string


userReplace : String -> (Regex.Match -> String) -> String -> String
userReplace regexString replacer string =
    case Regex.fromString regexString of
        Nothing ->
            string

        Just regex ->
            Regex.replace regex replacer string


substituteForITEM : String -> String -> String -> String
substituteForITEM regexString source target =
    case firstMatch regexString source of
        Nothing ->
            target

        Just match ->
            String.replace "ITEM" match target



-- > firstMatch "\\[subheading (.+?)\\]" "[subheading Intro]"
-- Just "Intro" : Maybe String


firstMatch : String -> String -> Maybe String
firstMatch regexString src =
    Regex.find (userRegex regexString) src
        |> List.map .submatches
        |> List.map (List.filterMap identity)
        |> List.concat
        |> List.head


matchToString : Regex.Match -> String
matchToString match =
    match.match


userRegex : String -> Regex.Regex
userRegex str =
    Maybe.withDefault Regex.never <|
        Regex.fromString str
