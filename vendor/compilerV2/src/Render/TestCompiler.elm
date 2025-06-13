module Render.TestCompiler exposing (main)

{-| Test module to verify direct usage of Tree2 in Compiler
-}

import Html exposing (Html)
import Render.Tree
import ScriptaV2.Compiler as Compiler
import ScriptaV2.Language exposing (Language(..))


main : Html msg
main =
    let
        compilerParams =
            { lang = EnclosureLang
            , docWidth = 800
            , editCount = 0
            , selectedId = ""
            , idsOfOpenNodes = []
            , filter = Compiler.NoFilter
            }
            
        testDocument =
            "| title\nTest Document\n\n| section\nTest Section\n\nThis is a paragraph with some text."
            
        compiled =
            Compiler.compile compilerParams (String.lines testDocument)
    in
    Html.div []
        [ Html.h1 [] [ Html.text "Testing Compiler with Tree2" ]
        , Html.p [] [ Html.text "Compilation successful" ]
        ]