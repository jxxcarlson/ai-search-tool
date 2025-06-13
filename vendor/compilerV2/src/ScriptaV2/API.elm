module ScriptaV2.API exposing
    ( compile, compileString
    , compileStringWithTitle
    )

{-|

@docs compile, compileString

-}

import Element exposing (Element)
import Element.Font
import ScriptaV2.Compiler
import ScriptaV2.Language exposing (Language)
import ScriptaV2.Msg exposing (MarkupMsg)


settings : { filter : ScriptaV2.Compiler.Filter, lang : Language, width : Int }
settings =
    { filter = ScriptaV2.Compiler.NoFilter
    , lang = ScriptaV2.Language.MicroLaTeXLang
    , width = 800
    }


{-| -}
compile : ScriptaV2.Compiler.CompilerParameters -> List String -> List (Element MarkupMsg)
compile params lines =
    ScriptaV2.Compiler.compile params lines |> ScriptaV2.Compiler.view params.docWidth


{-| -}
compileString : ScriptaV2.Compiler.CompilerParameters -> String -> List (Element MarkupMsg)
compileString params str =
    -- ScriptaV2.Compiler.compile filter lang width 0 "---" (String.lines str) |> ScriptaV2.Compiler.view width
    ScriptaV2.Compiler.compile params (String.lines str) |> ScriptaV2.Compiler.view params.docWidth


compileStringWithTitle : String -> ScriptaV2.Compiler.CompilerParameters -> String -> List (Element MarkupMsg)
compileStringWithTitle title params str =
    ScriptaV2.Compiler.compile params (String.lines str)
        |> ScriptaV2.Compiler.viewBodyOnly params.docWidth
        |> (\x -> Element.el [ Element.height (Element.px 96) ] (Element.text title) :: x)
