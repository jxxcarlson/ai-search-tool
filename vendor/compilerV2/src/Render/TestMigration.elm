module Render.TestMigration exposing (main)

{-| Test module to verify our refactored code compiles properly.
-}

import Dict exposing (Dict)
import Either exposing (Either(..))
import Element exposing (Element)
import Generic.Acc
import Generic.Language exposing (ExpressionBlock, Heading(..))
import Render.Attributes
import Render.OrdinaryBlock
import Render.Settings
import Render.Tree
import Render.TreeSupport
import ScriptaV2.Msg exposing (MarkupMsg)


main : Element MarkupMsg
main =
    Element.column []
        [ Element.text "Testing refactored render modules"
        , Element.text "All imports compile successfully"
        ]


sampleBlock : ExpressionBlock
sampleBlock =
    { args = []
    , body = Right []
    , heading = Ordinary "box"
    , indent = 0
    , meta =
        { id = "1"
        , lineNumber = 1
        , numberOfLines = 1
        , error = Nothing
        }
    , properties = Dict.empty
    }


sampleSettings : Render.Settings.RenderSettings
sampleSettings =
    { width = 500
    , titleSize = 24
    , paragraphSpacing = 10
    , displayed = True
    , selectedId = ""
    , backgroundColor = Element.rgb 1 1 1
    , titlePrefix = "test-"
    , isLight = True
    , leftIndent = 0
    , rightIndent = 0
    , leftMargin = 0
    , rightMargin = 0
    , showTOC = True
    , showErrorMessages = True
    , topMarginForChildren = 0
    , seed = 0
    , counterValue = 0
    , selectedSlug = Nothing
    , headingFontSize = 16
    , maxHeadingFontSize = 32
    , redColor = Element.rgb 0.8 0 0
    }


testAttributes : List (Element.Attribute msg)
testAttributes =
    Render.Attributes.getBlockAttributes sampleBlock sampleSettings


testRenderer : Int -> Element MarkupMsg
testRenderer count =
    Render.OrdinaryBlock.render count Generic.Acc.initialData sampleSettings [] sampleBlock