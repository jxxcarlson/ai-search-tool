module Generic.Forest exposing
    ( Error(..)
    , Forest, map
    )

{-| This module provides tools for building
a tree from a string or a list of blocks. As noted
in the README.md, a tree
is represented in text as an outline:

     > block = "1\n 2\n 3\n 4\n5\n 6\n 7"

To build a tree from it, we apply the function fromString:

    fromString :
        node
        -> (Block -> block)
        -> String
        -> Result Error (Tree block)


    > fromString "?" .content block
      Tree "0" [
            Tree "1" [Tree "2" [],Tree "3" [], Tree "4" []]
          , Tree "5" [Tree "6" [],Tree "7" []]
      ]

The first argument of fromString is a label for a default node.
The second argument tells how to build a node from a Block.
In the example, we are building a tree with string labels,
so we need a function of type (Block -> String). Recall that

        type alias Block = { indent : Int, content: String }

Therefore

        .content : Block -> String

has the correct type. Here we use the representation of rose trees found in
[elm/rose-tree](https://package.elm-lang.org/packages/zwilias/elm-rosetree/latest/).

@docs fromString, fromBlocks, forestFromString, forestFromBlocks, Error

-}

-- import Tree.Blocks as Blocks exposing (Block)
-- import Library.Forest

import RoseTree.Tree as Tree exposing (Tree)


type alias Forest a =
    List (Tree a)


map : (a -> b) -> List (Tree a) -> List (Tree b)
map f forest =
    List.map (Tree.mapValues f) forest


{-| -}
type Error
    = EmptyBlocks


{-| -}



-- fromBlocks : block -> (block -> Int) -> List block -> Result Error (Tree block)
--forestFromBlocks : (a -> Int) -> List a -> List (Tree a)
--forestFromBlocks indentation blocks =
--    Library.Forest.makeForest indentation blocks
--
-- HELPERS II


repeatM : Int -> (block -> Maybe block) -> Maybe block -> Maybe block
repeatM n f x =
    if n == 0 then
        x

    else
        repeatM (n - 1) f (Maybe.andThen f x)


{-|

    Apply f to x n times

-}
repeat : Int -> (a -> Maybe a) -> a -> a
repeat n f x =
    case repeatM n f (Just x) of
        Nothing ->
            x

        Just y ->
            y
