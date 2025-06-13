module Generic.Line exposing
    ( HeadingData
    , HeadingError(..)
    , Line
    , classify
    , errorToString
    , isEmpty
    , isNonEmptyBlank
    )

import Dict exposing (Dict)
import Generic.Language exposing (Heading(..))
import Parser exposing ((|.), (|=), Parser)


{-|

    - ident:      the number of blanks before the first non-blank
    - prefix:     the string of blanks preceding the first non-blank
    - content:    the original string with the prefix removed
    - lineNumber: the line number in the source text
    - position:   the position of the first character of the line in the source text

-}
type alias Line =
    { indent : Int, prefix : String, content : String, lineNumber : Int, position : Int }


type HeadingError
    = HEMissingPrefix
    | HEMissingName
    | HENoContent


type alias HeadingData =
    { heading : Generic.Language.Heading, args : List String, properties : Dict String String }


errorToString : HeadingError -> String
errorToString error =
    case error of
        HEMissingPrefix ->
            "Missing prefix"

        HEMissingName ->
            "Missing name"

        HENoContent ->
            "No content"


isEmpty : Line -> Bool
isEmpty line =
    line.indent == 0 && line.content == ""


isNonEmptyBlank : Line -> Bool
isNonEmptyBlank line =
    line.indent > 0 && line.content == ""


classify : Int -> Int -> String -> Line
classify position lineNumber str =
    case Parser.run (prefixParser position lineNumber) str of
        Err _ ->
            { indent = 0, content = "!!ERROR", prefix = "", position = position, lineNumber = lineNumber }

        Ok result ->
            result


{-|

    The prefix is the first word of the line.
    The content field is the _raw_ line.

-}
prefixParser : Int -> Int -> Parser Line
prefixParser position lineNumber =
    Parser.succeed
        (\prefixStart prefixEnd lineEnd content ->
            { indent = prefixEnd - prefixStart
            , prefix = String.slice 0 prefixEnd content
            , content = content
            , position = position
            , lineNumber = lineNumber
            }
        )
        |= Parser.getOffset
        |. Parser.chompWhile (\c -> c == ' ')
        |= Parser.getOffset
        |. Parser.chompWhile (\c -> c /= '\n')
        |= Parser.getOffset
        |= Parser.getSource
