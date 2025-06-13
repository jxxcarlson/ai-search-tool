module Library.TestForest1 exposing (t2, t3, t4, testEquality, tt1)

import Array
import Dict
import Either exposing (Either(..))
import Generic.Language exposing (Expr(..), Heading(..))
import Library.Forest exposing (depths, makeForest, print, toListList)
import Library.Tree
import Render.TOCTree exposing (TOCNodeValue)
import RoseTree.Tree exposing (Tree(..))



--|> Debug.log "@@::DONE"
-- TESTS


{-| OK (see print output)
-}
tt1 =
    makeForest .level testData1
        |> print .name


{-| OK
-}
testEquality =
    ( tt1 == tt1b, tt1 == tt1c )


tt1b =
    makeForest .level testData1b
        |> print .name


tt1c =
    makeForest .level testData1c
        |> print .name


{-| OK see print output
-}
t2 =
    makeForest .level testData2
        |> print .name


{-| OK see print output
-}
t3 =
    makeForest .level testData3
        |> print .name


{-| OK see print output
-}
t4 =
    makeForest .level testData4
        |> print .name


testData1 =
    [ { level = 1, name = "I" }
    , { level = 2, name = "A" }
    , { level = 2, name = "B" }
    , { level = 1, name = "II" }
    , { level = 2, name = "C" }
    , { level = 2, name = "D" }
    ]


testData1b =
    [ { level = 0, name = "I" }
    , { level = 1, name = "A" }
    , { level = 1, name = "B" }
    , { level = 0, name = "II" }
    , { level = 1, name = "C" }
    , { level = 1, name = "D" }
    ]


testData1c =
    [ { level = 0, name = "I" }
    , { level = 2, name = "A" }
    , { level = 2, name = "B" }
    , { level = 0, name = "II" }
    , { level = 2, name = "C" }
    , { level = 2, name = "D" }
    ]


testData2 =
    [ { level = 1, name = "I" }
    , { level = 2, name = "A" }
    , { level = 2, name = "B" }
    , { level = 1, name = "II" }
    , { level = 2, name = "A" }
    , { level = 3, name = "a" }
    , { level = 3, name = "b" }
    , { level = 3, name = "c" }
    , { level = 2, name = "B" }
    , { level = 2, name = "C" }
    ]


testData3 =
    [ { level = 1, name = "A" }
    , { level = 1, name = "B" }
    ]


testData4 =
    [ { level = 1, name = "A" }
    , { level = 1, name = "B" }
    , { level = 1, name = "C" }
    ]


data =
    [ { block = { args = [ "1" ], body = Right [ Text " Intro" { begin = 46, end = 51, id = "xye-6.0", index = 0 } ], firstLine = "# Intro", heading = Ordinary "section", indent = 0, meta = { error = Nothing, id = "@-2", lineNumber = 6, messages = [], numberOfLines = 1, position = 46, sourceText = "# Intro" }, properties = Dict.fromList [ ( "id", "@-2" ), ( "label", "1" ), ( "level", "1" ), ( "section-type", "markdown" ), ( "tag", "intro" ) ] }, visible = True }, { block = { args = [ "1" ], body = Right [ Text " Particles" { begin = 67, end = 76, id = "xye-10.0", index = 0 } ], firstLine = "# Particles", heading = Ordinary "section", indent = 0, meta = { error = Nothing, id = "@-4", lineNumber = 10, messages = [], numberOfLines = 1, position = 67, sourceText = "# Particles" }, properties = Dict.fromList [ ( "id", "@-4" ), ( "label", "2" ), ( "level", "1" ), ( "section-type", "markdown" ), ( "tag", "particles" ) ] }, visible = True }, { block = { args = [ "2" ], body = Right [ Text " Fermions" { begin = 80, end = 88, id = "xye-12.0", index = 0 } ], firstLine = "## Fermions", heading = Ordinary "section", indent = 0, meta = { error = Nothing, id = "@-5", lineNumber = 12, messages = [], numberOfLines = 1, position = 80, sourceText = "## Fermions" }, properties = Dict.fromList [ ( "id", "@-5" ), ( "label", "2.1" ), ( "level", "2" ), ( "section-type", "markdown" ), ( "tag", "fermions" ) ] }, visible = True }, { block = { args = [ "2" ], body = Right [ Text " Bosons" { begin = 93, end = 99, id = "xye-14.0", index = 0 } ], firstLine = "## Bosons", heading = Ordinary "section", indent = 0, meta = { error = Nothing, id = "@-6", lineNumber = 14, messages = [], numberOfLines = 1, position = 93, sourceText = "## Bosons" }, properties = Dict.fromList [ ( "id", "@-6" ), ( "label", "2.2" ), ( "level", "2" ), ( "section-type", "markdown" ), ( "tag", "bosons" ) ] }, visible = True } ]


lev : { a | block : { b | properties : Dict.Dict String String } } -> Int
lev { block } =
    case Dict.get "level" block.properties of
        Just level ->
            String.toInt level |> Maybe.withDefault 1 |> (\x -> x - 1)

        Nothing ->
            0
