module Library.Forest exposing
    ( depths
    , makeForest
    , print
    , toListList
    )

import Library.Tree
import RoseTree.Tree exposing (Tree)


makeForest : (a -> Int) -> List a -> List (Tree a)
makeForest getLevel input =
    input
        |> toListList getLevel
        |> List.map (Library.Tree.makeTree getLevel)
        |> List.filterMap identity


init : (a -> Int) -> List a -> State a
init getLevel input =
    case List.head input of
        Nothing ->
            { currentLevel = 0
            , rootLevel = 0
            , input = []
            , currentList = []
            , output = []
            }

        Just item ->
            { currentLevel = getLevel item
            , rootLevel = getLevel item
            , input = input
            , currentList = []
            , output = []
            }


toListList : (a -> Int) -> List a -> List (List a)
toListList getLevel input =
    let
        initialState =
            init getLevel input
    in
    loop initialState (nextStep getLevel)


nextStep : (a -> Int) -> State a -> Step (State a) (List (List a))
nextStep getLevel state =
    case state.input of
        [] ->
            Done (List.reverse state.currentList :: state.output |> List.reverse)

        x :: xs ->
            let
                level =
                    getLevel x
            in
            if level == state.rootLevel then
                Loop
                    { state
                        | input = xs
                        , currentLevel = level
                        , currentList = [ x ]
                        , output =
                            if state.currentList == [] then
                                state.output

                            else
                                List.reverse state.currentList :: state.output
                    }

            else
                -- new item at higher than root leve, push it onto the current list
                Loop { state | input = xs, currentLevel = level, currentList = x :: state.currentList }


type Step state output
    = Loop state
    | Done output


loop : state -> (state -> Step state block) -> block
loop s f =
    case f s of
        Loop s_ ->
            loop s_ f

        Done b ->
            b



-- PRINTING


print : (a -> String) -> List (Tree a) -> String
print toText list =
    List.map (Library.Tree.print toText) list |> String.join "\n"



-- INTERNALS


type alias State a =
    { currentLevel : Int
    , rootLevel : Int
    , currentList : List a
    , input : List a
    , output : List (List a)
    }



-- UTILITIES


depths : List (Tree a) -> List Int
depths =
    List.map Library.Tree.depth
