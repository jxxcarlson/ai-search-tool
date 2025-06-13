module MicroLaTeX.PrimitiveBlock exposing
    ( example
    , example2
    , getLevel
    , p
    , parse
    , parseLoop
    , print
    , printErr
    )

{-|

    The 'parser' function transforms a list of strings into a list of primitive blocks
    for LaTeX, making use of an error recovery strategy in the case of syntax errors,
    e.g., unterminated blocks.

    The strategy is to examine each line in turn, building up a stack of blocks,
    moving them from the stack to the block list as blocks are closed, i.e.,
    are found to be properly terminated.  If the stack is nonempty after all
    blocks have been consumed, we know that there is a syntax error, and
    so an error recovery procedure is invoked.  Error recovery always
    terminates and provides an indication of the nature of the error.

-}

import Dict exposing (Dict)
import Generic.BlockUtilities
import Generic.Language exposing (Heading(..), PrimitiveBlock)
import Generic.Print
import List.Extra
import MicroLaTeX.ClassifyBlock as ClassifyBlock exposing (Classification(..), LXSpecial(..))
import MicroLaTeX.Line as Line exposing (Line)
import MicroLaTeX.Util
import ScriptaV2.Config as Config


type alias State =
    { committedBlocks : List PrimitiveBlock
    , stack : List PrimitiveBlock
    , inVerbatimBlock : Bool
    , holdingStack : List PrimitiveBlock
    , labelStack : List Label
    , lines : List String
    , sourceText : String
    , firstBlockLine : Int
    , indent : Int
    , level : Int
    , lineNumber : Int
    , position : Int
    , blockClassification : Maybe Classification
    , count : Int
    , outerCount : Int
    , idPrefix : String
    , label : String
    }


type alias Label =
    { classification : ClassifyBlock.Classification
    , level : Int
    , status : Status
    , lineNumber : Int
    }


type Status
    = Finished
    | Started
    | Filled


type alias ParserOutput =
    { blocks : List PrimitiveBlock, stack : List PrimitiveBlock, holdingStack : List PrimitiveBlock }


example =
    """\\begin{table}
1 & $x^2$ \\\\
$x^3$ & 666
\\end{table}
"""


example2 =
    """\\begin{textarray}
1 & $x^2$ \\\\
$x^3$ & 666
\\end{textarray}
"""


p str =
    parse "!!" 0 (String.lines str)


parse : String -> Int -> List String -> List PrimitiveBlock
parse idPrefix outerCount lines =
    -- TODO: idPrefix must be used
    lines |> parseLoop idPrefix outerCount |> .blocks


parseLoop : String -> Int -> List String -> ParserOutput
parseLoop idPrefix outerCount lines =
    loop (init idPrefix outerCount lines) nextStep |> finalize


finalize : State -> ParserOutput
finalize state =
    { blocks =
        state.committedBlocks
            |> List.reverse
            |> List.map (\b -> { b | properties = Dict.remove "status" b.properties })
    , stack = state.stack
    , holdingStack = state.holdingStack
    }


{-|

    Recall: classify position lineNumber, where position
    is the position of the first character in the source
    and lineNumber is the index of the current line in the source

-}
init : String -> Int -> List String -> State
init idPrefix outerCount lines =
    { committedBlocks = []
    , stack = []
    , inVerbatimBlock = False
    , holdingStack = []
    , labelStack = []
    , lines = lines
    , sourceText = ""
    , firstBlockLine = 0
    , indent = 0
    , level = -1
    , lineNumber = -1
    , position = 0
    , blockClassification = Nothing
    , count = -1
    , outerCount = 0
    , idPrefix = idPrefix
    , label = "0, START"
    }


verbatimBlocks =
    [ "table", "textarray", "array", "code", "equation", "aligned", "verbatim" ]


{-|

    This is the driver function for the parser's functional loop.

      - Increment state.lineNumber.

      - If the input (state.lines) has been consumed and
            - the stack is empty, return Done state
            - the stack is non empty, return recoverFromError state
      - Let the current raw line be the string at index state.lineNumber of state.lines.
      - Classify the raw line, a value of type Classification:

            type Classification
                = CBeginBlock String
                | CEndBlock String
                | CSpecialBlock LXSpecial
                | CMathBlockDelim
                | CMathBlockBegin
                | CMathBlockEnd
                | CVerbatimBlockDelim
                | CPlainText
                | CEmpty

      - Invoke a handler based on the classification that returns a value
        of type Step State State

-}
nextStep : State -> Step State State
nextStep state_ =
    let
        state =
            { state_
                | lineNumber = state_.lineNumber + 1
                , count = state_.count + 1
                , position = newPosition
            }

        mTopLabel =
            List.head state.labelStack |> Maybe.map .classification

        currentLine__ =
            List.Extra.getAt state_.lineNumber state_.lines

        newPosition =
            case currentLine__ of
                Nothing ->
                    state_.position

                Just currentLine_ ->
                    state_.position + String.length currentLine_
    in
    case List.Extra.getAt state.lineNumber state.lines of
        Nothing ->
            -- no more input, stack empty,so end the parser loop
            if List.isEmpty state.stack then
                Done state

            else
                -- no more input, but stack is empty, so there is an error:
                -- invoke the error recovery procedure
                Loop (recoverFromError state)

        Just rawLine ->
            let
                currentLine =
                    Line.classify (getPosition rawLine state) state.lineNumber rawLine
                        |> Debug.log "CLASSIFY"
            in
            if state.inVerbatimBlock then
                case ClassifyBlock.classify (currentLine.content ++ "\n") of
                    -- DOO
                    CEndBlock label ->
                        if List.member label verbatimBlocks then
                            Loop (state |> handleVerbatimBlock currentLine)

                        else
                            { state | label = "XXX" } |> Loop

                    CMathBlockEnd ->
                        Loop (state |> handleVerbatimBlock currentLine)

                    _ ->
                        { state | label = "XXX" } |> Loop

            else
                nexStepAux currentLine mTopLabel state


nexStepAux : { indent : Int, prefix : String, content : String, lineNumber : Int, position : Int } -> b -> { committedBlocks : List PrimitiveBlock, stack : List PrimitiveBlock, inVerbatimBlock : Bool, holdingStack : List PrimitiveBlock, labelStack : List Label, lines : List String, sourceText : String, firstBlockLine : Int, indent : Int, level : Int, lineNumber : Int, position : Int, blockClassification : Maybe Classification, count : Int, outerCount : Int, idPrefix : String, label : String } -> Step State State
nexStepAux currentLine mTopLabel state =
    case ClassifyBlock.classify (currentLine.content ++ "\n") of
        CBeginBlock label ->
            let
                _ =
                    Debug.log "1." ( label, currentLine.lineNumber )
            in
            if List.member label verbatimBlocks then
                Loop ({ state | inVerbatimBlock = True, label = "CBeginBlock 3" } |> dispatchBeginBlock state.idPrefix state.outerCount (CBeginBlock label) currentLine)

            else
                Loop ({ state | label = "CBeginBlock 3" } |> dispatchBeginBlock state.idPrefix state.outerCount (CBeginBlock label) currentLine)

        CEndBlock label ->
            let
                _ =
                    Debug.log "2." ( label, currentLine.lineNumber )
            in
            -- TODO: changed, review
            if List.member (state.labelStack |> List.reverse |> List.head |> Maybe.map .classification) [ Just <| CBeginBlock "code" ] then
                { state | label = "CEndBlock 2" } |> endBlockOnMatch Nothing (CBeginBlock "code") currentLine |> Loop

            else if List.member (state.labelStack |> List.reverse |> List.head |> Maybe.map .classification) [ Just <| CBeginBlock "equation" ] then
                { state | label = "CEndBlock 3" } |> endBlockOnMatch Nothing (CBeginBlock "equation") currentLine |> Loop

            else if List.member (state.labelStack |> List.reverse |> List.head |> Maybe.map .classification) [ Just <| CBeginBlock "aligned" ] then
                { state | label = "CEndBlock 4" } |> endBlockOnMatch Nothing (CBeginBlock "aligned") currentLine |> Loop

            else if List.member (state.labelStack |> List.reverse |> List.head |> Maybe.map .classification) [ Just <| CBeginBlock "array" ] then
                { state | label = "CEndBlock 4" } |> endBlockOnMatch Nothing (CBeginBlock "array") currentLine |> Loop

            else if List.member (state.labelStack |> List.reverse |> List.head |> Maybe.map .classification) [ Just <| CBeginBlock "textarray" ] then
                { state | label = "CEndBlock 4" } |> endBlockOnMatch Nothing (CBeginBlock "textarray") currentLine |> Loop

            else if List.member (state.labelStack |> List.reverse |> List.head |> Maybe.map .classification) [ Just <| CBeginBlock "verbatim" ] then
                { state | label = "CEndBlock 4" } |> endBlockOnMatch Nothing (CBeginBlock "verbatim") currentLine |> Loop

            else
                endBlock (CEndBlock label) currentLine { state | label = "CEndBlock 5" }

        CSpecialBlock label ->
            let
                _ =
                    Debug.log "3." ( label, currentLine.lineNumber )
            in
            -- TODO: review all the List.member clauses
            if List.member (List.head state.labelStack |> Maybe.map .classification) [ Just <| CBeginBlock "code", Just CMathBlockDelim ] then
                Loop state

            else
                Loop <| handleSpecialBlock (CSpecialBlock label) currentLine state

        CMathBlockDelim ->
            let
                _ =
                    Debug.log "4." currentLine.lineNumber
            in
            -- TODO: changed, review
            case List.head state.labelStack of
                Nothing ->
                    -- TODO: should we indeed set the inVerbatimBlock flag to True here?
                    -- Loop ({ state | inVerbatimBlock = True } |> dispatchBeginBlock state.idPrefix state.outerCount CMathBlockDelim currentLine)
                    Loop (state |> dispatchBeginBlock state.idPrefix state.outerCount CMathBlockDelim currentLine)

                Just label ->
                    if List.member label.classification [ CBeginBlock "code" ] then
                        Loop state

                    else if label.classification == CMathBlockDelim then
                        state |> endBlockOnMatch (Just label) CMathBlockDelim currentLine |> Loop

                    else
                        Loop (state |> dispatchBeginBlock state.idPrefix state.outerCount CMathBlockDelim currentLine)

        CMathBlockBegin ->
            let
                _ =
                    Debug.log "9." currentLine.lineNumber
            in
            Loop ({ state | inVerbatimBlock = True } |> dispatchBeginBlock state.idPrefix state.outerCount CMathBlockBegin currentLine)

        CMathBlockEnd ->
            let
                _ =
                    Debug.log "10." currentLine.lineNumber
            in
            case List.head state.labelStack of
                Just label ->
                    if label.classification == CMathBlockBegin then
                        { state | inVerbatimBlock = False } |> endBlockOnMatch (Just label) CMathBlockEnd currentLine |> Loop

                    else
                        Loop state

                Nothing ->
                    Loop state

        CVerbatimBlockDelim ->
            let
                _ =
                    Debug.log "11." currentLine.lineNumber
            in
            Loop (state |> handleVerbatimBlock currentLine)

        CPlainText ->
            let
                _ =
                    Debug.log "12." ( currentLine.lineNumber, state.labelStack )
            in
            case List.head state.labelStack of
                Just label ->
                    case label.classification of
                        CMathBlockDelim ->
                            Loop state

                        _ ->
                            plainText state currentLine

                Nothing ->
                    plainText state currentLine

        CEmpty ->
            let
                _ =
                    Debug.log "13." currentLine.lineNumber
            in
            emptyLine currentLine state



-- HANDLERS


dispatchBeginBlock : String -> Int -> Classification -> Line -> State -> State
dispatchBeginBlock idPrefix count classifier line state =
    case List.Extra.uncons state.stack of
        -- stack is empty; begin block
        Nothing ->
            beginBlock idPrefix count classifier line state

        -- stack is not empty; change status of stack top if need be, then begin block
        Just ( block, rest ) ->
            beginBlock idPrefix count classifier line { state | stack = changeStatusOfStackTop block rest state }


{-|

    1. Modify the classifier if need be to account for verbatim blocks

    2. Increase the block level, then construct a new block based on the
       new level and the current line; push this block onto the stack.

    3. If the labelStack is nonempty, set the status of the top label to Filled.

    4. Update the state with the results of these computations.

-}
beginBlock : String -> Int -> Classification -> Line -> State -> State
beginBlock idPrefix count classifier line state =
    let
        newBlockClassifier =
            case classifier of
                CBeginBlock name ->
                    if List.member name verbatimBlockNames then
                        Just classifier

                    else
                        Nothing

                _ ->
                    Nothing

        level =
            state.level + 1

        newBlock =
            blockFromLine state.position idPrefix count level line |> elaborate line

        labelStack =
            case List.Extra.uncons state.labelStack of
                Nothing ->
                    state.labelStack

                Just ( label, rest_ ) ->
                    { label | status = Filled } :: rest_
    in
    { state
        | lineNumber = line.lineNumber
        , blockClassification = newBlockClassifier
        , firstBlockLine = line.lineNumber
        , level = level
        , labelStack = { classification = classifier, level = level, status = Started, lineNumber = line.lineNumber } :: labelStack
        , stack = newBlock :: state.stack
    }


handleSpecialBlock : Classification -> Line -> State -> State
handleSpecialBlock classifier line state =
    case List.Extra.uncons state.stack of
        Nothing ->
            handleSpecial_ classifier line state

        Just ( block, rest ) ->
            handleSpecial_ classifier line { state | stack = changeStatusOfStackTop block rest state }


handleSpecial_ : Classification -> Line -> State -> State
handleSpecial_ classifier line state =
    let
        level =
            state.level + 1

        newBlock_ =
            blockFromLine state.position state.idPrefix state.outerCount level line
                -- TODO: should we add line.content to the body?
                |> (\b -> { b | body = b.firstLine :: b.body })
                |> elaborate line

        newBlock =
            case classifier of
                CSpecialBlock (LXItem str) ->
                    -- TODO: use str to modify block content
                    { newBlock_
                        | heading = Ordinary "item"

                        -- TODO: Do we really need to set the firstLine property?
                        , properties = Dict.fromList [ ( "firstLine", String.replace "\\item" "" line.content ) ]
                    }

                CSpecialBlock (LXNumbered str) ->
                    { newBlock_
                        | heading = Ordinary "numbered"
                        , properties = Dict.fromList [ ( "firstLine", String.replace str "" line.content ) ]
                    }

                CSpecialBlock (LXDescription str) ->
                    { newBlock_
                        | heading = Ordinary "desc"
                        , args = [ String.replace "\\desc " "" line.content ]
                        , properties = Dict.fromList [ ( "firstLine", String.replace str "" line.content ) ]
                    }

                CVerbatimBlockDelim ->
                    { newBlock_
                        | heading = Ordinary "numbered"
                        , properties = Dict.fromList [ ( "firstLine", String.replace "```" "" line.content ) ]
                    }

                CSpecialBlock (LXOrdinaryBlock name_) ->
                    -- TODO: more work here and on related issues (see also module ClassifyBlock)
                    let
                        ( name, args ) =
                            case name_ of
                                "banner" ->
                                    ( "banner", [] )

                                "section" ->
                                    ( "section", [ "2" ] )

                                "subsection" ->
                                    ( "section", [ "3" ] )

                                "subsubsection" ->
                                    ( "section", [ "4" ] )

                                "subheading" ->
                                    ( "section", [ "5" ] )

                                "setcounter" ->
                                    ( "setcounter", [ ClassifyBlock.getArg name_ newBlock_.firstLine |> Result.withDefault "1" ] )

                                "shiftandsetcounter" ->
                                    ( "shiftandsetcounter", [ ClassifyBlock.getArg name_ newBlock_.firstLine |> Result.withDefault "1" ] )

                                _ ->
                                    ( name_, [] )
                    in
                    { newBlock_
                        | heading = Ordinary name
                        , args = args
                        , body =
                            case ClassifyBlock.getArg name_ newBlock_.firstLine of
                                Err _ ->
                                    []

                                Ok arg ->
                                    [ arg ]
                        , properties = statusFinished
                    }

                CSpecialBlock (LXVerbatimBlock name) ->
                    { newBlock_
                        | heading = Verbatim name
                    }

                _ ->
                    newBlock_

        labelStack =
            case List.Extra.uncons state.labelStack of
                Nothing ->
                    state.labelStack

                Just ( label, rest_ ) ->
                    { label | status = Filled } :: rest_
    in
    { state
        | lineNumber = line.lineNumber
        , firstBlockLine = line.lineNumber
        , indent = line.indent
        , level = level
        , labelStack = { classification = classifier, level = level, status = Started, lineNumber = line.lineNumber } :: labelStack
        , stack = newBlock :: state.stack
    }


{-|

    This function changes the status of the block on top of the
    stack to Filled if status = Started.

-}
changeStatusOfStackTop : PrimitiveBlock -> List PrimitiveBlock -> State -> List PrimitiveBlock
changeStatusOfStackTop block rest state =
    if (List.head state.labelStack |> Maybe.map .status) == Just Filled then
        state.stack

    else if (List.head state.labelStack |> Maybe.map .status) == Just Started then
        let
            firstBlockLine =
                List.head state.labelStack |> Maybe.map .lineNumber |> Maybe.withDefault 0

            newBlock =
                let
                    body =
                        slice (firstBlockLine + 1) (state.lineNumber - 1) state.lines

                    numberOfLines =
                        List.length body
                in
                -- set the status to Filled and grab lines from state.lines to fill the content field of the block
                { block
                    | body = slice (firstBlockLine + 1) (state.lineNumber - 1) state.lines
                    , properties = statusFilled
                }
                    |> Generic.BlockUtilities.updateMeta (\m -> { m | numberOfLines = numberOfLines })
        in
        newBlock :: rest

    else
        state.stack


{-| We arrive here only from clause CEndBlock of function nextStep.
The classification is that of the current line, e.g. 'CEndBlock "theorem"'
-}
endBlock : Classification -> Line -> State -> Step State State
endBlock classification currentLine state =
    -- TODO: changed, review
    case List.head state.labelStack of
        Nothing ->
            Loop <| { state | level = state.level - 1 }

        Just label ->
            if ClassifyBlock.match label.classification classification && state.level == label.level then
                -- the current classification agrees with the one on top of the stack
                Loop <| endBlockOnMatch (Just label) classification currentLine { state | blockClassification = Nothing }

            else
                -- the current classification disagrees with the one on top of the stack
                Loop <| endBlockOnMismatch label classification currentLine { state | blockClassification = Nothing }


endBlockOnMismatch : Label -> Classification -> Line -> State -> State
endBlockOnMismatch label_ classifier line state =
    case List.Extra.uncons state.stack of
        Nothing ->
            -- TODO: ???
            state

        Just ( block, rest ) ->
            case List.Extra.uncons state.labelStack of
                Nothing ->
                    -- TODO: ???
                    state

                Just ( label, _ ) ->
                    let
                        ( heading, name__ ) =
                            case block.heading of
                                Paragraph ->
                                    ( Paragraph, "-" )

                                Ordinary name_ ->
                                    ( Ordinary name_, name_ )

                                Verbatim name_ ->
                                    if List.member name_ verbatimBlocks then
                                        ( Verbatim "code", "code" )

                                    else
                                        ( Verbatim name_, name_ )

                        body =
                            --- TODO: WTF!?
                            if List.member name__ verbatimBlockNames then
                                getContent label_.classification line state |> List.reverse

                            else
                                getContent label_.classification line state |> List.reverse

                        newBlock =
                            let
                                error =
                                    case ( label.classification, classifier ) of
                                        ( CBeginBlock a, CEndBlock b ) ->
                                            Just <| "Mismatch: \\begin{" ++ a ++ "} ≠ \\end{" ++ b ++ "}"

                                        ( CBeginBlock a, _ ) ->
                                            Just <| "Missing \\end{" ++ a ++ "}"

                                        _ ->
                                            -- TODO: Is this the right thing to do?
                                            Nothing
                            in
                            { block
                                | heading = heading
                                , body = body
                                , args = block.args
                                , properties = statusFinished
                            }
                                |> Generic.BlockUtilities.updateMeta
                                    (\m -> { m | numberOfLines = List.length body, error = error })
                                |> addSource line.content
                    in
                    { state
                        | holdingStack = newBlock :: state.holdingStack
                        , level = state.level - 1
                        , stack = rest
                        , labelStack = List.drop 1 state.labelStack
                    }
                        |> finishBlock line.content
                        |> resolveIfStackEmpty


resolveIfStackEmpty : State -> State
resolveIfStackEmpty state =
    if state.stack == [] then
        { state | committedBlocks = state.holdingStack ++ state.committedBlocks, holdingStack = [] }

    else
        state


finishBlock : String -> State -> State
finishBlock lastLine state =
    case List.Extra.uncons state.stack of
        Nothing ->
            state

        Just ( block, _ ) ->
            let
                updatedBlock =
                    { block | properties = statusFinished }
                        |> Generic.BlockUtilities.updateMeta (\m -> { m | numberOfLines = state.lineNumber - state.firstBlockLine })
                        |> addSource lastLine
            in
            { state
                | committedBlocks = updatedBlock :: state.committedBlocks
                , stack = List.drop 1 state.stack
                , labelStack = List.drop 1 state.labelStack
            }


{-| Be sure to decrement level (both branches of if) when the end of a block is reached.
-}
endBlockOnMatch : Maybe Label -> Classification -> Line -> State -> State
endBlockOnMatch labelHead classifier line state =
    case List.Extra.uncons state.stack of
        Nothing ->
            -- TODO: error state!
            state

        Just ( block, rest ) ->
            if (labelHead |> Maybe.map .status) == Just Filled then
                { state | level = state.level - 1, committedBlocks = ({ block | properties = statusFinished } |> addSource line.content) :: state.committedBlocks, stack = rest } |> resolveIfStackEmpty

            else
                let
                    newBlock =
                        case classifier of
                            CSpecialBlock (LXVerbatimBlock "texComment") ->
                                newBlockWithError
                                    classifier
                                    (getContent classifier line state ++ [ block.firstLine ])
                                    block
                                    |> addSource line.content

                            CSpecialBlock (LXOrdinaryBlock name) ->
                                case name of
                                    "banner" ->
                                        let
                                            listSlice : Int -> Int -> List a -> List a
                                            listSlice start end list =
                                                List.drop start (List.take end list)
                                        in
                                        --{ block | body = listSlice line.lineNumber state.lineNumber state.lines }
                                        let
                                            start =
                                                Maybe.map .lineNumber labelHead |> Maybe.withDefault finish |> (\x -> x + 1)

                                            finish =
                                                state.lineNumber
                                        in
                                        { block | body = listSlice start finish state.lines }

                                    _ ->
                                        block

                            _ ->
                                if List.member classifier (List.map CEndBlock verbatimBlockNames) then
                                    let
                                        sourceText =
                                            getSource line state
                                    in
                                    newBlockWithError classifier
                                        (getContent classifier line state)
                                        (block
                                            |> Generic.BlockUtilities.updateMeta
                                                (\m -> { m | numberOfLines = List.length block.body, sourceText = sourceText })
                                        )

                                else
                                    newBlockWithOutError (getContent classifier line state) block |> addSource line.content
                in
                { state
                    | holdingStack = newBlock :: state.holdingStack

                    -- blocks = newBlock :: state.blocks
                    -- , stack = List.drop 1 (fillBlockOnStack state)
                    -- TODO. I think the change below is OK because (referring to line above),
                    -- when fillBlockOnStack is invoked, it uses the current state, hence
                    -- the values block and rest as defined in Just (block, rest) ->
                    , stack = List.drop 1 (changeStatusOfStackTop block rest state)
                    , labelStack = List.drop 1 state.labelStack
                    , level = state.level - 1
                }
                    |> resolveIfStackEmpty


addSource : String -> PrimitiveBlock -> PrimitiveBlock
addSource lastLine block =
    block
        |> Generic.BlockUtilities.updateMeta
            (\m ->
                { m
                    | sourceText = block.firstLine ++ "\n" ++ String.join "\n" block.body ++ "\n" ++ lastLine
                    , numberOfLines = List.length block.body + 2 -- TODO: problem here?
                }
            )


getError : { a | classification : Classification } -> Classification -> Maybe { error : String }
getError label classifier =
    if label.classification == CPlainText then
        Nothing

    else if ClassifyBlock.classificationString classifier == "missing" then
        Just { error = "Missing end tag (" ++ ClassifyBlock.classificationString label.classification ++ ")" }

    else
        let
            classfication1 =
                "(" ++ ClassifyBlock.classificationString label.classification ++ ")"

            classification2 =
                "(" ++ ClassifyBlock.classificationString classifier ++ ")"
        in
        Just { error = "Missmatched tags: begin" ++ classfication1 ++ " ≠ end" ++ classification2 }


getContent : Classification -> Line -> State -> List String
getContent classifier line state =
    case classifier of
        CPlainText ->
            slice state.firstBlockLine (line.lineNumber - 1) state.lines |> List.reverse

        CSpecialBlock (LXItem str) ->
            -- TODO: trim?
            slice state.firstBlockLine line.lineNumber state.lines
                |> List.reverse
                |> List.map (\line_ -> String.replace str "" line_ |> String.trim)

        CSpecialBlock (LXNumbered str) ->
            -- TODO: trim?
            slice state.firstBlockLine line.lineNumber state.lines
                |> List.reverse
                |> List.map (\line_ -> String.replace str "" line_ |> String.trim)

        CEndBlock _ ->
            -- TODO: is this robust?
            slice (state.firstBlockLine + 1) (line.lineNumber - 1) state.lines |> List.reverse

        _ ->
            slice (state.firstBlockLine + 1) (line.lineNumber - 1) state.lines |> List.reverse


getSource : Line -> State -> String
getSource line state =
    slice state.firstBlockLine line.lineNumber state.lines |> String.join "\n"


newBlockWithOutError : List String -> PrimitiveBlock -> PrimitiveBlock
newBlockWithOutError content block =
    { block
        | body = List.reverse content
        , properties = statusFinished
    }


newBlockWithError : Classification -> List String -> PrimitiveBlock -> PrimitiveBlock
newBlockWithError classifier content block =
    case classifier of
        CMathBlockDelim ->
            { block
                | body = List.reverse content
                , properties = statusFinished
            }
                |> setError (Just "Missing $$ at end")

        CVerbatimBlockDelim ->
            { block
                | body = List.reverse content |> List.map (String.replace "```" "")
                , properties = statusFinished
            }
                |> setError (Just "Missing ``` at end")

        CSpecialBlock (LXItem str) ->
            { block
                | body = List.reverse content |> List.filter (\line_ -> line_ /= "")
                , properties = statusFinished
            }

        CSpecialBlock (LXNumbered str) ->
            { block
                | body = List.reverse content |> List.filter (\line_ -> line_ /= "")
                , properties = statusFinished
            }

        _ ->
            { block | body = List.reverse content, properties = statusFinished }


plainText state_ currentLine =
    let
        state =
            if currentLine.indent > state_.indent then
                { state_ | indent = currentLine.indent, level = state_.level + 1 }

            else if currentLine.indent < state_.indent then
                { state_ | indent = currentLine.indent, level = state_.level - 1 }

            else
                state_
    in
    if (List.head state.labelStack |> Maybe.map .status) == Just Filled || state.labelStack == [] then
        if String.left 1 currentLine.content == "%" then
            Loop (handleComment currentLine state)

        else
            Loop (dispatchBeginBlock state.idPrefix state.outerCount CPlainText currentLine state)

    else
        case List.head state.labelStack of
            Nothing ->
                Loop state

            Just topLabel ->
                if
                    state.level
                        > topLabel.level
                        && (not <|
                                List.member topLabel.classification
                                    [ CBeginBlock "equation"
                                    , CBeginBlock "array"
                                    , CBeginBlock "textarray"
                                    , CBeginBlock "aligned"
                                    ]
                           )
                then
                    Loop (dispatchBeginBlock state.idPrefix state.outerCount CPlainText currentLine state)

                else
                    Loop state


handleComment : Line -> State -> State
handleComment line state =
    let
        newBlock =
            blockFromLine state.position state.idPrefix state.outerCount 0 line
                |> (\b -> { b | heading = Verbatim "texComment" })
                |> Generic.BlockUtilities.updateMeta
                    (\m -> { m | numberOfLines = 1 })

        labelStack =
            case List.Extra.uncons state.labelStack of
                Nothing ->
                    state.labelStack

                Just ( label, rest_ ) ->
                    { label | status = Filled } :: rest_
    in
    { state
        | lineNumber = line.lineNumber
        , firstBlockLine = line.lineNumber
        , indent = line.indent
        , level = 0
        , labelStack = { classification = CSpecialBlock (LXVerbatimBlock "texComment"), level = 0, status = Started, lineNumber = line.lineNumber } :: labelStack
        , stack = newBlock :: state.stack
    }


elaborate : Line -> PrimitiveBlock -> PrimitiveBlock
elaborate line pb =
    if pb.body == [ "" ] then
        pb

    else
        let
            ( name, args_ ) =
                Line.getNameAndArgString line

            namedArgs =
                getKVData args_

            simpleArgs =
                case name of
                    Nothing ->
                        -- not a \begin{??} ... \end{??} block
                        getArgs args_

                    Just name_ ->
                        -- is a \begin{??} ... \end{??} block
                        let
                            prefix =
                                "\\begin{" ++ name_ ++ "}"

                            adjustedLine =
                                String.replace prefix "" line.content
                        in
                        if name_ == "table" || name_ == "tabular" then
                            [ adjustedLine ]

                        else
                            MicroLaTeX.Util.getBracedItems adjustedLine

            properties =
                namedArgs |> prepareList |> prepareKVData

            body =
                case pb.heading of
                    Verbatim _ ->
                        List.map String.trimLeft pb.body

                    _ ->
                        pb.body
        in
        { pb | body = body, heading = updateHeadingWithName name pb.heading, args = simpleArgs, properties = properties }


{-| return all the comma-separated elements of the given Maybe String that contain
the character ':' and hence are potentially elements defining key:value pairs.

    > getKVData (Just "foo:bar, a:b:c, hoho")
    ["foo:bar","a:b:c"]

-}
getKVData : Maybe String -> List String
getKVData mstr =
    case mstr of
        Nothing ->
            []

        Just str ->
            let
                strs =
                    String.split ", " str |> List.map String.trim
            in
            List.filter (\t -> String.contains ":" t) strs


{-| return all the comma-separated elements of the given Maybe String that do not contain
the character ':' and hence are not elements defining key:value pairs.

        > getArgs (Just "foo:bar, a:b:c, hoho")
        ["hoho"]

-}
getArgs : Maybe String -> List String
getArgs mstr =
    case mstr of
        Nothing ->
            []

        Just str ->
            let
                strs =
                    String.split ", " str |> List.map String.trim
            in
            List.filter (\t -> not <| String.contains ":" t) strs


explode : List String -> List (List String)
explode txt =
    List.map (String.split ":") txt


prepareList : List String -> List String
prepareList strs =
    strs |> explode |> List.map fix |> List.concat


fix : List String -> List String
fix strs =
    case strs of
        a :: b :: _ ->
            (a ++ ":") :: b :: []

        a :: [] ->
            a :: []

        [] ->
            []


prepareKVData : List String -> Dict String String
prepareKVData data_ =
    let
        initialState =
            { input = data_, kvList = [], currentKey = Nothing, currentValue = [], kvStatus = KVInKey }
    in
    loop initialState nextKVStep


type alias KVState =
    { input : List String
    , kvList : List ( String, List String )
    , currentKey : Maybe String
    , currentValue : List String
    , kvStatus : KVStatus
    }


type KVStatus
    = KVInKey
    | KVInValue


nextKVStep : KVState -> Step KVState (Dict String String)
nextKVStep state =
    case List.Extra.uncons <| state.input of
        Nothing ->
            let
                kvList_ =
                    case state.currentKey of
                        Nothing ->
                            state.kvList

                        Just key ->
                            ( key, state.currentValue )
                                :: state.kvList
                                |> List.map (\( k, v ) -> ( k, List.reverse v ))
            in
            Done (Dict.fromList (List.map (\( k, v ) -> ( k, String.join " " v )) kvList_))

        Just ( item, rest ) ->
            case state.kvStatus of
                KVInKey ->
                    if String.contains ":" item then
                        case state.currentKey of
                            Nothing ->
                                Loop { state | input = rest, currentKey = Just (String.dropRight 1 item), kvStatus = KVInValue }

                            Just key ->
                                Loop
                                    { input = rest
                                    , currentKey = Just (String.dropRight 1 item)
                                    , kvStatus = KVInValue
                                    , kvList = ( key, state.currentValue ) :: state.kvList
                                    , currentValue = []
                                    }

                    else
                        Loop { state | input = rest }

                KVInValue ->
                    if String.contains ":" item then
                        case state.currentKey of
                            Nothing ->
                                Loop
                                    { state
                                        | input = rest
                                        , currentKey = Just (String.dropRight 1 item)
                                        , currentValue = []
                                        , kvStatus = KVInValue
                                    }

                            Just key ->
                                Loop
                                    { state
                                        | input = rest
                                        , currentKey = Just (String.dropRight 1 item)
                                        , kvStatus = KVInValue
                                        , kvList = ( key, state.currentValue ) :: state.kvList
                                        , currentValue = []
                                    }

                    else
                        Loop { state | input = rest, currentValue = item :: state.currentValue }


emptyLine currentLine state =
    case List.head state.labelStack of
        Nothing ->
            -- { state | blockClassification = Nothing, level = state.level - 1 }
            Loop (resetLevelIfStackIsEmpty state)

        Just label ->
            case label.classification of
                CPlainText ->
                    endBlock CPlainText currentLine state

                CMathBlockDelim ->
                    Loop <| endBlockOnMismatch label CMathBlockDelim currentLine state

                CMathBlockBegin ->
                    -- For math blocks, we'll keep the block open on empty lines
                    Loop state

                CMathBlockEnd ->
                    -- This case shouldn't occur, but we'll handle it just in case
                    Loop (resetLevelIfStackIsEmpty state)

                CBeginBlock name ->
                    if List.member name verbatimBlocks then
                        -- equation and aligned blocks are terminated if an empty line is encountered
                        Loop <| endBlockOnMismatch label (CBeginBlock name) currentLine state

                    else
                        -- if the top of the labelstack is  (CBeginBlock name) and empty line
                        -- is encountered, keep going to try to find (CEndBlock name)
                        Loop <| state

                CSpecialBlock LXPseudoBlock ->
                    endBlock (CSpecialBlock (LXItem "")) currentLine state

                CSpecialBlock (LXItem str) ->
                    endBlock (CSpecialBlock (LXItem str)) currentLine state

                CSpecialBlock (LXDescription str) ->
                    endBlock (CSpecialBlock (LXDescription str)) currentLine state

                CSpecialBlock (LXNumbered str) ->
                    endBlock (CSpecialBlock (LXNumbered str)) currentLine state

                CSpecialBlock (LXOrdinaryBlock name) ->
                    endBlock (CSpecialBlock (LXOrdinaryBlock name)) currentLine state

                CSpecialBlock (LXVerbatimBlock name) ->
                    endBlock (CSpecialBlock (LXVerbatimBlock name)) currentLine state

                CEndBlock _ ->
                    Loop (resetLevelIfStackIsEmpty state)

                CVerbatimBlockDelim ->
                    Loop (resetLevelIfStackIsEmpty state)

                CEmpty ->
                    Loop (resetLevelIfStackIsEmpty state)


resetLevelIfStackIsEmpty : State -> State
resetLevelIfStackIsEmpty state =
    if List.isEmpty state.stack then
        { state | level = -1 }

    else
        state


handleMathBlock : Line -> State -> State
handleMathBlock line state =
    case List.head state.labelStack of
        Nothing ->
            { state
                | lineNumber = line.lineNumber
                , firstBlockLine = line.lineNumber
                , indent = line.indent
                , level = state.level + 1
                , labelStack = { classification = CMathBlockDelim, level = state.level + 1, status = Started, lineNumber = line.lineNumber } :: state.labelStack
                , stack = blockFromLine state.position state.idPrefix state.outerCount (state.level + 1) line :: state.stack
            }

        Just label ->
            case List.Extra.uncons state.stack of
                Nothing ->
                    state

                Just ( block, rest ) ->
                    case List.Extra.uncons state.labelStack of
                        Nothing ->
                            state

                        Just ( topLabel, otherLabels ) ->
                            let
                                body =
                                    slice (topLabel.lineNumber + 1) (state.lineNumber - 1) state.lines

                                newBlock =
                                    { block | body = body, properties = statusFinished }
                                        |> addSource "$$"
                                        |> Generic.BlockUtilities.updateMeta (\m -> { m | numberOfLines = List.length body })
                            in
                            { state | committedBlocks = newBlock :: state.committedBlocks, labelStack = otherLabels, stack = rest, level = state.level - 1 }


handleVerbatimBlock line state =
    case List.Extra.uncons state.stack of
        Nothing ->
            state

        Just ( block, rest ) ->
            case List.Extra.uncons state.labelStack of
                Nothing ->
                    state

                Just ( topLabel, otherLabels ) ->
                    let
                        newBlock =
                            { block | body = slice (topLabel.lineNumber + 1) (state.lineNumber - 1) state.lines, properties = statusFinished } |> addSource line.content
                    in
                    { state | inVerbatimBlock = False, committedBlocks = newBlock :: state.committedBlocks, labelStack = otherLabels, stack = rest, level = state.level - 1 }



-- ERROR RECOVERY


recoverFromError : State -> State
recoverFromError state =
    case List.Extra.unconsLast state.stack of
        Nothing ->
            state

        Just ( block, _ ) ->
            case List.Extra.unconsLast state.labelStack of
                Nothing ->
                    state

                Just ( topLabel, _ ) ->
                    let
                        firstLineNumber =
                            topLabel.lineNumber

                        lastLineNumber =
                            state.lineNumber

                        provisionalContent =
                            case topLabel.status of
                                Filled ->
                                    -- the block is Filled, so its content is already set
                                    block.body

                                _ ->
                                    -- the block is not filled, so we grab it content from state.lines
                                    slice (firstLineNumber + 1) lastLineNumber state.lines

                        body =
                            -- remove blank lines
                            -- TODO: is this the right thing to do?
                            List.Extra.takeWhile (\item -> item /= "") provisionalContent

                        revisedContent =
                            -- drop the last line if it is "\\end{...}"
                            case List.Extra.last body of
                                Nothing ->
                                    body

                                Just str ->
                                    if String.left 4 str == "\\end" then
                                        MicroLaTeX.Util.dropLast body

                                    else
                                        body

                        lineNumber =
                            -- set the line number to be just past the current block
                            firstLineNumber + List.length body + 1

                        newBlock =
                            -- set the content of the block, declare it to be finished,
                            -- and add and error message
                            { block
                                | body = revisedContent
                                , properties = statusFinished
                            }
                                |> setError (missingTagError block)
                                |> addSource ""
                    in
                    { state
                        | committedBlocks = newBlock :: state.committedBlocks
                        , stack = []
                        , holdingStack = []
                        , labelStack = []
                        , lineNumber = lineNumber
                        , blockClassification = Nothing
                    }


missingTagError : PrimitiveBlock -> Maybe String
missingTagError block =
    case block.heading of
        Ordinary "item" ->
            Nothing

        Verbatim "math" ->
            Just "Missing \\end{math}"

        Verbatim "code" ->
            Just "Missing \\end{code}"

        _ ->
            Nothing


slice : Int -> Int -> List a -> List a
slice a b list =
    list |> List.take (b + 1) |> List.drop a


transfer : State -> State
transfer state =
    state



--- PRINT


printErr : PrimitiveBlock -> String
printErr block =
    showError block.meta.error


{-| Used for debugging with CLI.LXPB
-}
print : PrimitiveBlock -> String
print block =
    Generic.Print.print block


showProperties : Dict String String -> String
showProperties dict =
    dict |> Dict.toList |> List.map (\( k, v ) -> k ++ ": " ++ v) |> String.join ", "


showArgs : List String -> String
showArgs args =
    args |> String.join ", "


showError : Maybe String -> String
showError mError =
    Generic.Print.showError mError


showName : Maybe String -> String
showName mstr =
    case mstr of
        Nothing ->
            "(anon)"

        Just name ->
            name


showStatus : Status -> String
showStatus status =
    case status of
        Finished ->
            "Finished"

        Started ->
            "Started"

        Filled ->
            "Filled"



--- HELPERS


{-| Construct a skeleton block given one line of text, .e.g.,

        \begin{equation}

-}
blockFromLine : Int -> String -> Int -> Int -> Line -> PrimitiveBlock
blockFromLine statePosition idPrefix count level ({ indent, lineNumber, position, prefix, content } as line) =
    { heading = getHeading line.content

    -- @@NOTE: the line below is essential for correctly setting the indentation
    -- of the blocks, hence to constructing the proper tree structure
    , indent = indent
    , args = []
    , properties = statusStarted |> Dict.insert "level" (String.fromInt level)
    , firstLine = line.content
    , body = []
    , meta =
        { position =
            if statePosition == 0 then
                0

            else
                statePosition + 2

        -- TODO: GET THIS RIGHT!
        , lineNumber = lineNumber
        , numberOfLines = 0
        , id = Config.idPrefix ++ "-" ++ String.fromInt lineNumber
        , messages = []
        , sourceText = ""
        , error = Nothing
        }
    , style = Nothing
    }



-- HELPERS


updateHeadingWithName : Maybe String -> Generic.Language.Heading -> Generic.Language.Heading
updateHeadingWithName name_ heading =
    case name_ of
        Nothing ->
            heading

        Just name ->
            case heading of
                Paragraph ->
                    Paragraph

                Ordinary "tabular" ->
                    Ordinary "table"

                Ordinary _ ->
                    Ordinary name

                Verbatim _ ->
                    Verbatim name


setError : Maybe String -> PrimitiveBlock -> PrimitiveBlock
setError error =
    Generic.BlockUtilities.updateMeta (\m -> { m | error = error })


setLevel : Int -> PrimitiveBlock -> PrimitiveBlock
setLevel level block =
    { block | properties = Dict.insert "level" (String.fromInt level) block.properties }


getLevel : PrimitiveBlock -> Maybe Int
getLevel block =
    case Dict.get "level" block.properties of
        Nothing ->
            Nothing

        Just str ->
            String.toInt str |> Maybe.withDefault 0 |> Just


statusFinished =
    Dict.singleton "status" "finished"


statusStarted =
    Dict.singleton "status" "started"


statusFilled =
    Dict.singleton "status" "filled"


verbatimBlockNames =
    [ "equation"
    , "table"
    , "array"
    , "textarray"
    , "aligned"
    , "math"
    , "code"
    , "verbatim"
    , "verse"
    , "mathmacros"
    , "textmacros"
    , "hide"
    , "docinfo"
    , "datatable"
    , "chart"
    , "svg"
    , "quiver"
    , "image"
    , "tikz"
    , "load-files"
    , "include"
    , "iframe"
    ]


getHeading : String -> Generic.Language.Heading
getHeading str =
    case ClassifyBlock.classify str of
        CBeginBlock label ->
            if List.member label verbatimBlockNames then
                Verbatim label

            else
                Ordinary label

        CMathBlockDelim ->
            Verbatim "math"

        CVerbatimBlockDelim ->
            Verbatim "code"

        CMathBlockBegin ->
            Verbatim "math"

        CMathBlockEnd ->
            Verbatim "math"

        _ ->
            Paragraph


type Step state a
    = Loop state
    | Done a


loop : state -> (state -> Step state a) -> a
loop s f =
    case f s of
        Loop s_ ->
            loop s_ f

        Done b ->
            b


dropLast : List a -> List a
dropLast list =
    List.take (List.length list - 1) list


isEmpty : Line -> Bool
isEmpty line =
    String.replace " " "" line.content == ""


getPosition : String -> State -> Int
getPosition rawLine state =
    if rawLine == "" then
        state.position + 1

    else
        state.position + String.length rawLine + 1
