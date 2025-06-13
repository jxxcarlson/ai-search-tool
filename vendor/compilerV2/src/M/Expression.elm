module M.Expression exposing
    ( State
    , extractMessages
    , fixup
    , foo
    , parse
    , parseToState
    , parseWithMessages
    , reduceTokens
    )

import Generic.Language exposing (Expr(..), ExprMeta, Expression)
import List.Extra
import M.Match as M
import M.Symbol as Symbol exposing (Symbol(..))
import M.Tokenizer as Token exposing (Token, TokenType(..), Token_(..))
import ScriptaV2.Config as Config
import Tools.Loop exposing (Step(..), loop)
import Tools.ParserHelpers as Helpers



-- EXPOSED FUNCTIONS


{-|

    > import Generic.Language exposing(..)
    > p str = parse 0 str |> List.map simplifyExpr
      <function> : String -> List (Expr ())

    > p "hello"
    [Text "hello" ()] : List (Expr ())

    > p "This is [b important]"
    [Text ("This is ") (),Fun "b" [Text (" important") ()] ()]

    > p "I like $a^2 + b^2 = c^2$"
    [Text ("I like ") (),VFun "math" ("a^2 + b^2 = c^2") ()]

-}
parse : Int -> String -> List Expression
parse lineNumber str =
    let
        state =
            parseToState lineNumber str
    in
    state.committed |> fixup


fixup input =
    case input of
        (Fun name exprList meta) :: rest ->
            let
                newExprlist =
                    case exprList of
                        head :: tail ->
                            case head of
                                Text str meta_ ->
                                    [ Text (String.trim str) meta_ ] ++ tail

                                _ ->
                                    exprList

                        [] ->
                            []
            in
            Fun name newExprlist meta :: fixup rest

        _ ->
            input



-- no fixup needed for other types, like


foo =
    [ Fun "quote" [ Text " abc def " { begin = 6, end = 14, id = "e-0.2", index = 2 }, Fun "i" [ Text " xyz" { begin = 17, end = 20, id = "e-0.5", index = 5 } ] { begin = 16, end = 16, id = "e-77.4", index = 4 } ] { begin = 1, end = 5, id = "e-77.1", index = 1 } ]


parseWithMessages : Int -> String -> ( List Expression, List String )
parseWithMessages lineNumber str =
    let
        state =
            parseToState lineNumber str
    in
    ( state.committed, state.messages )


extractMessages : State -> List String
extractMessages state =
    state.messages


parseToState : Int -> String -> State
parseToState lineNumber str =
    str
        |> Token.run
        |> parseTokenListToState lineNumber



-- STATE FOR THE PARSER


type alias State =
    { step : Int
    , tokens : List Token
    , numberOfTokens : Int
    , tokenIndex : Int
    , committed : List Expression
    , stack : List Token
    , messages : List String
    , lineNumber : Int
    }


initWithTokens : Int -> List Token -> State
initWithTokens lineNumber tokens =
    { step = 0
    , tokens = List.reverse tokens
    , numberOfTokens = List.length tokens
    , tokenIndex = 0
    , committed = []
    , stack = []
    , messages = []
    , lineNumber = lineNumber
    }



-- PARSER


parseTokenListToState : Int -> List Token -> State
parseTokenListToState lineNumber tokens =
    let
        state =
            tokens |> initWithTokens lineNumber |> run
    in
    state


run : State -> State
run state =
    loop state nextStep
        |> (\state_ -> { state_ | committed = List.reverse state_.committed })


nextStep : State -> Step State State
nextStep state =
    case getToken state of
        Nothing ->
            if stackIsEmpty state then
                Done state

            else
                recoverFromError state

        Just token ->
            state
                |> advanceTokenIndex
                |> pushOrCommit token
                |> reduceState
                |> (\st -> { st | step = st.step + 1 })
                |> Loop


advanceTokenIndex : State -> State
advanceTokenIndex state =
    { state | tokenIndex = state.tokenIndex + 1 }


getToken : State -> Maybe Token
getToken state =
    List.Extra.getAt state.tokenIndex state.tokens


stackIsEmpty : State -> Bool
stackIsEmpty state =
    List.isEmpty state.stack


pushOrCommit : Token -> State -> State
pushOrCommit token state =
    case token of
        S _ _ ->
            pushOrCommit_ token state

        W _ _ ->
            pushOrCommit_ token state

        MathToken _ ->
            pushOnStack_ token state

        BracketedMath _ _ ->
            pushOrCommit_ token state

        CodeToken _ ->
            pushOnStack_ token state

        LB _ ->
            pushOnStack_ token state

        RB _ ->
            pushOnStack_ token state

        LMB _ ->
            pushOnStack_ token state

        RMB _ ->
            pushOnStack_ token state

        TokenError _ _ ->
            pushOnStack_ token state


pushOnStack_ : Token -> State -> State
pushOnStack_ token state =
    { state | stack = token :: state.stack }


pushOrCommit_ : Token -> State -> State
pushOrCommit_ token state =
    if List.isEmpty state.stack then
        commit token state

    else
        push token state


push : Token -> State -> State
push token state =
    { state | stack = token :: state.stack }


commit : Token -> State -> State
commit token state =
    case stringTokenToExpr state.lineNumber token of
        Nothing ->
            state

        Just expr ->
            { state | committed = expr :: state.committed }


stringTokenToExpr : Int -> Token -> Maybe Expression
stringTokenToExpr lineNumber token =
    case token of
        S str loc ->
            Just (Text str (boostMeta lineNumber (Token.indexOf token) loc))

        W str loc ->
            Just (Text str (boostMeta lineNumber (Token.indexOf token) loc))

        BracketedMath str loc ->
            Just (VFun "math" str (boostMeta lineNumber (Token.indexOf token) loc))

        _ ->
            Nothing



-- REDUCE


reduceState : State -> State
reduceState state =
    if tokensAreReducible state then
        { state | stack = [], committed = reduceStack state ++ state.committed }

    else
        state


tokensAreReducible state =
    M.isReducible (state.stack |> Symbol.toSymbols |> List.reverse)


reduceStack : State -> List Expression
reduceStack state =
    reduceTokens state.lineNumber (state.stack |> List.reverse)


reduceTokens : Int -> List Token -> List Expression
reduceTokens lineNumber tokens =
    if isExpr tokens then
        let
            args =
                unbracket tokens
        in
        case args of
            -- The reversed token list is of the form [LB name EXPRS RB], so return [Expression name (evalList EXPRS)]
            (S name meta) :: _ ->
                [ Fun name (reduceRestOfTokens lineNumber (List.drop 1 args)) (boostMeta lineNumber meta.index meta) ]

            _ ->
                -- this happens with input of "[]"
                [ errorMessage "[????]" ]

    else
        case tokens of
            (MathToken meta) :: (S str _) :: (MathToken _) :: rest ->
                VFun "math" str (boostMeta lineNumber meta.index meta) :: reduceRestOfTokens lineNumber rest

            (CodeToken meta) :: (S str _) :: (CodeToken _) :: rest ->
                VFun "code" str (boostMeta lineNumber meta.index meta) :: reduceRestOfTokens lineNumber rest

            (LMB meta) :: (S str _) :: (RMB _) :: rest ->
                VFun "math" str (boostMeta lineNumber meta.index meta) :: reduceRestOfTokens lineNumber rest

            (LMB meta) :: rest ->
                let
                    reversedRest =
                        List.reverse rest
                in
                case List.head reversedRest of
                    Just (RMB _) ->
                        let
                            content =
                                rest
                                    |> List.map
                                        (\t ->
                                            case t of
                                                S str _ ->
                                                    str

                                                LB _ ->
                                                    "["

                                                RB _ ->
                                                    "]"

                                                _ ->
                                                    ""
                                        )
                                    |> String.join " "
                        in
                        [ VFun "math" content (boostMeta lineNumber meta.index meta) ]

                    _ ->
                        -- this happens with input of "["
                        [ errorMessage "[????]" ]

            _ ->
                [ errorMessage "[????]" ]


reduceRestOfTokens : Int -> List Token -> List Expression
reduceRestOfTokens lineNumber tokens =
    case tokens of
        (LB _) :: _ ->
            case splitTokens tokens of
                Nothing ->
                    [ errorMessageInvisible "Error on match", Text "error on match" dummyLocWithId ]

                Just ( a, b ) ->
                    reduceTokens lineNumber a ++ reduceRestOfTokens lineNumber b

        (LMB _) :: _ ->
            case splitTokens tokens of
                Nothing ->
                    [ errorMessageInvisible "Error on match", Text "error on match" dummyLocWithId ]

                Just ( a, b ) ->
                    reduceTokens lineNumber a ++ reduceRestOfTokens lineNumber b

        (MathToken _) :: _ ->
            let
                ( a, b ) =
                    splitTokensWithSegment tokens
            in
            reduceTokens lineNumber a ++ reduceRestOfTokens lineNumber b

        (CodeToken _) :: _ ->
            let
                ( a, b ) =
                    splitTokensWithSegment tokens
            in
            reduceTokens lineNumber a ++ reduceRestOfTokens lineNumber b

        (S str meta) :: _ ->
            Text str (boostMeta 0 (Token.indexOf (S str meta)) meta) :: reduceRestOfTokens lineNumber (List.drop 1 tokens)

        token :: _ ->
            case stringTokenToExpr lineNumber token of
                Just expr ->
                    expr :: reduceRestOfTokens lineNumber (List.drop 1 tokens)

                Nothing ->
                    [ errorMessage ("Line " ++ String.fromInt lineNumber ++ ", error converting token"), Text "error converting Token" dummyLocWithId ]

        _ ->
            []



-- ERROR RECOVERY


recoverFromError : State -> Step State State
recoverFromError state =
    case List.reverse state.stack of
        -- brackets with no intervening text
        (LB _) :: (RB meta) :: _ ->
            Loop
                { state
                    | committed = errorMessage "[?]" :: state.committed
                    , stack = []
                    , tokenIndex = meta.index + 1
                    , messages = Helpers.prependMessage state.lineNumber "Brackets must enclose something" state.messages
                }

        -- consecutive left brackets
        (LB meta1) :: (LB _) :: _ ->
            let
                k =
                    meta1.index

                shiftedTokens =
                    Token.changeTokenIndicesFrom (k + 1) 1 state.tokens
            in
            Loop
                { state
                    | tokens = List.take (k + 1) state.tokens ++ (S "1[??" { dummyLoc | index = k + 1 } :: List.drop (k + 1) shiftedTokens)
                    , stack = []
                    , tokenIndex = meta1.index
                    , messages = Helpers.prependMessage state.lineNumber "Consecutive left brackets" state.messages
                }

        (LMB meta1) :: rest ->
            let
                k =
                    meta1.index

                shiftedTokens =
                    Token.changeTokenIndicesFrom (k + 1) 4 state.tokens

                errorTokens : List (Token_ { begin : number, end : number, index : Int })
                errorTokens =
                    [ LB { begin = 0, end = 0, index = k + 1 }
                    , S "red" { begin = 1, end = 3, index = k + 2 }
                    , S " unmatched \\(" { begin = 4, end = 9, index = k + 3 }
                    , RB { begin = 10, end = 10, index = k + 4 }
                    ]
            in
            Loop
                { state
                    | tokens = List.take (k + 1) state.tokens ++ errorTokens ++ List.drop (k + 1) shiftedTokens
                    , stack = []
                    , tokenIndex = meta1.index + 1
                    , messages = Helpers.prependMessage state.lineNumber "No terminating right math bracket" state.messages
                }

        (RMB meta1) :: _ ->
            let
                k =
                    meta1.index

                shiftedTokens =
                    Token.changeTokenIndicesFrom (k + 1) 4 state.tokens

                errorTokens : List (Token_ { begin : number, end : number, index : Int })
                errorTokens =
                    [ LB { begin = 0, end = 0, index = k + 1 }
                    , S "red" { begin = 1, end = 3, index = k + 2 }
                    , S "unmatched \\)" { begin = 4, end = 9, index = k + 3 }
                    , RB { begin = 10, end = 10, index = k + 4 }
                    ]
            in
            Loop
                { state
                    | tokens = List.take (k + 1) state.tokens ++ errorTokens ++ List.drop (k + 1) shiftedTokens
                    , stack = []
                    , tokenIndex = meta1.index + 1
                    , messages = Helpers.prependMessage state.lineNumber "No terminating right math bracket" state.messages
                }

        -- missing right bracket // OK
        (LB _) :: (S fName meta) :: rest ->
            Loop
                { state
                    | committed = errorMessage (errorSuffix rest) :: errorMessage ("[" ++ fName) :: state.committed
                    , stack = []
                    , tokenIndex = meta.index + 1
                    , messages = Helpers.prependMessage state.lineNumber "Missing right bracket" state.messages
                }

        -- space after left bracket // OK
        (LB _) :: (W " " meta) :: _ ->
            Loop
                { state
                    | committed = errorMessage "[ - can't have space after the bracket " :: state.committed
                    , stack = []
                    , tokenIndex = meta.index + 1
                    , messages = Helpers.prependMessage state.lineNumber "Can't have space after left bracket - try [something ..." state.messages
                }

        -- left bracket with nothing after it.  // OK
        (LB _) :: [] ->
            Done
                { state
                    | committed = errorMessage "[...?" :: state.committed
                    , stack = []
                    , tokenIndex = 0
                    , numberOfTokens = 0
                    , messages = Helpers.prependMessage state.lineNumber "That left bracket needs something after it" state.messages
                }

        -- extra right bracket
        (RB meta) :: _ ->
            Loop
                { state
                    | committed = errorMessage " extra ]?" :: state.committed
                    , stack = []
                    , tokenIndex = meta.index + 1
                    , messages = Helpers.prependMessage state.lineNumber "Extra right bracket(s)" state.messages
                }

        -- dollar sign with no closing dollar sign
        (MathToken meta) :: rest ->
            let
                content =
                    Token.toString rest

                message =
                    if content == "" then
                        "$?$"

                    else
                        "$ "
            in
            Loop
                { state
                    | committed = errorMessage message :: state.committed
                    , stack = []
                    , tokenIndex = meta.index + 1
                    , numberOfTokens = 0
                    , messages = Helpers.prependMessage state.lineNumber "opening dollar sign needs to be matched with a closing one" state.messages
                }

        -- backtick with no closing backtick
        (CodeToken meta) :: rest ->
            let
                content =
                    Token.toString rest

                message =
                    if content == "" then
                        "`?`"

                    else
                        "` "
            in
            Loop
                { state
                    | committed = errorMessage message :: state.committed
                    , stack = []
                    , tokenIndex = meta.index + 1
                    , numberOfTokens = 0
                    , messages = Helpers.prependMessage state.lineNumber "opening backtick needs to be matched with a closing one" state.messages
                }

        -- probably a \[ that was not matched ... need to make use of 'errorInfo'
        (TokenError _ meta) :: _ ->
            Loop
                { state
                    | committed = errorMessage "\\[..??" :: state.committed
                    , stack = []
                    , tokenIndex = meta.index + 1
                    , messages = Helpers.prependMessage state.lineNumber "No mathching \\]??" state.messages
                }

        _ ->
            recoverFromUnknownError state


recoverFromUnknownError : State -> Step State State
recoverFromUnknownError state =
    let
        k =
            Symbol.balance <| Symbol.toSymbols (List.reverse state.stack)

        newStack =
            List.repeat k (RB dummyLoc) ++ state.stack

        newSymbols =
            Symbol.toSymbols (List.reverse newStack)

        reducible =
            M.isReducible newSymbols
    in
    if reducible then
        Done <|
            addErrorMessage " ?!?(1) " <|
                reduceState <|
                    { state
                        | stack = newStack
                        , tokenIndex = 0
                        , numberOfTokens = List.length newStack
                        , committed = errorMessage " ?!?(2) " :: state.committed
                        , messages = Helpers.prependMessage state.lineNumber (" ?!?(3) " ++ String.fromInt k ++ " right brackets") state.messages
                    }

    else
        Done
            { state
                | committed =
                    bracketError k
                        :: state.committed
                , messages = Helpers.prependMessage state.lineNumber (bracketErrorAsString k) state.messages
            }



-- ERROR MESSAGES


errorMessageInvisible : String -> Expression
errorMessageInvisible _ =
    Fun "invisible" [ Text "foo" dummyLocWithId ] dummyLocWithId


errorMessage : String -> Expression
errorMessage message =
    Fun "errorHighlight" [ Text message dummyLocWithId ] dummyLocWithId


addErrorMessage : String -> State -> State
addErrorMessage message state =
    let
        committed =
            errorMessage message :: state.committed
    in
    { state | committed = committed }


errorSuffix rest =
    case rest of
        [] ->
            "]?"

        (W _ _) :: [] ->
            "]?"

        _ ->
            ""


bracketError : Int -> Expression
bracketError k =
    if k < 0 then
        let
            brackets =
                List.repeat -k "]" |> String.join ""
        in
        errorMessage <| " " ++ brackets ++ " << Too many right brackets (" ++ String.fromInt -k ++ ")"

    else
        let
            brackets =
                List.repeat k "[" |> String.join ""
        in
        errorMessage <| " " ++ brackets ++ " << Too many left brackets (" ++ String.fromInt k ++ ")"


bracketErrorAsString : Int -> String
bracketErrorAsString k =
    if k < 0 then
        "Too many right brackets (" ++ String.fromInt -k ++ ")"

    else
        "Too many left brackets (" ++ String.fromInt k ++ ")"



-- HELPERS


{-| remove first and last token
-}
unbracket : List a -> List a
unbracket list =
    List.drop 1 (List.take (List.length list - 1) list)


{-| areBracketed tokens == True iff tokens are derived from "[ ... ]"
-}
isExpr : List Token -> Bool
isExpr tokens =
    List.map Token.type_ (List.take 1 tokens)
        == [ TLB ]
        && List.map Token.type_ (List.take 1 (List.reverse tokens))
        == [ TRB ]


{-|

    This is where the id of an expression is created fromm the lie number and token index.

-}
boostMeta : Int -> Int -> { begin : Int, end : Int, index : Int } -> { begin : Int, end : Int, index : Int, id : String }
boostMeta lineNumber tokenIndex { begin, end, index } =
    { begin = begin, end = end, index = index, id = makeId lineNumber tokenIndex }


splitTokens : List Token -> Maybe ( List Token, List Token )
splitTokens tokens =
    case M.match (Symbol.toSymbols tokens) of
        Nothing ->
            Nothing

        Just k ->
            Just (M.splitAt (k + 1) tokens)


splitTokensWithSegment : List Token -> ( List Token, List Token )
splitTokensWithSegment tokens =
    M.splitAt (segLength tokens + 1) tokens


segLength : List Token -> Int
segLength tokens =
    M.getSegment M (tokens |> Symbol.toSymbols) |> List.length


makeId : Int -> Int -> String
makeId lineNumber tokenIndex =
    Config.expressionIdPrefix ++ String.fromInt lineNumber ++ "." ++ String.fromInt tokenIndex


dummyTokenIndex =
    0


dummyLoc =
    { begin = 0, end = 0, index = dummyTokenIndex }


dummyLocWithId : ExprMeta
dummyLocWithId =
    { begin = 0, end = 0, index = dummyTokenIndex, id = "dummy (2)" }
