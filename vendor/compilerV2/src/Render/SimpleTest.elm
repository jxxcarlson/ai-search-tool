module Render.SimpleTest exposing (main)

{-| Simple test module to verify our refactored code compiles properly.
-}

import Html exposing (Html)
import Render.Attributes
import Render.BlockType
import Render.Compatibility.OrdinaryBlock
import Render.Compatibility.Tree
import Render.TreeSupport


main : Html msg
main =
    Html.div []
        [ Html.h1 [] [ Html.text "Testing Refactored Modules" ]
        , Html.p [] [ Html.text "The refactored Render modules now compile successfully." ]
        ]