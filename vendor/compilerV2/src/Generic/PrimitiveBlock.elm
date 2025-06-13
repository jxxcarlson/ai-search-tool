module Generic.PrimitiveBlock exposing
    ( empty, parse
    , ParserFunctions, bogusBlockFromLine, eq, length, listLength, raiseBlockLevelsIfNeeded_
    )

{-| The main function is

    parse : String -> List String -> List PrimitiveBlock

@docs PrimitiveBlock, empty, parse

-}

import Dict exposing (Dict)
import Generic.BlockUtilities
import Generic.Language exposing (BlockMeta, Heading(..), PrimitiveBlock, emptyBlockMeta)
import Generic.Line as Line exposing (HeadingData, HeadingError, Line)
import List.Extra
import Tools.Loop exposing (Step(..), loop)
import Tools.Utility


{-| Parse a list of strings into a list of primitive blocks given
a function for determining when a string is the first line
of a verbatim block

NOTE (TODO) for the moment we assume that the input ends with
a blank line.

-}
parse : ParserFunctions -> String -> Int -> List String -> List PrimitiveBlock
parse functionData initialId outerCount lines =
    loop (init functionData initialId outerCount lines) nextStep


type alias ParserFunctions =
    { isVerbatimBlock : String -> Bool
    , getHeadingData : String -> Result HeadingError HeadingData
    , findSectionPrefix : String -> Maybe String
    }


type alias State =
    { parserFunctions : ParserFunctions
    , blocks : List PrimitiveBlock
    , currentBlock : Maybe PrimitiveBlock
    , lines : List String -- the input
    , idPrefix : String -- the prefix used for block ids
    , inBlock : Bool
    , indent : Int
    , lineNumber : Int
    , position : Int -- the string position in the input text of the first character in the block (an "offset")
    , inVerbatim : Bool
    , count : Int
    , outerCount : Int
    , blocksCommitted : Int
    , label : String
    , error : Maybe HeadingError
    }


{-|

    Reverse the order of the strings in the body.
    Then prepend the first line, and concatenate the result.
    This is the source text of the block.

-}
finalize : PrimitiveBlock -> PrimitiveBlock
finalize block =
    let
        content =
            List.reverse block.body

        sourceText =
            if block.heading /= Paragraph then
                String.join "\n" (block.firstLine :: content)

            else
                String.join "\n" content

        oldMeta =
            block.meta

        newMeta =
            { oldMeta | sourceText = sourceText }

        properties =
            case block.heading of
                Ordinary "document" ->
                    let
                        docId =
                            block.properties
                                |> Dict.toList
                                |> List.head
                                |> Maybe.map (\( a, b ) -> a ++ ":" ++ b)
                                |> Maybe.withDefault "noDocId"
                    in
                    Dict.insert "docId" docId block.properties

                _ ->
                    block.properties
    in
    { block | properties = properties, body = content, meta = newMeta }


{-|

    Recall: classify position lineNumber, where position
    is the position of the first character in the source
    and lineNumber is the index of the current line in the source

-}
init : ParserFunctions -> String -> Int -> List String -> State
init parserFunctions initialId outerCount lines =
    { blocks = []
    , currentBlock = Nothing
    , lines = lines
    , idPrefix = initialId
    , indent = 0
    , lineNumber = 0
    , inBlock = False
    , position = 0
    , inVerbatim = False
    , parserFunctions = parserFunctions
    , count = 0
    , outerCount = outerCount
    , blocksCommitted = 0
    , label = "0, START"
    , error = Nothing
    }


blockFromLine : ParserFunctions -> Line -> Result Line.HeadingError PrimitiveBlock
blockFromLine parserFunctions ({ indent, lineNumber, position, prefix, content } as line) =
    case parserFunctions.getHeadingData content of
        Err err ->
            Ok (bogusBlockFromLine "<= something missing" line)

        Ok { heading, args, properties } ->
            let
                meta =
                    { emptyBlockMeta
                        | lineNumber = lineNumber
                        , position = position
                        , sourceText = ""
                        , numberOfLines = 1
                    }
            in
            Ok
                { heading = heading
                , indent = indent
                , args = args
                , properties = properties
                , firstLine = content
                , body = [ prefix ++ content ]
                , meta = meta
                , style = Nothing
                }


bogusBlockFromLine : String -> Line -> PrimitiveBlock
bogusBlockFromLine message_ { indent, lineNumber, position, prefix, content } =
    let
        message =
            "[b [red " ++ content ++ "]] [blue [i " ++ message_ ++ "]]"

        meta =
            { emptyBlockMeta
                | lineNumber = lineNumber
                , position = position
                , sourceText = message
                , numberOfLines = 1
            }
    in
    { heading = Paragraph
    , indent = indent
    , args = []
    , properties = Dict.empty
    , firstLine = ""
    , body = [ message ]
    , meta = meta
    , style = Nothing
    }


nextStep : State -> Step State (List PrimitiveBlock)
nextStep state =
    case List.head state.lines of
        Nothing ->
            -- finish up: no more lines to process
            case state.currentBlock of
                Nothing ->
                    Done (List.reverse state.blocks)

                Just block_ ->
                    let
                        block =
                            { block_ | body = Generic.BlockUtilities.dropLast block_.body }

                        blocks =
                            if block.body == [ "" ] then
                                -- Debug.log (LogTools.cyan "****, DONE" 13)
                                List.reverse state.blocks

                            else
                                -- Debug.log (LogTools.cyan "****, DONE" 13)
                                List.reverse (block :: state.blocks)
                    in
                    Done blocks

        Just rawLine ->
            let
                newPosition =
                    state.position + String.length rawLine + 1

                currentLine : Line
                currentLine =
                    Line.classify state.position (state.lineNumber + 1) rawLine
            in
            case ( state.inBlock, Line.isEmpty currentLine, Line.isNonEmptyBlank currentLine ) of
                -- (in block, current line is empty, current line is blank but not empty)
                -- not in a block, pass over empty line
                ( False, True, _ ) ->
                    Loop (advance newPosition { state | label = "1, EMPTY" })

                -- not in a block, pass over blank, non-empty line
                ( False, False, True ) ->
                    Loop (advance newPosition { state | label = "2, PASS" })

                -- create a new block: we are not in a block, but
                -- the current line is nonempty and nonblank
                ( False, False, False ) ->
                    Loop (createBlock { state | position = newPosition, label = "3, NEW" } currentLine)

                -- A nonempty line was encountered inside a block, so add it
                ( True, False, _ ) ->
                    Loop (addCurrentLine2 { state | position = newPosition, label = "4, ADD" } currentLine)

                -- commit the current block: we are in a block and the
                -- current line is empty
                ( True, True, _ ) ->
                    Loop (commitBlock { state | position = newPosition, label = "5, COMMIT" } currentLine)


advance : Int -> State -> State
advance newPosition state =
    { state
        | lines = List.drop 1 state.lines
        , lineNumber = state.lineNumber + 1
        , position = newPosition
        , count = state.count + 1
    }


addCurrentLine2 : State -> Line -> State
addCurrentLine2 state currentLine =
    case state.currentBlock of
        Nothing ->
            { state | lines = List.drop 1 state.lines }

        Just block ->
            { state
                | lines = List.drop 1 state.lines
                , lineNumber = state.lineNumber + 1
                , count = state.count + 1
                , currentBlock =
                    Just (addCurrentLine_ currentLine block)
            }


addCurrentLine_ : Line -> PrimitiveBlock -> PrimitiveBlock
addCurrentLine_ ({ prefix, content } as line) block =
    let
        oldMeta =
            block.meta

        newMeta =
            { oldMeta | sourceText = block.meta.sourceText ++ "\n" ++ prefix ++ content }
    in
    { block | body = line.content :: block.body, meta = newMeta }


commitBlock : State -> Line -> State
commitBlock state currentLine =
    case state.currentBlock of
        Nothing ->
            { state
                | lines = List.drop 1 state.lines
                , indent = currentLine.indent
            }

        Just block__ ->
            let
                block_ =
                    block__
                        |> Generic.BlockUtilities.updateMeta (\m -> { m | id = state.idPrefix ++ "-" ++ String.fromInt state.blocksCommitted })
                        |> Generic.BlockUtilities.updateMeta (\m -> { m | numberOfLines = List.length block__.body })

                block =
                    case block_.heading of
                        Paragraph ->
                            block_ |> finalize

                        Ordinary _ ->
                            case Dict.get "section-style" block_.properties of
                                Just "markdown" ->
                                    { block_ | body = block_.body |> Generic.BlockUtilities.dropLast }
                                        |> finalize
                                        |> transformBlock state.parserFunctions.findSectionPrefix
                                        |> fixMarkdownTitleBlock state.parserFunctions.findSectionPrefix

                                _ ->
                                    { block_ | body = block_.body |> Generic.BlockUtilities.dropLast }
                                        |> finalize
                                        |> transformBlock state.parserFunctions.findSectionPrefix

                        Verbatim str ->
                            if List.head block_.body == Just "```" then
                                { block_ | body = List.filter (\l -> l /= "```") block_.body }
                                    |> finalize

                            else
                                { block_ | body = Generic.BlockUtilities.dropLast block_.body } |> finalize
            in
            { state
                | lines = List.drop 1 state.lines
                , lineNumber = state.lineNumber + 1
                , count = state.count + 1
                , blocksCommitted = state.blocksCommitted + 1
                , blocks = block :: state.blocks |> raiseBlockLevelsIfNeeded_ block
                , inBlock = False
                , inVerbatim = state.parserFunctions.isVerbatimBlock currentLine.content
                , currentBlock = Nothing
            }


raiseBlockLevelsIfNeeded__ : PrimitiveBlock -> List PrimitiveBlock -> List PrimitiveBlock
raiseBlockLevelsIfNeeded__ lastBlock blocks =
    blocks


raiseBlockLevelsIfNeeded_ : PrimitiveBlock -> List PrimitiveBlock -> List PrimitiveBlock
raiseBlockLevelsIfNeeded_ lastBlock blocks =
    case findOrdinaryTagAtEnd lastBlock of
        Nothing ->
            blocks

        Just tag ->
            if not <| List.member tag [ "quotation", "indent", "theorem" ] then
                blocks

            else
                let
                    candidateBlocksToRaise =
                        List.Extra.takeWhile (acceptBlock tag) blocks
                            |> Debug.log ("@##@ CANDIDATES (" ++ tag ++ ")")

                    _ =
                        Debug.log "@##@ N CANDIDATES" (List.length candidateBlocksToRaise)

                    raisedBlocks_ =
                        List.map (\b -> { b | indent = b.indent + 2 }) candidateBlocksToRaise

                    raisedBlocks =
                        case List.Extra.uncons raisedBlocks_ of
                            Nothing ->
                                raisedBlocks_

                            Just ( first, rest ) ->
                                let
                                    m =
                                        List.length first.body
                                in
                                { first | body = List.take (m - 1) first.body } :: rest

                    n =
                        List.length raisedBlocks_

                    tail =
                        List.drop n blocks
                in
                raisedBlocks ++ tail


findOrdinaryTagAtEnd : PrimitiveBlock -> Maybe String
findOrdinaryTagAtEnd primitiveBlock =
    primitiveBlock.body
        |> List.Extra.last
        |> Maybe.withDefault ""
        |> Tools.Utility.findOrdinaryTagAtEnd


acceptBlock : String -> PrimitiveBlock -> Bool
acceptBlock tag block =
    not <| block.heading == Ordinary tag



--findMatchingBlock : List PrimitiveBlock


fixMarkdownTitleBlock : (String -> Maybe String) -> PrimitiveBlock -> PrimitiveBlock
fixMarkdownTitleBlock findTitlePrefix block =
    case findTitlePrefix block.firstLine of
        Nothing ->
            block

        Just prefix ->
            if prefix == "!!" then
                { block | heading = Ordinary "title", body = String.replace prefix "" block.firstLine :: block.body }

            else
                { block | body = String.replace prefix "" block.firstLine :: block.body }


{-|

    transformBlock provides for certain notational conveniences, e.g.:

       - write "| section" instead of "| section\n1"
        - write "| subsection" instead of "| section\n2"

-}
transformBlock : (String -> Maybe String) -> PrimitiveBlock -> PrimitiveBlock
transformBlock findTitlePrefix block =
    case Generic.BlockUtilities.getPrimitiveBlockName block of
        Just "section" ->
            let
                fixedBlock =
                    fixMarkdownTitleBlock findTitlePrefix block
            in
            case List.head block.args of
                Nothing ->
                    { fixedBlock | properties = Dict.insert "level" "1" block.properties }

                Just level ->
                    { fixedBlock | properties = Dict.insert "level" level block.properties }

        Just "subsection" ->
            { block | properties = Dict.insert "level" "2" block.properties, heading = Ordinary "section" }

        Just "subsubsection" ->
            { block | properties = Dict.insert "level" "3" block.properties, heading = Ordinary "section" }

        --Just "subheading" ->
        --    { block | properties = Dict.insert "level" "4" block.properties, heading = Ordinary "section" }
        Just "item" ->
            { block
                | body =
                    (block.firstLine
                        |> String.trim
                        |> String.replace "| item" ""
                        |> Tools.Utility.replaceLeadingDashSpace
                    )
                        :: block.body
            }

        Just "numbered" ->
            { block
                | body =
                    (block.firstLine
                        |> String.trim
                        |> String.replace "| numbered" ""
                        |> Tools.Utility.replaceLeadingDotSpace
                    )
                        :: block.body
            }

        _ ->
            block


createBlock : State -> Line -> State
createBlock state currentLine =
    let
        blocks =
            case state.currentBlock of
                Nothing ->
                    state.blocks

                -- When creating a new block push the current block onto state.blocks
                -- only if its content is nontrivial (not == [""])
                Just block ->
                    if block.body == [ "" ] then
                        state.blocks

                    else
                        block :: state.blocks

        rNewBlock =
            blockFromLine state.parserFunctions currentLine
    in
    case rNewBlock of
        Err err ->
            { state
                | lines = List.drop 1 state.lines
                , lineNumber = state.lineNumber + 1
                , position = state.position
                , count = state.count + 1
                , indent = currentLine.indent
                , inBlock = True
                , currentBlock = Just <| bogusBlockFromLine "error" currentLine
                , blocks = blocks
            }

        Ok newBlock ->
            { state
                | lines = List.drop 1 state.lines
                , lineNumber = state.lineNumber + 1
                , position = state.position
                , count = state.count + 1
                , indent = currentLine.indent
                , inBlock = True
                , currentBlock = Just newBlock
                , blocks = blocks
            }



--HELPERS


length : PrimitiveBlock -> Int
length block =
    List.length block.body


listLength : List PrimitiveBlock -> Int
listLength blocks =
    case List.Extra.unconsLast blocks of
        Nothing ->
            0

        Just ( lastBlock, _ ) ->
            lastBlock.meta.lineNumber + length lastBlock - 1


eq : PrimitiveBlock -> PrimitiveBlock -> Bool
eq b1 b2 =
    if b1.meta.sourceText /= b2.meta.sourceText then
        False

    else if b1.heading /= b2.heading then
        False

    else
        True


empty : PrimitiveBlock
empty =
    Generic.Language.primitiveBlockEmpty
