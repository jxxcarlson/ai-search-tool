module Render.TestCompile exposing (main)

{-| Test module to verify our changes don't have circular dependencies.
-}

import Element exposing (Element)
import Generic.Acc
import Render.Compatibility.Tree
import Render.Settings
import Render.TreeSupport
import ScriptaV2.Msg exposing (MarkupMsg)


main : Element MarkupMsg
main =
    Element.text "It compiles!"