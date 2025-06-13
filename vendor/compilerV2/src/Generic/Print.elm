module Generic.Print exposing (print, showError, toString, toStringFromList)

{-| Used for debugging with CLI.LOPB
-}

import Dict exposing (Dict)
import Generic.Language exposing (Expr(..), Expression, Heading(..), PrimitiveBlock)


print : PrimitiveBlock -> String
print block =
    [ "BLOCK:"
    , "Heading: " ++ displayHeading block.heading
    , "Indent: " ++ String.fromInt block.indent
    , "Args: " ++ showArgs block.args
    , "Properties: " ++ showProperties block.properties
    , "Content:\n---------\n"
        ++ (block.body
                |> List.indexedMap (\k s -> String.padLeft 3 ' ' (String.fromInt (k + 1 + block.meta.lineNumber)) ++ ": " ++ s)
                |> String.join "\n"
           )
    , "---------    "
    , "MetaData:"
    , "    Id: " ++ block.meta.id
    , "    Position: " ++ String.fromInt block.meta.position
    , "    Line number: " ++ String.fromInt block.meta.lineNumber
    , "    Number of lines: " ++ String.fromInt block.meta.numberOfLines
    , "    messages: " ++ String.join ", " block.meta.messages
    , "    Error: " ++ showError block.meta.error
    , "    Source text:\n--------\n" ++ block.meta.sourceText
    , "--------"
    ]
        |> String.join "\n"


displayHeading : Heading -> String
displayHeading heading =
    case heading of
        Paragraph ->
            "Paragraph"

        Ordinary name ->
            "OrdinaryBlock " ++ name

        Verbatim name ->
            "VerbatimBlock " ++ name


showProperties : Dict String String -> String
showProperties dict =
    dict |> Dict.toList |> List.map (\( k, v ) -> k ++ "=" ++ v) |> String.join ", "


showArgs : List String -> String
showArgs args =
    args |> String.join ", "


showError : Maybe String -> String
showError mError =
    case mError of
        Nothing ->
            "none"

        Just error ->
            error


toStringFromList : List Expression -> String
toStringFromList expressions =
    List.map toString expressions |> String.join ""


toString : Expression -> String
toString expr =
    case expr of
        Fun name expressions _ ->
            let
                body_ =
                    List.map toString expressions |> String.join ""

                body =
                    if body_ == "" then
                        body_

                    else if String.left 1 body_ == "[" then
                        body_

                    else if String.left 1 body_ == " " then
                        body_

                    else
                        " " ++ body_
            in
            "[" ++ name ++ body ++ "]"

        Text str _ ->
            str

        VFun name str _ ->
            case name of
                "math" ->
                    "$" ++ str ++ "$"

                "code" ->
                    "`" ++ str ++ "`"

                _ ->
                    "error: verbatim " ++ name ++ " not recognized"
