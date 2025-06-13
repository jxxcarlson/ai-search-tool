module Render.Export.Util exposing (getArgs, getOneArg, getTwoArgs)

import Generic.ASTTools as ASTTools
import Generic.Language exposing (Expression)


getArgs : List Expression -> List String
getArgs =
    ASTTools.exprListToStringList >> List.map String.words >> List.concat >> List.filter (\x -> x /= "")


getOneArg : List Expression -> String
getOneArg exprs =
    case List.head (getArgs exprs) of
        Nothing ->
            ""

        Just str ->
            str


getTwoArgs : List Expression -> { first : String, second : String }
getTwoArgs exprs =
    let
        args =
            getArgs exprs

        n =
            List.length args

        first =
            List.take (n - 1) args |> String.join " "

        second =
            List.drop (n - 1) args |> String.join ""
    in
    { first = first, second = second }
