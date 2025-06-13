module Render.TestRender exposing (main)

{-| Test module to verify our changes to Block.elm
-}

import Html exposing (Html)
import Render.Block


main : Html msg
main =
    Html.div []
        [ Html.h1 [] [ Html.text "Testing Block Module" ]
        , Html.p [] [ Html.text "Block module updated to use OrdinaryBlock2 directly" ]
        ]