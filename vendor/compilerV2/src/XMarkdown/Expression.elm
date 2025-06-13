module XMarkdown.Expression exposing
    ( State
    , eval
    , evalList
    , extractMessages
    , isReducible
    , parse
    , parseToState
    )

-- import L0.Parser.Expression

import Generic.Language exposing (Expr(..), Expression)
import List.Extra
import M.Expression exposing (parseWithMessages)
import ScriptaV2.Config as Config
import Tools.Loop exposing (Step(..), loop)
import XMarkdown.ForkLog as Tools
import XMarkdown.Match as M
import XMarkdown.Meta as Meta
import XMarkdown.Symbol as Symbol exposing (Symbol(..))
import XMarkdown.Token as Token exposing (Token(..), TokenType(..))


forkLogWidth =
    12



-- TYPES


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


extractMessages : State -> List String
extractMessages state =
    state.messages



-- STATE FOR THE PARSER


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



-- Exposed functions


parse : Int -> String -> List Expression
parse lineNumber str =
    str
        |> Token.run
        |> Tools.forklogCyan "TOKENS" forkLogWidth Token.toString2
        |> initWithTokens lineNumber
        |> run
        |> .committed
        |> Tools.forklogCyan "LENGTH" forkLogWidth List.length


parseTokens : Int -> List Token -> List Expression
parseTokens lineNumber tokens =
    tokens
        |> Tools.forklogCyan "TOKENS" forkLogWidth Token.toString2
        |> initWithTokens lineNumber
        |> run
        |> .committed
        |> Tools.forklogCyan "LENGTH" forkLogWidth List.length


parseToState : Int -> String -> State
parseToState lineNumber str =
    str
        |> Token.run
        |> initWithTokens lineNumber
        |> run



-- PARSER


run : State -> State
run state =
    loop state nextStep
        |> (\state_ -> { state_ | committed = List.reverse state_.committed })


nextStep : State -> Step State State
nextStep state =
    case List.Extra.getAt state.tokenIndex state.tokens of
        Nothing ->
            if List.isEmpty state.stack then
                Done state

            else
                -- the stack is not empty, so we need to handle the parse error
                recoverFromError (state |> Tools.forklogBlue "RECOVER" 12 (.stack >> List.reverse >> Token.toString2))

        Just token ->
            state
                |> advanceTokenIndex
                |> pushToken token
                |> Tools.forklogBlue "STACK" forkLogWidth (.stack >> Token.toString2)
                |> reduceState
                |> (\st -> { st | step = st.step + 1 })
                |> Loop


advanceTokenIndex : State -> State
advanceTokenIndex state =
    { state | tokenIndex = state.tokenIndex + 1 }



-- PUSH


pushToken : Token -> State -> State
pushToken token state =
    case token of
        S str meta ->
            if String.right 1 str == " " then
                pushOrCommit token state

            else
                case List.Extra.getAt (meta.index + 1) state.tokens of
                    Just (Italic meta_) ->
                        state |> push token |> push (Italic meta_) |> advanceTokenIndex

                    Just (Bold meta_) ->
                        state |> push token |> push (Bold meta_) |> advanceTokenIndex

                    _ ->
                        -- TODO: this is the place!
                        pushOrCommit token state

        W _ _ ->
            pushOrCommit token state

        _ ->
            pushOnStack token state


pushOnStack : Token -> State -> State
pushOnStack token state =
    { state | stack = token :: state.stack }


pushOrCommit : Token -> State -> State
pushOrCommit token state =
    if List.isEmpty state.stack then
        commit token state

    else
        push token state


commit : Token -> State -> State
commit token state =
    case exprOfToken token of
        Nothing ->
            state

        Just expr ->
            -- TODO: the "0" below is problematics, but I am using this rather than token.index
            -- TODO: in order to match what the TOC needs
            { state | committed = Generic.Language.updateMeta (\m -> { m | id = makeId state.lineNumber 0 }) expr :: state.committed }


exprOfToken : Token -> Maybe Expression
exprOfToken token =
    case token of
        S str loc ->
            Just (Text str loc)

        W str loc ->
            Just (Text str loc)

        _ ->
            Nothing


push : Token -> State -> State
push token state =
    { state | stack = token :: state.stack }



-- REDUCE


reduceState : State -> State
reduceState state =
    let
        -- peek : Maybe Token
        reducible1 =
            isReducible state.stack |> Tools.forklogRed "SYMBOLS (!!)" forkLogWidth identity
    in
    -- if state.tokenIndex >= state.numberOfTokens || (reducible1 && not (isLBToken peek)) then
    if state.tokenIndex >= state.numberOfTokens || reducible1 then
        let
            symbols =
                state.stack |> Symbol.convertTokens |> List.reverse |> Tools.forklogRed "SYMBOLS" forkLogWidth identity
        in
        case List.head symbols of
            Just SAT ->
                handleAt state

            Just M ->
                handleMathSymbol symbols state

            Just C ->
                handleCodeSymbol symbols state

            Just SBold ->
                case symbols of
                    SBold :: SItalic :: _ ->
                        case List.reverse symbols of
                            SBold :: SItalic :: _ ->
                                handleBoldItalic state

                            _ ->
                                state

                    _ ->
                        handleBoldSymbol symbols state

            Just SItalic ->
                handleItalicSymbol symbols state

            Just LBracket ->
                if symbols == [ LBracket, RBracket, LParen, RParen ] then
                    handleLink state

                else
                    handleBracketedText state |> Tools.forklogRed "HANDLE[]" forkLogWidth identity

            --else
            --    state
            Just SImage ->
                handleImage state

            Just LParen ->
                handleParens state

            _ ->
                state

    else
        state


takeMiddleReversed : List a -> List a
takeMiddleReversed list =
    list
        |> List.drop 1
        |> List.reverse
        |> List.drop 1


takeMiddle : List a -> List a
takeMiddle list =
    list
        |> List.take (List.length list - 1)
        |> List.drop 1


handleLink : State -> State
handleLink state =
    let
        expr =
            case state.stack of
                [ RP _, S url _, LP _, RB _, S linkText _, LB _ ] ->
                    Fun "link" [ Text (linkText ++ " " ++ url) meta ] meta

                [ RP _, LP _, RB _, S linkText _, LB _ ] ->
                    Fun "red" [ Text ("[" ++ linkText ++ "](no label)") meta ] meta

                [ RP _, S url _, LP _, RB _, LB _ ] ->
                    Fun "red" [ Text ("[Link: no label](" ++ url ++ ")") meta ] meta

                _ ->
                    Fun "red" [ Text "[Link: no label or url]" meta ] meta

        meta =
            { begin = 0, end = 0, index = 0, id = makeId state.lineNumber state.tokenIndex }
    in
    { state | committed = expr :: state.committed, stack = [] }


handleBracketedText : State -> State
handleBracketedText state =
    let
        str =
            case state.stack of
                [ RP _, S str_ _, LP _ ] ->
                    "[" ++ str_ ++ "]"

                _ ->
                    state.stack |> List.reverse |> Token.toString

        meta =
            { begin = 0, end = 0, index = 0, id = makeId state.lineNumber state.tokenIndex }

        expr =
            Text str meta
    in
    { state | committed = expr :: state.committed, stack = [] }


handleImage : State -> State
handleImage state =
    let
        data =
            case state.stack of
                [ RP _, S url _, LP _, RB _, S label _, LB _, Image _ ] ->
                    { label = label, url = url }

                _ ->
                    { label = "no image label", url = "no image url" }

        expr =
            Fun "image" [ Text (data.url ++ " " ++ data.label) meta ] meta |> Tools.forklogRed "EXPR" forkLogWidth identity

        meta =
            { begin = 0, end = 0, index = 0, id = makeId state.lineNumber state.tokenIndex }
    in
    { state | committed = expr :: state.committed, stack = [] }


handleAt : State -> State
handleAt state =
    let
        content =
            state.stack
                |> List.reverse
                |> Token.toString
                |> String.dropLeft 1
                |> Tools.forklogRed "STACK (AT)" forkLogWidth identity

        expr : List Expression
        expr =
            parseWithMessages 0 content |> Tuple.first
    in
    { state | committed = expr ++ state.committed, stack = [] }


handleParens : State -> State
handleParens state =
    let
        str =
            case state.stack of
                [ RP _, S str_ _, LP _ ] ->
                    "(" ++ str_ ++ ")"

                _ ->
                    state.stack |> List.reverse |> Token.toString

        meta =
            { begin = 0, end = 0, index = 0, id = makeId state.lineNumber state.tokenIndex }

        expr =
            Text str meta
    in
    { state | committed = expr :: state.committed, stack = [] }


handleS : State -> State
handleS state =
    let
        str =
            case state.stack of
                [ S str_ _ ] ->
                    str_

                _ ->
                    state.stack |> List.reverse |> Token.toString

        meta =
            { begin = 0, end = 0, index = 0, id = makeId state.lineNumber state.tokenIndex }

        expr =
            Text str meta
    in
    { state | committed = expr :: state.committed, stack = [] }


handleItalicSymbol : List Symbol -> State -> State
handleItalicSymbol symbols state =
    if List.head symbols == Just SItalic && List.Extra.last symbols == Just SItalic then
        let
            meta =
                { begin = 0, end = 0, index = 0, id = makeId state.lineNumber state.tokenIndex }

            innerExprs : List Expression
            innerExprs =
                takeMiddle state.stack |> parseTokens 0

            expr =
                Fun "italic" innerExprs meta
        in
        { state | stack = [], committed = expr :: state.committed }

    else
        state


handleBoldSymbol : List Symbol -> State -> State
handleBoldSymbol symbols state =
    if List.head symbols == Just SBold && List.Extra.last symbols == Just SBold then
        let
            meta =
                { begin = 0, end = 0, index = 0, id = makeId state.lineNumber state.tokenIndex }

            innerExprs : List Expression
            innerExprs =
                takeMiddle state.stack |> parseTokens 0

            expr =
                Fun "bold" innerExprs meta
        in
        { state | stack = [], committed = expr :: state.committed }

    else
        state


handleBoldItalic : State -> State
handleBoldItalic state =
    let
        n =
            List.length state.stack

        inner =
            state.stack |> List.take (n - 2) |> List.drop 2

        exprs =
            parseTokens 0 inner

        meta =
            { begin = 0, end = 0, index = 0, id = makeId state.lineNumber state.tokenIndex }

        expr =
            Fun "bold" [ Fun "italic" exprs meta ] meta
    in
    { state | stack = [], committed = expr :: state.committed }


handleMathSymbol : List Symbol -> State -> State
handleMathSymbol symbols state =
    if symbols == [ M, M ] then
        let
            content =
                takeMiddleReversed state.stack |> Token.toString2

            expr =
                VFun "math" content { begin = 0, end = 0, index = 0, id = makeId state.lineNumber state.tokenIndex }
        in
        { state | stack = [], committed = expr :: state.committed }

    else
        state


handleCodeSymbol : List Symbol -> State -> State
handleCodeSymbol symbols state =
    if symbols == [ C, C ] then
        let
            content =
                takeMiddleReversed state.stack |> Token.toString2

            expr =
                VFun "code" content { begin = 0, end = 0, index = 0, id = makeId state.lineNumber state.tokenIndex }
        in
        { state | stack = [], committed = expr :: state.committed }

    else
        state


eval : Int -> List Token -> List Expression
eval lineNumber tokens =
    case tokens of
        (S t m2) :: rest ->
            Text t m2 :: evalList Nothing lineNumber rest

        _ ->
            errorMessage2Part "\\" "{??}(5)"


evalList : Maybe String -> Int -> List Token -> List Expression
evalList macroName lineNumber tokens =
    case List.head tokens of
        Just token ->
            case Token.type_ token of
                TLB ->
                    case M.match (Symbol.convertTokens tokens) of
                        Nothing ->
                            errorMessage3Part ("\\" ++ (macroName |> Maybe.withDefault "x")) (Token.toString2 tokens) " ?}"

                        Just k ->
                            let
                                ( a, b ) =
                                    M.splitAt (k + 1) tokens

                                aa =
                                    -- drop the leading and trailing LB, RG
                                    a |> List.take (List.length a - 1) |> List.drop 1
                            in
                            eval lineNumber aa
                                ++ evalList Nothing lineNumber b

                _ ->
                    case exprOfToken token of
                        Just expr ->
                            expr
                                :: evalList Nothing lineNumber (List.drop 1 tokens)

                        Nothing ->
                            [ errorMessage "•••?(7)" ]

        _ ->
            []


errorMessage2Part : String -> String -> List Expression
errorMessage2Part a b =
    [ Fun "red" [ Text b dummyLocWithId ] dummyLocWithId, Fun "blue" [ Text a dummyLocWithId ] dummyLocWithId ]


errorMessage3Part : String -> String -> String -> List Expression
errorMessage3Part a b c =
    [ Fun "blue" [ Text a dummyLocWithId ] dummyLocWithId, Fun "blue" [ Text b dummyLocWithId ] dummyLocWithId, Fun "red" [ Text c dummyLocWithId ] dummyLocWithId ]


errorMessage : String -> Expression
errorMessage message =
    Fun "red" [ Text message dummyLocWithId ] dummyLocWithId


errorMessageBold : String -> Expression
errorMessageBold message =
    Fun "bold" [ Fun "red" [ Text message dummyLocWithId ] dummyLocWithId ] dummyLocWithId


isReducible : List Token -> Bool
isReducible tokens =
    let
        preliminary =
            tokens |> List.reverse |> Symbol.convertTokens |> List.filter (\sym -> sym /= O) |> Tools.forklogYellow "SYMBOLS" forkLogWidth identity
    in
    if preliminary == [] then
        False

    else
        preliminary |> M.reducible |> Tools.forklogYellow "REDUCIBLE ?" forkLogWidth identity



-- TODO: finish recoverFromError


recoverFromError : State -> Step State State
recoverFromError state =
    case List.reverse state.stack of
        (S content meta) :: (Italic _) :: rest ->
            Loop
                { state
                    | tokens =
                        state.tokens
                            |> Token.changeTokenContentAt meta.index (String.trim content)
                            |> insertAt meta.index (Italic meta)
                            |> Token.changeTokenIndicesFrom (meta.index + 1) 1
                    , tokenIndex = meta.index
                    , stack = []
                    , committed = Fun "pink" [ Text " *" dummyLocWithId ] dummyLocWithId :: state.committed
                }

        (S content meta) :: (Bold _) :: rest ->
            Loop
                { state
                    | tokens =
                        state.tokens
                            |> Token.changeTokenContentAt meta.index (String.trim content)
                            |> insertAt meta.index (Bold meta)
                            |> Token.changeTokenIndicesFrom (meta.index + 1) 1
                    , tokenIndex = meta.index
                    , stack = []
                    , committed = Fun "pink" [ Text " **" dummyLocWithId ] dummyLocWithId :: state.committed
                }

        (LB _) :: (S txt meta) :: (RB _) :: [] ->
            Loop { state | stack = [], committed = Text ("[" ++ txt ++ "]") meta :: [] }

        (Italic meta) :: [] ->
            if List.isEmpty state.committed then
                Loop { state | stack = [], committed = errorMessage "*" :: [] }

            else
                let
                    expr =
                        case List.head state.committed of
                            Just (Text str1 meta1) ->
                                Fun "italic" [ Text str1 meta1 ] meta1

                            _ ->
                                Fun "italic" [ Text "??" meta ] meta
                in
                Loop
                    { state
                        | stack = []
                        , committed = expr :: errorMessage "*?1" :: List.drop 1 state.committed
                        , tokenIndex = meta.index + 1
                        , messages = [ "!!" ]
                    }

        (Italic meta1) :: (S str meta2) :: [] ->
            Loop
                { state
                    | stack = []
                    , committed =
                        Fun "pink" [ Text "* " dummyLocWithId ] dummyLocWithId
                            :: Fun "italic" [ Text str dummyLocWithId ] dummyLocWithId
                            :: state.committed
                    , tokenIndex = meta2.index + 1
                }

        (Italic meta1) :: (S str meta2) :: (Bold meta3) :: [] ->
            Loop
                { state
                    | stack = []
                    , committed =
                        Fun "pink" [ Text "* << extra? " dummyLocWithId ] dummyLocWithId
                            :: Fun "italic" [ Text str dummyLocWithId ] dummyLocWithId
                            :: state.committed
                    , tokenIndex = meta3.index + 1
                }

        (Italic meta1) :: (S str meta2) :: (Bold meta3) :: rest ->
            if String.right 1 str == " " then
                Loop
                    { state
                        | stack = []
                        , committed =
                            Fun "pink" [ Text "* " dummyLocWithId ] dummyLocWithId
                                :: Fun "italic" [ Text str dummyLocWithId ] dummyLocWithId
                                :: state.committed
                        , tokenIndex = meta3.index
                    }

            else
                Loop
                    { state
                        | stack = []
                        , committed =
                            Fun "pink" [ Text "* << extra? " dummyLocWithId ] dummyLocWithId
                                :: Fun "italic" [ Text str dummyLocWithId ] dummyLocWithId
                                :: state.committed
                        , tokenIndex = meta3.index + 1
                    }

        (Italic meta1) :: (S str meta2) :: rest ->
            Loop
                { state
                    | stack = []
                    , committed =
                        Fun "pink" [ Text "* " dummyLocWithId ] dummyLocWithId
                            :: Fun "italic" [ Text str dummyLocWithId ] dummyLocWithId
                            :: state.committed
                    , tokenIndex = meta2.index + 1
                }

        (Italic meta1) :: rest ->
            case List.Extra.last rest of
                Just (Bold meta2) ->
                    Loop
                        { state
                            | stack = []
                            , tokens =
                                List.Extra.setAt meta2.index (Italic meta2) state.tokens
                                    |> insertAt meta2.index (S "* << extra? " { meta2 | index = meta2.index + 1 })
                                    |> Token.changeTokenIndicesFrom (meta2.index + 2) 1
                            , tokenIndex = meta2.index + 2
                        }

                Just _ ->
                    Loop
                        { state
                            | stack = []
                            , committed = state.committed ++ (errorMessage "*??1a" :: List.drop 1 state.committed)
                            , tokenIndex = meta1.index + 1
                            , messages = [ "!!" ]
                        }

                Nothing ->
                    Loop
                        { state
                            | stack = []
                            , committed = state.committed ++ (errorMessage "*??1b" :: List.drop 1 state.committed)
                            , tokenIndex = meta1.index + 1
                            , messages = [ "!!" ]
                        }

        (Bold meta) :: [] ->
            if List.isEmpty state.committed then
                Loop { state | stack = [], committed = errorMessage "**" :: [] }

            else
                let
                    expr =
                        case List.head state.committed of
                            Just (Text str1 meta1) ->
                                Fun "bold" [ Text str1 meta1 ] meta1

                            _ ->
                                Fun "bold" [ Text "??" meta ] meta
                in
                Loop
                    { state
                        | stack = []
                        , committed = expr :: errorMessage "**?2" :: List.drop 1 state.committed
                        , tokenIndex = meta.index + 1
                        , messages = [ "!!" ]
                    }

        (Bold _) :: (S str meta) :: [] ->
            Loop
                { state
                    | stack = []
                    , committed = errorMessage "** " :: Fun "bold" [ Text str meta ] meta :: state.committed
                    , tokenIndex = meta.index + 1
                    , messages = [ "!!" ]
                }

        (Bold meta1) :: (S str meta2) :: (Italic meta3) :: rest ->
            Loop
                { state
                    | stack = []
                    , committed =
                        errorMessage "* "
                            :: Fun "bold" [ Text str dummyLocWithId ] dummyLocWithId
                            :: state.committed
                    , tokenIndex = meta3.index + 1
                    , messages = [ "!!" ]
                }

        -- dollar sign with no closing dollar sign
        (MathToken meta) :: rest ->
            let
                content =
                    Token.toString2 rest

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
                    , messages = prependMessage state.lineNumber "opening dollar sign needs to be matched with a closing one" state.messages
                }

        -- backtick with no closing backtick
        (CodeToken meta) :: rest ->
            let
                content =
                    Token.toString2 rest

                message =
                    if content == "" then
                        "`?`"

                    else
                        "` "
            in
            Loop
                { state
                    | committed = errorMessageBold message :: state.committed
                    , stack = []
                    , tokenIndex = meta.index + 1
                    , numberOfTokens = 0
                    , messages = prependMessage state.lineNumber "opening backtick needs to be matched with a closing one" state.messages
                }

        _ ->
            Done { state | committed = Fun "red" [ Text (Token.toString (List.reverse state.stack)) Meta.dummy ] Meta.dummy :: state.committed, stack = [] }


makeId : Int -> Int -> String
makeId lineNumber tokenIndex =
    Config.expressionIdPrefix ++ String.fromInt lineNumber ++ "." ++ String.fromInt tokenIndex



-- HELPERS


insertAt : Int -> a -> List a -> List a
insertAt k a list =
    let
        ( p, q ) =
            List.Extra.splitAt k list
    in
    p ++ (a :: q)


dummyTokenIndex =
    0


dummyLocWithId =
    { begin = 0, end = 0, index = dummyTokenIndex, id = "dummy (3)" }


prependMessage : Int -> String -> List String -> List String
prependMessage lineNumber message messages =
    (message ++ " (line " ++ String.fromInt lineNumber ++ ")") :: List.take 2 messages
