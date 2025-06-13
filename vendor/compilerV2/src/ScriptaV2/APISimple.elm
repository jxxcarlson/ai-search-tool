module ScriptaV2.APISimple exposing (compile)

{-| Use `ScriptaV2.APISimple.compile` to transform source text to elm-ui HTML for the given markup language.
You will need the following imports in your Elm file:

    import ScriptaV2.APISimple
    import ScriptaV2.Msg exposing (MarkupMsg)
    import ScriptaV2.Language exposing (Language)
    import Element exposing (Element)

Your `Msg` type definition should read:

    type Msg
        =  ...
        | Render MarkupMsg

The choice of language is made from

    type Language
        = MicroLaTeXLang
        | EnclosureLang
        | SMarkdownLang

in ScriptaV2.Language

@docs compile

-}

import Element exposing (Element)
import ScriptaV2.Compiler
import ScriptaV2.Language exposing (Language)
import ScriptaV2.Msg exposing (MarkupMsg)


type alias Input =
    { lang : Language
    , docWidth : Int
    , editCount : Int
    }


{-| Compile source text to elm-ui HTML. The width of the rendered text in pixels is
defined by docWidth. The editCount should be 0 for a static document. For documents
in a live editing context, the editCount should be increment after each edit.
This ensures that the rendered text is properly updated.
-}
compile : ScriptaV2.Compiler.CompilerParameters -> String -> List (Element MarkupMsg)
compile params sourceText =
    ScriptaV2.Compiler.compile params (String.lines sourceText) |> ScriptaV2.Compiler.view params.docWidth
