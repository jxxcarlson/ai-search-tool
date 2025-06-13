module Library.TestTree exposing (ta, test1, test2, testEquality)

import Library.Tree exposing (makeTree, print)



-- TESTS


{-| Passed (see print output)
-}
test1 =
    makeTree (\a -> a.level) testData1 |> Maybe.map (print (\a -> a.name))


{-| Passed (see print output)
-}
test2 =
    makeTree (\a -> a.level) testData2 |> Maybe.map (print (\a -> a.name))


{-| Passed (see print output)
-}
ta =
    makeTree (\a -> a.level) tA |> Maybe.map (print (\a -> a.name))


{-| tb => True
-}
testEquality =
    ( ta == tb_, ta == tc_ )


tb_ =
    makeTree (\a -> a.level) tB |> Maybe.map (print (\a -> a.name))


tc_ =
    makeTree (\a -> a.level) tC |> Maybe.map (print (\a -> a.name))


tA =
    [ { level = 0, name = "I" }
    , { level = 1, name = "A" }
    , { level = 1, name = "B" }
    , { level = 2, name = "x" }
    , { level = 2, name = "y" }
    , { level = 1, name = "P" }
    , { level = 1, name = "Q" }
    ]


tB =
    [ { level = 1, name = "I" }
    , { level = 2, name = "A" }
    , { level = 2, name = "B" }
    , { level = 3, name = "x" }
    , { level = 3, name = "y" }
    , { level = 2, name = "P" }
    , { level = 2, name = "Q" }
    ]


tC =
    [ { level = 0, name = "I" }
    , { level = 2, name = "A" }
    , { level = 2, name = "B" }
    , { level = 4, name = "x" }
    , { level = 4, name = "y" }
    , { level = 2, name = "P" }
    , { level = 0, name = "Q" }
    ]


testData1 =
    [ { level = 0, name = "I" }
    , { level = 1, name = "A" }
    , { level = 2, name = "a" }
    , { level = 2, name = "b" }
    , { level = 3, name = "i" }
    , { level = 3, name = "ii" }
    , { level = 2, name = "c" }
    , { level = 1, name = "B" }
    , { level = 1, name = "C" }
    ]


testData2 =
    [ { level = 0, name = "I" }
    , { level = 1, name = "A" }
    , { level = 2, name = "i" }
    , { level = 2, name = "ii" }
    , { level = 1, name = "B" }
    , { level = 1, name = "P" }
    , { level = 2, name = "i" }
    , { level = 2, name = "ii" }
    , { level = 1, name = "Q" }
    ]
