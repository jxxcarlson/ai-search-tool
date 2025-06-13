module Library.TestForest2 exposing
    ( hottDataAppStatic
    , hottForestOfExpressionBlocks
    , hottForestOfTOCNodeValue
    , sanityCheck
    )

import Array
import Dict
import Either exposing (Either(..))
import Generic.Language exposing (Expr(..), Heading(..))
import Library.Forest exposing (depths, makeForest)
import Library.Tree
import RoseTree.Tree exposing (Tree(..))


{-| The report below documents an odd divergence in the behavior of
Elm code in running locally in the Scripta app (item 1 below) or
in the Lamdera repl while in the repo for the Scripta app (item 2)
-- as opposed to the same code running in the Elm or Lamdera repls while
in the repo for the Scripta compiler (item 3).

I still don't understand why I get computed = [1,1,2,1]. The imports are

    import Array
    import Dict
    import Either exposing (Either(..))
    import Generic.Language exposing (Expr(..), Heading(..))
    import Library.Forest exposing (depths, makeForest)
    import Library.Tree
    import RoseTree.Tree exposing (Tree(..))

None of them reference code in the Scripta app. Therefore
the behavior of the code in should be the same in all three cases.

Repos:

  - Scripta compiler: <https://github.com/jxxcarlson/scripta-compiler-v2>

  - Scripta app: <https://github.com/jxxcarlson/microlatex-lamdera>

    The lists of numbers you see below are the depths of trees in a list
    of trees. The correct value is [1,1,2,1] in (1) but [1,1,1,1] in (2) and (3).
    I am running the same code in both cases. The code is in module
    Library.TestForest2. The imports

1.  Elm repl running in the Scripta compiler repo:

    > import Library.TestForest2 exposing (..)
    > sanityCheck
    > { compareDepths = { computed = [1,1,2,1], goal = [1,1,2,1], static = [1,1,2,1] } }

2.  Debug.log output from Scripta running locally
    It does not matter what doc you are looking at.

    Debug.log "@@::SANITYCHECK" =>
    { compareDepths = { computed = [1,1,1,1], goal = [1,1,2,1], static = [1,1,2,1] } }
    WTF ?!?! ===========^^^^^^^^^^^^^^^^^^^^=========== WTF ?!?!

3.  Lamdera repl running in the Scripta app repo:

    > import Library.TestForest2 exposing(..)
    > { compareDepths = { computed = [1,1,1,1], goal = [1,1,2,1], static = [1,1,2,1] } }
    > WTF ?!?! ===========^^^^^^^^^^^^^^^^^^^^=========== WTF ?!?!

-}
sanityCheck =
    { compareDepths = comparedDepths
    }


{-| Diagnostic info, so help me God.
Static entities are actual data .. not the immediate result of a function call
-}
comparedDepths =
    { computed = makeForest Library.Tree.lev hottDataAppStatic |> depths
    , static = hottForestOfTOCNodeValueStatic |> depths
    , goal = [ 1, 1, 2, 1 ]
    }


type alias TOCNodeValue =
    { block : Generic.Language.ExpressionBlock, visible : Bool }


{-| Data captured via Debug.log in Scripta running locally on the document HoTT
-}
hottDataAppStatic : List TOCNodeValue
hottDataAppStatic =
    [ { block = { args = [ "1" ], body = Right [ Text " Path Space of " { begin = 1275, end = 1289, id = "xye-41.0", index = 0 }, VFun "math" "\\nat" { begin = 1290, end = 1290, id = "xye-41.1", index = 1 } ], firstLine = "# Path Space of $\\nat$", heading = Ordinary "section", indent = 0, meta = { error = Nothing, id = "@-3", lineNumber = 41, messages = [], numberOfLines = 1, position = 1275, sourceText = "# Path Space of $\\nat$" }, properties = Dict.fromList [ ( "id", "@-3" ), ( "label", "1" ), ( "level", "1" ), ( "section-type", "markdown" ), ( "tag", "path-space-of-nat" ) ], style = Nothing }, visible = True }
    , { block = { args = [ "1" ], body = Right [ Text " Types that are not Sets" { begin = 1930, end = 1953, id = "xye-69.0", index = 0 } ], firstLine = "# Types that are not Sets", heading = Ordinary "section", indent = 0, meta = { error = Nothing, id = "@-11", lineNumber = 69, messages = [], numberOfLines = 1, position = 1930, sourceText = "# Types that are not Sets" }, properties = Dict.fromList [ ( "id", "@-11" ), ( "label", "2" ), ( "level", "1" ), ( "section-type", "markdown" ), ( "tag", "types-that-are-not-sets" ) ], style = Nothing }, visible = True }
    , { block = { args = [ "1" ], body = Right [ Text " Higher Inductive Types" { begin = 3168, end = 3190, id = "xye-102.0", index = 0 } ], firstLine = "# Higher Inductive Types", heading = Ordinary "section", indent = 0, meta = { error = Nothing, id = "@-19", lineNumber = 102, messages = [], numberOfLines = 1, position = 3168, sourceText = "# Higher Inductive Types" }, properties = Dict.fromList [ ( "id", "@-19" ), ( "label", "3" ), ( "level", "1" ), ( "section-type", "markdown" ), ( "tag", "higher-inductive-types" ) ], style = Nothing }, visible = True }
    , { block = { args = [ "2" ], body = Right [ Text " The circle" { begin = 3194, end = 3204, id = "xye-104.0", index = 0 } ], firstLine = "## The circle", heading = Ordinary "section", indent = 0, meta = { error = Nothing, id = "@-20", lineNumber = 104, messages = [], numberOfLines = 1, position = 3194, sourceText = "## The circle" }, properties = Dict.fromList [ ( "id", "@-20" ), ( "label", "3.1" ), ( "level", "2" ), ( "section-type", "markdown" ), ( "tag", "the-circle" ) ], style = Nothing }, visible = True }
    , { block = { args = [ "2" ], body = Right [ Text " " { begin = 3317, end = 3317, id = "xye-109.0", index = 0 }, VFun "math" "\\integers" { begin = 3318, end = 3318, id = "xye-109.1", index = 1 }, Text " (Notes)" { begin = 3329, end = 3336, id = "xye-109.4", index = 4 } ], firstLine = "## $\\integers$ (Notes)", heading = Ordinary "section", indent = 0, meta = { error = Nothing, id = "@-22", lineNumber = 109, messages = [], numberOfLines = 1, position = 3317, sourceText = "## $\\integers$ (Notes)" }, properties = Dict.fromList [ ( "id", "@-22" ), ( "label", "3.2" ), ( "level", "2" ), ( "section-type", "markdown" ), ( "tag", "integers-notes" ) ], style = Nothing }, visible = True }
    , { block = { args = [ "2" ], body = Right [ Text " " { begin = 3539, end = 3539, id = "xye-117.0", index = 0 }, VFun "math" "\\integers" { begin = 3540, end = 3540, id = "xye-117.1", index = 1 }, Text " (Mortberg)" { begin = 3551, end = 3561, id = "xye-117.4", index = 4 } ], firstLine = "## $\\integers$ (Mortberg)", heading = Ordinary "section", indent = 0, meta = { error = Nothing, id = "@-24", lineNumber = 117, messages = [], numberOfLines = 1, position = 3539, sourceText = "## $\\integers$ (Mortberg)" }, properties = Dict.fromList [ ( "id", "@-24" ), ( "label", "3.3" ), ( "level", "2" ), ( "section-type", "markdown" ), ( "tag", "integers-mortberg" ) ], style = Nothing }, visible = True }
    , { block = { args = [ "2" ], body = Right [ Text " " { begin = 6503, end = 6503, id = "xye-203.0", index = 0 }, VFun "math" "\\integers" { begin = 6504, end = 6504, id = "xye-203.1", index = 1 } ], firstLine = "## $\\integers$", heading = Ordinary "section", indent = 0, meta = { error = Nothing, id = "@-27", lineNumber = 203, messages = [], numberOfLines = 1, position = 6503, sourceText = "## $\\integers$" }, properties = Dict.fromList [ ( "id", "@-27" ), ( "label", "3.4" ), ( "level", "2" ), ( "section-type", "markdown" ), ( "tag", "integers" ) ], style = Nothing }, visible = True }
    , { block = { args = [ "2" ], body = Right [ Text " " { begin = 7029, end = 7029, id = "xye-225.0", index = 0 }, VFun "math" "\\integers/N" { begin = 7030, end = 7030, id = "xye-225.1", index = 1 } ], firstLine = "## $\\integers/N$", heading = Ordinary "section", indent = 0, meta = { error = Nothing, id = "@-29", lineNumber = 225, messages = [], numberOfLines = 1, position = 7029, sourceText = "## $\\integers/N$" }, properties = Dict.fromList [ ( "id", "@-29" ), ( "label", "3.5" ), ( "level", "2" ), ( "section-type", "markdown" ), ( "tag", "integers-n" ) ], style = Nothing }, visible = True }
    , { block = { args = [ "1" ], body = Right [ Text " References" { begin = 7879, end = 7889, id = "xye-263.0", index = 0 } ], firstLine = "# References", heading = Ordinary "section", indent = 0, meta = { error = Nothing, id = "@-34", lineNumber = 263, messages = [], numberOfLines = 1, position = 7879, sourceText = "# References" }, properties = Dict.fromList [ ( "id", "@-34" ), ( "label", "4" ), ( "level", "1" ), ( "section-type", "markdown" ), ( "tag", "references" ) ], style = Nothing }, visible = True }
    ]


{-| That same data transformed from a list to a list of trees by applying .level to the properties field of the blocks and convertin the result to an Int.
-}
hottForestOfTOCNodeValueStatic : List (Tree TOCNodeValue)
hottForestOfTOCNodeValueStatic =
    [ RoseTree.Tree.Tree { block = { args = [ "1" ], body = Right [ Text " Path Space of " { begin = 1275, end = 1289, id = "xye-41.0", index = 0 }, VFun "math" "\\nat" { begin = 1290, end = 1290, id = "xye-41.1", index = 1 } ], firstLine = "# Path Space of $\\nat$", heading = Ordinary "section", indent = 0, meta = { error = Nothing, id = "@-3", lineNumber = 41, messages = [], numberOfLines = 1, position = 1275, sourceText = "# Path Space of $\\nat$" }, properties = Dict.fromList [ ( "id", "@-3" ), ( "label", "1" ), ( "level", "1" ), ( "section-type", "markdown" ), ( "tag", "path-space-of-nat" ) ], style = Nothing }, visible = True }
        (Array.fromList [])
    , RoseTree.Tree.Tree { block = { args = [ "1" ], body = Right [ Text " Types that are not Sets" { begin = 1930, end = 1953, id = "xye-69.0", index = 0 } ], firstLine = "# Types that are not Sets", heading = Ordinary "section", indent = 0, meta = { error = Nothing, id = "@-11", lineNumber = 69, messages = [], numberOfLines = 1, position = 1930, sourceText = "# Types that are not Sets" }, properties = Dict.fromList [ ( "id", "@-11" ), ( "label", "2" ), ( "level", "1" ), ( "section-type", "markdown" ), ( "tag", "types-that-are-not-sets" ) ], style = Nothing }, visible = True }
        (Array.fromList [])
    , RoseTree.Tree.Tree { block = { args = [ "1" ], body = Right [ Text " Higher Inductive Types" { begin = 3168, end = 3190, id = "xye-102.0", index = 0 } ], firstLine = "# Higher Inductive Types", heading = Ordinary "section", indent = 0, meta = { error = Nothing, id = "@-19", lineNumber = 102, messages = [], numberOfLines = 1, position = 3168, sourceText = "# Higher Inductive Types" }, properties = Dict.fromList [ ( "id", "@-19" ), ( "label", "3" ), ( "level", "1" ), ( "section-type", "markdown" ), ( "tag", "higher-inductive-types" ) ], style = Nothing }, visible = True }
        (Array.fromList
            [ RoseTree.Tree.Tree { block = { args = [ "2" ], body = Right [ Text " The circle" { begin = 3194, end = 3204, id = "xye-104.0", index = 0 } ], firstLine = "## The circle", heading = Ordinary "section", indent = 0, meta = { error = Nothing, id = "@-20", lineNumber = 104, messages = [], numberOfLines = 1, position = 3194, sourceText = "## The circle" }, properties = Dict.fromList [ ( "id", "@-20" ), ( "label", "3.1" ), ( "level", "2" ), ( "section-type", "markdown" ), ( "tag", "the-circle" ) ], style = Nothing }, visible = True } (Array.fromList [])
            , RoseTree.Tree.Tree { block = { args = [ "2" ], body = Right [ Text " " { begin = 3317, end = 3317, id = "xye-109.0", index = 0 }, VFun "math" "\\integers" { begin = 3318, end = 3318, id = "xye-109.1", index = 1 }, Text " (Notes)" { begin = 3329, end = 3336, id = "xye-109.4", index = 4 } ], firstLine = "## $\\integers$ (Notes)", heading = Ordinary "section", indent = 0, meta = { error = Nothing, id = "@-22", lineNumber = 109, messages = [], numberOfLines = 1, position = 3317, sourceText = "## $\\integers$ (Notes)" }, properties = Dict.fromList [ ( "id", "@-22" ), ( "label", "3.2" ), ( "level", "2" ), ( "section-type", "markdown" ), ( "tag", "integers-notes" ) ], style = Nothing }, visible = True } (Array.fromList [])
            , RoseTree.Tree.Tree { block = { args = [ "2" ], body = Right [ Text " " { begin = 3539, end = 3539, id = "xye-117.0", index = 0 }, VFun "math" "\\integers" { begin = 3540, end = 3540, id = "xye-117.1", index = 1 }, Text " (Mortberg)" { begin = 3551, end = 3561, id = "xye-117.4", index = 4 } ], firstLine = "## $\\integers$ (Mortberg)", heading = Ordinary "section", indent = 0, meta = { error = Nothing, id = "@-24", lineNumber = 117, messages = [], numberOfLines = 1, position = 3539, sourceText = "## $\\integers$ (Mortberg)" }, properties = Dict.fromList [ ( "id", "@-24" ), ( "label", "3.3" ), ( "level", "2" ), ( "section-type", "markdown" ), ( "tag", "integers-mortberg" ) ], style = Nothing }, visible = True } (Array.fromList [])
            , RoseTree.Tree.Tree { block = { args = [ "2" ], body = Right [ Text " " { begin = 6503, end = 6503, id = "xye-203.0", index = 0 }, VFun "math" "\\integers" { begin = 6504, end = 6504, id = "xye-203.1", index = 1 } ], firstLine = "## $\\integers$", heading = Ordinary "section", indent = 0, meta = { error = Nothing, id = "@-27", lineNumber = 203, messages = [], numberOfLines = 1, position = 6503, sourceText = "## $\\integers$" }, properties = Dict.fromList [ ( "id", "@-27" ), ( "label", "3.4" ), ( "level", "2" ), ( "section-type", "markdown" ), ( "tag", "integers" ) ], style = Nothing }, visible = True } (Array.fromList [])
            , RoseTree.Tree.Tree { block = { args = [ "2" ], body = Right [ Text " " { begin = 7029, end = 7029, id = "xye-225.0", index = 0 }, VFun "math" "\\integers/N" { begin = 7030, end = 7030, id = "xye-225.1", index = 1 } ], firstLine = "## $\\integers/N$", heading = Ordinary "section", indent = 0, meta = { error = Nothing, id = "@-29", lineNumber = 225, messages = [], numberOfLines = 1, position = 7029, sourceText = "## $\\integers/N$" }, properties = Dict.fromList [ ( "id", "@-29" ), ( "label", "3.5" ), ( "level", "2" ), ( "section-type", "markdown" ), ( "tag", "integers-n" ) ], style = Nothing }, visible = True } (Array.fromList [])
            ]
        )
    , RoseTree.Tree.Tree { block = { args = [ "1" ], body = Right [ Text " References" { begin = 7879, end = 7889, id = "xye-263.0", index = 0 } ], firstLine = "# References", heading = Ordinary "section", indent = 0, meta = { error = Nothing, id = "@-34", lineNumber = 263, messages = [], numberOfLines = 1, position = 7879, sourceText = "# References" }, properties = Dict.fromList [ ( "id", "@-34" ), ( "label", "4" ), ( "level", "1" ), ( "section-type", "markdown" ), ( "tag", "references" ) ], style = Nothing }, visible = True }
        (Array.fromList [])
    ]


hottForestOfTOCNodeValue : List (Tree TOCNodeValue)
hottForestOfTOCNodeValue =
    makeForest Library.Tree.lev hottDataAppStatic


hottForestOfExpressionBlocks : List (Tree Generic.Language.ExpressionBlock)
hottForestOfExpressionBlocks =
    hottForestOfTOCNodeValue |> List.map (RoseTree.Tree.mapValues .block)


hottData =
    [ ( 1, "# Path Space of $\\nat$" )
    , ( 1, "# Types that are not Sets" )
    , ( 1, "# Higher Inductive Types" )
    , ( 2, "## The circle" )
    , ( 2, "## $\\integers$ (Notes)" )
    , ( 2, "## $\\integers$ (Mortberg)" )
    , ( 2, "## $\\integers$" )
    , ( 2, "## $\\integers/N$" )
    , ( 1, "# References" )
    ]


toForestTOCNodeValue : List (List TOCNodeValue) -> List (Tree TOCNodeValue)
toForestTOCNodeValue listList_ =
    --> processPrep prep |> List.map Library.Tree.depth
    --[1,2] : List Int
    listList_
        |> List.map (Library.Tree.makeTree Library.Tree.lev)
        |> List.filterMap identity


simplify : TOCNodeValue -> String
simplify { block } =
    block.firstLine
