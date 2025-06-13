module XMarkdown.PrimitiveBlock exposing (parse)

import Dict exposing (Dict)
import Generic.Language exposing (Heading(..), PrimitiveBlock)
import Generic.Line exposing (HeadingData, HeadingError(..), Line)
import Generic.PrimitiveBlock exposing (ParserFunctions)
import Regex
import Tools.KV as KV
import Tools.Utility


{-| Parse a list of strings into a list of primitive blocks given
a function for determexaining when a string is the first line
of a verbatim block

NOTE (TODO) for the moment we assume that the input ends with
a blank line.

-}
parse : String -> Int -> List String -> List PrimitiveBlock
parse initialId outerCount lines =
    Generic.PrimitiveBlock.parse functionData initialId outerCount lines


functionData =
    { isVerbatimBlock = isVerbatimLine
    , getHeadingData = getHeadingData
    , findSectionPrefix = findSectionPrefix
    }


isVerbatimLine : String -> Bool
isVerbatimLine str =
    (String.left 2 str == "||")
        || (String.left 3 str == "```")
        || (String.left 2 str == "$$")


getHeadingData : String -> Result HeadingError HeadingData
getHeadingData line_ =
    let
        line =
            String.trim line_

        ( args1, properties ) =
            KV.argsAndProperties (String.words line)
    in
    case findSectionPrefix line of
        Just prefix ->
            { heading = Ordinary "section", args = [ String.length prefix |> String.fromInt ], properties = Dict.singleton "section-type" "markdown" }
                |> Ok

        Nothing ->
            case findTitlePrefix line of
                Just prefix ->
                    { heading = Ordinary "title", args = [ String.length prefix |> String.fromInt ], properties = Dict.singleton "section-type" "markdown" }
                        |> Ok

                Nothing ->
                    case args1 of
                        [] ->
                            -- Err <| HEMissingPrefix
                            Ok <| { heading = Paragraph, args = [], properties = Dict.empty }

                        prefix :: args ->
                            case prefix of
                                ">" ->
                                    --Ok <| { heading = Ordinary "quote", args = args, properties = properties }
                                    let
                                        reducedLine =
                                            -- String.replace ". " "" line
                                            line |> String.trim |> Tools.Utility.replaceLeadingGreaterThanSign |> Debug.log "REDUCED LINE"
                                    in
                                    if String.isEmpty reducedLine then
                                        Err HENoContent

                                    else
                                        Ok <|
                                            { heading = Ordinary "quotation"
                                            , args = []
                                            , properties = Dict.singleton "firstLine" reducedLine
                                            }

                                "||" ->
                                    case args of
                                        [] ->
                                            Err <| HEMissingName

                                        name :: args2 ->
                                            Ok <| { heading = Verbatim name, args = args2, properties = properties }

                                "|" ->
                                    case args of
                                        [] ->
                                            Err <| HEMissingName

                                        name :: args2 ->
                                            Ok <| { heading = Ordinary name, args = args2, properties = properties }

                                "!!" ->
                                    let
                                        reducedLine =
                                            String.replace "!! " "" line
                                    in
                                    if String.isEmpty reducedLine then
                                        Err HENoContent

                                    else
                                        Ok <|
                                            { heading = Ordinary "title"
                                            , args = []
                                            , properties =
                                                Dict.fromList
                                                    [ ( "firstLine", String.replace "!! " "" line )
                                                    , ( "section-type", "markdown" )
                                                    ]
                                            }

                                "-" ->
                                    let
                                        reducedLine =
                                            line |> String.trim |> Tools.Utility.replaceLeadingDashSpace
                                    in
                                    if String.isEmpty reducedLine then
                                        Err HENoContent

                                    else
                                        Ok <|
                                            { heading = Ordinary "item"
                                            , args = []
                                            , properties = Dict.singleton "firstLine" reducedLine
                                            }

                                "." ->
                                    let
                                        reducedLine =
                                            -- String.replace ". " "" line
                                            line |> String.trim |> Tools.Utility.replaceLeadingDotSpace |> Debug.log "REDUCED LINE"
                                    in
                                    if String.isEmpty reducedLine then
                                        Err HENoContent

                                    else
                                        Ok <|
                                            { heading = Ordinary "numbered"
                                            , args = []
                                            , properties = Dict.singleton "firstLine" reducedLine
                                            }

                                "$$" ->
                                    Ok <| { heading = Verbatim "math", args = [], properties = Dict.empty }

                                "```" ->
                                    Ok <| { heading = Verbatim "code", args = [], properties = Dict.empty }

                                _ ->
                                    Ok <| { heading = Paragraph, args = [], properties = Dict.empty }


sectionRegex : Regex.Regex
sectionRegex =
    Maybe.withDefault Regex.never <|
        Regex.fromString "^(#+\\s*|!!\\s*)"


findSectionPrefix : String -> Maybe String
findSectionPrefix string =
    Regex.find sectionRegex string
        |> List.map .match
        |> List.head
        |> Maybe.map String.trim


titleRegex : Regex.Regex
titleRegex =
    Maybe.withDefault Regex.never <|
        Regex.fromString "^!!\\s"


findTitlePrefix : String -> Maybe String
findTitlePrefix string =
    Regex.find titleRegex string
        |> List.map .match
        |> List.head
        |> Maybe.map String.trim
