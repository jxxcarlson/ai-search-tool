module ScriptaV2.Compiler exposing
    ( CompilerOutput, Filter(..), compile, parse, parseFromString, render, renderForest, view, viewTOC, filterForest, px, viewBody
    , CompilerParameters, filterForest2, parseM, pl, pm, ps, viewBodyOnly
    )

{-|

@docs CompilerOutput, Filter, compile, parse, parseFromString, render, renderForest, view, viewTOC, filterForest, p, px, viewBody

-}

import Element exposing (Element)
import Element.Font as Font
import Generic.ASTTools
import Generic.Acc
import Generic.Compiler
import Generic.Forest exposing (Forest)
import Generic.Language exposing (ExpressionBlock)
import M.Expression
import M.PrimitiveBlock
import MicroLaTeX.Expression
import MicroLaTeX.PrimitiveBlock
import Render.Block
import Render.Settings
import Render.TOCTree
import Render.Tree
import RoseTree.Tree
import ScriptaV2.Config as Config
import ScriptaV2.Language exposing (Language(..))
import ScriptaV2.Msg exposing (MarkupMsg(..))
import XMarkdown.Expression
import XMarkdown.PrimitiveBlock


{-| -}
type alias CompilerParameters =
    { lang : Language
    , docWidth : Int
    , editCount : Int
    , selectedId : String
    , idsOfOpenNodes : List String
    , filter : Filter
    }


{-| -}
type Filter
    = NoFilter
    | SuppressDocumentBlocks


{-| -}
view : Int -> CompilerOutput -> List (Element MarkupMsg)
view width_ compiled =
    [ Element.column [ Element.width (Element.px (width_ - 60)) ]
        (header compiled)
    , body compiled
    ]


{-| -}
viewBody : Int -> CompilerOutput -> List (Element MarkupMsg)
viewBody width_ compiled =
    [ Element.column [ Element.width (Element.px (width_ - 60)) ]
        (header_ compiled)
    , body compiled
    ]



--viewBodyOnly : Int -> CompilerOutput -> List (Element MarkupMsg)


viewBodyOnly : Int -> CompilerOutput -> List (Element MarkupMsg)
viewBodyOnly width_ compiled =
    [ Element.column [ Element.width (Element.px (width_ - 60)) ]
        [ body compiled ]
    ]


header_ : CompilerOutput -> List (Element MarkupMsg)
header_ compiled =
    case compiled.banner of
        Nothing ->
            Element.el [ Font.size 48, bottomPadding 86 ] compiled.title
                :: []

        Just banner ->
            Element.el [] banner
                :: (Element.el [ Font.size 48, bottomPadding 86 ] compiled.title
                        :: []
                   )


{-| -}
header : CompilerOutput -> List (Element MarkupMsg)
header compiled =
    case compiled.banner of
        Nothing ->
            Element.el [ Font.size 32, bottomPadding 18 ] compiled.title
                :: Element.column [ Element.spacing 8, bottomPadding 72 ] compiled.toc
                :: []

        Just banner ->
            Element.el [] banner
                :: (Element.el [ Font.size 32, bottomPadding 18 ] compiled.title
                        :: Element.column [ Element.spacing 8, bottomPadding 36 ] compiled.toc
                        :: []
                   )


{-| -}
body : CompilerOutput -> Element MarkupMsg
body compiled =
    Element.column [ Element.spacing 18, Element.moveUp 96 ] compiled.body


{-| -}
viewTOC : CompilerOutput -> List (Element MarkupMsg)
viewTOC compiled =
    compiled.toc


bottomPadding k =
    Element.paddingEach { left = 0, right = 0, top = 0, bottom = k }


{-|

    compile lang width counter selectedId lines
    Used only in View.Phone (twice)

-}
compile : CompilerParameters -> List String -> CompilerOutput
compile params lines =
    case params.lang of
        EnclosureLang ->
            compileM params lines

        MicroLaTeXLang ->
            compileL params lines

        SMarkdownLang ->
            compileX params lines


{-|

    > cm "hello!\n\n  [b how are you?]\n\n  $x^2 = 7$\n\n"
    Ok [ Tree { args = [], body = Right [Text "hello!" ()], firstLine = "hello!", heading = Paragraph
           , indent = 0, meta = () , properties = Dict.fromList [] }
         [ Tree { args = [], body = Right [Text ("   ") (),Fun "b" [Text (" how are you?") ()] ()]
            , firstLine = "[b how are you?]", heading = Paragraph, indent = 2, meta = ()
            , properties = Dict.fromList [] } []
         , Tree { args = [], body = Right [Text ("   ") (),VFun "math" ("x^2 = 7") ()]
           , firstLine = "$x^2 = 7$", heading = Paragraph, indent = 2, meta = ()
           , properties = Dict.fromList [] } []]]

    -- proof that the output is a one-tree forest
    > cm "hello!\n\n  [b how are you?]\n\n  $x^2 = 7$\n\n" |> Result.map List.length
    Ok 1

-}
pm str =
    parseM "!!" 0 (String.lines str) |> Generic.Forest.map Generic.Language.simplifyExpressionBlock


{-| -}
parseFromString : Language -> String -> Forest ExpressionBlock
parseFromString lang str =
    parse lang Config.idPrefix 0 (String.lines str)


{-|

    parse lang idPrefix counter lines
    Used only in CurrentDocument.setInPhone

-}
parse : Language -> String -> Int -> List String -> List (RoseTree.Tree.Tree ExpressionBlock)
parse lang idPrefix outerCount lines =
    case lang of
        EnclosureLang ->
            parseM idPrefix outerCount lines

        MicroLaTeXLang ->
            parseL idPrefix outerCount lines

        SMarkdownLang ->
            parseX idPrefix outerCount lines


parseM : String -> Int -> List String -> List (RoseTree.Tree.Tree ExpressionBlock)
parseM idPrefix outerCount lines =
    Generic.Compiler.parse_ EnclosureLang M.PrimitiveBlock.parse M.Expression.parse idPrefix outerCount lines


parseX : String -> Int -> List String -> List (RoseTree.Tree.Tree ExpressionBlock)
parseX idPrefix outerCount lines =
    Generic.Compiler.parse_ SMarkdownLang XMarkdown.PrimitiveBlock.parse XMarkdown.Expression.parse idPrefix outerCount lines


{-| =
-}
px : String -> List (RoseTree.Tree.Tree ExpressionBlock)
px str =
    parseX "!!" 0 (String.lines str)


{-|

    > pl str = parseL "!!" (String.lines str) |> Result.map (F.map simplifyExpressionBlock)

-}
parseL : String -> Int -> List String -> Forest ExpressionBlock
parseL idPrefix outerCount lines =
    Generic.Compiler.parse_ MicroLaTeXLang MicroLaTeX.PrimitiveBlock.parse MicroLaTeX.Expression.parse idPrefix outerCount lines



-- M compiler


{-| -}
type alias CompilerOutput =
    { body : List (Element MarkupMsg)
    , banner : Maybe (Element MarkupMsg)
    , toc : List (Element MarkupMsg)
    , title : Element MarkupMsg
    }


{-| -}
ps : String -> Forest ExpressionBlock
ps str =
    parseM Config.idPrefix 0 (String.lines str)


pl : String -> Forest ExpressionBlock
pl str =
    parseL Config.idPrefix 0 (String.lines str)


{-| -}
filterForest : Filter -> Forest ExpressionBlock -> Forest ExpressionBlock
filterForest filter forest =
    case filter of
        NoFilter ->
            forest

        SuppressDocumentBlocks ->
            forest
                |> Generic.ASTTools.filterForestOnLabelNames (\name -> name /= Just "document")
                |> Generic.ASTTools.filterForestOnLabelNames (\name -> name /= Just "title")


filterForest2 : Forest ExpressionBlock -> Forest ExpressionBlock
filterForest2 forest =
    forest
        |> Generic.ASTTools.filterForestOnLabelNames (\name -> name /= Just "document")
        |> Generic.ASTTools.filterForestOnLabelNames (\name -> name /= Just "title")


compileM : CompilerParameters -> List String -> CompilerOutput
compileM params lines =
    render params (filterForest params.filter (parseM Config.idPrefix params.editCount lines))


compileX : CompilerParameters -> List String -> CompilerOutput
compileX params lines =
    render params (filterForest params.filter (parseX Config.idPrefix params.editCount lines))



-- LaTeX compiler


compileL : CompilerParameters -> List String -> CompilerOutput
compileL params lines =
    render params (filterForest params.filter (parseL Config.idPrefix params.editCount lines))


{-|

    render width selectedId counter forest

type alias ViewParameters =
{ idsOfOpenNodes : List String
, selectedId : String
, counter : Int
, attr : List (Element.Attribute MarkupMsg)
, settings : Render.Settings.RenderSettings
}

-}
render : CompilerParameters -> Forest ExpressionBlock -> CompilerOutput
render params forest_ =
    let
        renderSettings =
            Generic.Compiler.defaultRenderSettings params.docWidth params.selectedId

        ( accumulator, forest ) =
            Generic.Acc.transformAccumulate Generic.Acc.initialData forest_

        viewParameters =
            { idsOfOpenNodes = params.idsOfOpenNodes
            , selectedId = params.selectedId
            , counter = params.editCount
            , attr = []
            , settings = renderSettings
            }

        toc : List (Element MarkupMsg)
        toc =
            -- this value is used in DemoTOC for the document TOC
            -- it is NOT used for the documentTOC in Lamdera
            --Render.TOCTree.view viewParameters accumulator forest_
            Render.TOCTree.view viewParameters accumulator forest_

        banner : Maybe (Element MarkupMsg)
        banner =
            Generic.ASTTools.banner forest
                |> Maybe.map (Render.Block.renderBody params.editCount accumulator renderSettings [ Font.color (Element.rgb 1 0 0) ])
                |> Maybe.map (Element.row [ Element.height (Element.px 40) ])

        title : Element MarkupMsg
        title =
            Element.paragraph [] [ Element.text <| Generic.ASTTools.title forest ]
    in
    { body =
        renderForest params.editCount renderSettings accumulator forest
    , banner = banner
    , toc = toc
    , title = title
    }


{-|

    renderForest count renderSettings accumulator

-}
renderForest : Int -> Render.Settings.RenderSettings -> Generic.Acc.Accumulator -> List (RoseTree.Tree.Tree ExpressionBlock) -> List (Element MarkupMsg)
renderForest count renderSettings accumulator =
    List.map (Render.Tree.renderTree count accumulator renderSettings [])



--
