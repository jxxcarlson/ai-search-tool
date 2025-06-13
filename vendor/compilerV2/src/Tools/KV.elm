module Tools.KV exposing (argsAndProperties, cleanArgs, makeDict, prepareKVData, prepareList)

import Dict exposing (Dict)
import List.Extra
import Tools.Loop exposing (Step(..), loop)


{-|

    > stuff = "source:http://localhost:80/data/hubble.csv\nfoo:bar\nyuuk"
    > makeDict stuff
    Dict.fromList [("foo","bar"),("source","http://localhost:80/data/hubble.csv"),("yuuk","")]

-}
makeDict : String -> Dict String String
makeDict str =
    str
        |> String.lines
        |> List.map String.trim
        |> List.filter (\s -> s /= "")
        |> preparePairs
        |> Dict.fromList


argsAndProperties : List String -> ( List String, Dict String String )
argsAndProperties words =
    let
        args =
            cleanArgs words

        namedArgs =
            List.drop (List.length args) words

        properties =
            namedArgs |> prepareList |> prepareKVData
    in
    ( args, properties )


prepareKVData : List String -> Dict String String
prepareKVData data_ =
    let
        initialState =
            { input = data_, kvList = [], currentKey = Nothing, currentValue = [], kvStatus = KVInKey }
    in
    loop initialState nextKVStep


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


prepareList : List String -> List String
prepareList strs =
    strs |> explode |> List.map fix |> List.concat |> List.filter (\s -> s /= "")


preparePairs : List String -> List ( String, String )
preparePairs strs =
    strs |> explode |> List.map makePair |> List.filter (\( k, _ ) -> k /= "")


fix : List String -> List String
fix strs =
    case strs of
        a :: b :: _ ->
            (a ++ ":") :: b :: []

        a :: [] ->
            a :: []

        [] ->
            []


makePair : List String -> ( String, String )
makePair strs =
    case strs of
        a :: b :: rest ->
            ( a, String.join ":" (b :: rest) )

        a :: [] ->
            ( a, "" )

        [] ->
            ( "", "" )


explode : List String -> List (List String)
explode txt =
    List.map (String.split ":") txt


{-| return all the elements in the list 'strs' up to the first element contaiing ':'
This function is used to return the positional arguments but not the named ones.
-}
cleanArgs : List String -> List String
cleanArgs strs =
    case List.Extra.findIndex (\t -> String.contains ":" t) strs of
        Nothing ->
            strs

        Just k ->
            List.take k strs
