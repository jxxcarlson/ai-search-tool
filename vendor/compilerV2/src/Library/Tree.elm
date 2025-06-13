module Library.Tree exposing (depth, flatten, lev, makeTree, print)

import Dict
import RoseTree.Tree exposing (Tree)


makeTree : (a -> Int) -> List a -> Maybe (Tree a)
makeTree getLevel input =
    let
        initialState =
            initTree input
    in
    loop initialState (nextStepTree getLevel)



-- UTILITIES


lev : { a | block : { b | properties : Dict.Dict String String } } -> Int
lev { block } =
    case Dict.get "level" block.properties of
        Just level ->
            String.toInt level |> Maybe.withDefault 1 |> (\x -> x - 1)

        Nothing ->
            0


flatten : Tree a -> List a
flatten =
    RoseTree.Tree.foldr (\n acc -> RoseTree.Tree.value n :: acc) []


depth : Tree a -> Int
depth tree =
    case RoseTree.Tree.children tree of
        [] ->
            1

        children ->
            (List.maximum (List.map depth children) |> Maybe.withDefault 0) + 1



-- PRINTING


print : (a -> String) -> Tree a -> String
print f tree =
    print_ 0 f tree


print_ : Int -> (a -> String) -> Tree a -> String
print_ level f tree =
    let
        eol =
            "\n"

        g : Int -> a -> String
        g level_ x =
            eol ++ String.repeat level_ "  " ++ f x
    in
    g level (RoseTree.Tree.value tree) ++ (List.map (print_ (level + 1) f) (RoseTree.Tree.children tree) |> String.join "")



-- INTERNALS


type alias StateTree a =
    { pathToActiveNode : Maybe (List Int)
    , input : List a
    , output : Maybe (RoseTree.Tree.Tree a)
    , n : Int
    }


initTree : List a -> StateTree a
initTree input =
    { pathToActiveNode = Nothing
    , input = input
    , output = Nothing
    , n = 0
    }


nextStepTree : (a -> Int) -> StateTree a -> Step (StateTree a) (Maybe (Tree a))
nextStepTree getLevel state =
    case state.input of
        [] ->
            Done state.output

        [ lastItem ] ->
            case state.pathToActiveNode of
                Nothing ->
                    Just (RoseTree.Tree.branch lastItem []) |> Done

                Just path ->
                    Maybe.map (RoseTree.Tree.pushChildFor path (RoseTree.Tree.leaf lastItem)) state.output |> Done

        currentItem :: nextItem :: rest ->
            let
                newPath : Maybe (List Int)
                newPath =
                    getNewPath currentItem nextItem

                getNewPath : a -> a -> Maybe (List Int)
                getNewPath currentItem_ nextItem_ =
                    case compare (getLevel nextItem_) (getLevel currentItem_) of
                        GT ->
                            case state.pathToActiveNode of
                                Nothing ->
                                    Just []

                                Just _ ->
                                    Maybe.map2 append indexToActiveNode state.pathToActiveNode

                        EQ ->
                            state.pathToActiveNode

                        LT ->
                            Maybe.map dropLast state.pathToActiveNode

                newOutput : Maybe (Tree a)
                newOutput =
                    case state.pathToActiveNode of
                        Nothing ->
                            Just (RoseTree.Tree.branch currentItem [])

                        Just path ->
                            Maybe.map (RoseTree.Tree.pushChildFor path (RoseTree.Tree.leaf currentItem)) state.output

                indexToActiveNode =
                    Maybe.map (RoseTree.Tree.children >> List.length >> (\i -> i - 1)) newOutput

                dropLast : List Int -> List Int
                dropLast list =
                    List.take (List.length list - 1) list

                append : Int -> List Int -> List Int
                append k list =
                    list ++ [ k ]
            in
            Loop
                { input = nextItem :: rest
                , pathToActiveNode = newPath
                , output = newOutput
                , n = state.n + 1
                }


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
