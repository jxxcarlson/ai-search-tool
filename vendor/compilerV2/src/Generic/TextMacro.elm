module Generic.TextMacro exposing
    ( Macro
    , applyMacro
    , applyMacroS
    , applyMacroS2
    , buildDictionary
    , expand
    , exportTexMacros
    , extract
    , getTextMacroFunctionNames
    , listSubst
    , macroFromL0String
    , macroFromString
    , parseMicroLaTeX
    , printMacro
    , toString
    )

import Dict exposing (Dict)
import Generic.ASTTools as AT
import Generic.Language exposing (Expr(..), Expression)
import Generic.Print
import Generic.TextMacroParser
import List.Extra
import M.Expression


type alias Macro =
    { name : String, vars : List String, body : List Expression }


macroFromString : String -> Maybe Macro
macroFromString str =
    case String.left 1 str of
        "\\" ->
            macroFromMicroLaTeXString str

        "[" ->
            macroFromL0String str

        _ ->
            Nothing


{-|

    Construct a Lambda from a string

-}
macroFromL0String : String -> Maybe Macro
macroFromL0String str =
    str
        |> M.Expression.parse 0
        |> List.head
        |> Maybe.andThen extract


macroFromMicroLaTeXString : String -> Maybe Macro
macroFromMicroLaTeXString macroS =
    Maybe.andThen extract2 (parseMicroLaTeX macroS |> List.head)


printMacro : Macro -> String
printMacro macro =
    "Macro "
        ++ macro.name
        ++ ", vars: ["
        ++ String.join ", " macro.vars
        ++ "], expr:  "
        ++ Generic.Print.toStringFromList macro.body


printLaTeXMacro : Macro -> String
printLaTeXMacro macro =
    if List.length macro.vars == 0 then
        "\\newcommand{\\"
            ++ macro.name
            ++ "}{"
            ++ (List.map toLaTeXString macro.body |> String.join "")
            ++ "}"

    else
        "\\newcommand{\\"
            ++ macro.name
            ++ "}"
            ++ "["
            ++ String.fromInt (List.length macro.vars)
            ++ "]{"
            ++ (List.map toLaTeXString macro.body |> String.join "")
            ++ "}"


toLaTeXString : Expression -> String
toLaTeXString expr =
    case expr of
        Fun name expressions _ ->
            let
                body_ =
                    List.map toLaTeXString expressions |> String.join ""

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
            "\\" ++ name ++ "{" ++ body ++ "}"

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


extract2 : Expression -> Maybe Macro
extract2 expr =
    case expr of
        Fun name body meta ->
            if name == "newcommand" then
                extract2Aux body meta

            else
                Nothing

        _ ->
            Nothing


getVars : List Expression -> List String
getVars exprs =
    List.map getVars_ exprs |> List.concat |> List.Extra.unique |> List.sort


getVars_ : Expression -> List String
getVars_ expr =
    case expr of
        Text str _ ->
            getParam str

        Fun _ exprs _ ->
            List.map getVars_ exprs |> List.concat

        _ ->
            []


getParam : String -> List String
getParam str =
    case Generic.TextMacroParser.getParam str of
        Just result ->
            [ result ]

        Nothing ->
            []


extract2Aux body meta =
    case body of
        (Fun name _ _) :: rest ->
            Just (extract3Aux name rest meta)

        _ ->
            Nothing



-- extract3Aux : String -> List String -> meta -> Lambda


extract3Aux : String -> List Expression -> c -> { name : String, vars : List String, body : List Expression }
extract3Aux name rest meta =
    { name = name, vars = getVars rest, body = rest }


extract : Expression -> Maybe Macro
extract expr_ =
    case expr_ of
        Fun "macro" ((Text argString _) :: exprs) _ ->
            case String.words (String.trim argString) of
                name :: rest ->
                    Just { name = name, vars = rest, body = exprs }

                _ ->
                    Nothing

        _ ->
            Nothing


{-| Insert a lambda in the dictionary
-}
insert : Maybe Macro -> Dict String Macro -> Dict String Macro
insert data dict =
    case data of
        Nothing ->
            dict

        Just macro ->
            Dict.insert macro.name macro dict


buildDictionary : List String -> Dict String Macro
buildDictionary lines =
    List.foldl (\line acc -> insert (macroFromString line) acc) Dict.empty lines


getTextMacroFunctionNames : String -> List String
getTextMacroFunctionNames str =
    str
        |> String.lines
        |> buildDictionary
        |> Dict.toList
        |> List.map Tuple.second
        |> List.map .body
        |> List.map functionNames
        |> List.concat
        |> List.Extra.unique
        |> List.sort


functionNames : List Expression -> List String
functionNames exprs =
    List.map functionNames_ exprs |> List.concat


functionNames_ : Expression -> List String
functionNames_ expr =
    case expr of
        Fun name body _ ->
            name :: (List.map functionNames_ body |> List.concat)

        Text _ _ ->
            []

        VFun _ _ _ ->
            []


exportTexMacros : String -> String
exportTexMacros str =
    str
        |> String.lines
        |> buildDictionary
        |> Dict.toList
        |> List.map Tuple.second
        |> List.map printLaTeXMacro
        |> String.join "\n"


{-| Expand the given expression using the given dictionary of lambdas.
-}
expand : Dict String Macro -> Expression -> Expression
expand dict expr =
    case expr of
        Fun name _ _ ->
            case Dict.get name dict of
                Nothing ->
                    expr

                Just macro ->
                    expandWithMacro macro expr

        _ ->
            expr


{-| Substitute a for all occurrences of (Text var ..) in e
-}
subst : Expression -> String -> Expression -> Expression
subst a var body =
    case body of
        Text str _ ->
            if String.trim str == String.trim var then
                -- the trimming is a temporary hack.  Need to adjust the parser
                a

            else if String.contains var str then
                let
                    parts =
                        String.split var str |> List.map (\s -> Text s dummy)
                in
                List.intersperse a parts |> group

            else
                body

        Fun name exprs meta ->
            Fun name (List.map (subst a var) exprs) meta

        _ ->
            body


listSubst : List Expression -> List String -> List Expression -> List Expression
listSubst as_ vars exprs =
    if List.length as_ /= List.length vars then
        exprs

    else
        let
            funcs =
                List.map2 makeF as_ vars
        in
        List.foldl (\func acc -> func acc) exprs funcs


expandWithMacro : Macro -> Expression -> Expression
expandWithMacro macro expr =
    case expr of
        Fun name fArgs _ ->
            if name == macro.name then
                listSubst (fArgs |> filterOutBlanks) macro.vars macro.body |> group

            else
                expr

        _ ->
            expr


{-| Apply a lambda to an expression.
-}
group : List Expression -> Expression
group exprs =
    Fun "group" exprs dummy


makeF : Expression -> String -> (List Expression -> List Expression)
makeF a var =
    List.map (subst a var)


toString : (Expression -> String) -> Macro -> String
toString exprToString macro =
    [ "\\newcommand{\\"
    , macro.name
    , "}["
    , String.fromInt (List.length macro.vars)
    , "]{"
    , macro.body |> List.map exprToString |> String.join "" --|> mapArgs lambda.vars
    , "}    "
    ]
        |> String.join ""



-- FOR TESTING --


parseExpr : String -> Maybe Expression
parseExpr str =
    M.Expression.parse 0 str |> List.head


parseMacro : String -> Maybe Macro
parseMacro str =
    str |> parseExpr |> Maybe.andThen extract


applyMacro : Maybe Macro -> Maybe Expression -> Maybe Expression
applyMacro macro_ expr_ =
    Maybe.map2 expandWithMacro macro_ expr_


applyMacroS : String -> String -> Maybe String
applyMacroS macroS exprS =
    applyMacro (parseMacro macroS) (parseExpr exprS) |> Maybe.map Generic.Print.toString


applyMacroS2 : String -> String -> Maybe String
applyMacroS2 macroS exprS =
    applyMacro (Maybe.andThen extract2 (parseMicroLaTeX macroS |> List.head))
        (parseMicroLaTeX exprS |> List.head)
        |> Maybe.map Generic.Print.toString


parseMicroLaTeX : String -> List Expression
parseMicroLaTeX str =
    M.Expression.parse 0 str



-- HELPERS


filterOutBlanks : List Expression -> List Expression
filterOutBlanks =
    AT.filterExprs (\e -> not (AT.isBlank e))


dummy =
    { begin = 0, end = 0, index = 0, id = "dummyId" }
