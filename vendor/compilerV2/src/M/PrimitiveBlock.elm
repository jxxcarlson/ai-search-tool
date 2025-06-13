module M.PrimitiveBlock exposing (..)

import Dict exposing (Dict)
import Generic.Language exposing (Heading(..), PrimitiveBlock)
import Generic.Line exposing (HeadingData, HeadingError(..), Line)
import Generic.PrimitiveBlock exposing (ParserFunctions)
import M.Regex
import Parser exposing ((|.), (|=), Parser)
import Tools.KV as KV


x3 =
    """
| equation
\\int_0^1 x^n dx = \\frac{1}{n+1}
"""


x4 =
    """
| aligned
& a  = b^2    \\
& c  = d^2    \\
"""


x3b =
    """
|| equation
\\int_0^1 x^n dx = \\frac{1}{n+1}
"""


ex1 =
    """
| code
$$
\\int_0^1 x^n dx = \\frac{1}{n+1}
$$


"""


p str =
    parse "0" 0 (String.lines str)


{-| Parse a list of strings into a list of primitive blocks given
a function for determining when a string is the first line
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
    , findSectionPrefix = M.Regex.findSectionPrefix
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
    case M.Regex.findSectionPrefix line of
        Just prefix ->
            { heading = Ordinary "section", args = [ String.length prefix |> String.fromInt ], properties = Dict.singleton "section-type" "markdown" }
                |> Ok

        Nothing ->
            case args1 of
                [] ->
                    --Err <| HEMissingPrefix
                    { heading = Paragraph, args = [], properties = Dict.empty }
                        |> Ok

                prefix :: args ->
                    case prefix of
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
                                    coerce line args name args2 properties

                        "-" ->
                            let
                                reducedLine =
                                    String.replace "- " "" line
                            in
                            if String.isEmpty reducedLine then
                                Err HENoContent

                            else
                                Ok <|
                                    { heading = Ordinary "item"
                                    , args = []
                                    , properties = Dict.singleton "firstLine" (String.replace "- " "" line)
                                    }

                        "." ->
                            let
                                reducedLine =
                                    String.replace ". " "" line
                            in
                            if String.isEmpty reducedLine then
                                Err HENoContent

                            else
                                Ok <|
                                    { heading = Ordinary "numbered"
                                    , args = []
                                    , properties = Dict.singleton "firstLine" (String.replace ". " "" line)
                                    }

                        "```" ->
                            Ok <|
                                { heading = Verbatim "code"
                                , args = []
                                , properties = Dict.empty
                                }

                        "$$" ->
                            Ok <| { heading = Verbatim "math", args = [], properties = Dict.empty }

                        _ ->
                            Ok <| { heading = Paragraph, args = [], properties = Dict.empty }


coerce line args name args2 properties =
    case hasVerbatimWord line of
        Just element ->
            Ok <| coerce_ line args element

        Nothing ->
            Ok <| { heading = Ordinary name, args = args2, properties = properties }


hasVerbatimWord : String -> Maybe String
hasVerbatimWord line =
    case mElementWord line of
        Nothing ->
            Nothing

        Just word ->
            if List.member word verbatimWords then
                Just word

            else
                Nothing


verbatimWords =
    [ "math"
    , "equation"
    , "aligned"
    , "array"
    , "textarray"
    , "table"
    , "code"
    , "verse"
    , "verbatim"
    , "load"
    , "load-data"
    , "hide"
    , "texComment"
    , "docinfo"
    , "mathmacros"
    , "textmacros"
    , "datatable"
    , "chart"
    , "svg"
    , "quiver"
    , "image"
    , "tikz"
    , "load-files"
    , "include"
    , "setup"
    , "iframe"
    ]


mElementWord line =
    line
        |> String.dropLeft 2
        |> String.trim
        |> String.split " "
        |> List.head
        |> Maybe.map String.trim



--String.contains "code" line
--    || String.contains "equation" line
--    || String.contains "verse" line
--    || String.contains "aligned" line


coerce_ line args2 element =
    { heading = Verbatim element
    , args = args2
    , properties = Dict.singleton "firstLine" (String.replace "| " "" line)
    }
