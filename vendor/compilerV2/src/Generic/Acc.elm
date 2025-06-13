module Generic.Acc exposing
    ( Accumulator
    , InListState(..)
    , InitialAccumulatorData
    , TermLoc
    , getMacroArg
    , initialData
    , transformAccumulate
    )

{-|

    The function the Generic.Acc module is to collect information from the AST that will
    be used when it is rendered. This information is built up in an Accumulator, a
    data structure used for

            - numbering sections, theorems, figures, etc.
            - creating
               - a dictionary of references
               - a dictionary of terms
               - a dictionary of footnotes
               - a dictionary of math macros
               - a dictionary of text macros
               - a dictionary of key-value pairs
               - a dictionary of questions and answers


     The main function is transformAccumulate, which has the signature

           InitialAccumulatorData -> Forest ExpressionBlock -> ( Accumulator, Forest ExpressionBlock )

     Two helper functions are of special interest,

          updateAccumulator : ExpressionBlock -> Accumulator -> Accumulator

     and

          transformBlock : Accumulator -> ExpressionBlock -> ExpressionBlock

      The first function is used to update the accumulator with information from the AST. The second
      updates expression blocks with information already gathered in the accumulator.

-}

import Array exposing (Array)
import Dict exposing (Dict)
import Either exposing (Either(..))
import Generic.ASTTools
import Generic.BlockUtilities
import Generic.Language exposing (Expr(..), Expression, ExpressionBlock, Heading(..))
import Generic.MathMacro
import Generic.Settings
import Generic.TextMacro exposing (Macro)
import Generic.Vector as Vector exposing (Vector)
import Maybe.Extra
import Parser exposing ((|.), (|=), Parser)
import RoseTree.Tree as Tree exposing (Tree)
import ScriptaV2.Config as Config
import ScriptaV2.Language exposing (Language)
import Tools.String
import Tools.Utility as Utility


initialData : InitialAccumulatorData
initialData =
    { mathMacros = ""
    , textMacros = ""
    , vectorSize = 4
    , language = Config.defaultLanguage
    }


type alias Accumulator =
    { headingIndex : Vector
    , documentIndex : Vector
    , counter : Dict String Int
    , blockCounter : Int
    , itemVector : Vector -- Used for section numbering
    , deltaLevel : Int
    , numberedItemDict : Dict String { level : Int, index : Int }
    , numberedBlockNames : List String
    , inListState : InListState
    , reference : Dict String { id : String, numRef : String }
    , terms : Dict String TermLoc
    , footnotes : Dict String TermLoc2
    , footnoteNumbers : Dict String Int
    , mathMacroDict : Generic.MathMacro.MathMacroDict
    , textMacroDict : Dict String Macro
    , keyValueDict : Dict String String
    , qAndAList : List ( String, String )
    , qAndADict : Dict String String
    }


type InListState
    = SInList
    | SNotInList


{-| Note that function transformAccumulate operates on initialized accumulator.
-}
transformAccumulate : InitialAccumulatorData -> List (Tree ExpressionBlock) -> ( Accumulator, List (Tree ExpressionBlock) )
transformAccumulate data forest =
    List.foldl (\tree ( acc_, ast_ ) -> transformAccumulateTree tree acc_ |> mapper ast_) ( init data, [] ) forest
        |> (\( acc_, ast_ ) -> ( acc_, List.reverse ast_ ))


getCounter : String -> Dict String Int -> Int
getCounter name dict =
    Dict.get name dict |> Maybe.withDefault 0


getCounterAsString : String -> Dict String Int -> String
getCounterAsString name dict =
    Dict.get name dict |> Maybe.map String.fromInt |> Maybe.withDefault ""


incrementCounter : String -> Dict String Int -> Dict String Int
incrementCounter name dict =
    Dict.insert name (getCounter name dict + 1) dict


type alias InitialAccumulatorData =
    { mathMacros : String
    , textMacros : String
    , vectorSize : Int
    , language : Language
    }


init : InitialAccumulatorData -> Accumulator
init data =
    { headingIndex = Vector.init data.vectorSize
    , deltaLevel = 0
    , documentIndex = Vector.init data.vectorSize
    , inListState = SNotInList
    , counter = Dict.empty
    , blockCounter = 0
    , itemVector = Vector.init data.vectorSize
    , numberedItemDict = Dict.empty
    , numberedBlockNames = Generic.Settings.numberedBlockNames
    , reference = Dict.empty
    , terms = Dict.empty
    , footnotes = Dict.empty
    , footnoteNumbers = Dict.empty
    , mathMacroDict = Dict.empty
    , textMacroDict = Dict.empty
    , keyValueDict = Dict.empty
    , qAndAList = []
    , qAndADict = Dict.empty
    }
        |> updateWithMathMacros data.mathMacros


mapper ast_ ( acc_, tree_ ) =
    ( acc_, tree_ :: ast_ )


transformAccumulateTree : Tree ExpressionBlock -> Accumulator -> ( Accumulator, Tree ExpressionBlock )
transformAccumulateTree tree acc =
    mapAccumulate transformAccumulateBlock acc tree


mapAccumulate : (s -> a -> ( s, b )) -> s -> Tree a -> ( s, Tree b )
mapAccumulate f s tree =
    let
        ( s_, value_ ) =
            f s (Tree.value tree)

        ( s__, children_ ) =
            List.foldl
                (\child ( accState, accChildren ) ->
                    let
                        ( newState, newChild ) =
                            mapAccumulate f accState child
                    in
                    ( newState, newChild :: accChildren )
                )
                ( s_, [] )
                (Tree.children tree)
    in
    ( s__, Tree.branch value_ (reverse children_) )


reverse : List a -> List a
reverse list =
    List.foldl (\x xs -> x :: xs) [] list


{-|

    This function first updates the Accumulator with information from the ExpressionBlock
    (for example, the headingIndex, used to number sections), and then transforms the
    ExpressionBlock with information from the Accumulator (for example, the label property).

    The transformAccumulate block takes an Accumulator and an ExpressionBlock as
    arguments and returns a pair (Accumulator, ExpressionBlock) of the updated data.

-}
transformAccumulateBlock : Accumulator -> ExpressionBlock -> ( Accumulator, ExpressionBlock )
transformAccumulateBlock =
    \acc_ block_ ->
        let
            newAcc =
                updateAccumulator block_ acc_
        in
        ( newAcc, transformBlock newAcc block_ )


{-|

    Add labels to blocks, e.g. number sections and equations

-}
transformBlock : Accumulator -> ExpressionBlock -> ExpressionBlock
transformBlock acc block =
    case ( block.heading, block.args ) of
        ( Ordinary "section", _ ) ->
            { block
                | properties =
                    block.properties
                        |> Dict.insert "label" (Vector.toString acc.headingIndex)
                        |> Dict.insert "tag" (block.firstLine |> Tools.String.makeSlug)
            }

        ( Ordinary "quiver", _ ) ->
            { block | properties = Dict.insert "figure" (getCounterAsString "figure" acc.counter) block.properties }

        ( Ordinary "chart", _ ) ->
            { block | properties = Dict.insert "figure" (getCounterAsString "figure" acc.counter) block.properties }

        ( Ordinary "image", _ ) ->
            { block | properties = Dict.insert "figure" (getCounterAsString "figure" acc.counter) block.properties }

        ( Ordinary "iframe", _ ) ->
            { block | properties = Dict.insert "figure" (getCounterAsString "figure" acc.counter) block.properties }

        ( Ordinary "document", _ ) ->
            let
                title =
                    case block.body of
                        Left str ->
                            str

                        Right expr ->
                            List.map Generic.ASTTools.getText expr |> Maybe.Extra.values |> String.join " "

                label =
                    if List.member (title |> String.toLower) itemsNotNumbered then
                        ""

                    else
                        Vector.toString acc.documentIndex
            in
            { block | properties = Dict.insert "label" label block.properties }

        ( Verbatim "equation", args ) ->
            let
                prefix =
                    Vector.toString acc.headingIndex

                equationProp =
                    if prefix == "" then
                        getCounterAsString "equation" acc.counter

                    else
                        Vector.toString acc.headingIndex ++ "." ++ getCounterAsString "equation" acc.counter
            in
            { block | properties = Dict.insert "equation-number" equationProp block.properties }

        ( Verbatim "aligned", _ ) ->
            let
                prefix =
                    Vector.toString acc.headingIndex

                equationProp =
                    if prefix == "" then
                        getCounterAsString "equation" acc.counter

                    else
                        Vector.toString acc.headingIndex ++ "." ++ getCounterAsString "equation" acc.counter
            in
            { block | properties = Dict.insert "equation-number" equationProp block.properties }

        ( heading, _ ) ->
            -- TODO: not at all sure that the below is correct
            case Generic.Language.getNameFromHeading heading of
                Nothing ->
                    block

                Just name ->
                    -- Insert the numerical counter, e.g,, equation number, in the arg list of the block
                    if List.member name [ "section" ] then
                        let
                            prefix =
                                Vector.toString acc.headingIndex

                            equationProp =
                                if prefix == "" then
                                    getCounterAsString "equation" acc.counter

                                else
                                    Vector.toString acc.headingIndex ++ "." ++ getCounterAsString "equation" acc.counter
                        in
                        { block
                            | properties = Dict.insert "label" equationProp block.properties
                        }

                    else
                        -- Default insertion of "label" property (used for block numbering)
                        (if List.member name Generic.Settings.numberedBlockNames then
                            { block
                                | properties =
                                    Dict.insert "label"
                                        (vectorPrefix acc.headingIndex ++ String.fromInt acc.blockCounter)
                                        block.properties
                            }

                         else
                            block
                        )
                            |> expand acc.textMacroDict


vectorPrefix : Vector -> String
vectorPrefix headingIndex =
    let
        prefix =
            Vector.toString headingIndex
    in
    if prefix == "" then
        ""

    else
        Vector.toString headingIndex ++ "."


{-| Map name to name of counter
-}
reduceName : String -> String
reduceName str =
    if List.member str [ "equation", "aligned" ] then
        "equation"

    else if str == "code" then
        "listing"

    else if List.member str [ "quiver", "image", "iframe", "chart", "datatable", "svg", "tikz", "iframe" ] then
        "figure"

    else
        str


expand : Dict String Macro -> ExpressionBlock -> ExpressionBlock
expand dict block =
    { block | body = Either.map (List.map (Generic.TextMacro.expand dict)) block.body }


{-| The first component of the return value (Bool, Maybe Vector) is the
updated inList.
-}
nextInListState : Heading -> InListState -> InListState
nextInListState heading state =
    case ( state, heading ) of
        ( SNotInList, Ordinary "numbered" ) ->
            SInList

        ( SNotInList, _ ) ->
            SNotInList

        ( SInList, Ordinary "numbered" ) ->
            SInList

        ( SInList, _ ) ->
            SNotInList


type alias ReferenceDatum =
    { id : String
    , tag : String
    , numRef : String
    }


makeReferenceDatum : String -> String -> String -> ReferenceDatum
makeReferenceDatum id tag numRef =
    { id = id
    , tag = tag
    , numRef = numRef
    }


{-| Update the references dictionary: add a key-value pair where the
key is defined as in the examples \\label{foo} or [label foo],
and where value is a record with an id and a "numerical" reference,
e.g, "2" or "2.3"
-}
updateReference : Vector -> ReferenceDatum -> Accumulator -> Accumulator
updateReference headingIndex referenceDatum acc =
    -- Update the accumulator.reference dictionary with new reference data:
    -- Namely, insert a new key-value pair where the key is the tag of the
    -- reference, e.g., "foo" in \\label{foo} or [label foo], and where the
    -- value is a record with an id and a "numerical" reference, e.g, "2" or "2.3"
    --  TODO: review!
    if referenceDatum.tag /= "" then
        { acc
            | reference =
                Dict.insert referenceDatum.tag
                    { id = referenceDatum.id, numRef = referenceDatum.numRef }
                    acc.reference
        }

    else
        acc



-- Simplify this function:
--   - take the tag from block.properties with key "tag"
--   - set the numRef to acc.headingIndex . acc.blockCounter


updateReferenceWithBlock : ExpressionBlock -> Accumulator -> Accumulator
updateReferenceWithBlock block acc =
    case getReferenceDatum acc block of
        Just referenceDatum ->
            updateReference acc.headingIndex referenceDatum acc

        Nothing ->
            acc


getNameContentId : ExpressionBlock -> Maybe { name : String, content : Either String (List Expression), id : String }
getNameContentId block =
    let
        name : Maybe String
        name =
            Generic.Language.getNameFromHeading block.heading

        content : Maybe (Either String (List Expression))
        content =
            Just block.body

        id =
            Just block.meta.id
    in
    case ( name, content, id ) of
        ( Just name_, Just content_, Just id_ ) ->
            Just { name = name_, content = content_, id = id_ }

        _ ->
            Nothing


getNameContentIdTag : ExpressionBlock -> Maybe { name : String, content : Either String (List Expression), id : String, tag : String }
getNameContentIdTag block =
    let
        name =
            Dict.get "name" block.properties

        content : Either String (List Expression)
        content =
            block.body

        id =
            block.meta.id

        tag =
            Dict.get "tag" block.properties |> Maybe.withDefault id
    in
    case name of
        Nothing ->
            Nothing

        Just name_ ->
            Just { name = name_, content = block.body, id = id, tag = tag }


getReferenceDatum : Accumulator -> ExpressionBlock -> Maybe ReferenceDatum
getReferenceDatum acc block =
    -- TODO: REVIEW!
    let
        id : String
        id =
            block.meta.id

        tag =
            -- TODO: REVIEW!
            Dict.get "tag" block.properties |> Maybe.withDefault "no-tag"

        numRef =
            (acc.headingIndex |> Vector.toString) ++ "." ++ (acc.blockCounter |> String.fromInt)
    in
    Just { id = id, tag = tag, numRef = numRef }


{-|

    Update the accumulator with data from a block, e.g., update the
    headingIndex, a vector of integers that is used to number the sections

-}
updateAccumulator : ExpressionBlock -> Accumulator -> Accumulator
updateAccumulator ({ heading, indent, args, body, meta, properties } as block) accumulator =
    -- Update the accumulator for expression blocks with selected name
    case heading of
        -- provide numbering for sections
        -- reference : Dict String { id : String, numRef : String }
        Ordinary "q" ->
            { accumulator
              -- set the qAndAList to  [(id, "??")]
              -- where id is the id of the question block
                | qAndAList = [ ( block.meta.id, "??" ) ]
                , blockCounter = accumulator.blockCounter + 1
            }
                |> updateReferenceWithBlock block

        Ordinary "a" ->
            case List.head accumulator.qAndAList of
                Just ( idQ, "??" ) ->
                    -- Assumption: the qAndAList consists of a single pair
                    -- (qId, "??") where qId is the id of the question block.
                    -- We now insert (qId, aId), where aId is the id o
                    -- the answer block now being processed in the qAndADict
                    -- Then we clear the qAndAList (set it to empty)
                    { accumulator
                        | qAndAList = []
                        , qAndADict = Dict.insert idQ block.meta.id accumulator.qAndADict
                    }
                        |> updateReferenceWithBlock block

                _ ->
                    accumulator

        Ordinary "set-key" ->
            case args of
                key :: value :: rest ->
                    { accumulator | keyValueDict = Dict.insert key value accumulator.keyValueDict }

                _ ->
                    accumulator

        Ordinary "list" ->
            { accumulator | itemVector = Vector.init 4 }

        Ordinary "section" ->
            let
                level =
                    Dict.get "level" properties |> Maybe.withDefault "1"
            in
            case getNameContentId block of
                Just { name, content, id } ->
                    updateWithOrdinarySectionBlock accumulator (Just name) content level id
                        |> updateReferenceWithBlock block

                Nothing ->
                    accumulator |> updateReferenceWithBlock block

        Ordinary "document" ->
            let
                level =
                    List.head args |> Maybe.withDefault "1"
            in
            case getNameContentId block of
                Just { name, content, id } ->
                    updateWithOrdinaryDocumentBlock accumulator (Just name) content level id

                _ ->
                    accumulator

        Ordinary "setcounter" ->
            let
                n =
                    List.head args |> Maybe.andThen String.toInt |> Maybe.withDefault 1
            in
            { accumulator | headingIndex = { content = [ n, 0, 0, 0 ], size = 4 } }

        Ordinary "shiftandsetcounter" ->
            let
                n =
                    List.head args |> Maybe.andThen String.toInt |> Maybe.withDefault 1
            in
            { accumulator | headingIndex = { content = [ n, 0, 0, 0 ], size = 4 }, deltaLevel = 1 }

        Ordinary "bibitem" ->
            updateBibItemBlock accumulator args block.meta.id

        Ordinary _ ->
            updateWithOrdinaryBlock block accumulator
                |> updateReferenceWithBlock block

        -- provide for numbering of equations
        Verbatim "mathmacros" ->
            case Generic.Language.getVerbatimContent block of
                Nothing ->
                    accumulator

                Just str ->
                    updateWithMathMacros str accumulator

        Verbatim "textmacros" ->
            case Generic.Language.getVerbatimContent block of
                Nothing ->
                    accumulator

                Just str ->
                    updateWithTextMacros str accumulator

        Verbatim name_ ->
            case block.body of
                Left str ->
                    updateWithVerbatimBlock block accumulator

                Right _ ->
                    accumulator

        Paragraph ->
            case getNameContentIdTag block of
                Nothing ->
                    { accumulator | inListState = nextInListState block.heading accumulator.inListState }
                        |> updateWithParagraph block
                        |> updateReferenceWithBlock block

                Just { name, content, id, tag } ->
                    accumulator |> updateWithParagraph block |> updateReferenceWithBlock block


normalzeLines : List String -> List String
normalzeLines lines =
    List.map (\line -> String.trim line) lines |> List.filter (\line -> line /= "")


updateWithOrdinarySectionBlock : Accumulator -> Maybe String -> Either String (List Expression) -> String -> String -> Accumulator
updateWithOrdinarySectionBlock accumulator name content level id =
    let
        titleWords =
            case content of
                Left str ->
                    [ Utility.compressWhitespace str ]

                Right expr ->
                    List.map Generic.ASTTools.getText expr |> Maybe.Extra.values |> List.map Utility.compressWhitespace

        sectionTag =
            -- TODO: the below is a bad solution
            titleWords |> List.map (String.toLower >> String.trim >> String.replace " " "-") |> String.join ""

        headingIndex =
            Vector.increment (String.toInt level |> Maybe.withDefault 1 |> (\x -> x - 1 + accumulator.deltaLevel)) accumulator.headingIndex

        blockCounter =
            0

        referenceDatum =
            makeReferenceDatum id sectionTag (Vector.toString headingIndex)
    in
    -- TODO: take care of numberedItemIndex = 0 here and elsewhere
    { accumulator
        | headingIndex = headingIndex
        , blockCounter = blockCounter
        , counter = Dict.insert "equation" 0 accumulator.counter --TODO: this is strange!!
    }
        |> updateReference accumulator.headingIndex referenceDatum


itemsNotNumbered =
    [ "preface", "introduction", "appendix", "references", "index", "scratch" ]


{-| Update the accumulator with data from a document block, e.g., update the
documentIndex, a vector of integers that is used to number the documents in a collection
-}
updateWithOrdinaryDocumentBlock : Accumulator -> Maybe String -> Either String (List Expression) -> String -> String -> Accumulator
updateWithOrdinaryDocumentBlock accumulator name content level id =
    let
        title =
            case content of
                Left str ->
                    str

                Right expr ->
                    List.map Generic.ASTTools.getText expr |> Maybe.Extra.values |> String.join " "

        sectionTag =
            title |> String.toLower |> String.replace " " "-"

        documentIndex =
            if List.member (String.toLower title) itemsNotNumbered then
                accumulator.documentIndex

            else
                Vector.increment (String.toInt level |> Maybe.withDefault 0) accumulator.documentIndex

        referenceDatum : ReferenceDatum
        referenceDatum =
            if List.member (String.toLower title) itemsNotNumbered then
                makeReferenceDatum id sectionTag (Vector.toString documentIndex)

            else
                makeReferenceDatum id sectionTag ""
    in
    -- TODO: take care of numberedItemIndex = 0 here and elsewhere
    { accumulator | documentIndex = documentIndex } |> updateReference accumulator.headingIndex referenceDatum


updateBibItemBlock accumulator args id =
    case List.head args of
        Nothing ->
            accumulator

        Just label ->
            { accumulator | reference = Dict.insert label { id = id, numRef = "_irrelevant_" } accumulator.reference }


updateWithOrdinaryBlock : ExpressionBlock -> Accumulator -> Accumulator
updateWithOrdinaryBlock block accumulator =
    case Generic.BlockUtilities.getExpressionBlockName block of
        Just "setcounter" ->
            case block.body of
                Left _ ->
                    accumulator

                Right exprs ->
                    let
                        ctr =
                            case exprs of
                                [ Text val _ ] ->
                                    String.toInt val |> Maybe.withDefault 1

                                _ ->
                                    1

                        headingIndex =
                            Vector.init accumulator.headingIndex.size |> Vector.set 0 (ctr - 1)
                    in
                    { accumulator | headingIndex = headingIndex }

        Just "numbered" ->
            let
                level =
                    block.indent // Config.indentationQuantum

                itemVector =
                    case accumulator.inListState of
                        SInList ->
                            Vector.increment level accumulator.itemVector

                        SNotInList ->
                            Vector.init 4 |> Vector.increment 0

                index =
                    Vector.get level itemVector

                numberedItemDict =
                    Dict.insert block.meta.id { level = level, index = index } accumulator.numberedItemDict

                referenceDatum =
                    makeReferenceDatum block.meta.id (getTag block) (String.fromInt (Vector.get level itemVector))
            in
            { accumulator
                | inListState = nextInListState block.heading accumulator.inListState
                , itemVector = itemVector
                , numberedItemDict = numberedItemDict
            }
                |> updateReference accumulator.headingIndex referenceDatum

        Just "item" ->
            let
                level =
                    block.indent // Config.indentationQuantum
            in
            { accumulator | inListState = nextInListState block.heading accumulator.inListState }

        Just name_ ->
            if List.member name_ [ "title", "contents", "banner", "a" ] then
                accumulator

            else if List.member name_ Generic.Settings.numberedBlockNames then
                --- TODO: fix thereom labels
                let
                    level =
                        block.indent // Config.indentationQuantum

                    itemVector =
                        Vector.increment level accumulator.itemVector

                    numberedItemDict =
                        Dict.insert block.meta.id { level = level, index = Vector.get level itemVector } accumulator.numberedItemDict

                    referenceDatum =
                        makeReferenceDatum block.meta.id (getTag block) (String.fromInt (Vector.get level itemVector))
                in
                { accumulator
                    | inListState = nextInListState block.heading accumulator.inListState
                    , blockCounter = accumulator.blockCounter + 1
                    , itemVector = itemVector
                    , numberedItemDict = numberedItemDict
                }
                    |> updateReference accumulator.headingIndex referenceDatum

            else
                { accumulator | inListState = nextInListState block.heading accumulator.inListState }

        _ ->
            accumulator


updateWithTextMacros : String -> Accumulator -> Accumulator
updateWithTextMacros content accumulator =
    { accumulator | textMacroDict = Generic.TextMacro.buildDictionary (String.lines content |> normalzeLines) }


updateWithMathMacros : String -> Accumulator -> Accumulator
updateWithMathMacros content accumulator =
    let
        definitions =
            content
                |> String.replace "\\begin{mathmacros}" ""
                |> String.replace "\\end{mathmacros}" ""
                |> String.replace "end" ""
                |> String.trim

        mathMacroDict =
            Generic.MathMacro.makeMacroDict (String.trim definitions)
    in
    { accumulator | mathMacroDict = mathMacroDict }


updateWithVerbatimBlock : ExpressionBlock -> Accumulator -> Accumulator
updateWithVerbatimBlock block accumulator =
    case block.body of
        Right _ ->
            accumulator

        Left content ->
            let
                name =
                    Generic.BlockUtilities.getExpressionBlockName block |> Maybe.withDefault ""

                tag =
                    case getMacroArg "label" content of
                        Ok str ->
                            str

                        Err _ ->
                            "???"

                --Dict.get "label" dict |> Maybe.withDefault body
                isSimple =
                    List.member name [ "quiver", "image" ]

                -- Increment the appropriate counter, e.g., "equation" and "aligned"
                -- reduceName maps these both to "equation"
                newCounter =
                    if List.member name accumulator.numberedBlockNames then
                        incrementCounter (reduceName name) accumulator.counter

                    else
                        accumulator.counter

                referenceDatum =
                    makeReferenceDatum block.meta.id tag (verbatimBlockReference isSimple accumulator.headingIndex name newCounter)
            in
            { accumulator | inListState = nextInListState block.heading accumulator.inListState, counter = newCounter }
                |> updateReference accumulator.headingIndex referenceDatum


verbatimBlockReference : Bool -> Vector -> String -> Dict String Int -> String
verbatimBlockReference isSimple headingIndex name newCounter =
    let
        a =
            Vector.toString headingIndex
    in
    if a == "" || isSimple then
        getCounter (reduceName name) newCounter |> String.fromInt

    else
        a ++ "." ++ (getCounter (reduceName name) newCounter |> String.fromInt)


updateWithParagraph : ExpressionBlock -> Accumulator -> Accumulator
updateWithParagraph block accumulator =
    let
        ( footnotes, footnoteNumbers ) =
            addFootnotesFromContent block ( accumulator.footnotes, accumulator.footnoteNumbers )
    in
    { accumulator
        | inListState = nextInListState block.heading accumulator.inListState
        , footnotes = footnotes
        , footnoteNumbers = footnoteNumbers
        , terms = addTermsFromContent block accumulator.terms
    }


addTermsFromContent : ExpressionBlock -> Dict String TermLoc -> Dict String TermLoc
addTermsFromContent block_ dict =
    let
        newTerms : List TermData
        newTerms =
            getTerms block_.meta.id block_.body

        folder : TermData -> Dict String TermLoc -> Dict String TermLoc
        folder termData dict_ =
            addTerm termData dict_
    in
    List.foldl folder dict newTerms



--|> updateReference tag id tag


type alias TermLoc =
    { begin : Int, end : Int, id : String }


type alias TermLoc2 =
    { begin : Int, end : Int, id : String, mSourceId : Maybe String }


type alias TermData =
    { term : String, loc : TermLoc }


type alias TermData2 =
    { term : String, loc : TermLoc2 }


getTerms : String -> Either String (List Expression) -> List TermData
getTerms id content_ =
    case content_ of
        Right expressionList ->
            Generic.ASTTools.filterExpressionsOnName_ "term" expressionList
                |> List.map (extract id)
                |> Maybe.Extra.values

        Left _ ->
            []



-- TERMS: [Expression "term" [Text "group" { begin = 19, end = 23, index = 4 }] { begin = 13, end = 13, index = 1 }]


extract : String -> Expression -> Maybe TermData
extract id expr =
    case expr of
        Fun "term" [ Text name { begin, end } ] _ ->
            Just { term = name, loc = { begin = begin, end = end, id = id } }

        Fun "term_" [ Text name { begin, end } ] _ ->
            Just { term = name, loc = { begin = begin, end = end, id = id } }

        _ ->
            Nothing


addTerm : TermData -> Dict String TermLoc -> Dict String TermLoc
addTerm termData dict =
    Dict.insert termData.term termData.loc dict



-- FOOTNOTES


getFootnotes : Maybe String -> String -> Either String (List Expression) -> List TermData2
getFootnotes mBlockId id content_ =
    case content_ of
        Right expressionList ->
            Generic.ASTTools.filterExpressionsOnName_ "footnote" expressionList
                |> List.map (extractFootnote mBlockId id)
                |> Maybe.Extra.values

        Left _ ->
            []


extractFootnote : Maybe String -> String -> Expression -> Maybe TermData2
extractFootnote mSourceId id_ expr =
    case expr of
        Fun "footnote" [ Text content { begin, end, index, id } ] _ ->
            Just { term = content, loc = { begin = begin, end = end, id = id, mSourceId = mSourceId } } |> Debug.log ("@@TermData " ++ id ++ ", " ++ id_)

        _ ->
            Nothing



-- EXTRACT ??


addFootnote : TermData2 -> Dict String TermLoc2 -> Dict String TermLoc2
addFootnote footnoteData dict =
    Dict.insert footnoteData.term footnoteData.loc dict


addFootnoteLabel : TermData2 -> Dict String Int -> Dict String Int
addFootnoteLabel footnoteData dict =
    Dict.insert footnoteData.loc.id (Dict.size dict + 1) dict


addFootnotes : List TermData2 -> ( Dict String TermLoc2, Dict String Int ) -> ( Dict String TermLoc2, Dict String Int )
addFootnotes termDataList ( dict1, dict2 ) =
    List.foldl (\data ( d1, d2 ) -> ( addFootnote data d1, addFootnoteLabel data d2 )) ( dict1, dict2 ) termDataList


addFootnotesFromContent : ExpressionBlock -> ( Dict String TermLoc2, Dict String Int ) -> ( Dict String TermLoc2, Dict String Int )
addFootnotesFromContent block ( dict1, dict2 ) =
    let
        blockId =
            case block.body of
                Left _ ->
                    Nothing

                Right expr ->
                    List.map Generic.Language.getMeta expr |> List.head |> Maybe.map .id
    in
    addFootnotes (getFootnotes blockId block.meta.id block.body) ( dict1, dict2 )



-- PARSER STUFF


macroParser : String -> Parser String
macroParser name =
    Parser.succeed (\start end source -> String.slice start end source)
        |. Parser.chompUntil ("\\" ++ name ++ "{")
        |. Parser.symbol ("\\" ++ name ++ "{")
        |= Parser.getOffset
        |. Parser.chompUntil "}"
        |= Parser.getOffset
        |= Parser.getSource


getMacroArg name str =
    Parser.run (macroParser name) str


getTag : ExpressionBlock -> String
getTag block =
    case Dict.get "tag" block.properties of
        Just tag ->
            tag

        Nothing ->
            block.meta.id
